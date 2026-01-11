param(
  [ValidateSet("Info","Warn","Critical","All")]
  [string]$Severity = "All",
  [string]$TestId = ("SIGNOFF-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
)

$ErrorActionPreference = "Stop"

$LogRoot = Join-Path $env:ProgramData "FirewallCore\Logs"
New-Item -ItemType Directory -Force $LogRoot | Out-Null
$LogPath = Join-Path $LogRoot ("Notifiers-Signoff_{0}.log" -f $TestId)

function Log([string]$msg) {
  $line = ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $msg)
  $line | Tee-Object -FilePath $LogPath -Append | Out-Host
}

function Run-One([string]$sev, [string]$expectedSound, [string]$expectedAutoClose) {
  Log ""
  Log "=== SIGNOFF START: $sev ==="
  Log "Expected: Sound=$expectedSound | AutoClose=$expectedAutoClose | Click->EV Filtered View"
  if ($sev -eq "Critical") {
    Log "Expected Critical: NO autoclose | Close/X disabled | Manual Review required | Remind every 10s until acknowledged"
  }

  Log "Triggering notification..."
  try {
    # Adjust arguments here to match your actual function signature
    Send-FirewallNotification -Severity $sev -EventId 3000 -Title "$sev SIGNOFF" -Message "Signoff test ($TestId)" -TestId $TestId
    Log "[OK] Triggered $sev notification (TestId=$TestId)"
  } catch {
    Log "[FAIL] Trigger failed: $($_.Exception.Message)"
    throw
  }

  Log "Operator checks:"
  Log "  1) Confirm style for $sev"
  Log "  2) Confirm sound plays: $expectedSound"
  Log "  3) Confirm auto-close: $expectedAutoClose"
  Log "  4) Click notification -> must open Event Viewer filtered view (FirewallCore log + correct provider/event filter)"
  Log "  5) Confirm logs record: severity/eventid/context/click-handler result"
  if ($sev -eq "Critical") {
    Log "  6) Confirm Close/X does NOT dismiss"
    Log "  7) Confirm Manual Review acknowledges (reminders stop)"
    Log "  8) Confirm reminders repeat about every 10s until acknowledged"
  }

  Log "=== SIGNOFF END: $sev (manual verification required) ==="
}

$targets = @()
if ($Severity -eq "All") { $targets = @("Info","Warn","Critical") } else { $targets = @($Severity) }

foreach ($t in $targets) {
  switch ($t) {
    "Info"     { Run-One "Info"     "ding.wav"   "15s" }
    "Warn"     { Run-One "Warn"     "chimes.wav" "30s" }
    "Critical" { Run-One "Critical" "chord.wav"  "Never" }
  }
}

Log ""
Log "[DONE] Signoff run complete. Log: $LogPath"
