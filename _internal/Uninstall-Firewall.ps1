<#
Uninstall-Firewall.ps1 (v4)
Production-grade uninstaller with:
- Snapshot + diff
- Tamper detection
- Rollback guardrails
- Optional cert removal
- Firewall reset to defaults
#>
# ================= DEV / INSTALLER CONTEXT =================
$IsInstallerContext = $true

$FirewallRoot = if ($IsInstallerContext) {
    "C:\FirewallInstaller\Firewall"
} else {
    "C:\Firewall"
}

$ModulesDir    = Join-Path $FirewallRoot "Modules"
$SnapshotsDir  = Join-Path $FirewallRoot "Snapshots"
$DiffDir       = Join-Path $FirewallRoot "Diff"
$StateDir      = Join-Path $FirewallRoot "State"
$LogsDir       = Join-Path $FirewallRoot "Logs"
# ===========================================================


[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Quiet,
    [switch]$RemoveCerts,
    [string]$InstallerRoot = "C:\FirewallInstaller"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -------------------------
# Helpers
# -------------------------
function STEP($m){ Write-Host "[*] $m" }
function OK($m){ Write-Host "[OK] $m" }
function WARN($m){ Write-Warning $m }

function Ensure-Dir($p){
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
    }
}

# -------------------------
# Snapshot system
# -------------------------
$SnapshotDir = Join-Path $InstallerRoot "Tools\Snapshots"
Ensure-Dir $SnapshotDir

function Save-Snapshot {
    param([Parameter(Mandatory)][string]$OutFile)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("SnapshotTime: $(Get-Date -Format o)")
    $lines.Add("Computer: $env:COMPUTERNAME")
    $lines.Add("User: $env:USERNAME")
    $lines.Add("")

    $lines.Add("=== Firewall Profiles ===")
    try {
        Get-NetFirewallProfile | ForEach-Object {
            $lines.Add("Profile=$($_.Name) Enabled=$($_.Enabled) In=$($_.DefaultInboundAction) Out=$($_.DefaultOutboundAction)")
        }
    } catch {
        $lines.Add("ERROR: $($_.Exception.Message)")
    }

    $lines.Add("")
    $lines.Add("=== Scheduled Tasks ===")
    foreach ($t in @("Firewall Core Monitor","Firewall WFP Monitor")) {
        if (schtasks /Query /TN $t 2>$null) {
            $lines.Add("$t: PRESENT")
        } else {
            $lines.Add("$t: MISSING")
        }
    }

    $lines.Add("")
    $lines.Add("=== Firewall Rules (project) ===")
    try {
        $rules = Get-NetFirewallRule | Where-Object {
            $_.DisplayName -like "WFP-*"
        }
        if ($rules) {
            foreach ($r in $rules) {
                $lines.Add("RULE: $($r.DisplayName) Enabled=$($r.Enabled) Action=$($r.Action)")
            }
        } else {
            $lines.Add("(none)")
        }
    } catch {
        $lines.Add("ERROR: $($_.Exception.Message)")
    }

    Ensure-Dir (Split-Path $OutFile -Parent)
    $lines | Set-Content -Path $OutFile -Encoding UTF8
}

function Latest-Snapshot($pattern){
    Get-ChildItem $SnapshotDir -Filter $pattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

# -------------------------
# Tamper detection
# -------------------------
function Assert-NoTamper {
    param([switch]$Force)

    $manifest = "C:\Firewall\Golden\payload.manifest.sha256.json"
    if (-not (Test-Path $manifest)) {
        WARN "No payload manifest found"
        return
    }

    $m = Get-Content $manifest -Raw | ConvertFrom-Json
    $bad = @()

    foreach ($e in $m) {
        if (-not (Test-Path $e.Path)) {
            $bad += $e.Path
            continue
        }
        $h = (Get-FileHash -Algorithm SHA256 -Path $e.Path).Hash
        if ($h -ne $e.Sha256) {
            $bad += $e.Path
        }
    }

    if ($bad.Count -gt 0 -and -not $Force) {
        throw "Tamper detected in payload. Refusing uninstall (use -Force to override)."
    }

    if ($bad.Count -eq 0) {
        OK "Tamper check passed"
    }
}

# -------------------------
# Snapshot + drift gate
# -------------------------
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$preSnap = Join-Path $SnapshotDir "Snapshot-Before-Uninstall-$stamp.txt"
Save-Snapshot -OutFile $preSnap
OK "Snapshot saved: $preSnap"

Assert-NoTamper -Force:$Force

$expected = Latest-Snapshot "Snapshot-After-Install-*.txt"
if ($expected) {
    $diff = Join-Path $SnapshotDir "SnapshotDiff-PreUninstall-$stamp.txt"
    Compare-Object (Get-Content $expected.FullName) (Get-Content $preSnap) |
        Set-Content $diff

    if ((Get-Item $diff).Length -gt 0 -and -not $Force) {
        throw "System drift detected vs install snapshot. Review $diff (use -Force to override)."
    }
}

if (-not $Force -and -not $Quiet) {
    $resp = Read-Host "Type UNINSTALL to proceed"
    if ($resp -ne "UNINSTALL") { throw "User aborted uninstall" }
}

# -------------------------
# UNINSTALL ACTIONS
# -------------------------
STEP "Stopping scheduled tasks"

# Core monitors (SYSTEM / admin)
schtasks /Delete /TN "Firewall Core Monitor" /F 2>$null | Out-Null
schtasks /Delete /TN "Firewall WFP Monitor" /F 2>$null | Out-Null

# User-context notifier (v1)
$UserNotifierTask = "FirewallCore User Notifier"
Get-ScheduledTask -TaskName $UserNotifierTask -ErrorAction SilentlyContinue |
    Unregister-ScheduledTask -Confirm:$false

OK "Scheduled tasks removed (including user notifier if present)"

STEP "Removing firewall rules"
Get-NetFirewallRule | Where-Object {
    $_.DisplayName -like "WFP-*"
} | Remove-NetFirewallRule -ErrorAction SilentlyContinue

STEP "Resetting Windows Firewall to defaults"
netsh advfirewall reset | Out-Null

if ($RemoveCerts) {
    STEP "Removing Firewall signing certificates"
    Get-ChildItem Cert:\LocalMachine\Root |
        Where-Object Subject -like "*Firewall*" |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

STEP "Removing C:\Firewall directory"
Remove-Item "C:\Firewall" -Recurse -Force -ErrorAction SilentlyContinue

# -------------------------
# Post snapshot
# -------------------------
$postSnap = Join-Path $SnapshotDir "Snapshot-After-Uninstall-$stamp.txt"
Save-Snapshot -OutFile $postSnap
OK "Post-uninstall snapshot saved: $postSnap"

OK "Firewall Core successfully uninstalled"
