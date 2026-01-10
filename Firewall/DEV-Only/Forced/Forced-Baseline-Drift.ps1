[CmdletBinding()]
param(
    [ValidateSet("DEV","LIVE")]
    [string]$Mode = "DEV",
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log($m){ if(-not $Quiet){ Write-Host $m } }
function Result($s){
    $c = @{ PASS="Green"; FAIL="Red"; SKIPPED="Yellow" }[$s]
    Write-Host "[FORCED-RESULT] $s" -ForegroundColor $c
}

$FirewallRoot = "C:\FirewallInstaller\Firewall"
$BaselinePath = Join-Path $FirewallRoot "State\Baseline\baseline.sha256.json"

if ($Mode -ne "LIVE") {
    Log "[INFO] DEV mode  baseline drift test skipped"
    Result "SKIPPED"
    exit 0
}

if (-not (Test-Path $BaselinePath)) {
    throw "Baseline missing  cannot validate drift"
}

$baseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json
$algo = $baseline.Algorithm

$drift = @()

foreach ($item in $baseline.Items) {
    if (-not (Test-Path $item.Path)) {
        $drift += [pscustomobject]@{
            Type = "MissingFile"
            Path = $item.Path
        }
        continue
    }

    $h = (Get-FileHash -Algorithm $algo -Path $item.Path).Hash
    if ($h -ne $item.Sha256) {
        $drift += [pscustomobject]@{
            Type = "HashMismatch"
            Path = $item.Path
        }
    }
}

if ($drift.Count -eq 0) {
    Log "[OK] No baseline drift detected"
    Result "PASS"
    exit 0
}

Log "[WARN] Baseline drift detected  analyzing firewall state"

$rules = Get-NetFirewallRule | Select DisplayName, Enabled, Action, Direction, Profile
$malicious = @()

foreach ($r in $rules) {
    if (-not $r.Enabled -and $r.DisplayName -like "WFP-*") {
        $malicious += "Security rule disabled: $($r.DisplayName)"
    }
    if ($r.Action -eq "Allow" -and $r.DisplayName -like "WFP-*") {
        $malicious += "Allow rule present: $($r.DisplayName)"
    }
}

foreach ($p in Get-NetFirewallProfile) {
    if ($p.DefaultInboundAction -ne "Block") {
        $malicious += "Inbound default not BLOCK on profile $($p.Name)"
    }
}

$severity = if ($malicious.Count -gt 0) { "Critical" } else { "Warning" }

try {
    Import-Module "$FirewallRoot\Modules\FirewallNotifications.psm1" -Force -ErrorAction Stop
    $msg = if ($severity -eq "Critical") {
        "Baseline drift + firewall weakening detected:`n" + ($malicious -join "`n")
    } else {
        "Baseline drift detected with no live firewall weakening."
    }

    Send-FirewallNotification `
        -Severity $severity `
        -Title "Firewall baseline drift detected" `
        -Message $msg `
        -Notify @("Popup","Event") `
        -TestId "Forced-Baseline-Drift"
}
catch {}

if ($severity -eq "Critical") {
    Result "FAIL"
    exit 2
}

Result "PASS"
exit 0
