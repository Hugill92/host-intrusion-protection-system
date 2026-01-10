# FirewallCore-EventListener.ps1
# Unified DEV / LIVE event listener for FirewallCore
# - User context (required for toasts)
# - Severity-based throttling
# - Click opens Event Viewer
# - No per-test wiring needed
# DEV (no throttling, verbose behavior)
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass `
  -File C:\FirewallInstaller\Firewall\User\FirewallCore-EventListener.ps1 `
  -Mode DEV

# LIVE (throttling + auto-open EV on HIGH)
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass `
  -File C:\FirewallInstaller\Firewall\User\FirewallCore-EventListener.ps1 `
  -Mode LIVE

param(
    [ValidateSet("DEV","LIVE")]
    [string]$Mode = "LIVE"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$LogName = "FirewallCore"
$AppId   = "FirewallCore"

Write-Host "[LISTENER] FirewallCore listener starting (Mode=$Mode)"

# ------------------------------------------------------------
# AppUserModelId registration (required for toast identity)
# ------------------------------------------------------------
$regPath = "HKCU:\Software\Classes\AppUserModelId\$AppId"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
    New-ItemProperty -Path $regPath -Name DisplayName -Value "Firewall Core" -Force | Out-Null
    New-ItemProperty -Path $regPath -Name IconUri -Value "C:\Windows\System32\FirewallControlPanel.dll" -Force | Out-Null
}

# ------------------------------------------------------------
# Load WinRT toast APIs (requires STA)
# ------------------------------------------------------------
[Windows.UI.Notifications.ToastNotificationManager,
 Windows.UI.Notifications,
 ContentType = WindowsRuntime] | Out-Null

[Windows.Data.Xml.Dom.XmlDocument,
 Windows.Data.Xml.Dom.XmlDocument,
 ContentType = WindowsRuntime] | Out-Null

$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)

# ------------------------------------------------------------
# Throttle state (per-user)
# ------------------------------------------------------------
$StateDir = Join-Path $env:LOCALAPPDATA "FirewallCore"
$ThrottleFile = Join-Path $StateDir "toast-throttle.json"
if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir -Force | Out-Null }

function Get-Throttle {
    if (-not (Test-Path $ThrottleFile)) { return @{} }
    try { (Get-Content $ThrottleFile -Raw) | ConvertFrom-Json } catch { @{} }
}

function Save-Throttle($obj) {
    $obj | ConvertTo-Json -Depth 4 | Out-File $ThrottleFile -Encoding UTF8
}

function Should-Notify {
    param([string]$Severity)

    # DEV mode = never suppress
    if ($Mode -eq "DEV") { return $true }

    # LIVE throttling
    $cooldown = switch ($Severity) {
        "HIGH"   { 0 }
        "MEDIUM" { 60 }
        "LOW"    { 300 }
        default  { 120 }
    }

    $state = Get-Throttle
    $now = Get-Date

    if ($state.$Severity) {
        try {
            $last = Get-Date $state.$Severity
            if (($now - $last).TotalSeconds -lt $cooldown) {
                return $false
            }
        } catch {}
    }

    $state | Add-Member -NotePropertyName $Severity -NotePropertyValue ($now.ToString("o")) -Force
    Save-Throttle $state
    return $true
}

# ------------------------------------------------------------
# Toast renderer
# ------------------------------------------------------------
function Show-Toast {
    param(
        [string]$Title,
        [string]$Line,
        [string]$Severity
    )

$xml = @"
<toast launch="firewallcore://open-events">
  <visual>
    <binding template="ToastGeneric">
      <text>$Title</text>
      <text>$Line</text>
      <text>Severity: $Severity</text>
    </binding>
  </visual>
  <actions>
    <action content="Open Event Log"
            activationType="protocol"
            arguments="firewallcore://open-events"/>
  </actions>
</toast>
"@

    $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
    $doc.LoadXml($xml)

    $toast = New-Object Windows.UI.Notifications.ToastNotification $doc
    $notifier.Show($toast)
}

# ------------------------------------------------------------
# Event watcher
# ------------------------------------------------------------
$query = New-Object System.Diagnostics.Eventing.Reader.EventLogQuery(
    $LogName,
    [System.Diagnostics.Eventing.Reader.PathType]::LogName
)

$watcher = New-Object System.Diagnostics.Eventing.Reader.EventLogWatcher($query)

Unregister-Event -SourceIdentifier FirewallCoreListener -ErrorAction SilentlyContinue

Register-ObjectEvent `
    -InputObject $watcher `
    -EventName EventRecordWritten `
    -SourceIdentifier FirewallCoreListener `
    -Action {

        try {
            $ev = $Event.SourceEventArgs.EventRecord
            if (-not $ev) { return }

            $msg = $ev.FormatDescription()
            if (-not $msg) { return }

            # Expect JSON message
            $data = $msg | ConvertFrom-Json -ErrorAction Stop

            $severity = $data.Severity
            $title    = $data.Title
            $detail   = $data.RuleName

            if (-not $severity) { $severity = "INFO" }
            if (-not $title)    { $title = "Firewall Event" }
            if (-not $detail)   { $detail = "See FirewallCore log" }

            if (-not (Should-Notify -Severity $severity)) { return }

            Show-Toast -Title $title -Line $detail -Severity $severity

            # HIGH = open Event Viewer automatically
            if ($severity -eq "HIGH" -and $Mode -eq "LIVE") {
                Start-Process eventvwr.msc | Out-Null
            }
        }
        catch {
            # Listener must never crash
        }
    }

$watcher.Enabled = $true

Write-Host "[LISTENER] Active — watching '$LogName' (Mode=$Mode)"
Write-Host "[LISTENER] Waiting for FirewallCore events..."

# Block forever
while ($true) {
    Wait-Event -Timeout 60 | Out-Null
}
