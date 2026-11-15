function Write-Utf8Text {
  param([string]$Path, [string]$Text)
  $parent = Split-Path -Parent $Path
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Read-JsonFile {
  param([string]$Path)
  $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
  return $text | ConvertFrom-Json
}

function Write-JsonFile {
  param([string]$Path, $Value)
  $json = $Value | ConvertTo-Json -Depth 100
  Write-Utf8Text -Path $Path -Text ($json + "`n")
}

function Get-CodexDiscoveryResult {
  $helper = Join-Path $packageRoot "lib\find-codex.ps1"
  try {
    $helperCommand = "& '" + $helper.Replace("'", "''") + "' -Json"
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $helperCommand 2>$null
    $text = (@($output) -join "`n").Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { throw "应用检测脚本没有返回结果。" }
    return $text | ConvertFrom-Json
  } catch {
    return [pscustomobject]@{
      found = $false
      failureKind = "ToolError"
      app = $null
      attempts = @([pscustomobject]@{ Method = "Helper"; Ok = $false; Detail = $_.Exception.Message })
    }
  }
}

function Assert-CopiedResourceTree {
  param(
    [string]$Source,
    [string]$Destination
  )

  $marketplace = Join-Path $Destination ".agents\plugins\marketplace.json"
  if (-not (Test-Path -LiteralPath $marketplace)) {
    throw "复制结果不完整：缺少 marketplace.json。目标目录：$Destination"
  }
  $sourceCount = @(Get-ChildItem -LiteralPath $Source -File -Recurse -Force).Count
  $destinationCount = @(Get-ChildItem -LiteralPath $Destination -File -Recurse -Force).Count
  if ($sourceCount -ne $destinationCount) {
    throw "复制结果不完整：源文件 $sourceCount 个，目标文件 $destinationCount 个。"
  }
}

function Copy-DirectoryByStream {
  param(
    [string]$Source,
    [string]$Destination
  )

  $sourceRoot = (Get-Item -LiteralPath $Source -Force).FullName.TrimEnd("\")
  if (Test-Path -LiteralPath $Destination) {
    Remove-Item -LiteralPath $Destination -Recurse -Force
  }
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null

  foreach ($directory in Get-ChildItem -LiteralPath $sourceRoot -Directory -Recurse -Force) {
    $relative = $directory.FullName.Substring($sourceRoot.Length).TrimStart("\")
    New-Item -ItemType Directory -Path (Join-Path $Destination $relative) -Force | Out-Null
  }

  foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -File -Recurse -Force) {
    $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart("\")
    $target = Join-Path $Destination $relative
    $targetParent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $targetParent)) {
      New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
    }

    $input = [System.IO.File]::Open($file.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
      $output = New-Object System.IO.FileStream($target, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
      try {
        $input.CopyTo($output)
      } finally {
        $output.Dispose()
      }
    } finally {
      $input.Dispose()
    }
    [System.IO.File]::SetLastWriteTime($target, $file.LastWriteTime)
  }
}

function Copy-CodexResourceTree {
  param(
    [string]$Source,
    [string]$Destination
  )

  $forceStreamCopy = $env:CODEX_ZH_FORCE_STREAM_COPY -eq "1"
  $forceRobocopy = $env:CODEX_ZH_FORCE_ROBOCOPY -eq "1"
  if (-not $forceStreamCopy -and -not $forceRobocopy) {
    try {
      Get-ChildItem -LiteralPath $Source -Force | Copy-Item -Destination $Destination -Recurse -Force
      Assert-CopiedResourceTree -Source $Source -Destination $Destination
      return $false
    } catch {
      Write-Host "标准复制遇到文件属性兼容问题，正在自动切换兼容模式..." -ForegroundColor Yellow
      Write-Host $_.Exception.Message
    }
  }

  if (-not $forceRobocopy) {
    try {
      Copy-DirectoryByStream -Source $Source -Destination $Destination
      Assert-CopiedResourceTree -Source $Source -Destination $Destination
      Write-Host "已使用逐文件流式复制完成插件资源写入。" -ForegroundColor Green
      return $true
    } catch {
      Write-Host "流式复制失败，正在尝试最后的 robocopy 兼容模式..." -ForegroundColor Yellow
      Write-Host $_.Exception.Message
    }
  }

  if (Test-Path -LiteralPath $Destination) {
    Remove-Item -LiteralPath $Destination -Recurse -Force
  }
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  $arguments = @(
    $Source,
    $Destination,
    "/E",
    "/COPY:DT",
    "/DCOPY:DT",
    "/XJ",
    "/R:1",
    "/W:1",
    "/NFL",
    "/NDL",
    "/NJH",
    "/NJS",
    "/NP"
  )
  & robocopy.exe @arguments | Out-Null
  $copyExit = $LASTEXITCODE
  if ($copyExit -ge 8) {
    throw "兼容复制失败，robocopy 退出码：$copyExit"
  }
  Assert-CopiedResourceTree -Source $Source -Destination $Destination
  Write-Host "已使用 robocopy 兼容模式完成插件资源写入。" -ForegroundColor Green
  return $true
}

function Get-MappingValue {
  param($Object, [string]$Name)
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return ,$property.Value
}

function Set-JsonValue {
  param($Object, [string]$Name, $Value)
  if ($null -eq $Value) { return }
  if ($null -eq $Object.PSObject.Properties[$Name]) {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  } else {
    $Object.$Name = $Value
  }
}

function Update-PluginManifest {
  param(
    [string]$ManifestPath,
    $PluginMapping
  )

  if (-not (Test-Path -LiteralPath $ManifestPath)) { return }
  $manifest = Read-JsonFile -Path $ManifestPath

  $description = Get-MappingValue -Object $PluginMapping -Name "description"
  Set-JsonValue -Object $manifest -Name "description" -Value $description

  $interfaceMapping = Get-MappingValue -Object $PluginMapping -Name "interface"
  if ($null -ne $interfaceMapping) {
    if ($null -eq $manifest.PSObject.Properties["interface"]) {
      $manifest | Add-Member -NotePropertyName "interface" -NotePropertyValue ([pscustomobject]@{})
    }
    foreach ($field in @("displayName", "shortDescription", "longDescription", "category", "defaultPrompt")) {
      $value = Get-MappingValue -Object $interfaceMapping -Name $field
      Set-JsonValue -Object $manifest.interface -Name $field -Value $value
    }
  }

  Write-JsonFile -Path $ManifestPath -Value $manifest
}

function Update-SkillDescription {
  param(
    [string]$SkillPath,
    [string]$Description
  )

  if (-not (Test-Path -LiteralPath $SkillPath) -or [string]::IsNullOrWhiteSpace($Description)) {
    return $false
  }

  $text = [System.IO.File]::ReadAllText($SkillPath, [System.Text.Encoding]::UTF8)
  $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
  $lines = $text -split "\r?\n"
  if ($lines.Count -lt 3 -or $lines[0].TrimStart([char]0xFEFF) -ne "---") { return $false }

  $end = -1
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -eq "---") { $end = $i; break }
  }
  if ($end -lt 0) { return $false }

  $quoted = $Description | ConvertTo-Json -Compress
  $changed = $false
  for ($i = 1; $i -lt $end; $i++) {
    if ($lines[$i] -match "^description:\s*") {
      $lines[$i] = "description: $quoted"
      $changed = $true
      break
    }
  }

  if ($changed) {
    Write-Utf8Text -Path $SkillPath -Text ($lines -join $newline)
  }
  return $changed
}

function Update-YamlInterface {
  param(
    [string]$YamlPath,
    $InterfaceMapping
  )

  if (-not (Test-Path -LiteralPath $YamlPath) -or $null -eq $InterfaceMapping) { return $false }

  $text = [System.IO.File]::ReadAllText($YamlPath, [System.Text.Encoding]::UTF8)
  $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
  $lines = $text -split "\r?\n"
  $changed = $false

  foreach ($field in @("display_name", "short_description", "default_prompt")) {
    $value = Get-MappingValue -Object $InterfaceMapping -Name $field
    if ([string]::IsNullOrWhiteSpace($value)) { continue }
    $quoted = $value | ConvertTo-Json -Compress
    $pattern = "^(\s*" + [regex]::Escape($field) + ":\s*).*$"
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match $pattern) {
        $lines[$i] = $matches[1] + $quoted
        $changed = $true
        break
      }
    }
  }

  if ($changed) {
    Write-Utf8Text -Path $YamlPath -Text ($lines -join $newline)
  }
  return $changed
}

function Apply-LocalizationOverlay {
  param([string]$ResourceRoot)

  $pluginMappingPath = Join-Path $packageRoot "localization\plugins.json"
  $skillMappingPath = Join-Path $packageRoot "localization\plugin-skills.json"
  $pluginMapping = Read-JsonFile -Path $pluginMappingPath
  $skillMapping = Read-JsonFile -Path $skillMappingPath

  $marketplacePath = Join-Path $ResourceRoot ".agents\plugins\marketplace.json"
  if (Test-Path -LiteralPath $marketplacePath) {
    $marketplace = Read-JsonFile -Path $marketplacePath
    if ($null -eq $marketplace.PSObject.Properties["interface"]) {
      $marketplace | Add-Member -NotePropertyName "interface" -NotePropertyValue ([pscustomobject]@{})
    }
    $displayName = Get-MappingValue -Object $pluginMapping -Name "marketplaceDisplayName"
    Set-JsonValue -Object $marketplace.interface -Name "displayName" -Value $displayName
    if ($null -ne $marketplace.plugins) {
      foreach ($marketplacePlugin in $marketplace.plugins) {
        $category = Get-MappingValue -Object $pluginMapping.marketplaceCategories -Name $marketplacePlugin.name
        Set-JsonValue -Object $marketplacePlugin -Name "category" -Value $category
      }
    }
    Write-JsonFile -Path $marketplacePath -Value $marketplace
  }

  $pluginsRoot = Join-Path $ResourceRoot "plugins"
  if (Test-Path -LiteralPath $pluginsRoot) {
    foreach ($pluginDir in Get-ChildItem -LiteralPath $pluginsRoot -Directory) {
      $mapping = Get-MappingValue -Object $pluginMapping.plugins -Name $pluginDir.Name
      if ($null -eq $mapping) { continue }
      Update-PluginManifest -ManifestPath (Join-Path $pluginDir.FullName ".codex-plugin\plugin.json") -PluginMapping $mapping
    }
  }

  $skillProperties = $skillMapping.skills.PSObject.Properties
  foreach ($property in $skillProperties) {
    $relativePath = $property.Name.Replace("/", "\")
    $mapping = $property.Value
    $skillPath = Join-Path $ResourceRoot $relativePath
    $description = Get-MappingValue -Object $mapping -Name "description"
    $updated = Update-SkillDescription -SkillPath $skillPath -Description $description

    $interface = Get-MappingValue -Object $mapping -Name "interface"
    if ($null -ne $interface -and (Test-Path -LiteralPath $skillPath)) {
      $yamlPath = Join-Path (Split-Path -Parent $skillPath) "agents\openai.yaml"
      Update-YamlInterface -YamlPath $yamlPath -InterfaceMapping $interface | Out-Null
    }
  }
}

function Test-JsonTree {
  param([string]$Root)
  $errors = @()
  foreach ($file in Get-ChildItem -LiteralPath $Root -Filter "*.json" -File -Recurse) {
    try {
      $null = Read-JsonFile -Path $file.FullName
    } catch {
      $errors += "$($file.FullName): $($_.Exception.Message)"
    }
  }
  return $errors
}

function Test-NativeMenuLocale([string]$Path) {
  $stream = [IO.File]::OpenRead($Path)
  $reader = New-Object IO.BinaryReader($stream)
  try {
    if ($reader.ReadUInt32() -ne 4) { return $false }
    $stream.Position = 12
    $length = $reader.ReadInt32()
    if ($length -le 0 -or $length -gt 64MB -or $length -gt ($stream.Length - 16)) { return $false }
    Add-Type -AssemblyName System.Web.Extensions
    $parser = New-Object Web.Script.Serialization.JavaScriptSerializer
    $parser.MaxJsonLength = $length
    $index = $parser.DeserializeObject([Text.Encoding]::UTF8.GetString($reader.ReadBytes($length)))
    $menus = $index['files']['native-menu-locales']
    return ($null -ne $menus -and $menus['files'].ContainsKey('zh-CN.json'))
  } finally { $reader.Dispose() }
}

function Test-AsarMarker {
  param(
    [string]$RgPath,
    [string]$AsarPath,
    [string]$Marker
  )
  if (-not (Test-Path -LiteralPath $RgPath) -or -not (Test-Path -LiteralPath $AsarPath)) {
    return $null
  }
  $matches = & $RgPath -a -o -m 1 $Marker $AsarPath 2>$null
  return ($LASTEXITCODE -eq 0 -and $matches -contains $Marker)
}

