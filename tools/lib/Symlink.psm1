Set-StrictMode -Version Latest

function Test-SymlinkCapability {
    <#
        Probes whether this session can actually create a symlink by trying to
        make (and delete) one in the temp folder. This tests the real
        capability instead of guessing from Developer Mode / admin heuristics.
    #>
    [CmdletBinding()]
    param()

    $probeLink = Join-Path $env:TEMP ('symlink-probe-{0}' -f [Guid]::NewGuid().ToString('N'))
    $probeTarget = Join-Path $env:TEMP ('symlink-probe-target-{0}' -f [Guid]::NewGuid().ToString('N'))

    try {
        New-Item -ItemType File -Path $probeTarget -Force | Out-Null
        New-Item -ItemType SymbolicLink -Path $probeLink -Target $probeTarget -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
    finally {
        if (Test-IsSymlink -Path $probeLink) {
            Remove-LinkOnly -Path $probeLink
        }
        if (Test-Path -LiteralPath $probeTarget) {
            Remove-Item -LiteralPath $probeTarget -Force
        }
    }
}

function Test-IsSymlink {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    try {
        $attributes = [System.IO.File]::GetAttributes($Path)
        return [bool]($attributes -band [System.IO.FileAttributes]::ReparsePoint)
    }
    catch {
        return $false
    }
}

function Get-LinkTarget {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $target = $item.Target
    if ($null -eq $target) {
        return $null
    }
    if ($target -is [array]) {
        $target = $target[0]
    }
    return [string]$target
}

function Test-LinkPointsTo {
    <# True when the symlink at Path already resolves to the intended source. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Target
    )

    if (-not (Test-IsSymlink -Path $Path)) {
        return $false
    }

    $current = Get-LinkTarget -Path $Path
    if ([string]::IsNullOrEmpty($current)) {
        return $false
    }

    $currentFull = [System.IO.Path]::GetFullPath($current).TrimEnd('\', '/')
    $targetFull = [System.IO.Path]::GetFullPath($Target).TrimEnd('\', '/')
    return $currentFull -ieq $targetFull
}

function Remove-LinkOnly {
    <#
        Deletes the symlink itself without following it. Never touches the
        content the link points at (no recursion into the target).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-IsSymlink -Path $Path)) {
        throw "Refusing to remove '$Path' as a link: it is not a symlink."
    }

    $attributes = [System.IO.File]::GetAttributes($Path)
    if ($attributes -band [System.IO.FileAttributes]::Directory) {
        [System.IO.Directory]::Delete($Path, $false)
    }
    else {
        [System.IO.File]::Delete($Path)
    }
}

function Backup-ExistingTarget {
    <#
        Moves a real file/dir out of the way into BackupRoot, preserving its
        name. Returns the backup path. Must not be called on a symlink.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$BackupRoot
    )

    if (-not (Test-Path -LiteralPath $BackupRoot)) {
        New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    }

    $leaf = Split-Path -Leaf $Path
    $destination = Join-Path $BackupRoot $leaf
    if (Test-Path -LiteralPath $destination) {
        $destination = Join-Path $BackupRoot ("{0}.{1}" -f $leaf, [Guid]::NewGuid().ToString('N').Substring(0, 8))
    }

    Move-Item -LiteralPath $Path -Destination $destination -Force
    return $destination
}

function New-ConfigLink {
    <# Creates a symlink at Path pointing to Target (file or directory). #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Target
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    New-Item -ItemType SymbolicLink -Path $Path -Target $Target -ErrorAction Stop | Out-Null
}

Export-ModuleMember -Function `
    Test-SymlinkCapability, Test-IsSymlink, `
    Get-LinkTarget, Test-LinkPointsTo, Remove-LinkOnly, `
    Backup-ExistingTarget, New-ConfigLink
