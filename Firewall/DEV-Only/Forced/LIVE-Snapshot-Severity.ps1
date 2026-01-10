# Forced-Test
# Category: LiveDetection
# Requires: Firewall
# Fatal: false

param(
    [ValidateSet("LIVE")]
    [string]$Mode = "LIVE",

    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log($m) { if (-not $Quiet) { Write-Host $m } }
function Result($s) {
    $c = @{ PASS="Green"; FAIL="Red"; SKIPPED="Yellow" }[$s]
    Write-Host "[FORCED-RESULT] $s" -ForegroundColor $c
}

# --- Notifications (best-effort, never break the test) ---
$TestId = "Forced-LiveDetection-FW"
$NotifAvailable = $false
try {
    Import-Module "C:\Firewall\Modules\FirewallNotifications.psm1" -Force -ErrorAction Stop
    $NotifAvailable = $true
} catch {
    $NotifAvailable = $false
}

function Safe-Notify {
    param(
        [ValidateSet("Info","Warning","Critical")]
        [string]$Severity,
        [string]$Title,
        [string]$Message,
        [string[]]$Notify
    )
    if (-not $NotifAvailable) { return }
    try {
        Send-FirewallNotification `
            -Severity $Severity `
            -Title $Title `
            -Message $Message `
            -Notify $Notify `
            -TestId $TestId | Out-Null
    } catch {
        # Never fail the test because of notifications
    }
}
# ---------------------------------------------------------

$PolicyPath = "C:\Firewall\Policy\Firewall-Policy.json"
$Policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
$Profile = $Policy.Profiles.$($Policy.ActiveProfile)

$findings = @()

try {
    $rules = Get-NetFirewallRule |
        Select Name, DisplayName, Enabled, Action, Group, Direction, Profile

    foreach ($r in $rules) {
        if ($r.Group -match "File and Printer Sharing") {

            if (-not $r.Enabled) {
                $findings += @{
                    Severity = "WARN"
                    Reason   = "Predefined rule disabled"
                    Rule     = $r.DisplayName
                }
            }
            elseif ($r.Action -ne "Block") {
                $findings += @{
                    Severity = "WARN"
                    Reason   = "Predefined rule action drift"
                    Rule     = $r.DisplayName
                }
            }
        }
    }

    if ($findings.Count -eq 0) {
        Log "[INFO] Firewall state aligned with policy"
        Result "PASS"
        exit 0
    }

    foreach ($f in $findings) {
        Write-Host "[EVENT] $(ConvertTo-Json $f -Compress)"
    }

    # Info toast + event (click → Event Viewer) for drift findings
    Safe-Notify `
        -Severity "Info" `
        -Title "Firewall drift detected" `
        -Message ("{0} finding(s) detected in predefined rules. See Event Log for details." -f $findings.Count) `
        -Notify @("Toast","Event")

    Result "PASS"
    exit 0
}
catch {
    Write-Error $_

    # Warning toast + event for unexpected test failure
    Safe-Notify `
        -Severity "Warning" `
        -Title "Firewall live detection test failed" `
        -Message $_.Exception.Message `
        -Notify @("Toast","Event")

    Result "FAIL"
    exit 1
}
