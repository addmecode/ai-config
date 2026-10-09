<#
.SYNOPSIS
    Copies a verified built App package into the dependent Test project's local cache.
.EXAMPLE
    Sync-AlAppDependency.ps1 -AppProjectDir "C:\repo\App" -TestProjectDir "C:\repo\Test"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$AppProjectDir,
    [Parameter(Mandatory = $true)][string]$TestProjectDir
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AlPackage.psm1') -Force
foreach ($path in @($AppProjectDir, $TestProjectDir)) {
    if (-not [IO.Path]::IsPathRooted($path)) { throw 'Project paths must be absolute.' }
}
$app = Get-Content -LiteralPath (Join-Path $AppProjectDir 'app.json') -Raw | ConvertFrom-Json
$test = Get-Content -LiteralPath (Join-Path $TestProjectDir 'app.json') -Raw | ConvertFrom-Json
$dependencies = @($test.dependencies | Where-Object { [guid]$_.id -eq [guid]$app.id })
if ($dependencies.Count -ne 1) { throw 'Test must declare exactly one dependency on this App id; manifests were not changed.' }
$dependency = $dependencies[0]
if ($dependency.name -ne $app.name -or $dependency.publisher -ne $app.publisher -or
    [version]$app.version -lt [version]$dependency.version) {
    throw 'App identity/version does not satisfy the Test dependency; build or correct the manifests first.'
}
$fileName = '{0}_{1}_{2}.app' -f $app.publisher, $app.name, $app.version
if ([IO.Path]::GetFileName($fileName) -ne $fileName) { throw 'App metadata does not form a safe artifact filename.' }
$source = Join-Path (Resolve-Path -LiteralPath $AppProjectDir).Path $fileName
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Built App artifact missing: $source. Build App first." }
$sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
$package = Open-AlPackage -Path $source
try { $info = Get-AlPackageInfo -Package $package }
finally { Close-AlPackage -Package $package }
if ([guid]$info.Id -ne [guid]$app.id -or $info.Name -ne $app.name -or
    $info.Publisher -ne $app.publisher -or [version]$info.Version -ne [version]$app.version) {
    throw 'Built package metadata differs from App/app.json. Build App first; cache was not changed.'
}
if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $sourceHash) {
    throw 'App artifact changed while reading its metadata; cache was not changed.'
}
$cache = Join-Path (Resolve-Path -LiteralPath $TestProjectDir).Path '.alpackages'
$destination = Get-AlSourcePath -Root $cache -EntryName $fileName
if ((Test-Path -LiteralPath $destination -PathType Leaf) -and
    (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -eq $sourceHash) {
    Write-Host "SYNC SKIPPED: identical App package already cached: $destination"
    return
}
# Do not overwrite a different app that happens to have the same filename.
if (Test-Path -LiteralPath $destination -PathType Leaf) {
    $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    $existing = Open-AlPackage -Path $destination
    try { $existingInfo = Get-AlPackageInfo -Package $existing }
    finally { Close-AlPackage -Package $existing }
    if ($existingInfo.Id -ne $info.Id -or $existingInfo.Name -ne $info.Name -or
        $existingInfo.Publisher -ne $info.Publisher -or $existingInfo.Version -ne $info.Version) {
        throw 'Destination belongs to another package; it was not overwritten.'
    }
}
$null = New-Item -ItemType Directory -Force -Path $cache
$staging = Join-Path $cache ('.sync-' + [guid]::NewGuid().ToString('N'))
Copy-Item -LiteralPath $source -Destination $staging
if ((Get-FileHash -LiteralPath $staging -Algorithm SHA256).Hash -ne $sourceHash) {
    throw "App artifact changed during copying. Cache was not replaced; staging retained: $staging"
}
if (Test-Path -LiteralPath $destination) {
    if (-not $destinationHash -or (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $destinationHash) {
        throw "Destination changed during synchronization; it was not overwritten. Staging retained: $staging"
    }
    # PowerShell 5.1 otherwise converts $null to an invalid empty backup filename.
    [IO.File]::Replace($staging, $destination, [System.Management.Automation.Language.NullString]::Value)
}
else {
    if ($destinationHash) { throw 'Destination disappeared during synchronization; retry after checking the cache.' }
    [IO.File]::Move($staging, $destination)
}
Write-Host "SYNC OK: $destination (SHA256 $sourceHash)"
