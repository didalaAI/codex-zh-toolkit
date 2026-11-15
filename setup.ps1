[CmdletBinding()]
param(
    [ValidateSet('Install','Verify','Uninstall')][string]$Action = 'Install',
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }),
    [switch]$NoLaunch,
    [switch]$NoShortcut,
    [switch]$WaitForExit
)
$ErrorActionPreference = 'Stop'
$packageRoot = $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$exeName = 'Codex-Zh-Launcher-Windows-x64.exe'
$CodexHome = [IO.Path]::GetFullPath($CodexHome).TrimEnd('\')
$active = Join-Path $CodexHome 'zh-community-v17'
$previous = Join-Path $CodexHome 'zh-community-v17.previous'
$stage = Join-Path $CodexHome 'zh-community-v17.staging'
$shortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Codex 中文启动.lnk'
& (Join-Path $packageRoot 'check-package.ps1')
. (Join-Path $packageRoot 'lib\resources.ps1')
$cards = Read-JsonFile (Join-Path $packageRoot 'localization\system-skills.json')

function Assert-Owned([string]$dir) {
    if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($dir)) -ne $CodexHome -or $dir -notin @($active,$previous,$stage)) { throw "安装路径越界：$dir" }
    if (Test-Path -LiteralPath $dir) {
        if (!(Test-Path -LiteralPath (Join-Path $dir '.toolkit-v17')) -or ((Get-Item -LiteralPath $dir -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "请检查同名目录：$dir" }
    }
}
function Remove-Owned([string]$dir) {
    Assert-Owned $dir
    if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
}
function Get-CardPath([string]$name) {
    if ($name -notin $cards.PSObject.Properties.Name) { throw "未知技能：$name" }
    Join-Path $CodexHome "skills\.system\$name\agents\openai.yaml"
}
function Get-Hash([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
function Save-Card([string]$source,[string]$target) {
    $temp = "$target.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::Copy($source,$temp)
        [IO.File]::Replace($temp,$target,$temp+'.bak')
    } finally {
        foreach ($file in @($temp,($temp+'.bak'))) { if ([IO.File]::Exists($file)) { [IO.File]::Delete($file) } }
    }
}
function Prepare-Cards {
    $records = @()
    foreach ($prop in $cards.PSObject.Properties) {
        $name = $prop.Name
        $target = Get-CardPath $name
        if (!(Test-Path -LiteralPath $target)) { continue }
        $dest = Join-Path $stage "cards\$name"
        [void][IO.Directory]::CreateDirectory($dest)
        $inputHash = Get-Hash $target
        $baseline = $target
        if ($oldState) {
            $old = $oldState.cards | Where-Object { $_.name -eq $name } | Select-Object -First 1
            if ($old -and $old.hash -eq $inputHash) { $baseline = Join-Path $active "cards\$name\original.yaml" }
        }
        Copy-Item -LiteralPath $baseline -Destination "$dest\original.yaml"
        Copy-Item -LiteralPath $target -Destination "$dest\before.yaml"
        Copy-Item -LiteralPath $baseline -Destination "$dest\chinese.yaml"
        $changed = Update-YamlInterface "$dest\chinese.yaml" $prop.Value
        if ($changed) { $records += [pscustomobject]@{name=$name; hash=(Get-Hash "$dest\chinese.yaml"); before=$inputHash} }
    }
    return $records
}
function Restore-Cards($state,[string]$sourceName) {
    foreach ($card in $state.cards) {
        $target = Get-CardPath $card.name
        if ([IO.File]::Exists($target) -and (Get-Hash $target) -eq $card.hash) {
            Save-Card (Join-Path $active "cards\$($card.name)\$sourceName") $target
        }
    }
}
function Test-Install {
    $state = Read-JsonFile "$active\state.json"
    $bundle = "$active\resources\plugins\openai-bundled"
    $market = Read-JsonFile "$bundle\.agents\plugins\marketplace.json"
    if ($market.interface.displayName -ne 'OpenAI 内置') { throw '插件目录中文校验失败。' }
    if ((Get-Hash "$active\$exeName") -ne (Get-Hash "$packageRoot\bin\$exeName")) { throw '启动器校验失败。' }
    $source = Join-Path $app.InstallLocation 'app\resources\plugins\openai-bundled\plugins'
    $official = @(Get-ChildItem -LiteralPath $source -Directory | Select-Object -ExpandProperty Name)
    $installed = @(Get-ChildItem -LiteralPath "$bundle\plugins" -Directory | Select-Object -ExpandProperty Name)
    if (($installed.Count -ne $official.Count) -or @($official | Where-Object { $_ -notin $installed }).Count) { throw '插件列表已变化，请重新安装。' }
    foreach ($name in $official) {
        $sub = "$name\.codex-plugin\plugin.json"
        if ((Read-JsonFile "$source\$sub").version -ne (Read-JsonFile "$bundle\plugins\$sub").version) { throw "插件版本已变化：$name" }
    }
    foreach ($card in $state.cards) {
        if ((Get-Hash (Get-CardPath $card.name)) -ne $card.hash) { throw "技能卡片已更新：$($card.name)" }
    }
    Write-Output "VERIFY_RESULT=OK plugins=$($installed.Count) system_cards=$(@($state.cards).Count)"
}
function Set-Shortcut {
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($shortcut)
    $argsText = '-NoProfile -ExecutionPolicy Bypass -File "' + $active + '\open.ps1"'
    if ((Test-Path -LiteralPath $shortcut) -and $link.Arguments -ne $argsText) { throw "已有其他快捷方式使用名称：$shortcut" }
    $link.TargetPath = Join-Path $PSHOME 'powershell.exe'
    $link.Arguments = $argsText
    $link.WorkingDirectory = $active
    $link.IconLocation = "$active\$exeName,0"
    $link.Description = '打开 Codex 中文界面'
    $link.Save()
}
function Test-Running {
    $folder = Join-Path $app.InstallLocation 'app'
    $found = @(Get-Process -Name ChatGPT,Codex -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -and [IO.Path]::GetDirectoryName($_.Path) -eq $folder
    })
    return ($found.Count -gt 0)
}
function Install-Toolkit {
    $official = Join-Path $app.InstallLocation 'app\resources\plugins\openai-bundled'
    $appRes = Join-Path $app.InstallLocation 'app\resources'
    $nativeChinese = Test-NativeMenuLocale "$appRes\app.asar"
    $markers = @('CODEX_ELECTRON_BUNDLED_PLUGINS_RESOURCES_PATH')
    if (!$nativeChinese) { $markers += '72216192' }
    foreach ($marker in $markers) {
        $present = Test-AsarMarker "$appRes\rg.exe" "$appRes\app.asar" $marker
        if ($present -ne $true) { throw "当前客户端无法确认兼容性：$marker。版本 $($app.Version)" }
    }
    [void][IO.Directory]::CreateDirectory($stage)
    Write-Utf8Text "$stage\.toolkit-v17" '1.7'
    $bundle = "$stage\resources\plugins\openai-bundled"
    [void][IO.Directory]::CreateDirectory($bundle)
    $null = Copy-CodexResourceTree $official $bundle
    Apply-LocalizationOverlay $bundle
    $errors = @(Test-JsonTree $bundle)
    if ($errors.Count) { throw ($errors -join [Environment]::NewLine) }
    Copy-Item -LiteralPath "$packageRoot\bin\$exeName" -Destination $stage
    Copy-Item -LiteralPath "$packageRoot\start.ps1","$packageRoot\open.ps1" -Destination $stage
    $records = @(Prepare-Cards)
    Write-JsonFile "$stage\state.json" ([pscustomobject]@{version='1.7-community.2';appRoot=$app.InstallLocation;codexVersion=$app.Version;nativeChinese=$nativeChinese;sourceRoot=$packageRoot;cards=$records})
    Write-Utf8Text "$stage\.pending" 'install'
    Assert-Owned $active
    Assert-Owned $previous
    Assert-Owned $stage
    if (Test-Path -LiteralPath $active) { [IO.Directory]::Move($active,$previous) }
    [IO.Directory]::Move($stage,$active)
    foreach ($card in $records) {
        $target = Get-CardPath $card.name
        if ((Get-Hash $target) -ne $card.before) { throw "安装中技能文件发生变化：$target" }
        Save-Card "$active\cards\$($card.name)\chinese.yaml" $target
    }
    Test-Install
    if (!$NoShortcut) { Set-Shortcut }
    [IO.File]::Delete("$active\.pending")
    Remove-Owned $previous
    Write-Output 'INSTALL_RESULT=OK'
}
function Recover-Install {
    foreach ($dir in $active,$previous,$stage) { Assert-Owned $dir }
    if (Test-Path -LiteralPath "$active\.pending") {
        Restore-Cards (Read-JsonFile "$active\state.json") 'before.yaml'
        Remove-Owned $active
    }
    if (Test-Path -LiteralPath $previous) {
        if (!(Test-Path -LiteralPath $active)) { [IO.Directory]::Move($previous,$active) }
        else { Remove-Owned $previous }
    }
    Remove-Owned $stage
}

if ($Action -ne 'Uninstall') {
    $discovery = Get-CodexDiscoveryResult
    if (!$discovery.found) { throw ("找不到可读取的商店版 Codex：" + ($discovery | ConvertTo-Json -Depth 5 -Compress)) }
    $app = $discovery.app
}
if ($Action -eq 'Install' -and (Test-Path -LiteralPath $active) -and (Test-Running) -and !$WaitForExit) {
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -WaitForExit -CodexHome "' + $CodexHome + '"'
    if ($NoShortcut) { $arguments += ' -NoShortcut' }
    if ($NoLaunch) { $arguments += ' -NoLaunch' }
    $worker = Start-Process powershell.exe -ArgumentList $arguments -WindowStyle Hidden -PassThru
    Write-Output "WAITING_FOR_CODEX_EXIT phase=upgrade pid=$($worker.Id) 请保存工作并从托盘退出 Codex；退出后自动继续。"
    return
}
$mutex = New-Object Threading.Mutex($false, 'Local\CodexZhCommunityV17Setup')
$held = $false
try {
    try { $held = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $held = $true }
    if (!$held) { throw '另一个安装或维护进程正在执行。' }
    if ($WaitForExit) {
        $log = Join-Path $env:TEMP 'codex-zh-v17-install.log'
        Start-Transcript -Path $log -Force | Out-Null
        $deadline = [DateTime]::Now.AddHours(2)
        while (Test-Running) {
            if ([DateTime]::Now -ge $deadline) { throw '等待退出已超时，请重新运行一键安装。' }
            Start-Sleep -Seconds 2
        }
    }
    Recover-Install
    $oldState = if (Test-Path -LiteralPath "$active\state.json") { Read-JsonFile "$active\state.json" }
    switch ($Action) {
        'Install' {
            try { Install-Toolkit } catch { Recover-Install; throw }
            if (!$NoLaunch) {
                if (Test-Running) {
                    $argsText = '-NoProfile -ExecutionPolicy Bypass -File "' + $active + '\open.ps1" -WaitForExit'
                    $worker = Start-Process powershell.exe -ArgumentList $argsText -WindowStyle Hidden -PassThru
                    Write-Output "WAITING_FOR_CODEX_EXIT phase=launch pid=$($worker.Id) 已安装，请保存工作并从托盘完全退出 Codex。"
                } else { & "$active\start.ps1" }
            }
        }
        'Verify' { Test-Install }
        'Uninstall' {
            if ($oldState) {
                Restore-Cards $oldState 'original.yaml'
                if (!$NoShortcut -and [IO.File]::Exists($shortcut)) {
                    $link = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)
                    if ($link.Arguments.EndsWith('"' + $active + '\open.ps1"')) { [IO.File]::Delete($shortcut) }
                }
                Remove-Owned $active
            }
            Write-Output 'UNINSTALL_RESULT=OK'
        }
    }
} finally {
    if ($WaitForExit -and $log) { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null }
    if ($held) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
