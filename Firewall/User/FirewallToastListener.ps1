Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$LogName = "FirewallCore"
$AppId   = "FirewallCore"

Write-Host "[LISTENER] Firewall toast listener running (user context)"

# App registration
$regPath = "HKCU:\Software\Classes\AppUserModelId\$AppId"
if (-not (Test-Path $regPath)) {
    New-Item $regPath -Force | Out-Null
    Set-ItemProperty $regPath DisplayName "Firewall Core"
    Set-ItemProperty $regPath IconUri "C:\Windows\System32\FirewallControlPanel.dll"
}

# Load WinRT types (MUST be STA)
Add-Type -AssemblyName System.Runtime.WindowsRuntime

$ToastMgr = [Windows.UI.Notifications.ToastNotificationManager]
$notifier = $ToastMgr::CreateToastNotifier($AppId)

$query = New-Object System.Diagnostics.Eventing.Reader.EventLogQuery(
    $LogName,
    [System.Diagnostics.Eventing.Reader.PathType]::LogName
)

$watcher = New-Object System.Diagnostics.Eventing.Reader.EventLogWatcher($query)

Register-ObjectEvent $watcher EventRecordWritten -Action {
    try {
        $e = $Event.SourceEventArgs.EventRecord
        $data = $e.FormatDescription() | ConvertFrom-Json

        $xml = @"
<toast>
  <visual>
    <binding template='ToastGeneric'>
      <text>$($data.Title)</text>
      <text>$($data.RuleName)</text>
      <text>Severity: $($data.Severity)</text>
    </binding>
  </visual>
</toast>
"@

        $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
        $doc.LoadXml($xml)

        $toast = New-Object Windows.UI.Notifications.ToastNotification($doc)
        $notifier.Show($toast)
    } catch {}
}

$watcher.Enabled = $true
Write-Host "[LISTENER] Waiting for FirewallCore events..."
Wait-Event

# --- BEGIN FIREWALLCORE HEARTBEAT ---
# Heartbeat so SYSTEM watchdog can verify we're not hung.
try {
    $StateDir = Join-Path $env:ProgramData "FirewallCore\State"
    if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir -Force | Out-Null }
    $script:HeartbeatPath = Join-Path $StateDir "toastlistener.heartbeat"

    function Update-FirewallCoreHeartbeat {
        try {
            # Touch the file (LastWriteTimeUtc used by watchdog)
            Set-Content -LiteralPath $script:HeartbeatPath -Value ([DateTime]::UtcNow.ToString("o")) -Encoding ASCII -Force
        } catch {}
    }

    # Timer updates heartbeat every 15 seconds, independent of listener loop/event waits.
    $script:hbTimer = New-Object System.Timers.Timer
    $script:hbTimer.Interval = 15000
    $script:hbTimer.AutoReset = $true
    Register-ObjectEvent -InputObject $script:hbTimer -EventName Elapsed -SourceIdentifier "FirewallCore.ToastHeartbeat" -Action { 
        try { Update-FirewallCoreHeartbeat } catch {}
    } | Out-Null
    $script:hbTimer.Start() | Out-Null

    # Also update immediately on startup
    Update-FirewallCoreHeartbeat
} catch {
    # Never fail listener because of heartbeat
}
# --- END FIREWALLCORE HEARTBEAT ---

# --- BEGIN FIREWALLCORE HEARTBEAT ---
# Heartbeat so SYSTEM watchdog can verify we're not hung.
try {
    $StateDir = Join-Path $env:ProgramData "FirewallCore\State"
    if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir -Force | Out-Null }
    $script:HeartbeatPath = Join-Path $StateDir "toastlistener.heartbeat"

    function Update-FirewallCoreHeartbeat {
        try {
            # Touch the file (LastWriteTimeUtc used by watchdog)
            Set-Content -LiteralPath $script:HeartbeatPath -Value ([DateTime]::UtcNow.ToString("o")) -Encoding ASCII -Force
        } catch {}
    }

    # Timer updates heartbeat every 15 seconds, independent of listener loop/event waits.
    $script:hbTimer = New-Object System.Timers.Timer
    $script:hbTimer.Interval = 15000
    $script:hbTimer.AutoReset = $true
    Register-ObjectEvent -InputObject $script:hbTimer -EventName Elapsed -SourceIdentifier "FirewallCore.ToastHeartbeat" -Action { 
        try { Update-FirewallCoreHeartbeat } catch {}
    } | Out-Null
    $script:hbTimer.Start() | Out-Null

    # Also update immediately on startup
    Update-FirewallCoreHeartbeat
} catch {
    # Never fail listener because of heartbeat
}
# --- END FIREWALLCORE HEARTBEAT ---


# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAY7U4xr1iv2V3Q
# Y/Vy9GVrtJ/FyX6I0lXr3xCoVdHU2aCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ggEzMIIBLwIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# INLkE8nJyP9/gWHCNgR9PIlmygfSmyGT73ml0XH72J4zMAsGByqGSM49AgEFAARG
# MEQCIC/IF4x9QuXi/WNMWpKqaya161WwK8pnHnfu3+T6BmsXAiBXPS2Bl0Trro4z
# yG2sLNoF0+J84EYF7pffc3qtb6H9HA==
# SIG # End signature block
