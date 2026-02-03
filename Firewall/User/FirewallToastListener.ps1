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
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUrf9i4JZoXC/1K1zGxeAYYSnU
# 7pegggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUfzh3GuD8az6wA4og2imFmbdMPdQwCwYH
# KoZIzj0CAQUABEcwRQIgVb65Uun6UxrzNQVAa48cJ5zYOpl5Y6rHlxDCuWdlEUcC
# IQCi4n7tbFC6kY1f8ajeP/XLosB9uFIuDrBWhUjlRwp6KQ==
# SIG # End signature block
