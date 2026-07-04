<#
.SYNOPSIS
    Installs this repo's AI config (skills + shared memory) into each tool's
    expected location using symbolic links, driven by config/links.psd1.

.DESCRIPTION
    The repo is the single source of truth. Destinations (~/.claude, ~/.codex,
    ...) become symlinks pointing back into the repo, so one edit reaches every
    tool. Only skills and the shared memory file are linked; tool settings are
    left machine-local.

    State handling per target:
      - missing            -> create link
      - correct link       -> skip (idempotent)
      - wrong link         -> prompt (unless -Force), then replace link-only
      - real file / dir    -> prompt (unless -Force), back up, then replace

.PARAMETER Model
    One or more model keys to sync, restricted to models enabled in the
    manifest. A requested model that is disabled (Enabled = $false) is skipped
    with a warning. Default: every enabled model. Whether a model can be linked
    at all is controlled solely by its Enabled flag in the manifest.

.PARAMETER Force
    Replace conflicting targets (wrong links or real files/dirs) without asking.

.PARAMETER Unlink
    Remove managed symlinks instead of creating them (uninstall). Real files are
    never touched.

.EXAMPLE
    ./Sync-AiConfig.ps1 -WhatIf
    Preview every action without changing anything.

.EXAMPLE
    ./Sync-AiConfig.ps1 -Model codex
    Sync only the Codex links.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [string[]]$Model,
    [switch]$Force,
    [switch]$Unlink
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $RepoRoot 'config/links.psd1'
$BackupRoot = Join-Path $RepoRoot ('backups/{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

Import-Module (Join-Path $PSScriptRoot 'lib/Symlink.psm1') -Force

function Expand-ConfigPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [hashtable]$Tokens = @{}
    )

    foreach ($name in $Tokens.Keys) {
        $Path = $Path.Replace(('{{{0}}}' -f $name), $Tokens[$name])
    }
    if ($Path -like '~*') {
        $Path = $HOME + $Path.Substring(1)
    }
    $Path = [System.Environment]::ExpandEnvironmentVariables($Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Resolve-LinkPairs {
    <# Turns one manifest link into concrete source/target pairs. #>
    param(
        [Parameter(Mandatory)][hashtable]$Link,
        [Parameter(Mandatory)][hashtable]$Tokens
    )

    $source = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Link.Source))
    $target = Expand-ConfigPath -Path $Link.Target -Tokens $Tokens

    switch ($Link.Type) {
        'children' {
            if (-not (Test-Path -LiteralPath $source)) {
                Write-Warning "Source folder not found, skipping: $source"
                return @()
            }
            Get-ChildItem -LiteralPath $source -Force | ForEach-Object {
                [pscustomobject]@{
                    Source = $_.FullName
                    Target = Join-Path $target $_.Name
                }
            }
        }
        default {
            [pscustomobject]@{ Source = $source; Target = $target }
        }
    }
}

# --- Load manifest -----------------------------------------------------------

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}
$manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath

$tokens = @{}
foreach ($name in $manifest.Roots.Keys) {
    $tokens[$name] = Expand-ConfigPath -Path $manifest.Roots[$name]
}

# --- Select models -----------------------------------------------------------

$allModels = @($manifest.Models.Keys)
$enabledModels = @($allModels | Where-Object { $manifest.Models[$_].Enabled })

if ($Model) {
    foreach ($m in $Model) {
        if ($allModels -notcontains $m) {
            throw "Unknown model '$m'. Available: $($allModels -join ', ')"
        }
        if ($enabledModels -notcontains $m) {
            Write-Warning "Model '$m' is disabled in the manifest; skipping. Set Enabled = `$true to sync it."
        }
    }
    $selected = @($Model | Where-Object { $enabledModels -contains $_ })
}
else {
    $selected = $enabledModels
}

if (-not $selected) {
    Write-Warning 'No enabled models to sync. Set Enabled = $true in the manifest.'
    return
}

# --- Capability preflight ----------------------------------------------------

if (-not (Test-SymlinkCapability)) {
    $message = @'
Cannot create symbolic links on this machine. Run this script from an elevated (Administrator) PowerShell session
'@
    if ($WhatIfPreference) {
        Write-Warning $message
    }
    else {
        throw $message
    }
}

# --- Sync --------------------------------------------------------------------

$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param([string]$Model, [string]$Target, [string]$Status, [string]$Note = '')
    $results.Add([pscustomobject]@{
            Model  = $Model
            Target = $Target
            Status = $Status
            Note   = $Note
        })
}

foreach ($modelName in $selected) {
    foreach ($link in $manifest.Models[$modelName].Links) {
        foreach ($pair in (Resolve-LinkPairs -Link $link -Tokens $tokens)) {

            $source = $pair.Source
            $target = $pair.Target

            try {
                if (-not (Test-Path -LiteralPath $source)) {
                    Add-Result $modelName $target 'Failed' "source missing: $source"
                    continue
                }

                $isLink = Test-IsSymlink -Path $target
                $present = $isLink -or (Test-Path -LiteralPath $target)

                # --- Unlink mode: remove managed links only ------------------
                if ($Unlink) {
                    if (-not $isLink) {
                        Add-Result $modelName $target 'Skipped' 'not a link'
                        continue
                    }
                    if ($PSCmdlet.ShouldProcess($target, 'Remove managed link')) {
                        if ($Force -or $PSCmdlet.ShouldContinue('Remove this symlink?', "Remove: $target")) {
                            Remove-LinkOnly -Path $target
                            Add-Result $modelName $target 'Unlinked'
                        }
                        else {
                            Add-Result $modelName $target 'Skipped' 'declined'
                        }
                    }
                    continue
                }

                # --- Missing: create -----------------------------------------
                if (-not $present) {
                    if ($PSCmdlet.ShouldProcess($target, "Link -> $source")) {
                        New-ConfigLink -Path $target -Target $source
                        Add-Result $modelName $target 'Created'
                    }
                    continue
                }

                # --- Already a link ------------------------------------------
                if ($isLink) {
                    if (Test-LinkPointsTo -Path $target -Target $source) {
                        Add-Result $modelName $target 'Skipped' 'already correct'
                        continue
                    }
                    if ($PSCmdlet.ShouldProcess($target, "Replace wrong link -> $source")) {
                        if ($Force -or $PSCmdlet.ShouldContinue('Link points elsewhere. Replace it?', "Replace: $target")) {
                            Remove-LinkOnly -Path $target
                            New-ConfigLink -Path $target -Target $source
                            Add-Result $modelName $target 'Updated' 'was wrong link'
                        }
                        else {
                            Add-Result $modelName $target 'Skipped' 'declined'
                        }
                    }
                    continue
                }

                # --- Real file / directory: back up then replace -------------
                if ($PSCmdlet.ShouldProcess($target, "Back up and replace with link -> $source")) {
                    if ($Force -or $PSCmdlet.ShouldContinue('A real file/folder exists here. Back it up and replace with a link?', "Replace: $target")) {
                        $backup = Backup-ExistingTarget -Path $target -BackupRoot $BackupRoot
                        New-ConfigLink -Path $target -Target $source
                        Add-Result $modelName $target 'Backed-up' "-> $backup"
                    }
                    else {
                        Add-Result $modelName $target 'Skipped' 'declined'
                    }
                }
            }
            catch {
                Add-Result $modelName $target 'Failed' $_.Exception.Message
            }
        }
    }
}

# --- Summary -----------------------------------------------------------------

Write-Host ''
if ($results.Count -eq 0) {
    if ($WhatIfPreference) {
        Write-Host '(dry run) See the "What if:" lines above for the planned actions. No changes made.'
    }
    else {
        Write-Host 'Nothing to do.'
    }
    return
}

$results | Sort-Object Model, Target | Format-Table -AutoSize Model, Status, Target, Note

$summary = $results | Group-Object Status | ForEach-Object { '{0}: {1}' -f $_.Name, $_.Count }
Write-Host ''
Write-Host ("Summary  " + ($summary -join '   '))
if ($results.Status -contains 'Backed-up') {
    Write-Host "Backups  $BackupRoot"
}
