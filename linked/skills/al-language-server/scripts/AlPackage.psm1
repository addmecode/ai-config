# Local NAVX/ZIP package helpers. No external tools, downloads or installations.
Add-Type -AssemblyName System.IO.Compression

function Open-AlPackage {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $offset = 0
    $length = $bytes.Length
    if ($length -ge 40 -and [Text.Encoding]::ASCII.GetString($bytes, 0, 4) -eq 'NAVX') {
        $offset = [BitConverter]::ToInt32($bytes, 4)
        $length = [BitConverter]::ToInt64($bytes, 28)
        if ($offset -lt 40 -or $length -le 0 -or $length -gt [int]::MaxValue -or
            [long]$offset + $length -gt $bytes.Length) {
            throw "Invalid NAVX payload bounds: $Path"
        }
    }
    if ($length -lt 4 -or $bytes[$offset] -ne 0x50 -or $bytes[$offset + 1] -ne 0x4b) {
        throw "Unsupported local .app format: $Path. No package was downloaded."
    }
    $stream = [IO.MemoryStream]::new($bytes, $offset, [int]$length, $false)
    try {
        $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read)
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') }
        finally { $sha.Dispose() }
        return [pscustomobject]@{ Path = $Path; Stream = $stream; Archive = $archive; Hash = $hash }
    }
    catch { $stream.Dispose(); throw }
}

function Close-AlPackage {
    param($Package)
    if ($Package) {
        $Package.Archive.Dispose()
        $Package.Stream.Dispose()
    }
}

function Get-AlPackageInfo {
    param($Package)
    $entries = @($Package.Archive.Entries | Where-Object FullName -eq 'NavxManifest.xml')
    if ($entries.Count -ne 1 -or $entries[0].Length -gt 2MB) {
        throw "Missing, ambiguous or oversized NavxManifest.xml: $($Package.Path)"
    }
    $stream = $entries[0].Open()
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [Xml.XmlReader]::Create($stream, $settings)
    try {
        $xml = [Xml.XmlDocument]::new()
        $xml.XmlResolver = $null
        $xml.Load($reader)
        $app = $xml.SelectSingleNode('/*[local-name()="Package"]/*[local-name()="App"]')
        if (-not $app) { throw "App metadata missing: $($Package.Path)" }
        return [pscustomobject]@{
            Id = ([guid]$app.GetAttribute('Id')).ToString()
            Name = $app.GetAttribute('Name')
            Publisher = $app.GetAttribute('Publisher')
            Version = ([version]$app.GetAttribute('Version')).ToString()
            Path = $Package.Path
        }
    }
    finally { $reader.Dispose(); $stream.Dispose() }
}

function Get-AlEntryHash {
    param($Entry)
    $stream = $Entry.Open()
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Get-AlSourcePath {
    param([string]$Root, [string]$EntryName)
    $relative = $EntryName.Replace('/', [IO.Path]::DirectorySeparatorChar)
    if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)|:') {
        throw "Unsafe package source path: $EntryName"
    }
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
    $path = [IO.Path]::GetFullPath((Join-Path $Root $relative))
    if (-not $path.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Package source escapes extraction directory: $EntryName"
    }
    # Never follow existing junctions/symlinks when reading or writing extracted source.
    $parent = Split-Path -Parent $path
    while ($parent) {
        if (Test-Path -LiteralPath $parent) {
            if ((Get-Item -LiteralPath $parent -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Reparse point in source directory: $parent"
            }
        }
        $parent = Split-Path -Parent $parent
    }
    if ((Test-Path -LiteralPath $path) -and
        ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Reparse point in source file: $path"
    }
    return $path
}

function Expand-AlPackageSources {
    param($Package, $Info, [string]$CacheDirectory)
    $hash = $Package.Hash
    $root = Join-Path $CacheDirectory ".sources\$($Info.Id)\$($Info.Version)\$hash"
    $entries = @($Package.Archive.Entries | Where-Object FullName -like '*.al')
    if ($entries.Count -eq 0) { throw "Package has no AL source: $($Package.Path). Ask the user for the missing source." }
    $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $total = 0L
    foreach ($entry in $entries) {
        $path = Get-AlSourcePath -Root $root -EntryName $entry.FullName
        if (-not $paths.Add($path)) { throw "Duplicate package source path: $($entry.FullName)" }
        $total += $entry.Length
        if ($entry.Length -gt 100MB -or $total -gt 1GB) { throw 'Package source exceeds safe extraction limits.' }
    }
    if (Test-Path -LiteralPath $root -PathType Container) { return $root }
    $parent = Split-Path -Parent $root
    $null = New-Item -ItemType Directory -Force -Path $parent
    $staging = Join-Path $parent ('.extract-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $staging
    # Leave a failed isolated staging directory for inspection; do not discard user files.
    foreach ($entry in $entries) {
        $path = Get-AlSourcePath -Root $staging -EntryName $entry.FullName
        $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path)
        $inputStream = $entry.Open()
        $outputStream = [IO.File]::Open($path, [IO.FileMode]::CreateNew)
        try { $inputStream.CopyTo($outputStream) }
        finally { $outputStream.Dispose(); $inputStream.Dispose() }
    }
    [IO.Directory]::Move($staging, $root)
    return $root
}

Export-ModuleMember -Function Open-AlPackage, Close-AlPackage, Get-AlPackageInfo, Get-AlEntryHash, Get-AlSourcePath, Expand-AlPackageSources
