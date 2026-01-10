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
