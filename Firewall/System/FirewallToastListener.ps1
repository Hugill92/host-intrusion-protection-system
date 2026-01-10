Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$LogName = "FirewallCore"

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("FirewallCore")

Register-WinEvent `
    -LogName $LogName `
    -SourceIdentifier "FirewallToastListener" `
    -Action {

        $event = $Event.SourceEventArgs.NewEvent
        if ($event.Id -lt 3000) { return }

        $data = $event.Message | ConvertFrom-Json

        $xml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>Firewall Alert: $($data.Severity)</text>
      <text>$($data.Title)</text>
    </binding>
  </visual>
</toast>
"@

        $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
        $doc.LoadXml($xml)

        $toast = New-Object Windows.UI.Notifications.ToastNotification $doc
        $notifier.Show($toast)
    }
