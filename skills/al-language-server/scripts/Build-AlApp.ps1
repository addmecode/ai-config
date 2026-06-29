<#
.SYNOPSIS
    Compiles an AL project with alc.exe, locating the compiler automatically.

.DESCRIPTION
    Single entry point for building an AL app. It locates alc.exe by first
    checking a known-good default path, then scanning the VS Code extensions
    folder and picking the newest installed AL Language extension.

    The output .app file name defaults to "<Publisher>_<Name>_<Version>.app"
    read from the project's app.json, matching the usual AL naming convention.

.EXAMPLE
    Build-AlApp.ps1 -ProjectDir "C:\repo\Test"

.EXAMPLE
    Build-AlApp.ps1 -ProjectDir "C:\repo\Test" -OutputFile "C:\out\test.app" `
        -PackageCachePath "C:\repo\Test\.alpackages"
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

    # Extra arguments passed through to alc.exe (e.g. /ruleset:..., /analyzer:...).
    [string[]]$AdditionalArgs = @()
)

$ErrorActionPreference = 'Stop'

# Known-good alc.exe location, tried first before scanning the extensions folder.
$DefaultAlcPath = Join-Path $env:USERPROFILE ".vscode\extensions\ms-dynamics-smb.al-17.0.2273547\bin\win32\alc.exe"

function Resolve-AlcPath {
    param([string]$Default)

    if (Test-Path -LiteralPath $Default) {
        return $Default
    }

    $extensionsRoot = Join-Path $env:USERPROFILE ".vscode\extensions"
    $newest = Get-ChildItem -LiteralPath $extensionsRoot -Directory -Filter "ms-dynamics-smb.al-*" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $numericVersion = (($_.Name -replace '^ms-dynamics-smb\.al-', '') -split '-')[0]
            try { $v = [version]$numericVersion } catch { $v = [version]"0.0.0.0" }
            [pscustomobject]@{
                Version = $v
                AlcPath = Join-Path $_.FullName "bin\win32\alc.exe"
            }
        } |
        Where-Object { Test-Path -LiteralPath $_.AlcPath } |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if ($newest) { return $newest.AlcPath }

    throw "Could not locate alc.exe. Checked the default path ($Default) and $extensionsRoot. Install the AL Language extension."
}

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    throw "Project folder does not exist: $ProjectDir"
}

$appJsonPath = Join-Path $ProjectDir "app.json"
if (-not (Test-Path -LiteralPath $appJsonPath)) {
    throw "No app.json found in project folder: $ProjectDir"
}
$appJson = Get-Content -LiteralPath $appJsonPath -Raw | ConvertFrom-Json

if (-not $PackageCachePath) {
    $PackageCachePath = Join-Path $ProjectDir ".alpackages"
}

if (-not $OutputFile) {
    $appFileName = "{0}_{1}_{2}.app" -f $appJson.publisher, $appJson.name, $appJson.version
    $OutputFile = Join-Path $ProjectDir $appFileName
}

$alc = Resolve-AlcPath -Default $DefaultAlcPath

Write-Host "Compiler : $alc"
Write-Host "Project  : $ProjectDir"
Write-Host "Cache    : $PackageCachePath"
Write-Host "Output   : $OutputFile"

& $alc "/project:$ProjectDir" "/packagecachepath:$PackageCachePath" "/out:$OutputFile" @AdditionalArgs
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "BUILD OK: $OutputFile"
} else {
    Write-Host "BUILD FAILED (alc exit code $exitCode)"
}
exit $exitCode
