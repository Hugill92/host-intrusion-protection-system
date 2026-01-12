# Install-Firewall.ps1
# One-shot installer for Firewall Core system
# MUST be run as admin (auto-elevates)

param(
    [ValidateSet("DEV","LIVE")]
    [string]$Mode = "LIVE"
)

# --- Ensure FirewallCore Event Log (sources) ---
$log = "FirewallCore"
$EventLogPrecheckWarning = $null
try {
    if (-not [System.Diagnostics.EventLog]::SourceExists("FirewallCore")) {
        New-EventLog -LogName $log -Source "FirewallCore"
    }
    if (-not [System.Diagnostics.EventLog]::SourceExists("FirewallCore-Pentest")) {
        New-EventLog -LogName $log -Source "FirewallCore-Pentest"
    }
} catch {
    $EventLogPrecheckWarning = "Event log source precheck failed: $($_.Exception.Message). Will rely on Register-FirewallCore-EventLog.ps1."
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
$ThisDir = $PSScriptRoot

# Expected layout:
#   <InstallerRoot>\_internal\Install-Firewall.ps1   (this script)
#   <InstallerRoot>\_internal\System\...            (installer payload)
#   <InstallerRoot>\Firewall\...                     (repo payload / staging)
$InstallerRoot = if ((Split-Path -Leaf $ThisDir) -ieq "_internal") {
    Split-Path -Parent $ThisDir
} else {
    $ThisDir
}

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
    try { Stop-Transcript | Out-Null } catch { Write-Host "[WARN] Stop-Transcript failed: $($_.Exception.Message)" -ForegroundColor Yellow }
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

Write-Output "[STEP] Resolve roots and paths"
Write-Output "InstallerRoot : $InstallerRoot"
Write-Output "InternalRoot  : $InternalRoot"
Write-Output "FirewallRoot  : $FirewallRoot"
Write-Output "BasePath      : $BasePath"
Write-Output "LiveSystemDir : $LiveSystemDir"
Write-Output "LogsDir       : $LogsDir"
Write-Output ""

if ($EventLogPrecheckWarning) {
    Write-Host "[WARN] $EventLogPrecheckWarning" -ForegroundColor Yellow
}

$commandLine = [Environment]::CommandLine
$hasBypass = $commandLine -match '(?i)-ExecutionPolicy\s+Bypass'
if (-not $hasBypass) {
    try {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
    } catch {
        Write-Host "[WARN] Set-ExecutionPolicy failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "[*] Starting Firewall Core installation..." -ForegroundColor Cyan

# ============================================================
# MATERIALIZE SYSTEM SCRIPTS (INSTALLER → LIVE TREE)
# ============================================================
$RequiredSystemScripts = @(
    "Register-FirewallCore-EventLog.ps1"
)

function Resolve-InstallerPayloadScript {
    param([Parameter(Mandatory)][string]$Name)

    $candidates = @(
        (Join-Path $InternalSystemDir $Name),
        (Join-Path (Join-Path $FirewallRoot "System") $Name),
        (Join-Path $PSScriptRoot $Name)
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    return $candidates | Select-Object -First 1
}

Write-Output "[STEP] Materialize system scripts"
foreach ($script in $RequiredSystemScripts) {
    $src = Resolve-InstallerPayloadScript -Name $script
    $dst = Join-Path $LiveSystemDir $script

    if (-not $src) {
        throw "Installer missing required system script (searched _internal\System + Firewall\System): $script"
    }

    Copy-Item -LiteralPath $src -Destination $dst -Force
}

Write-Host "[OK] System scripts materialized: $LiveSystemDir" -ForegroundColor Green



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

$store = $null
try {
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $cert = $store.Certificates | Where-Object { $_.Thumbprint -eq $CertThumbprint }
    if (-not $cert) {
        if (-not (Test-Path $CertFilePath)) {
            throw "Missing certificate file: $CertFilePath"
        }
        $newCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertFilePath)
        $store.Add($newCert)
        Write-Host "[CERT] Certificate imported" -ForegroundColor Green
    } else {
        Write-Host "[CERT] Certificate already trusted" -ForegroundColor DarkGray
    }
} finally {
    if ($store) { $store.Close() }
}

# ============================================================
# SCHEDULED TASK - DEFENDER INTEGRATION (SYSTEM)
# ============================================================
Write-Output "[STEP] Register scheduled tasks"
if (-not (Test-Path $DefenderScript)) {
    throw "Missing Defender integration script: $DefenderScript"
}

$ActionArgs = '-NoProfile -ExecutionPolicy AllSigned -File "{0}"' -f $DefenderScript
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $ActionArgs

$Trigger   = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -Hidden

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
$LiveUserDir       = Join-Path $BasePath "User"
$ToastRunnerLive   = Join-Path $LiveUserDir "FirewallToastListener-Runner.ps1"
$ToastListenerLive = Join-Path $LiveUserDir "FirewallToastListener.ps1"
$ToastScript       = $null

if (Test-Path $ToastRunnerLive) {
    $ToastScript = $ToastRunnerLive
} elseif (Test-Path $ToastListenerLive) {
    $ToastScript = $ToastListenerLive
} else {
    $ToastScript = Join-Path $FirewallRoot "User\FirewallToastListener.ps1"
}

if (Test-Path $ToastScript) {
    $ToastActionArgs = '-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -STA -ExecutionPolicy Bypass -File "{0}"' -f $ToastScript
    $ToastAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $ToastActionArgs
    $ToastTrigger = New-ScheduledTaskTrigger -AtLogOn
    $ToastPrincipal = New-ScheduledTaskPrincipal `
        -UserId "$env:USERDOMAIN\$env:USERNAME" `
        -LogonType Interactive `
        -RunLevel Highest
    $ToastSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -Hidden

    Register-ScheduledTask `
        -TaskName "FirewallCore Toast Listener" `
        -Action $ToastAction `
        -Trigger $ToastTrigger `
        -Principal $ToastPrincipal `
        -Settings $ToastSettings `
        -Force | Out-Null

    Write-Host "[OK] Toast listener registered" -ForegroundColor Green
} else {
    Write-Host "[WARN] Toast listener script not found (skipped task): $ToastScript" -ForegroundColor Yellow
}

# ============================================================
# TOAST PROTOCOL HANDLER (REVIEW LOG / DETAILS)
# ============================================================
$Protocol = "firewallcore-review"
$ActivateScript = Join-Path $BasePath "User\FirewallToastActivate.ps1"
$PsExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$ProtocolCommand = "`"$PsExe`" -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ActivateScript`" `"%1`""

function Register-ToastProtocol {
    param([Parameter(Mandatory)][string]$RootKey)

    $base = Join-Path $RootKey ("Software\Classes\{0}" -f $Protocol)
    $cmdKey = Join-Path $base "shell\open\command"

    New-Item -Path $base -Force | Out-Null
    New-Item -Path $cmdKey -Force | Out-Null

    New-ItemProperty -Path $base -Name "(default)" -Value ("URL:{0}" -f $Protocol) -Force | Out-Null
    New-ItemProperty -Path $base -Name "URL Protocol" -Value "" -Force | Out-Null
    Set-ItemProperty -Path $cmdKey -Name "(default)" -Value $ProtocolCommand -Force | Out-Null
}

if (Test-Path $ActivateScript) {
    try {
        Register-ToastProtocol -RootKey "HKLM:\"
        Register-ToastProtocol -RootKey "HKCU:\"
        Write-Host "[OK] Protocol handler registered (firewallcore-review)" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] Protocol handler registration failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "[WARN] Protocol handler skipped; missing $ActivateScript" -ForegroundColor Yellow
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
    Write-Host "[STEP] Toast self-heal infra" -ForegroundColor Cyan
    $RepoRoot = $InstallerRoot
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
    $LiveUserDir       = Join-Path $LiveRoot "User"
    $ToastRunnerLive   = Join-Path $LiveUserDir "FirewallToastListener-Runner.ps1"
    $ToastListenerLive = Join-Path $LiveUserDir "FirewallToastListener.ps1"
    $ToastTaskScript   = $null

    if (Test-Path $ToastRunnerLive) {
        $ToastTaskScript = $ToastRunnerLive
    } elseif (Test-Path $ToastListenerLive) {
        $ToastTaskScript = $ToastListenerLive
    }

    $ToastTasks = @(
        "FirewallCore Toast Listener",
        "FirewallCore-ToastListener"
    )
    foreach ($toastTaskName in $ToastTasks) {
        $UserTask = Get-ScheduledTask -TaskName $toastTaskName -ErrorAction SilentlyContinue
        if ($UserTask) {
            try {
                if ($ToastTaskScript) {
                    $toastArgs = '-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -STA -ExecutionPolicy Bypass -File "{0}"' -f $ToastTaskScript
                    $toastAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $toastArgs
                    Set-ScheduledTask -TaskName $toastTaskName -TaskPath $UserTask.TaskPath -Action $toastAction | Out-Null
                    Write-Host "[OK] Updated listener task action: $toastTaskName" -ForegroundColor Green
                } else {
                    $a = $UserTask.Actions[0]
                    if ($a.Execute -match "powershell\.exe|pwsh\.exe") {
                        if ($a.Arguments -notmatch "-WindowStyle\\s+Hidden") {
                            $newArgs = $a.Arguments.Trim()
                            # Add -WindowStyle Hidden near the front (safe)
                            $newArgs = $newArgs -replace "^-NoProfile", "-NoProfile -WindowStyle Hidden"
                            if ($newArgs -eq $a.Arguments) {
                                $newArgs = "-WindowStyle Hidden " + $newArgs
                            }
                            $UserTask.Actions[0].Arguments = $newArgs
                            Set-ScheduledTask -TaskName $toastTaskName -TaskPath $UserTask.TaskPath -Action $UserTask.Actions[0] | Out-Null
                            Write-Host "[OK] Updated listener task to run hidden: $toastTaskName"
                        }
                    }
                }
            } catch {
                Write-Host "[WARN] Could not enforce hidden window on ${toastTaskName}: $($_.Exception.Message)" -ForegroundColor Yellow
            }
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

    # ---- Restart toast processes to ensure hidden execution ----
    $toastPattern = 'FirewallToastListener(-Runner)?\\.ps1|FirewallToastWatchdog\\.ps1'
    $toastProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -and $_.CommandLine -match $toastPattern
    }
    if ($toastProcs) {
        try {
            Stop-Process -Id $toastProcs.ProcessId -Force -ErrorAction Stop
            Write-Host "[OK] Stopped toast processes before restart"
        } catch {
            Write-Host "[WARN] Failed to stop toast processes: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # ---- Start tasks (background) ----
    try { Start-ScheduledTask -TaskName "FirewallCore Toast Listener" | Out-Null } catch { Write-Host "[WARN] Failed to start Toast Listener task: $($_.Exception.Message)" -ForegroundColor Yellow }
    try { schtasks.exe /Run /TN "FirewallCore Toast Watchdog" | Out-Null } catch { Write-Host "[WARN] Failed to start Toast Watchdog task: $($_.Exception.Message)" -ForegroundColor Yellow }

} catch {
    Write-Host "[WARN] Toast self-heal infra install block failed: $($_.Exception.Message)"
}
# --- END FIREWALLCORE TOAST SELFHEAL INFRA ---
