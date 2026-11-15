[CmdletBinding()]
param(
  [switch]$Json
)

function ConvertFrom-CodexPackageFullName {
  param([string]$PackageFullName)

  $match = [regex]::Match(
    $PackageFullName,
    "^OpenAI\.Codex_(?<Version>[^_]+)_(?<Architecture>[^_]+)__(?<Publisher>[^_]+)$",
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
  )
  if (-not $match.Success) { return $null }

  return [pscustomobject]@{
    FullName = $PackageFullName
    Version = $match.Groups["Version"].Value
    Architecture = $match.Groups["Architecture"].Value
    PackageFamilyName = "OpenAI.Codex_" + $match.Groups["Publisher"].Value
  }
}

function Test-CodexInstallRoot {
  param([string]$InstallLocation)

  if ([string]::IsNullOrWhiteSpace($InstallLocation)) { return $false }
  $marketplace = Join-Path $InstallLocation "app\resources\plugins\openai-bundled\.agents\plugins\marketplace.json"
  return Test-Path -LiteralPath $marketplace
}

function Find-OpenAICodexInstall {
  [CmdletBinding()]
  param(
    [switch]$SkipAppx,
    [switch]$SkipRegistry,
    [switch]$SkipProcess,
    [switch]$SkipWindowsApps
  )

  $script:CodexDiscoveryLog = @()
  $candidates = @()

  if (-not $SkipAppx) {
    try {
      $packages = @(Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction Stop |
        Sort-Object Version -Descending)
      foreach ($package in $packages) {
        $candidates += [pscustomobject]@{
          Name = "OpenAI.Codex"
          Version = $package.Version.ToString()
          PackageFamilyName = $package.PackageFamilyName
          InstallLocation = $package.InstallLocation
          DetectionMethod = "AppX"
        }
      }
      $script:CodexDiscoveryLog += [pscustomobject]@{ Method = "AppX"; Ok = ($packages.Count -gt 0); Detail = "$($packages.Count) package(s)" }
    } catch {
      $script:CodexDiscoveryLog += [pscustomobject]@{ Method = "AppX"; Ok = $false; Detail = $_.Exception.Message }
    }
  }

  if (-not $SkipRegistry) {
    $registryRoot = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages"
    $found = 0
    try {
      if (Test-Path -LiteralPath $registryRoot) {
        foreach ($key in Get-ChildItem -LiteralPath $registryRoot -ErrorAction Stop |
          Where-Object { $_.PSChildName -match "^OpenAI\.Codex_" }) {
          try {
            $properties = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
            $parsed = ConvertFrom-CodexPackageFullName -PackageFullName $key.PSChildName
            if ($null -eq $parsed -or [string]::IsNullOrWhiteSpace($properties.PackageRootFolder)) { continue }
            $candidates += [pscustomobject]@{
              Name = "OpenAI.Codex"
              Version = $parsed.Version
              PackageFamilyName = $parsed.PackageFamilyName
              InstallLocation = $properties.PackageRootFolder
              DetectionMethod = "Registry"
            }
            $found += 1
          } catch {
          }
        }
      }
      $script:CodexDiscoveryLog += [pscustomobject]@{ Method = "Registry"; Ok = ($found -gt 0); Detail = "$found package(s)" }
    } catch {
      $script:CodexDiscoveryLog += [pscustomobject]@{ Method = "Registry"; Ok = $false; Detail = $_.Exception.Message }
    }
  }

  if (-not $SkipProcess) {
    $found = 0
    try {
      foreach ($process in Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue) {
        try {
          $processPath = $process.Path
          if ([string]::IsNullOrWhiteSpace($processPath)) { continue }
          $match = [regex]::Match(
            $processPath,
            "^(?<Root>.+\\WindowsApps\\OpenAI\.Codex_(?<Package>[^\\]+))\\app\\ChatGPT\.exe$",
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
          )
          if (-not $match.Success) { continue }
          $parsed = ConvertFrom-CodexPackageFullName -PackageFullName $match.Groups["Package"].Value
          if ($null -eq $parsed) { continue }
          $candidates += [pscustomobject]@{
            Name = "OpenAI.Codex"
            Version = $parsed.Version
            PackageFamilyName = $parsed.PackageFamilyName
            InstallLocation = $match.Groups["Root"].Value
            DetectionMethod = "RunningProcess"
          }
          $found += 1
        } catch {
        }
      }
      if ($found -eq 0) {
        try {
          foreach ($cimProcess in Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe'" -ErrorAction Stop) {
            $processPath = $cimProcess.ExecutablePath
            if ([string]::IsNullOrWhiteSpace($processPath)) { continue }
            $match = [regex]::Match(
              $processPath,
              "^(?<Root>.+\\WindowsApps\\OpenAI\.Codex_(?<Package>[^\\]+))\\app\\ChatGPT\.exe$",
              [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
            )
            if (-not $match.Success) { continue }
            $parsed = ConvertFrom-CodexPackageFullName -PackageFullName $match.Groups["Package"].Value
            if ($null -eq $parsed) { continue }
            $candidates += [pscustomobject]@{
              Name = "OpenAI.Codex"
              Version = $parsed.Version
              PackageFamilyName = $parsed.PackageFamilyName
              InstallLocation = $match.Groups["Root"].Value
              DetectionMethod = "RunningProcess"
            }
            $found += 1
          }
        } catch {
        }
      }
      $script:CodexDiscoveryLog += [pscustomobject]@{ Method = "RunningProcess"; Ok = ($found -gt 0); Detail = "$found process path(s)" }
    } catch {
      $script:CodexDiscoveryLog += [pscustomobject]@{ Method = "RunningProcess"; Ok = $false; Detail = $_.Exception.Message }
    }
  }

  if (-not $SkipWindowsApps) {
    $found = 0
    $windowsApps = Join-Path $env:ProgramFiles "WindowsApps"
    try {
      if (Test-Path -LiteralPath $windowsApps) {
        foreach ($directory in Get-ChildItem -LiteralPath $windowsApps -Directory -ErrorAction Stop |
          Where-Object { $_.Name -match "^OpenAI\.Codex_" }) {
          $parsed = ConvertFrom-CodexPackageFullName -PackageFullName $directory.Name
          if ($null -eq $parsed) { continue }
          $candidates += [pscustomobject]@{
            Name = "OpenAI.Codex"
            Version = $parsed.Version
            PackageFamilyName = $parsed.PackageFamilyName
            InstallLocation = $directory.FullName
            DetectionMethod = "WindowsApps"
          }
          $found += 1
        }
      }
      $script:CodexDiscoveryLog += [pscustomobject]@{ Method = "WindowsApps"; Ok = ($found -gt 0); Detail = "$found install folder(s)" }
    } catch {
      $script:CodexDiscoveryLog += [pscustomobject]@{ Method = "WindowsApps"; Ok = $false; Detail = $_.Exception.Message }
    }
  }

  $valid = @()
  $seen = @{}
  foreach ($candidate in $candidates) {
    if (-not (Test-CodexInstallRoot -InstallLocation $candidate.InstallLocation)) { continue }
    $key = $candidate.InstallLocation.ToLowerInvariant()
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    $valid += $candidate
  }

  if ($valid.Count -eq 0) { return $null }

  return $valid |
    Sort-Object @{ Expression = { try { [version]$_.Version } catch { [version]"0.0.0.0" } } } -Descending |
    Select-Object -First 1
}

$app = Find-OpenAICodexInstall
$attempts = @($script:CodexDiscoveryLog)
$accessDenied = @($attempts | Where-Object {
  -not $_.Ok -and $_.Detail -match "Access is denied|access denied|拒绝访问|访问被拒绝"
}).Count -gt 0
$successfulAttempts = @($attempts | Where-Object { $_.Ok }).Count

$failureKind = if ($null -ne $app) {
  "None"
} elseif ($accessDenied -and $successfulAttempts -eq 0) {
  "SandboxBlocked"
} else {
  "NotFound"
}

$result = [pscustomobject]@{
  found = ($null -ne $app)
  failureKind = $failureKind
  app = $app
  attempts = $attempts
}

if ($Json) {
  $result | ConvertTo-Json -Depth 10
} else {
  Write-Host "Codex 汉化安装环境检查" -ForegroundColor Cyan
  Write-Host ""
  foreach ($attempt in $attempts) {
    $mark = if ($attempt.Ok) { "OK" } else { "--" }
    Write-Host ("[{0}] {1}: {2}" -f $mark, $attempt.Method, $attempt.Detail)
  }
  Write-Host ""
  if ($null -ne $app) {
    Write-Host "检测成功" -ForegroundColor Green
    Write-Host "版本：$($app.Version)"
    Write-Host "安装标识：$($app.PackageFamilyName)"
    Write-Host "安装目录：$($app.InstallLocation)"
    Write-Host "检测方式：$($app.DetectionMethod)"
  } elseif ($failureKind -eq "SandboxBlocked") {
    Write-Host "CODEX_DISCOVERY_RESULT=SANDBOX_BLOCKED" -ForegroundColor Yellow
    Write-Host "应用可能已经正确安装，但当前 Codex 工具环境无权访问 Microsoft Store 数据。"
    Write-Host "请让 Codex 请求一次沙箱外运行权限；或直接双击 [一键安装.bat]。"
  } else {
    Write-Host "CODEX_DISCOVERY_RESULT=NOT_FOUND" -ForegroundColor Red
    Write-Host "未找到可用的 OpenAI.Codex 桌面应用。"
  }
}

if ($null -ne $app) { exit 0 }
if ($failureKind -eq "SandboxBlocked") { exit 2 }
exit 1
