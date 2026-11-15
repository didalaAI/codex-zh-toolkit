[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$env:CODEX_HOME = Split-Path -Parent $PSScriptRoot
$env:CODEX_ELECTRON_BUNDLED_PLUGINS_RESOURCES_PATH = Join-Path $PSScriptRoot 'resources'
$exe = Join-Path $PSScriptRoot 'Codex-Zh-Launcher-Windows-x64.exe'
$state = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'state.json')) | ConvertFrom-Json
$env:CODEX_ZH_STORE_ROOT = $state.appRoot
$env:CODEX_ZH_NATIVE_LOCALE = if ($state.nativeChinese) { '1' } else { '0' }
$current = Get-AppxPackage -Name OpenAI.Codex -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
if ($current -and $current.InstallLocation -ne $state.appRoot) {
    $installer = Join-Path $state.sourceRoot 'setup.ps1'
    if (!(Test-Path -LiteralPath $installer)) { throw '商店版已更新，请从本项目重新下载并运行一键安装。' }
    Write-Host "正在为 Codex $($current.Version) 更新中文资源。"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -CodexHome $env:CODEX_HOME
    if ($LASTEXITCODE) { throw '中文资源更新失败，请检查上方错误。' }
    return
}
$proc = Start-Process -FilePath $exe -ArgumentList '--launch-zh' -PassThru
$proc.WaitForExit()
if ($proc.ExitCode -ne 0) {
    throw "启动器返回 $($proc.ExitCode)。请退出已有 Codex 后重试；日志位于 $env:LOCALAPPDATA\CodexZhLauncher\logs\launcher.log"
}
Write-Output 'LAUNCH_RESULT=OK'
