<#
.SYNOPSIS
    Runs a focused AL test codeunit through Business Central SaaS TestRunnerHub.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TestDir,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$CodeunitId,

    [string[]]$TestMethods,

    [string]$LaunchConfiguration,

    # Writes the complete altool output to a log file and prints a compact test summary.
    [switch]$Quiet,

    # Optional destination for the complete altool output when -Quiet is specified.
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'

function Get-QuietLogPath {
    param([string]$ProjectDirectory)

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logDirectory = Join-Path $ProjectDirectory '.altool-logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    Join-Path $logDirectory "altool-tests-$timestamp.log"
}

function Write-QuietTestSummary {
    param(
        [string[]]$Output,
        [bool]$Succeeded
    )

    $summary = $Output | Where-Object {
        $_ -match '^===== Codeunit ' -or
        $_ -match '^Test run completed:' -or
        $_ -match '^Results:' -or
        $_ -match '^  (PASS|FAIL|SKIP) '
    }
    if ($summary) {
        $summary | ForEach-Object { Write-Host $_ }
        return
    }

    if (-not $Succeeded) {
        $meaningfulOutput = $Output | Where-Object {
            $_ -notmatch '^\[MSAL\]' -and
            $_ -notmatch '^\[LogMetricsFromAuthResult\]'
        }
        $meaningfulOutput | Select-Object -Last 40 | ForEach-Object { Write-Host $_ }
    }
}

function Resolve-AltoolPath {
    $extensionsRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
    $candidates = @(
        Get-ChildItem -LiteralPath $extensionsRoot -Directory -Filter 'ms-dynamics-smb.al-*' -ErrorAction SilentlyContinue |
        ForEach-Object {
            $numericVersion = (($_.Name -replace '^ms-dynamics-smb\.al-', '') -split '-')[0]
            try { $version = [version]$numericVersion } catch { $version = [version]'0.0.0.0' }
            $paths = @(
                (Join-Path $_.FullName 'bin\altool.exe'),
                (Join-Path $_.FullName 'bin\win32\altool.exe')
            )
            for ($index = 0; $index -lt $paths.Count; $index++) {
                if (Test-Path -LiteralPath $paths[$index] -PathType Leaf) {
                    [pscustomobject]@{
                        Version = $version
                        LayoutOrder = $index
                        Path = $paths[$index]
                    }
                }
            }
        }
    )

    $altool = $candidates | Sort-Object @{ Expression = 'Version'; Descending = $true }, LayoutOrder | Select-Object -First 1
    if (-not $altool) {
        throw "Could not locate altool.exe under $extensionsRoot. Install the AL Language extension."
    }

    return $altool.Path
}

function Resolve-DotNetRuntimePath {
    $runtimeRoot = Join-Path $env:APPDATA 'Code\User\globalStorage\ms-dotnettools.vscode-dotnet-runtime\.dotnet'
    $candidates = @(
        Get-ChildItem -LiteralPath $runtimeRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like '*~x64~aspnetcore' -and
            (Test-Path -LiteralPath (Join-Path $_.FullName 'dotnet.exe') -PathType Leaf)
        } |
        ForEach-Object {
            $numericVersion = ($_.Name -split '~')[0]
            try { $version = [version]$numericVersion } catch { $version = [version]'0.0.0.0' }
            [pscustomobject]@{
                Version = $version
                Path = $_.FullName
            }
        }
    )

    $runtime = $candidates | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $runtime) {
        throw "Could not locate an x64 ASP.NET Core runtime supplied by the VS Code .NET Runtime extension under $runtimeRoot. Install that VS Code extension; do not install a separate runtime."
    }

    return $runtime.Path
}

function ConvertFrom-Jsonc {
    param([string]$Json)

    $withoutComments = New-Object System.Text.StringBuilder
    $inString = $false
    $escaped = $false
    $inLineComment = $false
    $inBlockComment = $false

    for ($index = 0; $index -lt $Json.Length; $index++) {
        $character = $Json[$index]
        $nextCharacter = if ($index + 1 -lt $Json.Length) { $Json[$index + 1] } else { [char]0 }

        if ($inLineComment) {
            if ($character -eq "`r" -or $character -eq "`n") {
                $inLineComment = $false
                [void]$withoutComments.Append($character)
            }
            continue
        }
        if ($inBlockComment) {
            if ($character -eq '*' -and $nextCharacter -eq '/') {
                $inBlockComment = $false
                $index++
            }
            continue
        }
        if ($inString) {
            [void]$withoutComments.Append($character)
            if ($escaped) {
                $escaped = $false
            }
            elseif ($character -eq [char]92) {
                $escaped = $true
            }
            elseif ($character -eq '"') {
                $inString = $false
            }
            continue
        }
        if ($character -eq '"') {
            $inString = $true
            [void]$withoutComments.Append($character)
            continue
        }
        if ($character -eq '/' -and $nextCharacter -eq '/') {
            $inLineComment = $true
            $index++
            continue
        }
        if ($character -eq '/' -and $nextCharacter -eq '*') {
            $inBlockComment = $true
            $index++
            continue
        }
        [void]$withoutComments.Append($character)
    }

    $withoutTrailingCommas = New-Object System.Text.StringBuilder
    $jsonWithoutComments = $withoutComments.ToString()
    $inString = $false
    $escaped = $false
    for ($index = 0; $index -lt $jsonWithoutComments.Length; $index++) {
        $character = $jsonWithoutComments[$index]
        if ($inString) {
            [void]$withoutTrailingCommas.Append($character)
            if ($escaped) {
                $escaped = $false
            }
            elseif ($character -eq [char]92) {
                $escaped = $true
            }
            elseif ($character -eq '"') {
                $inString = $false
            }
            continue
        }
        if ($character -eq '"') {
            $inString = $true
            [void]$withoutTrailingCommas.Append($character)
            continue
        }
        if ($character -eq ',') {
            $nextIndex = $index + 1
            while ($nextIndex -lt $jsonWithoutComments.Length -and [char]::IsWhiteSpace($jsonWithoutComments[$nextIndex])) {
                $nextIndex++
            }
            if ($nextIndex -lt $jsonWithoutComments.Length -and ($jsonWithoutComments[$nextIndex] -eq '}' -or $jsonWithoutComments[$nextIndex] -eq ']')) {
                continue
            }
        }
        [void]$withoutTrailingCommas.Append($character)
    }

    return ($withoutTrailingCommas.ToString() | ConvertFrom-Json)
}

function Get-LaunchConfiguration {
    param(
        [string]$Directory,
        [string]$Name
    )

    $launchPath = Join-Path $Directory '.vscode\launch.json'
    if (-not (Test-Path -LiteralPath $launchPath -PathType Leaf)) {
        throw "No launch.json found: $launchPath"
    }

    $launchSettings = ConvertFrom-Jsonc -Json (Get-Content -LiteralPath $launchPath -Raw)
    $configurations = @($launchSettings.configurations)
    if ($configurations.Count -eq 0) {
        throw "No launch configurations found in $launchPath"
    }

    if ($Name) {
        $selected = @($configurations | Where-Object { $_.name -eq $Name })
        if ($selected.Count -ne 1) {
            throw "Launch configuration '$Name' was not found uniquely in $launchPath"
        }
        return $selected[0]
    }

    if ($configurations.Count -ne 1) {
        throw "Specify -LaunchConfiguration because $launchPath contains multiple configurations."
    }

    return $configurations[0]
}

function Get-RequiredLaunchValue {
    param(
        [object]$Configuration,
        [string]$Property,
        [string]$LaunchPath
    )

    $value = $Configuration.$Property
    if ([string]::IsNullOrWhiteSpace([string]$value)) {
        throw "SaaS launch configuration in $LaunchPath is missing '$Property'."
    }

    return [string]$value
}

if (-not [System.IO.Path]::IsPathRooted($TestDir)) {
    throw '-TestDir must be an absolute path.'
}
if (-not (Test-Path -LiteralPath $TestDir -PathType Container)) {
    throw "Test folder does not exist: $TestDir"
}
$TestDir = (Resolve-Path -LiteralPath $TestDir).Path

$appJsonPath = Join-Path $TestDir 'app.json'
if (-not (Test-Path -LiteralPath $appJsonPath -PathType Leaf)) {
    throw "No app.json found in test folder: $TestDir"
}

$launchPath = Join-Path $TestDir '.vscode\launch.json'
$configuration = Get-LaunchConfiguration -Directory $TestDir -Name $LaunchConfiguration
if ($configuration.type -ne 'al' -or $configuration.request -ne 'launch') {
    throw "Launch configuration '$($configuration.name)' in $launchPath is not an AL launch configuration."
}

$environmentType = Get-RequiredLaunchValue -Configuration $configuration -Property 'environmentType' -LaunchPath $launchPath
if ($environmentType -notin @('Sandbox', 'Production')) {
    throw "Launch configuration '$($configuration.name)' in $launchPath is not a SaaS target. environmentType must be Sandbox or Production."
}
$environmentName = Get-RequiredLaunchValue -Configuration $configuration -Property 'environmentName' -LaunchPath $launchPath
$authentication = Get-RequiredLaunchValue -Configuration $configuration -Property 'authentication' -LaunchPath $launchPath
if ($authentication -ne 'AAD') {
    throw "SaaS launch configuration '$($configuration.name)' in $launchPath must use AAD authentication."
}
$tenant = Get-RequiredLaunchValue -Configuration $configuration -Property 'tenant' -LaunchPath $launchPath

$altool = Resolve-AltoolPath
$dotnetRoot = Resolve-DotNetRuntimePath
$env:DOTNET_ROOT = $dotnetRoot
$env:PATH = "$dotnetRoot;$env:PATH"

$arguments = @(
    'runtests', [string]$CodeunitId,
    '--project', $TestDir,
    '--environmenttype', $environmentType,
    '--environmentname', $environmentName,
    '--authentication', $authentication,
    '--tenant', $tenant,
    '--raw'
)
if ($configuration.environment) {
    $arguments += @('--environment', [string]$configuration.environment)
}
if ($TestMethods -and $TestMethods.Count -gt 0) {
    $arguments += @('--testmethods', ($TestMethods -join ','))
}

Write-Host "Running codeunit: $CodeunitId"
Write-Host "Target         : $environmentType / $environmentName"
$nativeErrorPreference = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ValueOnly -ErrorAction SilentlyContinue
$previousErrorActionPreference = $ErrorActionPreference
if ($null -ne $nativeErrorPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}
try {
    $ErrorActionPreference = 'Continue'
    $output = @(& $altool @arguments 2>&1 | ForEach-Object { [string]$_ })
    $exitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
    if ($null -ne $nativeErrorPreference) {
        $PSNativeCommandUseErrorActionPreference = $nativeErrorPreference
    }
}
if ($Quiet) {
    if (-not $LogPath) {
        $LogPath = Get-QuietLogPath -ProjectDirectory $TestDir
    }
    $output | Set-Content -LiteralPath $LogPath
    Write-Host "Full log       : $LogPath"
    Write-QuietTestSummary -Output $output -Succeeded ($exitCode -eq 0)
}
else {
    $output | ForEach-Object { Write-Host $_ }
}
if ($exitCode -ne 0) {
    Write-Host "TEST RUN FAILED (altool exit code $exitCode)"
    exit $exitCode
}

Write-Host "TEST RUN OK: codeunit $CodeunitId"
exit 0
