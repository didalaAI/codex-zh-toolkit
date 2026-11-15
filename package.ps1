[CmdletBinding()]
param([string]$OutputDirectory, [switch]$RebuildLauncher)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if ($RebuildLauncher) {
    & "$root\launcher\build.ps1"
    Copy-Item -LiteralPath "$root\launcher\dist\Codex-Zh-Launcher-Windows-x64.exe" -Destination "$root\bin" -Force
}
$files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force |
    ForEach-Object { $_.FullName.Substring($root.Length+1).Replace('\','/') } |
    Where-Object { $_ -ne 'SHA256SUMS.txt' -and $_ -notmatch '^(\.git/|launcher/(obj|dist)/)' } |
    Sort-Object)
$lines = foreach ($name in $files) {
    $hash = (Get-FileHash -LiteralPath (Join-Path $root $name) -Algorithm SHA256).Hash
    "$hash  $name"
}
[IO.File]::WriteAllLines("$root\SHA256SUMS.txt",[string[]]$lines,(New-Object Text.UTF8Encoding($false)))
& "$root\check-package.ps1"
if ($OutputDirectory) {
    $out = [IO.Path]::GetFullPath($OutputDirectory)
    if ($out -eq $root -or $out.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) { throw '请指定仓库之外的输出目录。' }
    [void][IO.Directory]::CreateDirectory($out)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = Join-Path $out 'codex-zh-toolkit-v1.7-community.2.zip'
    $temp = "$zip.$([Guid]::NewGuid()).tmp"
    try {
        $archive = [IO.Compression.ZipFile]::Open($temp,'Create')
        try {
            foreach ($file in @($files) + 'SHA256SUMS.txt') {
                [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $root $file),"codex-zh-toolkit/$file")
            }
        } finally { $archive.Dispose() }
        Copy-Item -LiteralPath $temp -Destination $zip -Force
    } finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
    Get-FileHash -LiteralPath $zip -Algorithm SHA256
}
