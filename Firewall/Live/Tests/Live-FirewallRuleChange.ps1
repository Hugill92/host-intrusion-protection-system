Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$BaselineDir  = "C:\FirewallInstaller\Firewall\Live\Baseline"
$BaselineFile = Join-Path $BaselineDir "firewall-baseline.json"

if (-not (Test-Path $BaselineDir)) {
    New-Item -ItemType Directory -Path $BaselineDir -Force | Out-Null
}

function Snapshot-Rules {
    Get-NetFirewallRule |
        Select-Object `
            InstanceID,
            DisplayName,
            Enabled,
            Action,
            Profile,
            Direction,
            PolicyStoreSourceType,
            RuleGroup
}

# --- Create baseline if missing ---
if (-not (Test-Path $BaselineFile)) {
    Snapshot-Rules |
        ConvertTo-Json -Depth 6 |
        Out-File $BaselineFile -Encoding UTF8

    Write-Host "[LIVE] Baseline created - no comparison performed"
    return
}

$baseline = Get-Content $BaselineFile -Raw | ConvertFrom-Json
$current  = Snapshot-Rules

$diff = Compare-Object `
    $baseline `
    $current `
    -Property `
        InstanceID,
        Enabled,
        Action,
        Profile,
        Direction `
    -PassThru

if ($diff) {

    # Severity hook (event + future toast)
    . "C:\FirewallInstaller\Firewall\System\Write-FirewallSeverity.ps1" `
        -Severity "HIGH" `
        -Title "Firewall Rule Instance Modified" `
        -Details "One or more firewall rule instances changed from baseline." `
        -Context @{
            ChangedRules = $diff |
                Select-Object DisplayName, Profile, Enabled, Action, Direction
            Count     = $diff.Count
            User      = $env:USERNAME
            Host      = $env:COMPUTERNAME
            Timestamp = (Get-Date).ToString("o")
        }

    Write-Host "[LIVE] Firewall rule INSTANCE change detected - HIGH severity"
}
else {
    Write-Host "[LIVE] No firewall rule changes detected"
}

# --- Update baseline AFTER detection ---
$current |
    ConvertTo-Json -Depth 6 |
    Out-File $BaselineFile -Encoding UTF8
