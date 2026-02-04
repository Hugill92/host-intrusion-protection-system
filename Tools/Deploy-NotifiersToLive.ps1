[CmdletBinding(DefaultParameterSetName='Ensure')]
param(
  [Parameter(ParameterSetName='Ensure')][switch]$EnsureProgramData,
  [Parameter(ParameterSetName='Restart')][switch]$RestartListener,
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

# Canonical live locations (per your established layout)
$LiveFirewallRoot = 'C:\Firewall'
$LiveProgramData  = 'C:\ProgramData\FirewallCore'

# Repo-relative sources
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SrcUser  = Join-Path $RepoRoot 'Firewall\User'
$SrcMods  = Join-Path $RepoRoot 'Firewall\Modules'

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) {
    if (-not $WhatIf) { $null = New-Item -ItemType Directory -Path $p -Force }
  }
}

function Log([string]$msg) {
  $logDir = Join-Path $LiveProgramData 'Logs'
  Ensure-Dir $logDir
  $log = Join-Path $logDir 'Notifiers-Deploy.log'
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
  if (-not $WhatIf) { Add-Content -LiteralPath $log -Value ("{0} {1}" -f $ts, $msg) }
}

function Copy-Safe([string]$from,[string]$toDir) {
  if (-not (Test-Path -LiteralPath $from)) { return }
  Ensure-Dir $toDir
  $to = Join-Path $toDir (Split-Path -Leaf $from)
  if ($WhatIf) {
    Write-Host ("[WHATIF] Copy {0} -> {1}" -f $from, $to)
  } else {
    Copy-Item -LiteralPath $from -Destination $to -Force
  }
  Log ("COPY {0} -> {1}" -f $from, $to)
}

function Restart-ToastListener {
  # Kill existing listener(s) best-effort
  $listenerPath = Join-Path $LiveFirewallRoot 'User\FirewallToastListener.ps1'
  try {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -and ($_.CommandLine -like ('*' + $listenerPath + '*')) } |
      ForEach-Object {
        if (-not $WhatIf) { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
      }
  } catch {}

  # Launch hidden using the locked process contract
  if (-not (Test-Path -LiteralPath $listenerPath)) {
    throw ("Listener script not found at {0}" -f $listenerPath)
  }

  $args = @(
    '-NoLogo',
    '-NoProfile',
    '-NonInteractive',
    '-WindowStyle','Hidden',
    '-ExecutionPolicy','Bypass',
    '-File', $listenerPath
  )

  if ($WhatIf) {
    Write-Host ("[WHATIF] Start powershell.exe {0}" -f ($args -join ' '))
  } else {
    Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WindowStyle Hidden | Out-Null
  }

  Log ("RESTART listener via powershell.exe -File {0}" -f $listenerPath)
  Write-Host ("[OK] Listener restart requested: {0}" -f $listenerPath)
}

if ($PSCmdlet.ParameterSetName -eq 'Ensure') {
  # Ensure ProgramData + live folders
  Ensure-Dir $LiveFirewallRoot
  Ensure-Dir $LiveProgramData
  Ensure-Dir (Join-Path $LiveProgramData 'Logs')
  Ensure-Dir (Join-Path $LiveProgramData 'User')
  Ensure-Dir (Join-Path $LiveProgramData 'NotifyQueue')

  # Deploy notifier runtime bits (minimal, deterministic)
  # Listener + handler scripts live under C:\Firewall\User per your contract
  Copy-Safe (Join-Path $SrcUser 'FirewallToastListener.ps1') (Join-Path $LiveFirewallRoot 'User')
  Copy-Safe (Join-Path $SrcUser 'FirewallToastActivate.ps1') (Join-Path $LiveFirewallRoot 'User')
  Copy-Safe (Join-Path $SrcUser 'FirewallReviewDialog.ps1') (Join-Path $LiveFirewallRoot 'User')
  Copy-Safe (Join-Path $SrcUser 'Open-FirewallCoreView.ps1') (Join-Path $LiveProgramData 'User')

  # Modules needed by tooling (best-effort)
  if (Test-Path -LiteralPath $SrcMods) {
    Ensure-Dir (Join-Path $LiveFirewallRoot 'Modules')
    if ($WhatIf) {
      Write-Host ("[WHATIF] Copy modules {0} -> {1}" -f $SrcMods, (Join-Path $LiveFirewallRoot 'Modules'))
    } else {
      Copy-Item -LiteralPath (Join-Path $SrcMods '*') -Destination (Join-Path $LiveFirewallRoot 'Modules') -Recurse -Force -ErrorAction SilentlyContinue
    }
    Log ("COPY modules {0} -> {1}" -f $SrcMods, (Join-Path $LiveFirewallRoot 'Modules'))
  }

  Write-Host "[OK] EnsureProgramData completed"
  Log "EnsureProgramData completed"
  return
}

if ($PSCmdlet.ParameterSetName -eq 'Restart') {
  Restart-ToastListener
  return
}
# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAPwSf6crh7vQD2
# 1ARbwUgNIkG/hOi2viR5n3jH8tuSBqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IJRaG93qx6X5HgE9oAEgX8LHNRRSKMvSiKMxR2iAMWM0MAsGByqGSM49AgEFAARH
# MEUCIFnqR3QUssKj2Rbir6pQ3pAIUN3oBVY6SuQmGWsIsXurAiEAykcl8BRPadbn
# j11goaRtBXUlkuh93yJFIyTNYwY3L1I=
# SIG # End signature block
