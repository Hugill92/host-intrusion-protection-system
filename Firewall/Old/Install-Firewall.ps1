# Install-Firewall.ps1
# FINAL – SIMPLE – WORKING

# ----------------------------
# Execution Policy Safety Net
# ----------------------------
try {
    $currentPolicy = Get-ExecutionPolicy -Scope Process
    if ($currentPolicy -ne 'Bypass') {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    }
} catch {
    Write-Error "Failed to set process execution policy"
    exit 1
}


$ErrorActionPreference = "Stop"

function OK($m){Write-Host "[OK] $m"}
function STEP($m){Write-Host "[*] $m"}
function WARN($m){Write-Warning $m}

# ---- ADMIN CHECK ----
if (-not ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')) {
    Write-Error "Run as Administrator"
    exit 1
}

$SourceRoot  = $PSScriptRoot
$InstallRoot = "C:\Firewall"
$TaskName    = "Firewall Core Monitor"
$RepeatMin   = 5
$SchTasks    = "C:\Windows\System32\schtasks.exe"

STEP "Source: $SourceRoot"
STEP "Install: $InstallRoot"

# ---- DIRECTORIES ----
$dirs = @(
    $InstallRoot,
    "$InstallRoot\Monitor",
    "$InstallRoot\Maintenance",
    "$InstallRoot\Modules",
    "$InstallRoot\State",
    "$InstallRoot\Logs",
    "$InstallRoot\Golden"
)

foreach ($d in $dirs) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}
OK "Directories created"

# ---- COPY FILES ----
$maps = @("Monitor","Maintenance","Modules","Golden","State")
foreach ($m in $maps) {
    $src = Join-Path $SourceRoot $m
    $dst = Join-Path $InstallRoot $m
    if (Test-Path $src) {
        Copy-Item "$src\*" $dst -Recurse -Force
        OK "Copied $m"
    }
}

Get-ChildItem $SourceRoot -Filter "*.ps1" -File |
    ForEach-Object {
        Copy-Item $_.FullName (Join-Path $InstallRoot $_.Name) -Force
    }

# ---- CERT TRUST ----
$cer = Join-Path $SourceRoot "ScriptSigningCert.cer"
if (Test-Path $cer) {
    Import-Certificate -FilePath $cer -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    OK "Certificate trusted"
}

# ---- VERIFY FILES ----
$required = @(
    "$InstallRoot\Monitor\Firewall-Core.ps1",
    "$InstallRoot\State\baseline.json"
)
foreach ($f in $required) {
    if (-not (Test-Path $f)) {
        Write-Error "Missing required file: $f"
        exit 1
    }
}
OK "Required files present"

# ---- EVENT LOG ----
if (-not [System.Diagnostics.EventLog]::SourceExists("Firewall-Core")) {
    New-EventLog -LogName Firewall -Source Firewall-Core
    OK "Event log source created"
}

# ---- SCHEDULED TASK (CORRECT) ----
STEP "Creating scheduled task..."

$fwCore = "$InstallRoot\Monitor\Firewall-Core.ps1"

# Delete if exists
Start-Process $SchTasks -ArgumentList "/Delete /TN `"$TaskName`" /F" -Wait -NoNewWindow -ErrorAction SilentlyContinue

# Create task
Start-Process $SchTasks -ArgumentList (
    "/Create /TN `"$TaskName`" /SC MINUTE /MO $RepeatMin /RU SYSTEM /RL HIGHEST " +
    "/TR `"powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$fwCore`"`" /F"
) -Wait -NoNewWindow

# Run task
Start-Process $SchTasks -ArgumentList "/Run /TN `"$TaskName`"" -Wait -NoNewWindow

OK "FIREWALL CORE INSTALLED SUCCESSFULLY"


# ---- EXECUTION POLICY HARDENING ----
STEP "Configuring execution policies..."

# Always safe: CurrentUser
try {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    OK "ExecutionPolicy CurrentUser = RemoteSigned"
} catch {
    WARN "Could not set CurrentUser execution policy: $_"
}

# Best-effort: LocalMachine (may be overridden by GP)
try {
    Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy AllSigned -Force
    OK "ExecutionPolicy LocalMachine = AllSigned"
} catch {
    WARN "LocalMachine execution policy overridden by Group Policy (expected on some systems)"
}

# Report final effective policy
$effective = Get-ExecutionPolicy
STEP "Effective execution policy: $effective"
