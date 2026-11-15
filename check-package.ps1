[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$manifest = Join-Path $PSScriptRoot 'SHA256SUMS.txt'
$seen = @{}
foreach ($line in [IO.File]::ReadAllLines($manifest)) {
    if ($line -notmatch '^([0-9a-fA-F]{64})  ([\w./-]+)$') { throw "无效的校验清单行：$line" }
    $hash = $Matches[1]
    $name = $Matches[2]
    if ($name -match '(^/|(^|/)\.\.(/|$))' -or $seen.ContainsKey($name)) { throw "无效的清单路径：$name" }
    $seen[$name] = $true
    $actual = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $name) -Algorithm SHA256).Hash
    if ($actual -ne $hash) { throw "文件校验失败：$name" }
}
foreach ($required in 'setup.ps1','start.ps1','lib/resources.ps1','lib/find-codex.ps1','bin/Codex-Zh-Launcher-Windows-x64.exe','localization/system-skills.json','localization/plugins.json','localization/plugin-skills.json') {
    if (!$seen.ContainsKey($required)) { throw "校验清单缺少 $required" }
}
Write-Output 'PACKAGE_CHECK=OK'