<#
.SYNOPSIS
    Compiles an AL project with alc.exe, locating the compiler automatically.

.DESCRIPTION
    Single entry point for building an AL app. It scans the VS Code extensions
    folder and picks the newest installed AL Language extension with alc.exe.
    With -UseCodeAnalyzers, reads project .vscode/settings.json (JSONC), never AL-Go.
    Resolves analyzer names locally; it never installs or downloads analyzers.

    The output .app file name defaults to "<Publisher>_<Name>_<Version>.app"
    read from the project's app.json, matching the usual AL naming convention.

.EXAMPLE
    Build-AlApp.ps1 -ProjectDir "C:\repo\Test"

.EXAMPLE
    Build-AlApp.ps1 -ProjectDir "C:\repo\Test" -OutputFile "C:\out\test.app" `
        -PackageCachePath "C:\repo\Test\.alpackages"

.EXAMPLE
    Build-AlApp.ps1 -ProjectDir "C:\repo\App" -UseCodeAnalyzers -Quiet
#>
[CmdletBinding()]
param(
    # Absolute path to the AL project folder (must contain app.json).
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    # Output .app file. Defaults to "<Publisher>_<Name>_<Version>.app" in ProjectDir.
    [string]$OutputFile,

    # Symbol/package cache. Defaults to "<ProjectDir>\.alpackages".
    [string]$PackageCachePath,

    # Opt in to analyzers and ruleset from ProjectDir\.vscode\settings.json.
    [switch]$UseCodeAnalyzers,

    # Extra compiler options. Analyzer/ruleset options must come from VS Code settings.
    [string[]]$AdditionalArgs = @(),

    # Suppress verbose output, but retain file count and warning/error diagnostics.
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Resolve-AlcPath {
    $extensionsRoot = Join-Path $env:USERPROFILE ".vscode\extensions"
    $newest = Get-ChildItem -LiteralPath $extensionsRoot -Directory -Filter "ms-dynamics-smb.al-*" -ErrorAction SilentlyContinue |
    ForEach-Object {
        $numericVersion = (($_.Name -replace '^ms-dynamics-smb\.al-', '') -split '-')[0]
        try { $v = [version]$numericVersion } catch { $v = [version]"0.0.0.0" }
        [pscustomobject]@{
            Version = $v
            AlcPaths = @(
                (Join-Path $_.FullName "bin\alc.exe"),
                (Join-Path $_.FullName "bin\win32\alc.exe")
            )
        }
    } |
    ForEach-Object {
        $candidate = $_
        for ($index = 0; $index -lt $candidate.AlcPaths.Count; $index++) {
            $alcPath = $candidate.AlcPaths[$index]
            if (Test-Path -LiteralPath $alcPath -PathType Leaf) {
                [pscustomobject]@{
                    Version = $candidate.Version
                    LayoutOrder = $index
                    AlcPath = $alcPath
                }
            }
        }
    } |
    Sort-Object @{ Expression = 'Version'; Descending = $true }, LayoutOrder |
    Select-Object -First 1

    if ($newest) { return $newest.AlcPath }

    throw "Could not locate alc.exe under $extensionsRoot. Install the AL Language extension."
}

function Read-VsCodeSettings {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "VS Code settings not found: $Path. -UseCodeAnalyzers requires project settings; AL-Go settings are not used."
    }
    $json = Get-Content -LiteralPath $Path -Raw
    # Preserve quoted strings (including URLs), removing only JSONC comment tokens.
    $json = [regex]::Replace($json, '(?s)"(?:\\.|[^"\\])*"|//[^\r\n]*|/\*.*?\*/', {
        param($match)
        if ($match.Value.StartsWith('"')) { return $match.Value }
        return [regex]::Replace($match.Value, '[^\r\n]', ' ')
    })
    $json = [regex]::Replace($json, '(?s)"(?:\\.|[^"\\])*"|,\s*(?=[}\]])', {
        param($match)
        if ($match.Value.StartsWith('"')) { return $match.Value }
        return ''
    })
    try {
        $settings = ConvertFrom-Json -InputObject $json -ErrorAction Stop
    }
    catch {
        throw "Invalid VS Code settings JSONC at ${Path}: $($_.Exception.Message)"
    }
    if ($null -eq $settings -or $settings -isnot [pscustomobject]) {
        throw "VS Code settings must be a JSONC object: $Path. A text file containing a path is not a settings file."
    }
    return $settings
}

function Resolve-ProjectPath {
    param([string]$Path, [string]$ProjectDirectory)

    $Path = $Path.Replace('${workspaceFolder}', $ProjectDirectory)
    if ($Path -match '\$\{') { throw "Unsupported VS Code path variable: $Path" }
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        $Path = Join-Path $ProjectDirectory $Path
    }
    return [System.IO.Path]::GetFullPath($Path)
}

function Resolve-CodeAnalyzer {
    param([string]$Name, [string]$CompilerPath, [string]$ProjectDirectory)

    if ([string]::IsNullOrWhiteSpace($Name)) { throw 'Analyzer name must not be empty.' }
    $compilerDirectory = Split-Path -Parent $CompilerPath
    # Standard analyzers live beside alc in current layouts, and in Analyzers in older ones.
    $searchDirectories = @(
        (Join-Path $compilerDirectory 'Analyzers'),
        $compilerDirectory,
        (Join-Path (Split-Path -Parent $compilerDirectory) 'Analyzers')
    )
    $builtIns = @{
        '${CodeCop}' = 'Microsoft.Dynamics.Nav.CodeCop.dll'
        '${UICop}' = 'Microsoft.Dynamics.Nav.UICop.dll'
        '${AppSourceCop}' = 'Microsoft.Dynamics.Nav.AppSourceCop.dll'
        '${PerTenantExtensionCop}' = 'Microsoft.Dynamics.Nav.PerTenantExtensionCop.dll'
    }
    $fileName = $null
    if ($builtIns.ContainsKey($Name)) {
        $fileName = $builtIns[$Name]
    }
    elseif ($Name.StartsWith('${analyzerFolder}')) {
        $fileName = $Name.Substring('${analyzerFolder}'.Length).TrimStart([char[]]'\/')
        if ([System.IO.Path]::GetFileName($fileName) -ne $fileName) {
            throw "Expected a DLL name after `${analyzerFolder}: $Name"
        }
    }
    elseif ($Name -notmatch '[\\/]' -and $Name -notmatch '\$\{') {
        # Also accept the DLL name itself, without a compiler-specific directory.
        $fileName = $Name
        if (-not $fileName.EndsWith('.dll', [System.StringComparison]::OrdinalIgnoreCase)) {
            $fileName = "Microsoft.Dynamics.Nav.$fileName.dll"
        }
    }
    else {
        $path = Resolve-ProjectPath -Path $Name -ProjectDirectory $ProjectDirectory
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
        throw "Analyzer '$Name' not found at '$path'. No analyzer was downloaded or installed."
    }
    foreach ($directory in $searchDirectories) {
        $path = Join-Path $directory $fileName
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            return (Resolve-Path -LiteralPath $path).Path
        }
    }
    throw "Analyzer '$Name' not found for the selected AL compiler. Searched: $($searchDirectories -join ', '). No analyzer was downloaded or installed."
}

if (-not [System.IO.Path]::IsPathRooted($ProjectDir)) {
    throw '-ProjectDir must be an absolute path.'
}
if (-not (Test-Path -LiteralPath $ProjectDir -PathType Container)) {
    throw "Project folder does not exist: $ProjectDir"
}
$ProjectDir = (Resolve-Path -LiteralPath $ProjectDir).Path

$appJsonPath = Join-Path $ProjectDir "app.json"
if (-not (Test-Path -LiteralPath $appJsonPath)) {
    throw "No app.json found in project folder: $ProjectDir"
}
$appJson = Get-Content -LiteralPath $appJsonPath -Raw | ConvertFrom-Json

$SettingsPath = $null
$settings = $null
if ($UseCodeAnalyzers) {
    $SettingsPath = Join-Path $ProjectDir '.vscode\settings.json'
    $settings = Read-VsCodeSettings -Path $SettingsPath
}

# Prevent legacy pass-through arguments from silently overriding VS Code configuration.
foreach ($argument in $AdditionalArgs) {
    if ($argument -match '^[/-](analyzer|ruleset):') {
        throw 'Use -UseCodeAnalyzers with al.codeAnalyzers and al.ruleSetPath in project VS Code settings, not -AdditionalArgs.'
    }
}

if (-not $PackageCachePath) {
    $PackageCachePath = Join-Path $ProjectDir ".alpackages"
}
$PackageCachePath = Resolve-ProjectPath -Path $PackageCachePath -ProjectDirectory $ProjectDir
if (-not (Test-Path -LiteralPath $PackageCachePath -PathType Container)) {
    throw "Package cache not found: $PackageCachePath. No dependencies were downloaded."
}

if (-not $OutputFile) {
    $appFileName = "{0}_{1}_{2}.app" -f $appJson.publisher, $appJson.name, $appJson.version
    $OutputFile = Join-Path $ProjectDir $appFileName
}
$OutputFile = Resolve-ProjectPath -Path $OutputFile -ProjectDirectory $ProjectDir

$alc = Resolve-AlcPath
$compilerArgs = @("/project:$ProjectDir", "/packagecachepath:$PackageCachePath", "/out:$OutputFile")
$analysisEnabled = [bool]$UseCodeAnalyzers
$resolvedAnalyzers = @()
if ($analysisEnabled) {
    $analyzerProperty = $settings.PSObject.Properties['al.codeAnalyzers']
    if (-not $analyzerProperty -or $analyzerProperty.Value -isnot [array]) {
        throw '-UseCodeAnalyzers requires an al.codeAnalyzers array in project VS Code settings.'
    }
    foreach ($name in $analyzerProperty.Value) {
        $path = Resolve-CodeAnalyzer -Name $name -CompilerPath $alc -ProjectDirectory $ProjectDir
        if ($resolvedAnalyzers -notcontains $path) {
            $resolvedAnalyzers += $path
            $compilerArgs += "/analyzer:$path"
        }
    }
}
$ruleSetProperty = $null
if ($analysisEnabled) { $ruleSetProperty = $settings.PSObject.Properties['al.ruleSetPath'] }
if ($analysisEnabled -and $ruleSetProperty -and $ruleSetProperty.Value) {
    $ruleSetPath = [string]$ruleSetProperty.Value
    if ($ruleSetPath -match '^https?://') {
        $externalProperty = $settings.PSObject.Properties['al.enableExternalRulesets']
        if ($externalProperty -and $externalProperty.Value -eq $false) {
            throw 'al.ruleSetPath is a URL but al.enableExternalRulesets is false.'
        }
        # Preserve the configured URL. Do not fetch or replace it with a made-up local ruleset.
    }
    else {
        $ruleSetPath = Resolve-ProjectPath -Path $ruleSetPath -ProjectDirectory $ProjectDir
        if (-not (Test-Path -LiteralPath $ruleSetPath -PathType Leaf)) {
            throw "VS Code ruleset not found: $ruleSetPath"
        }
    }
    $compilerArgs += "/ruleset:$ruleSetPath"
}
$compilerArgs += $AdditionalArgs

if (-not $Quiet) {
    Write-Host "Compiler : $alc"
    Write-Host "Project  : $ProjectDir"
    Write-Host "Settings : $SettingsPath"
    Write-Host "Analyzers: $($resolvedAnalyzers -join ', ')"
    Write-Host "Cache    : $PackageCachePath"
    Write-Host "Output   : $OutputFile"
}

if ($Quiet) {
    $buildOutput = & $alc @compilerArgs
    $exitCode = $LASTEXITCODE
    $diagnostics = @($buildOutput | Where-Object { $_ -match ': (error|warning) ' })
    $buildOutput | Where-Object { $_ -match "containing '\d+' files" }
    if ($diagnostics.Count -gt 0) { $diagnostics }
    if ($exitCode -ne 0 -and $diagnostics.Count -eq 0) {
        $buildOutput
    }
}
else {
    & $alc @compilerArgs
    $exitCode = $LASTEXITCODE
}

if ($exitCode -eq 0) {
    Write-Host "BUILD OK: $OutputFile"
}
else {
    Write-Host "BUILD FAILED (alc exit code $exitCode)"
}
exit $exitCode
