[CmdletBinding()]
param(
    [string]$FirewallRoot = "C:\FirewallInstaller\Firewall",
    [switch]$FailOnDrift = $true,
    [switch]$EmitEvents,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log($m){ if(-not $Quiet){ Write-Host $m } }

# Notification (best effort)
$NotifAvailable = $false
try {
    Import-Module (Join-Path $FirewallRoot "Modules\FirewallNotifications.psm1") -Force -ErrorAction Stop
    $NotifAvailable = $true
} catch { $NotifAvailable = $false }

function Safe-Notify {
    param(
        [string]$Severity,
        [string]$Title,
        [string]$Message,
        [string[]]$Notify,
        [string]$TestId
    )
    if (-not $NotifAvailable) { return }
    try {
        Send-FirewallNotification `
            -Severity $Severity `
            -Title $Title `
            -Message $Message `
            -Notify $Notify `
            -TestId $TestId
    } catch { }
}

$StateDir = Join-Path $FirewallRoot "State\Baseline"
$JsonPath = Join-Path $StateDir "baseline.sha256.json"

if (-not (Test-Path $JsonPath)) {
    throw "Baseline file missing: $JsonPath"
}

$baseline = Get-Content $JsonPath -Raw | ConvertFrom-Json
$algo     = $baseline.Algorithm
$testId  = "Baseline-Integrity"

$findings = New-Object System.Collections.Generic.List[object]

foreach ($item in $baseline.Items) {
    $p = [string]$item.Path

    if (-not (Test-Path $p)) {
        $findings.Add([pscustomobject]@{
            Severity = "Critical"
            Reason   = "Missing baseline file"
            Path     = $p
        })
        continue
    }

    $fi = Get-Item $p
    $h  = (Get-FileHash -Algorithm $algo -Path $p).Hash

    if ($h -ne [string]$item.Sha256) {
        $findings.Add([pscustomobject]@{
            Severity = "Critical"
            Reason   = "Hash mismatch"
            Path     = $p
            Expected = [string]$item.Sha256
            Actual   = $h
        })
    }
    elseif ([int64]$fi.Length -ne [int64]$item.Length) {
        $findings.Add([pscustomobject]@{
            Severity = "Warning"
            Reason   = "Length drift"
            Path     = $p
        })
    }
}

if ($findings.Count -eq 0) {
    Log "[OK] Baseline integrity verified (no drift)"
    exit 0
}

foreach ($f in $findings) {
    if ($EmitEvents) {
        Write-Host "[EVENT] $(($f | ConvertTo-Json -Compress))"
    }
}

$crit = ($findings | Where-Object Severity -eq "Critical").Count
$warn = ($findings | Where-Object Severity -eq "Warning").Count

$sev = if ($crit -gt 0) { "Critical" } else { "Warning" }
$msg = "Baseline drift detected. Critical=$crit Warning=$warn"

Safe-Notify `
    -Severity $sev `
    -Title "Firewall baseline drift detected" `
    -Message $msg `
    -Notify @("Popup","Event") `
    -TestId $testId

if ($FailOnDrift) { exit 2 } else { exit 0 }
