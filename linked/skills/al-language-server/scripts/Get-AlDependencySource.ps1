<#
.SYNOPSIS
    Finds an AL object's exact source in the current project's local .alpackages.
.EXAMPLE
    Get-AlDependencySource.ps1 -ProjectDir "C:\repo\App" -ObjectName 'No. Series' -ObjectType Codeunit
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectDir,
    [Parameter(Mandatory = $true)][string]$ObjectName,
    [string]$ObjectType,
    [guid]$AppId,
    [version]$Version
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AlPackage.psm1') -Force
if (-not [IO.Path]::IsPathRooted($ProjectDir)) { throw '-ProjectDir must be absolute.' }
$project = Get-Content -LiteralPath (Join-Path $ProjectDir 'app.json') -Raw | ConvertFrom-Json
$cache = Join-Path (Resolve-Path -LiteralPath $ProjectDir).Path '.alpackages'
if (-not (Test-Path -LiteralPath $cache -PathType Container)) { throw "Local package cache missing: $cache. Ask the user; do not download source." }
$escapedName = [regex]::Escape($ObjectName.Replace('"', '""'))
$types = 'table|tableextension|page|pageextension|pagecustomization|codeunit|report|reportextension|query|xmlport|enum|enumextension|interface|permissionset|permissionsetextension|profile|controladdin|entitlement'
$pattern = '(?im)^\s*(?<type>' + $types + ')\s+(?:\d+\s+)?(?:"' + $escapedName + '"|' + [regex]::Escape($ObjectName) + ')(?=\s*(?:\{|extends\b|implements\b|customizes\b))'
$found = [Collections.Generic.List[object]]::new()
$withoutSource = [Collections.Generic.List[string]]::new()
foreach ($file in Get-ChildItem -LiteralPath $cache -Filter '*.app' -File) {
    $package = $null
    try {
        $package = Open-AlPackage -Path $file.FullName
        $info = Get-AlPackageInfo -Package $package
        if ($PSBoundParameters.ContainsKey('AppId') -and $info.Id -ne $AppId.ToString()) { continue }
        if ($Version -and [version]$info.Version -ne $Version) { continue }
        $dependency = @($project.dependencies | Where-Object { $_.id -eq $info.Id })
        if ($dependency.Count -gt 0 -and ([version]$info.Version -lt [version]$dependency[0].version -or
            $info.Name -ne $dependency[0].name -or $info.Publisher -ne $dependency[0].publisher)) { continue }
        $entries = @($package.Archive.Entries | Where-Object FullName -like '*.al')
        if ($entries.Count -eq 0) { $withoutSource.Add("$($info.Name) $($info.Version)"); continue }
        foreach ($entry in $entries) {
            # Declarations are at the start of AL object files; do not load whole BaseApp files.
            $reader = [IO.StreamReader]::new($entry.Open())
            try {
                $buffer = New-Object char[] 32768
                $count = $reader.ReadBlock($buffer, 0, $buffer.Length)
                $text = [string]::new($buffer, 0, $count)
            }
            finally { $reader.Dispose() }
            # AL examples inside comments and literals are not object declarations.
            $text = [regex]::Replace($text, '(?s)"(?:""|[^"])*"|''(?:''''|[^''])*''|//[^\r\n]*|/\*.*?\*/', {
                param($token)
                if ($token.Value.StartsWith('"') -or $token.Value.StartsWith("'")) { return $token.Value }
                return [regex]::Replace($token.Value, '[^\r\n]', ' ')
            })
            $match = [regex]::Match($text, $pattern)
            if ($match.Success -and (-not $ObjectType -or $match.Groups['type'].Value -eq $ObjectType)) {
                $found.Add([pscustomobject]@{ Info = $info; Entry = $entry.FullName; Type = $match.Groups['type'].Value })
            }
        }
    }
    finally { Close-AlPackage -Package $package }
}
if ($found.Count -eq 0) {
    throw "Object '$ObjectName' source not found in $cache. Packages without source: $($withoutSource -join ', '). Ask the user; nothing was downloaded."
}
if ($found.Count -ne 1) {
    $choices = $found | ForEach-Object { "$($_.Info.Id) $($_.Info.Name) $($_.Info.Version) $($_.Type) [$($_.Entry)]" }
    throw "Ambiguous object '$ObjectName'. Specify -AppId, -Version and/or -ObjectType. Candidates: $($choices -join '; ')"
}
$selected = $found[0]
$package = Open-AlPackage -Path $selected.Info.Path
try {
    $currentInfo = Get-AlPackageInfo -Package $package
    if ($currentInfo.Id -ne $selected.Info.Id -or $currentInfo.Version -ne $selected.Info.Version -or
        $currentInfo.Name -ne $selected.Info.Name -or $currentInfo.Publisher -ne $selected.Info.Publisher) {
        throw 'Dependency package changed during lookup. Retry after checking the local cache.'
    }
    $entry = $package.Archive.GetEntry($selected.Entry)
    if (-not $entry) { throw 'Dependency source entry changed during lookup; check the local cache.' }
    $expectedHash = Get-AlEntryHash -Entry $entry
    $sourcePath = $null
    $stem = [IO.Path]::GetFileNameWithoutExtension($selected.Info.Path)
    # Reuse existing version-specific extractions only when their bytes match the package.
    foreach ($folder in @((Join-Path $cache $stem), (Join-Path $cache "$stem-extracted"))) {
        $candidate = Get-AlSourcePath -Root $folder -EntryName $entry.FullName
        if ((Test-Path -LiteralPath $candidate -PathType Leaf) -and
            (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -eq $expectedHash) {
            $sourcePath = $candidate
            break
        }
    }
    if (-not $sourcePath) {
        $root = Expand-AlPackageSources -Package $package -Info $selected.Info -CacheDirectory $cache
        $sourcePath = Get-AlSourcePath -Root $root -EntryName $entry.FullName
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -or
            (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -ne $expectedHash) {
            throw "Cached source differs from its package: $sourcePath. It was not overwritten; ask the user."
        }
    }
    [pscustomobject]@{
        ObjectName = $ObjectName; ObjectType = $selected.Type
        AppId = $selected.Info.Id; Publisher = $selected.Info.Publisher
        AppName = $selected.Info.Name; Version = $selected.Info.Version
        PackagePath = $selected.Info.Path; SourcePath = $sourcePath
    }
}
finally { Close-AlPackage -Package $package }
