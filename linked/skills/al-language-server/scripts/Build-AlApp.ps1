<#
.SYNOPSIS
    Compiles an AL project with alc.exe, locating the compiler automatically.

.DESCRIPTION
    Single entry point for building an AL app. It scans the VS Code extensions
    folder and picks the newest installed AL Language extension with alc.exe.

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
    [string[]]$AdditionalArgs = @(),

    # Suppress the header and alc's verbose stdout. On success prints only "BUILD OK";
    # on failure prints only the compiler error diagnostics.
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

if (-not $PackageCachePath) {
    $PackageCachePath = Join-Path $ProjectDir ".alpackages"
}

if (-not $OutputFile) {
    $appFileName = "{0}_{1}_{2}.app" -f $appJson.publisher, $appJson.name, $appJson.version
    $OutputFile = Join-Path $ProjectDir $appFileName
}

$alc = Resolve-AlcPath

if (-not $Quiet) {
    Write-Host "Compiler : $alc"
    Write-Host "Project  : $ProjectDir"
    Write-Host "Cache    : $PackageCachePath"
    Write-Host "Output   : $OutputFile"
}

if ($Quiet) {
    # Capture alc stdout: emit nothing on success, only the error diagnostics on failure.
    $buildOutput = & $alc "/project:$ProjectDir" "/packagecachepath:$PackageCachePath" "/out:$OutputFile" @AdditionalArgs
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $errs = $buildOutput | Where-Object { $_ -match ': error ' }
        if ($errs) { $errs } else { $buildOutput }
    }
}
else {
    & $alc "/project:$ProjectDir" "/packagecachepath:$PackageCachePath" "/out:$OutputFile" @AdditionalArgs
    $exitCode = $LASTEXITCODE
}

if ($exitCode -eq 0) {
    Write-Host "BUILD OK: $OutputFile"
}
else {
    Write-Host "BUILD FAILED (alc exit code $exitCode)"
}
exit $exitCode
