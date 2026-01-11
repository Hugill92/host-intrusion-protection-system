param(
  [Parameter(Mandatory)] [string]$Title,
  [Parameter(Mandatory)] [string]$Message,
  [int]$TimeoutMs = 15000,
  [switch]$OpenEventViewerOnClick
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ni = New-Object System.Windows.Forms.NotifyIcon
$ni.Icon = [System.Drawing.SystemIcons]::Information
$ni.Visible = $true
$ni.BalloonTipTitle = $Title
$ni.BalloonTipText  = $Message
$ni.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]::Info

$clicked = $false
$sub = Register-ObjectEvent -InputObject $ni -EventName BalloonTipClicked -Action {
  $script:clicked = $true
} | Out-Null

$ni.ShowBalloonTip($TimeoutMs)

# Wait up to timeout for click
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
  Start-Sleep -Milliseconds 100
  if ($script:clicked) { break }
}

if ($script:clicked -and $OpenEventViewerOnClick) {
  Start-Process "eventvwr.msc"
}

# Cleanup
Unregister-Event -SourceIdentifier $sub.Name -ErrorAction SilentlyContinue
$ni.Visible = $false
$ni.Dispose()
