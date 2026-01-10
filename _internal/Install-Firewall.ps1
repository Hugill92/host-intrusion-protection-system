# Install-Firewall.ps1
# One-shot installer for Firewall Core system
# MUST be run as admin (auto-elevates)

param(
    [ValidateSet("DEV","LIVE")]
    [string]$Mode = "LIVE"
)

# --- Ensure FirewallCore Event Log ---
$log = "FirewallCore"

if (-not [System.Diagnostics.EventLog]::Exists($log)) {
    New-EventLog -LogName $log -Source "FirewallCore"
    New-EventLog -LogName $log -Source "FirewallCore-Pentest"
}


Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$PSNativeCommandUseErrorActionPreference = $true

# ============================================================
# SELF-ELEVATION (MUST BE FIRST – NOTHING ABOVE THIS)
# ============================================================
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "[*] Elevation required. Relaunching as Administrator..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy","Bypass",
        "-File","`"$PSCommandPath`"",
        "-Mode",$Mode
    )
    exit
}

# ============================================================
# ROOTS – SINGLE SOURCE OF TRUTH
# ============================================================
$InstallerRoot = "C:\FirewallInstaller"
$InternalRoot  = Join-Path $InstallerRoot "_internal"
$FirewallRoot  = Join-Path $InstallerRoot "Firewall"

$InternalSystemDir = Join-Path $InternalRoot "System"
$LiveSystemDir     = Join-Path $FirewallRoot "System"

$BasePath     = "C:\Firewall"
$Maintenance  = Join-Path $BasePath "Maintenance"
$Monitor      = Join-Path $BasePath "Monitor"
$StateDir     = Join-Path $BasePath "State"
$LogsDir      = Join-Path $BasePath "Logs"

$CertFilePath   = Join-Path $BasePath "ScriptSigningCert.cer"
$CertThumbprint = "FEEFF3FF92386D69793128F4605155EF285A0CE4"
$DefenderScript = Join-Path $Maintenance "Enable-DefenderIntegration.ps1"

$Global:FirewallMode = $Mode

# ============================================================
# DIRECTORY PREP
# ============================================================
New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $LogsDir "Install") -Force | Out-Null
New-Item -ItemType Directory -Path $LiveSystemDir -Force | Out-Null

# ============================================================
# LOGGING
# ============================================================
$LogFile = Join-Path (Join-Path $LogsDir "Install") "install.log"

function Stop-TranscriptSafe {
    try { Stop-Transcript | Out-Null } catch {}
}

trap {
    Write-Host "[FATAL] $($_.Exception.Message)" -ForegroundColor Red
    Stop-TranscriptSafe
    exit 1
}

Start-Transcript -Path $LogFile -Append | Out-Null

Write-Output "================================================="
Write-Output "Firewall Core Installation Started"
Write-Output "Time      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "User      : $env:USERNAME"
Write-Output "Computer  : $env:COMPUTERNAME"
Write-Output "Mode      : $Mode"
Write-Output "Elevated  : True"
Write-Output "================================================="
Write-Output ""

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Host "[*] Starting Firewall Core installation..." -ForegroundColor Cyan

# ============================================================
# MATERIALIZE SYSTEM SCRIPTS (INSTALLER → LIVE TREE)
# ============================================================
$RequiredSystemScripts = @(
    "Register-FirewallCore-EventLog.ps1"
)

foreach ($script in $RequiredSystemScripts) {
    $src = Join-Path $InternalSystemDir $script
    $dst = Join-Path $LiveSystemDir $script

    if (-not (Test-Path $src)) {
        throw "Installer missing required system script: $src"
    }

    Copy-Item $src $dst -Force
}

# ============================================================
# REGISTER FIREWALLCORE EVENT LOG (LIVE TREE ONLY)
# ============================================================
$EventLogScript = Join-Path $LiveSystemDir "Register-FirewallCore-EventLog.ps1"

if (-not (Test-Path $EventLogScript)) {
    throw "Event log script missing after materialization: $EventLogScript"
}

Write-Host "[INSTALL] Registering FirewallCore event log..." -ForegroundColor Cyan
& $EventLogScript
Write-Host "[INSTALL] FirewallCore event log ready." -ForegroundColor Green

# ============================================================
# CERTIFICATE
# ============================================================
Write-Host "[CERT] Checking trusted certificate" -ForegroundColor Cyan

$cert = Get-ChildItem Cert:\LocalMachine\Root |
    Where-Object Thumbprint -EQ $CertThumbprint

if (-not $cert) {
    if (-not (Test-Path $CertFilePath)) {
        throw "Missing certificate file: $CertFilePath"
    }
    Import-Certificate -FilePath $CertFilePath `
        -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    Write-Host "[CERT] Certificate imported" -ForegroundColor Green
} else {
    Write-Host "[CERT] Certificate already trusted" -ForegroundColor DarkGray
}

# ============================================================
# SCHEDULED TASK – DEFENDER INTEGRATION (SYSTEM)
# ============================================================
if (-not (Test-Path $DefenderScript)) {
    throw "Missing Defender integration script: $DefenderScript"
}

$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument @(
    "-NoProfile",
    "-ExecutionPolicy","AllSigned",
    "-File","`"$DefenderScript`""
)

$Trigger   = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName "Firewall-Defender-Integration" `
    -Action $Action `
    -Trigger $Trigger `
    -Principal $Principal `
    -Settings $Settings `
    -Force | Out-Null

Write-Host "[OK] Scheduled task registered: Firewall-Defender-Integration" -ForegroundColor Green

# ============================================================
# TOAST LISTENER (USER LOGON)
# ============================================================
$ToastScript = Join-Path $FirewallRoot "User\FirewallToastListener.ps1"

if (Test-Path $ToastScript) {
    $ToastAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument @(
        "-STA","-NoProfile","-ExecutionPolicy","Bypass",
        "-File","`"$ToastScript`""
    )

    $ToastTrigger   = New-ScheduledTaskTrigger -AtLogOn
    $ToastPrincipal = New-ScheduledTaskPrincipal `
        -UserId "$env:USERDOMAIN\$env:USERNAME" `
        -LogonType Interactive `
        -RunLevel Highest

    Register-ScheduledTask `
        -TaskName "FirewallCore-ToastListener" `
        -Action $ToastAction `
        -Trigger $ToastTrigger `
        -Principal $ToastPrincipal `
        -Force | Out-Null

    Write-Host "[OK] Toast listener registered" -ForegroundColor Green
}

# ============================================================
# INSTALL FLAG
# ============================================================
New-Item -ItemType File -Path (Join-Path $StateDir "installed.flag") -Force | Out-Null

Write-Output ""
Write-Output "================================================="
Write-Output "Firewall Core Installation Completed Successfully"
Write-Output "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "================================================="
Write-Output ""

Stop-TranscriptSafe
Write-Host "[SUCCESS] Firewall Core installation completed." -ForegroundColor Green
