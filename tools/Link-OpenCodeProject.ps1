<#
.SYNOPSIS
    Links a project's .opencode folder to the shared OpenCode agent bundle.

.DESCRIPTION
    Creates <ProjectPath>/.opencode as a symbolic link to this repository's
    linked/agents/.opencode. If another .opencode target exists,
    the script asks whether to replace it.

.PARAMETER ProjectPath
    Existing project directory in which to create the .opencode link.

.EXAMPLE
    ./tools/Link-OpenCodeProject.ps1 -ProjectPath ../my-al-project -WhatIf

.EXAMPLE
    ./tools/Link-OpenCodeProject.ps1 -ProjectPath ../my-al-project

#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot 'linked/agents/.opencode'
Import-Module (Join-Path $PSScriptRoot 'lib/Symlink.psm1') -Force

function Remove-ExistingConfig {
    param([Parameter(Mandatory)][string]$Path)

    # Remove nested links themselves, never the content they point at.
    if (Test-IsSymlink -Path $Path) {
        Remove-LinkOnly -Path $Path
    }
    elseif (Test-Path -LiteralPath $Path -PathType Container) {
        foreach ($child in (Get-ChildItem -LiteralPath $Path -Force)) {
            Remove-ExistingConfig -Path $child.FullName
        }
        Remove-Item -LiteralPath $Path -Force
    }
    else {
        Remove-Item -LiteralPath $Path -Force
    }
}

if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
    throw "Shared OpenCode folder not found: $sourcePath"
}
if (-not (Test-Path -LiteralPath (Join-Path $sourcePath 'agents/orchestrator.md') -PathType Leaf)) {
    throw "The shared OpenCode folder has no orchestrator definition: $sourcePath"
}
if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
    throw "Project directory does not exist: $ProjectPath"
}

$project = Get-Item -LiteralPath $ProjectPath -Force
if ($project.PSProvider.Name -ne 'FileSystem') {
    throw '-ProjectPath must be a filesystem directory.'
}
$ProjectPath = $project.FullName
$sourcePath = (Resolve-Path -LiteralPath $sourcePath).ProviderPath
$linkPath = Join-Path $ProjectPath '.opencode'
$sourceFull = [System.IO.Path]::GetFullPath($sourcePath).TrimEnd('\', '/')
$linkFull = [System.IO.Path]::GetFullPath($linkPath).TrimEnd('\', '/')
$comparison = [StringComparison]::OrdinalIgnoreCase
if ($sourceFull.Equals($linkFull, $comparison) -or
    $sourceFull.StartsWith($linkFull + [System.IO.Path]::DirectorySeparatorChar, $comparison) -or
    $linkFull.StartsWith($sourceFull + [System.IO.Path]::DirectorySeparatorChar, $comparison)) {
    throw 'The target .opencode folder must not overlap the shared source folder.'
}

$isLink = Test-IsSymlink -Path $linkPath
$present = $isLink -or (Test-Path -LiteralPath $linkPath)
$result = [ordered]@{
    ProjectPath = $ProjectPath
    LinkPath    = $linkPath
    SourcePath  = $sourcePath
    Status      = 'AlreadyLinked'
}

$previousTarget = $null
if ($isLink) {
    $previousTarget = Get-LinkTarget -Path $linkPath
    if (-not [string]::IsNullOrEmpty($previousTarget)) {
        if (-not [System.IO.Path]::IsPathRooted($previousTarget)) {
            $previousTarget = Join-Path $ProjectPath $previousTarget
        }
        $previousFull = [System.IO.Path]::GetFullPath($previousTarget).TrimEnd('\', '/')
        if ($previousFull.Equals($sourceFull, $comparison)) {
            Write-Host "The .opencode link already points to the shared bundle: $linkPath"
            return [pscustomobject]$result
        }
    }
}
if (-not $PSCmdlet.ShouldProcess($linkPath, "Create symbolic link to $sourcePath")) {
    $result.Status = 'NotChanged'
    return [pscustomobject]$result
}
if ($present) {
    Write-Host "The .opencode target already exists: $linkPath"
    $replaceExisting = $PSCmdlet.ShouldContinue(
        'Replace it with the shared .opencode link? Existing contents will be removed without a backup.',
        'Replace existing .opencode'
    )
    if (-not $replaceExisting) {
        Write-Host 'The existing .opencode target was left unchanged.'
        $result.Status = 'NotChanged'
        return [pscustomobject]$result
    }
}
if (-not (Test-SymlinkCapability)) {
    throw 'Cannot create symbolic links. Enable the required Windows capability or run PowerShell as Administrator.'
}

if ($isLink) {
    if ([string]::IsNullOrEmpty($previousTarget)) {
        throw "Cannot read the existing link target: $linkPath"
    }
    Remove-LinkOnly -Path $linkPath
}
elseif ($present) {
    Remove-ExistingConfig -Path $linkPath
}

try {
    New-ConfigLink -Path $linkPath -Target $sourcePath
}
catch {
    if (-not ((Test-IsSymlink -Path $linkPath) -or (Test-Path -LiteralPath $linkPath))) {
        if ($previousTarget) {
            New-ConfigLink -Path $linkPath -Target $previousTarget
        }
    }
    throw
}

$result.Status = if ($isLink) { 'Relinked' } elseif ($present) { 'Replaced' } else { 'Created' }
[pscustomobject]$result
