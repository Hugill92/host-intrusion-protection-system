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

