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
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBlixzum9gl/OoT
# d55ZmWUpMx71awqh4m6oEuOS0vqsaKCCArUwggKxMIIBmaADAgECAhQD4857cPuq
# YA1JZL+WI1Yn9crpsTANBgkqhkiG9w0BAQsFADAnMSUwIwYDVQQDDBxGaXJld2Fs
# bENvcmUgT2ZmbGluZSBSb290IENBMB4XDTI2MDIwMzA3NTU1N1oXDTI5MDMwOTA3
# NTU1N1owWDELMAkGA1UEBhMCVVMxETAPBgNVBAsMCFNlY3VyaXR5MRUwEwYDVQQK
# DAxGaXJld2FsbENvcmUxHzAdBgNVBAMMFkZpcmV3YWxsQ29yZSBTaWduYXR1cmUw
# WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATEFkC5IO0Ns0zPmdtnHpeiy/QjGyR5
# XcfYjx8wjVhMYoyZ5gyGaXjRBAnBsRsbSL172kF3dMSv20JufNI5SmZMo28wbTAJ
# BgNVHRMEAjAAMAsGA1UdDwQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNV
# HQ4EFgQUqbvNi/eHRRZJy7n5n3zuXu/sSOwwHwYDVR0jBBgwFoAULCjMhE2sOk26
# qY28GVmu4DqwehMwDQYJKoZIhvcNAQELBQADggEBAJsvjHGxkxvAWGAH1xiR+SOb
# vLKaaqVwKme3hHAXmTathgWUjjDwHQgFohPy7Zig2Msu11zlReUCGdGu2easaECF
# dMyiKzfZIA4+MQHQWv+SMcm912OjDtwEtCjNC0/+Q1BDISPv7OA8w7TDrmLk00mS
# il/f6Z4ZNlfegdoDyeDYK8lf+9DO2ARrddRU+wYrgXcdRzhekkBs9IoJ4qfXokOv
# u2ZvVZrPE3f2IiFPbmuBgzdbJ/VdkeCoAOl+D33Qyddzk8J/z7WSDiWqISF1E7GZ
# KSjgQp8c9McTcW15Ym4MR+lbyn3+CigGOrl89lzhMymm6rj6vSbvSMml2AEQgH0x
# ggE0MIIBMAIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IOEBS8NevJR7aNmLg4Q1OLiJbeig9nB09oRL1aKL74baMAsGByqGSM49AgEFAARH
# MEUCIQCtSm9NDZgctWlPC9NlzpbBMeiNXOKbvGb+21RpMV8eHQIgZbjyouqIThYH
# UOJM3H383ehvjbnTC7NKsZc2MAWDPIM=
# SIG # End signature block
