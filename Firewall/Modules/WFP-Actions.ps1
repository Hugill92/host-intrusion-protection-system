# C:\Firewall\Modules\WFP-Actions.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ExePathFromPid {
  param([int]$Pid)

  try {
    $p = Get-Process -Id $Pid -ErrorAction Stop
    if ($p.Path -and (Test-Path $p.Path)) { return $p.Path }
  } catch {}
  return $null
}

function Get-SafeRuleTag {
  param([string]$ExePath)

  try {
    if ($ExePath -and (Test-Path $ExePath)) {
      $h = (Get-FileHash -Algorithm SHA256 -Path $ExePath).Hash.Substring(0,12)
      return $h
    }
  } catch {}
  return ([Guid]::NewGuid().ToString("N").Substring(0,12))
}

function Invoke-QuarantineExe {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$ExePath,
    [int]$Minutes = 0,                 # 0 = persistent until removed
    [switch]$AlsoBlockInbound
  )

  if (-not (Test-Path $ExePath)) {
    throw "Invoke-QuarantineExe: exe not found: $ExePath"
  }

  $tag = Get-SafeRuleTag -ExePath $ExePath
  $base = "WFP-QUARANTINE-$tag"

  # Outbound block
  if (-not (Get-NetFirewallRule -DisplayName "$base-OUT" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "$base-OUT" -Direction Outbound -Action Block -Profile Any -Program $ExePath | Out-Null
  }

  # Optional inbound block
  if ($AlsoBlockInbound) {
    if (-not (Get-NetFirewallRule -DisplayName "$base-IN" -ErrorAction SilentlyContinue)) {
      New-NetFirewallRule -DisplayName "$base-IN" -Direction Inbound -Action Block -Profile Any -Program $ExePath | Out-Null
    }
  }

  # Optional timed removal via scheduled job (simple + reliable)
  if ($Minutes -gt 0) {
    $removeCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Get-NetFirewallRule -DisplayName '$base-*' -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue`""
    $tn = "WFP-UNQUARANTINE-$tag"
    & "$env:WINDIR\System32\schtasks.exe" /Delete /TN $tn /F *> $null
    & "$env:WINDIR\System32\schtasks.exe" /Create /TN $tn /SC ONCE /ST (Get-Date).AddMinutes($Minutes).ToString("HH:mm") `
      /SD (Get-Date).ToString("MM/dd/yyyy") /RL HIGHEST /RU SYSTEM /TR $removeCmd /F | Out-Null
  }

  return $base
}

function Save-JsonFile {
  param([string]$Path, $Obj)
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $Obj | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
}

function Read-JsonFile {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return $null }
  return (Get-Content $Path -Raw | ConvertFrom-Json)
}

function Invoke-HostIsolationNow {
  [CmdletBinding()]
  param(
    # keep these allowed so you don’t brick networking:
    [switch]$AllowDHCP = $true,
    [switch]$AllowDNS  = $true,

    # optional: keep local RDP/WinRM allowed (only if you want it)
    [switch]$AllowRDPFromLocalSubnet,
    [switch]$AllowWinRMFromLocalSubnet
  )

  $Root  = "C:\Firewall"
  $State = Join-Path $Root "State"
  $backup = Join-Path $State "wfp.isolation.backup.json"

  # Backup current profile defaults
  $profiles = Get-NetFirewallProfile
  $bakObj = @{
    Taken = (Get-Date).ToString("o")
    Profiles = @()
  }
  foreach ($p in $profiles) {
    $bakObj.Profiles += @{
      Name = $p.Name
      DefaultInboundAction  = [string]$p.DefaultInboundAction
      DefaultOutboundAction = [string]$p.DefaultOutboundAction
    }
  }
  Save-JsonFile -Path $backup -Obj $bakObj

  # Set defaults to block (THIS is the isolation)
  Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultInboundAction Block -DefaultOutboundAction Block

  # Allow essentials (these are allow rules; they work because defaults are block)
  if ($AllowDHCP) {
    New-NetFirewallRule -DisplayName "WFP-ISOLATE-ALLOW-DHCP-OUT" -Direction Outbound -Action Allow -Protocol UDP -RemotePort 67,68 -Profile Any | Out-Null
    New-NetFirewallRule -DisplayName "WFP-ISOLATE-ALLOW-DHCP-IN"  -Direction Inbound  -Action Allow -Protocol UDP -LocalPort 67,68  -Profile Any | Out-Null
  }

  if ($AllowDNS) {
    # Allow DNS to whatever your adapter currently uses
    $dnsServers = @()
    try {
      $dnsServers = (Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses | Where-Object { $_ }
    } catch {}
    if ($dnsServers.Count -eq 0) {
      # fallback: allow DNS outbound generally
      New-NetFirewallRule -DisplayName "WFP-ISOLATE-ALLOW-DNS-OUT" -Direction Outbound -Action Allow -Protocol UDP -RemotePort 53 -Profile Any | Out-Null
      New-NetFirewallRule -DisplayName "WFP-ISOLATE-ALLOW-DNS-TCP-OUT" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 53 -Profile Any | Out-Null
    } else {
      foreach ($ip in $dnsServers) {
        New-NetFirewallRule -DisplayName "WFP-ISOLATE-ALLOW-DNS-$ip-UDP" -Direction Outbound -Action Allow -Protocol UDP -RemotePort 53 -RemoteAddress $ip -Profile Any | Out-Null
        New-NetFirewallRule -DisplayName "WFP-ISOLATE-ALLOW-DNS-$ip-TCP" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 53 -RemoteAddress $ip -Profile Any | Out-Null
      }
    }
  }

  if ($AllowRDPFromLocalSubnet) {
    New-NetFirewallRule -DisplayName "WFP-ISOLATE-ALLOW-RDP-IN" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3389 -RemoteAddress LocalSubnet -Profile Any | Out-Null
  }
  if ($AllowWinRMFromLocalSubnet) {
    New-NetFirewallRule -DisplayName "WFP-ISOLATE-ALLOW-WINRM-IN" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5985,5986 -RemoteAddress LocalSubnet -Profile Any | Out-Null
  }
}

function Undo-HostIsolation {
  [CmdletBinding()]
  param()

  $backup = "C:\Firewall\State\wfp.isolation.backup.json"
  if (-not (Test-Path $backup)) { throw "No isolation backup found: $backup" }

  $bak = Read-JsonFile $backup
  foreach ($p in $bak.Profiles) {
    # restore defaults
    Set-NetFirewallProfile -Profile $p.Name -DefaultInboundAction $p.DefaultInboundAction -DefaultOutboundAction $p.DefaultOutboundAction
  }

  # Remove isolation allow rules we created
  Get-NetFirewallRule -DisplayName "WFP-ISOLATE-ALLOW-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
}

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQURycK35pzMD/z4azTq065SlXs
# dMugggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
# hvcNAQELBQAwJzElMCMGA1UEAwwcRmlyZXdhbGxDb3JlIE9mZmxpbmUgUm9vdCBD
# QTAeFw0yNjAyMDMwNzU1NTdaFw0yOTAzMDkwNzU1NTdaMFgxCzAJBgNVBAYTAlVT
# MREwDwYDVQQLDAhTZWN1cml0eTEVMBMGA1UECgwMRmlyZXdhbGxDb3JlMR8wHQYD
# VQQDDBZGaXJld2FsbENvcmUgU2lnbmF0dXJlMFkwEwYHKoZIzj0CAQYIKoZIzj0D
# AQcDQgAExBZAuSDtDbNMz5nbZx6Xosv0IxskeV3H2I8fMI1YTGKMmeYMhml40QQJ
# wbEbG0i9e9pBd3TEr9tCbnzSOUpmTKNvMG0wCQYDVR0TBAIwADALBgNVHQ8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFKm7zYv3h0UWScu5+Z98
# 7l7v7EjsMB8GA1UdIwQYMBaAFCwozIRNrDpNuqmNvBlZruA6sHoTMA0GCSqGSIb3
# DQEBCwUAA4IBAQCbL4xxsZMbwFhgB9cYkfkjm7yymmqlcCpnt4RwF5k2rYYFlI4w
# 8B0IBaIT8u2YoNjLLtdc5UXlAhnRrtnmrGhAhXTMois32SAOPjEB0Fr/kjHJvddj
# ow7cBLQozQtP/kNQQyEj7+zgPMO0w65i5NNJkopf3+meGTZX3oHaA8ng2CvJX/vQ
# ztgEa3XUVPsGK4F3HUc4XpJAbPSKCeKn16JDr7tmb1WazxN39iIhT25rgYM3Wyf1
# XZHgqADpfg990MnXc5PCf8+1kg4lqiEhdROxmSko4EKfHPTHE3FteWJuDEfpW8p9
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIzCCAR8CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU7mRmW/VovuuMcP16jd5OaAQYkxQwCwYH
# KoZIzj0CAQUABEcwRQIhAIp6QMGvFpFm+e9yefTSFDQAswaKGmg40KsKxq+d4jVn
# AiBXvmDOYv6uDYLNSRWqPNtCcxKgCf0hck8VoI2PmYT3cg==
# SIG # End signature block
