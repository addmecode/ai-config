<#
.SYNOPSIS
Runs AL unit tests headless against a BC container using the jamespearson.al-test-runner
extension, deriving every value from the test project itself.

.DESCRIPTION
Resolves ALTestRunner.psm1 by wildcard (version-agnostic), reads ExtensionId/ExtensionName
from the test project's app.json, and takes the first configuration from its launch.json.
Both files are parsed as JSONC (comments + trailing commas tolerated) because Windows
PowerShell 5.1's ConvertFrom-Json rejects them.

NOTE: the runner only executes tests against the app ALREADY published in the container; it
does not republish. Build and publish (see Publish-AlTestApp.ps1) before running.

The per-codeunit / per-function Success|Failure lines are printed to the console, which is
authoritative. A trailing "Copy-FileFromBcContainer: Access to the path is denied" while
copying the result XML is a BcContainerHelper permissions warning, not a test failure.

.PARAMETER TestDir
Absolute path to the test project folder (the one whose app.json has the Library Assert /
Test Runner dependencies and a .vscode\launch.json).

.PARAMETER FileName
Optional absolute path to a single *.Codeunit.al to run instead of the whole suite.
Requires -SelectionStart.

.PARAMETER SelectionStart
Optional line number of the test procedure to run when -FileName is given.

.PARAMETER ResultsPath
Where to write results. Defaults to <TestDir>\.altestrunner.

.EXAMPLE
.\Invoke-AlTests.ps1 -TestDir 'C:\proj\Test'

.EXAMPLE
.\Invoke-AlTests.ps1 -TestDir 'C:\proj\Test' `
    -FileName 'C:\proj\Test\src\Outbox\Foo.Codeunit.al' -SelectionStart 42
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $TestDir,
    [string] $FileName,
    [int] $SelectionStart,
    [string] $ResultsPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $TestDir)) { throw "Test dir not found: $TestDir" }
if (-not $ResultsPath) { $ResultsPath = Join-Path $TestDir '.altestrunner' }

function ConvertFrom-Jsonc([string]$Path) {
    $raw = Get-Content $Path -Raw
    $raw = [regex]::Replace($raw, '/\*.*?\*/', '', 'Singleline')   # block comments
    $raw = [regex]::Replace($raw, '(?m)^\s*//.*$', '')             # line comments
    $raw = [regex]::Replace($raw, ',(\s*[}\]])', '$1')             # trailing commas
    $raw | ConvertFrom-Json
}

$psm1 = Get-ChildItem "$env:USERPROFILE\.vscode\extensions\jamespearson.al-test-runner-*\PowerShell\ALTestRunner.psm1" -ErrorAction Stop |
        Sort-Object FullName -Descending | Select-Object -First 1
if ($null -eq (Get-Module ALTestRunner)) { Import-Module $psm1.FullName -DisableNameChecking }

$app        = ConvertFrom-Jsonc (Join-Path $TestDir 'app.json')
$cfg        = (ConvertFrom-Jsonc (Join-Path $TestDir '.vscode\launch.json')).configurations | Select-Object -First 1
$launchJson = $cfg | ConvertTo-Json -Compress -Depth 10

Set-Location $TestDir

if ($FileName) {
    if (-not $SelectionStart) { throw "-SelectionStart is required when -FileName is given." }
    Invoke-ALTestRunner -Tests Test -FileName $FileName -SelectionStart $SelectionStart `
        -ExtensionId $app.id -ExtensionName $app.name `
        -LaunchConfig $launchJson -ResultsPath $ResultsPath
}
else {
    Invoke-ALTestRunner -Tests All `
        -ExtensionId $app.id -ExtensionName $app.name `
        -LaunchConfig $launchJson -ResultsPath $ResultsPath
}
