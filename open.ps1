[CmdletBinding()]
param([switch]$WaitForExit)
$ErrorActionPreference = 'Stop'
try {
    if ($WaitForExit) {
        Start-Transcript -Path (Join-Path $env:TEMP 'codex-zh-v17-open.log') -Force | Out-Null
        $state = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'state.json')) | ConvertFrom-Json
        $folder = Join-Path $state.appRoot 'app'
        $deadline = [DateTime]::Now.AddHours(2)
        do {
            $running = @(Get-Process -Name ChatGPT,Codex -ErrorAction SilentlyContinue | Where-Object {
                $_.Path -and [IO.Path]::GetDirectoryName($_.Path) -eq $folder
            })
            if ($running.Count -eq 0) { break }
            if ([DateTime]::Now -ge $deadline) { throw '等待退出已超时，请使用桌面的 Codex 中文启动。' }
            Start-Sleep -Seconds 2
        } while ($true)
    }
    & "$PSScriptRoot\start.ps1"
}
catch {
    if ($WaitForExit) {
        Add-Type -AssemblyName System.Windows.Forms
        [void][Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Codex 中文启动')
    } else { Write-Host $_ -ForegroundColor Red; Read-Host '按回车关闭' }
    exit 1
}
finally { if ($WaitForExit) { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } }