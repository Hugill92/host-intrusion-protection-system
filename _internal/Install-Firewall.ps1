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
# BEGIN FIREWALL POLICY APPLY (deterministic, installer-owned)
# Stages + applies FirewallCore policy on every install and
# captures PRE/POST baselines w/ SHA256 for auditability.
# ============================================================
try {
    $ProgramDataRoot = 'C:\ProgramData\FirewallCore'
    $PolicyDst       = Join-Path $ProgramDataRoot 'Policy\FirewallCorePolicy.wfw'
    $BaselineRoot    = Join-Path $ProgramDataRoot 'Baselines'
    $stamp           = Get-Date -Format 'yyyyMMdd_HHmmss'

    # Candidate policy sources (repo may vary by layout)
    $candidates = @(
        'C:\FirewallInstaller\Firewall\Policy\FirewallCorePolicy.wfw',
        'C:\FirewallInstaller\Firewall\Policy\FirewallCorePolicy.wfw'.Replace('FirewallInstaller','FirewallInstaller'), # no-op safety
        'C:\FirewallInstaller\FirewallCorePolicy.wfw',
        (Join-Path (Split-Path -Parent $PSScriptRoot) 'Firewall\Policy\FirewallCorePolicy.wfw'),
        (Join-Path (Split-Path -Parent $PSScriptRoot) 'FirewallCorePolicy.wfw')
    ) | Where-Object { $_ -and $_.Trim() -ne '' } | Select-Object -Unique

    $PolicySrc = $null
    foreach ($c in $candidates) {
        try {
            $p = (Resolve-Path $c -ErrorAction SilentlyContinue)
            if ($p) { $PolicySrc = $p.Path; break }
        } catch {}
    }

    if (-not $PolicySrc -or -not (Test-Path $PolicySrc)) {
        throw "Missing FirewallCore policy file. Expected one of: $($candidates -join ', ')"
    }

    # Stage policy into ProgramData (runtime-owned)
    New-Item -ItemType Directory -Path (Split-Path -Parent $PolicyDst) -Force | Out-Null
    Copy-Item $PolicySrc $PolicyDst -Force

    # Safety gate: refuse tiny/empty policy
    if ((Get-Item $PolicyDst).Length -lt 10240) {
        throw "Policy file too small — refusing to apply. Path: $PolicyDst"
    }

    Write-Host "[OK] FirewallCore policy staged: $PolicyDst"

    # PRE baseline
    $PreDir = Join-Path $BaselineRoot ("PRE_INSTALL_{0}" -f $stamp)
    New-Item -ItemType Directory -Path $PreDir -Force | Out-Null

    $PreFile = Join-Path $PreDir 'Firewall_PRE.wfw'
    netsh advfirewall export $PreFile | Out-Null
    Get-FileHash $PreFile -Algorithm SHA256 | Out-File ($PreFile + '.sha256') -Encoding ascii
    Write-Host "[OK] PRE firewall baseline captured: $PreFile"

    # Apply policy (deterministic enforcement)
    Write-Host "[INSTALL] Applying FirewallCore policy..."
    netsh advfirewall import $PolicyDst | Out-Null
    Write-Host "[OK] FirewallCore policy applied"

    # POST baseline
    $PostDir = Join-Path $BaselineRoot ("POST_INSTALL_{0}" -f $stamp)
    New-Item -ItemType Directory -Path $PostDir -Force | Out-Null

    $PostFile = Join-Path $PostDir 'Firewall_POST.wfw'
    netsh advfirewall export $PostFile | Out-Null
    Get-FileHash $PostFile -Algorithm SHA256 | Out-File ($PostFile + '.sha256') -Encoding ascii
    Write-Host "[OK] POST firewall baseline captured: $PostFile"

} catch {
    Write-Host ("[FATAL] Firewall policy apply failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
    throw
}
# ============================================================
# END FIREWALL POLICY APPLY
# ============================================================

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

$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ( @("-NoLogo","-NoProfile","-NonInteractive","-WindowStyle","Hidden",
    "-ExecutionPolicy","AllSigned",
    "-File","`"$DefenderScript`"") -join " " )

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
    $ToastAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ( @("-NoLogo","-STA","-NoProfile","-NonInteractive","-WindowStyle","Hidden","-ExecutionPolicy","Bypass",
        "-File","`"$ToastScript`"") -join " " )

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

# --- BEGIN FIREWALLCORE TOAST SELFHEAL INFRA ---
# Self-healing Toast Listener infra (no console windows; background tasks)
try {
    $RepoRoot = "C:\FirewallInstaller"
    $LiveRoot = "C:\Firewall"

    # ---- Copy packaged sounds (repo) -> live install root ----
    $RepoSounds = Join-Path $RepoRoot "Firewall\Sounds"
    $LiveSounds = Join-Path $LiveRoot "Sounds"
    if (Test-Path $RepoSounds) {
        if (-not (Test-Path $LiveSounds)) { New-Item -ItemType Directory -Path $LiveSounds -Force | Out-Null }
        Copy-Item -Path (Join-Path $RepoSounds "*.wav") -Destination $LiveSounds -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Sounds staged: $LiveSounds"
    } else {
        Write-Host "[WARN] Repo sounds folder missing: $RepoSounds"
    }

    # ---- Copy watchdog script -> live ----
    $RepoWatchdog = Join-Path $RepoRoot "Firewall\System\FirewallToastWatchdog.ps1"
    $LiveSystem   = Join-Path $LiveRoot "System"
    if (-not (Test-Path $LiveSystem)) { New-Item -ItemType Directory -Path $LiveSystem -Force | Out-Null }
    if (Test-Path $RepoWatchdog) {
        Copy-Item -Path $RepoWatchdog -Destination (Join-Path $LiveSystem "FirewallToastWatchdog.ps1") -Force
        Write-Host "[OK] Watchdog staged: $LiveSystem\FirewallToastWatchdog.ps1"
    } else {
        Write-Host "[WARN] Repo watchdog missing: $RepoWatchdog"
    }

    # ---- Ensure USER listener scheduled task runs hidden ----
    # If installer already creates the task, this just forces the Action args to include -WindowStyle Hidden.
    $UserTask = Get-ScheduledTask -TaskName "FirewallCore Toast Listener" -ErrorAction SilentlyContinue
    if ($UserTask) {
        try {
            $a = $UserTask.Actions[0]
            if ($a.Execute -match "powershell\.exe|pwsh\.exe") {
                if ($a.Arguments -notmatch "-WindowStyle\s+Hidden") {
                    $newArgs = $a.Arguments.Trim()
                    # Add -WindowStyle Hidden near the front (safe)
                    $newArgs = $newArgs -replace "^-NoProfile", "-NoProfile -WindowStyle Hidden"
                    if ($newArgs -eq $a.Arguments) {
                        $newArgs = "-WindowStyle Hidden " + $newArgs
                    }
                    $UserTask.Actions[0].Arguments = $newArgs
                    Set-ScheduledTask -TaskName "FirewallCore Toast Listener" -TaskPath $UserTask.TaskPath -Action $UserTask.Actions[0] | Out-Null
                    Write-Host "[OK] Updated listener task to run hidden"
                }
            }
        } catch {
            Write-Host "[WARN] Could not enforce hidden window on listener task"
        }
    }

    # ---- Create/Update SYSTEM watchdog task (every minute) ----
    $WatchdogScript = Join-Path $LiveSystem "FirewallToastWatchdog.ps1"
    if (Test-Path $WatchdogScript) {
        $tn = "FirewallCore Toast Watchdog"
        $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$WatchdogScript`""
        # Use schtasks for rock-solid minute scheduling (avoids repetition duration formatting issues)
        schtasks.exe /Create /F /TN "$tn" /SC MINUTE /MO 1 /RU "SYSTEM" /RL HIGHEST /TR "$tr" | Out-Null
        Write-Host "[OK] Watchdog task ensured: $tn"
    } else {
        Write-Host "[WARN] Watchdog script missing at install time: $WatchdogScript"
    }

    # ---- Start tasks (background) ----
    try { Start-ScheduledTask -TaskName "FirewallCore Toast Listener" | Out-Null } catch {}
    try { schtasks.exe /Run /TN "FirewallCore Toast Watchdog" | Out-Null } catch {}

} catch {
    Write-Host "[WARN] Toast self-heal infra install block failed: $($_.Exception.Message)"
}
# --- END FIREWALLCORE TOAST SELFHEAL INFRA ---







# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUf7B+doTXd60Vf3DEXdEynFRD
# aT+gggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
# hvcNAQELBQAwJzElMCMGA1UEAwwcRmlyZXdhbGxDb3JlIE9mZmxpbmUgUm9vdCBD
# QTAeFw0yNjAyMDMwNzU1NTdaFw0yOTAzMDkwNzU1NTdaMFgxCzAJBgNVBAYTAlVT
# MREwDwYDVQQLDAhTZWN1cml0eTEVMBMGA1UECgwMRmlyZXdhbGxDb3JlMR8wHQYD
# VQQDDBZGaXJld2FsbENvcmUgU2lnbmF0dXJlMFkwEwYHKoZIzj0CAQYIKoZIzj0D
# AQcDQgAExBZAuSDtDbNMz5nbZx6Xosv0IxskeV3H2I8fMI1YTGKMmeYMhml40QQJ
# wbEbG0i9e9pBd3TEr9tCbnzSOUpmTKNvMG0wCQYDVR0TBAIwADALBgNVHQ8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFKm7zYv3h0UWScu5+Z98
# 7l7v7EjsMB8GA1UdIwQYMBaAFCwozIRNrDpNuqmNvBlZruA6sHoTMA0GCSqGSIb3
# DQEBCwUAA4IBAQCbL4xxsZMbwFhgB9cYkfkjm7yymmqlcCpnt4RwF5k2rYYFlI4w
# 8B0IBaIT8u2YoNjLLtdc5UXlAhnRrtnmrGhAhXTMois32SAOPjEB0Fr/kjHJvddj
# ow7cBLQozQtP/kNQQyEj7+zgPMO0w65i5NNJkopf3+meGTZX3oHaA8ng2CvJX/vQ
# ztgEa3XUVPsGK4F3HUc4XpJAbPSKCeKn16JDr7tmb1WazxN39iIhT25rgYM3Wyf1
# XZHgqADpfg990MnXc5PCf8+1kg4lqiEhdROxmSko4EKfHPTHE3FteWJuDEfpW8p9
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIzCCAR8CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUMUFOsAO1MVAwBhjQawj9aalihO4wCwYH
# KoZIzj0CAQUABEcwRQIgNPk4F7Bu+XIAHwtrqPIesLDrRqDjIdfvhDogn7vvcSoC
# IQDT3H+FoOhq9iAvAXHq8fXx1hrg2koP6Zbe9Ca4Cyxcog==
# SIG # End signature block
