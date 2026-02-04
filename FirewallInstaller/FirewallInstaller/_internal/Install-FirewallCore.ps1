# Install-Firewall.ps1
# One-shot installer for Firewall Core system
# MUST be run as admin (auto-elevates)

param(
  [ValidateSet('DEV','LIVE')]
  [string]$Mode = 'LIVE'
)

# --- Bootstrap logging (PS5.1-safe, AllSigned friendly) ---
if (-not (Get-Command auditLog -ErrorAction SilentlyContinue)) {
  function auditLog {
    param(
      [Parameter(Mandatory=$false)][string]$Level = 'INFO',
      [Parameter(Mandatory=$true )][string]$Message
    )
    try {

      $line = ('[{0}] {1}' -f $Level.ToUpperInvariant(), $Message)
      if ($script:AuditLogPath) {
        $dir = Split-Path -Parent $script:AuditLogPath
        if ($dir -and -not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        Add-Content -Path $script:AuditLogPath -Value $line -Encoding UTF8
      }
    }
catch {
      # Last resort: avoid breaking install due to logging.
    }
  }
}
# --- End bootstrap ---


# ============================================================
# INVOCATION CONTEXT (MUST BE SET BEFORE ANY LOGGING)
# ============================================================
if ([string]::IsNullOrWhiteSpace($Mode)) { $Mode = 'LIVE' }
$ModeNormalized = $Mode.Trim().ToUpperInvariant()

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$Elevated  = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$ElevatedText = if ($Elevated) { 'true' } else { 'false' }

$RunUser     = $identity.Name
$RunComputer = $env:COMPUTERNAME
$RunStart    = Get-Date

$InstallerEventLogName = 'FirewallCore'
$InstallerEventSource  = 'FirewallCore-Installer'
$InstallerAuditDir     = Join-Path $env:ProgramData 'FirewallCore\Logs'
$InstallerAuditStamp   = $RunStart.ToString('yyyyMMdd_HHmmss')
$InstallerAuditFile    = Join-Path $InstallerAuditDir ("Install-FirewallCore_{0}_{1}.log" -f $ModeNormalized, $InstallerAuditStamp)
$InstallerTranscriptFile = ($InstallerAuditFile -replace '\.log$','_transcript.log')

$script:__TranscriptStarted = $false

function Stop-TranscriptSafe {
    if (-not $script:__TranscriptStarted) { return }
    try {
 Stop-Transcript | Out-Null }
catch {}
}

function Initialize-InstallerAuditLog {
    try {
 New-Item -ItemType Directory -Path $InstallerAuditDir -Force | Out-Null }
catch {}
    try {

        if (-not (Test-Path -LiteralPath $InstallerAuditFile)) {
            New-Item -ItemType File -Path $InstallerAuditFile -Force | Out-Null
        }
    }
catch {}
    try {

Start-Transcript -Path $InstallerTranscriptFile -Append | Out-Null
        $script:__TranscriptStarted = $true
    }
catch {}
}

function Write-InstallerAuditLine {
    param([Parameter(Mandatory=$true)][string]$Line)
    try {

        Add-Content -LiteralPath $InstallerAuditFile -Value $Line -Encoding Unicode
    }
catch {}
}

function Ensure-InstallerEventSource {
    try {

        if (-not [System.Diagnostics.EventLog]::SourceExists($InstallerEventSource)) {
            New-EventLog -LogName $InstallerEventLogName -Source $InstallerEventSource
        }
    }
catch {}
}

function Write-InstallerEvent {
    param(
        [Parameter(Mandatory=$true)][int]$EventId,
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('Information','Warning','Error')]
        [string]$EntryType = 'Information'
    )
    try {

        $max = 3

        for ($attempt = 1; $attempt -le $max; $attempt++) {

          try {

            Write-EventLog -LogName $InstallerEventLogName -Source $InstallerEventSource -EventId $EventId -EntryType $EntryType -Message $Message

            break

          } catch {

            if ($attempt -eq $max) {

              try { Write-InstallerAuditLine ("[WARN] Write-EventLog failed (attempts=" + $max + "): " + $_.Exception.Message) } catch {}

            } else {

              Start-Sleep -Milliseconds (200 * [Math]::Pow(2, ($attempt - 1)))

            }

          }

        }
    }
catch {}
}

# ============================================================
# ROOTS – SINGLE SOURCE OF TRUTH
# ============================================================
$InstallerRoot = Split-Path -Parent $PSScriptRoot
$InternalRoot  = $PSScriptRoot
$FirewallRoot  = Join-Path $InstallerRoot "Firewall"

$InternalSystemDir = Join-Path $InternalRoot "System"
$LiveSystemDir     = Join-Path $FirewallRoot "System"

$BasePath     = "C:\Firewall"
$Maintenance  = Join-Path $BasePath "Maintenance"
$Monitor      = Join-Path $BasePath "Monitor"
$StateDir     = Join-Path $BasePath "State"
$LogsDir      = Join-Path $BasePath "Logs"

# Resolve signing certificate file (prefer repo-shipped certs; legacy fallback supported)
$certCandidates = @(
    (Join-Path $InstallerRoot "Tools\Release\Certs\FirewallCore_CodeSigningEKU.cer"),
    (Join-Path $InstallerRoot "Tools\Release\Certs\FirewallCore_Signature.cer"),
    (Join-Path $InstallerRoot "Tools\Release\Certs\FirewallCore_Code_Signing.cer"),
    "C:\Firewall\ScriptSigningCert.cer"  # legacy fallback only
)

$CertFilePath = $null
foreach ($p in $certCandidates) {
    if (Test-Path $p) { $CertFilePath = $p; break }
}

if (-not $CertFilePath) {
    throw "Missing signing certificate file. Tried: $($certCandidates -join '; ')"
}

auditLog -Level $infoLevel -Message "[CERT] Using signing certificate file: $CertFilePath"


$CertThumbprint = "A33C8BA75D7975C2D67D2D5BB588AED7079B93A4"
$DefenderScript = Join-Path $Maintenance "Enable-DefenderIntegration.ps1"

$Global:FirewallMode = $ModeNormalized

# ============================================================
# INSTALLER FLOW (LOGGING WRAPPER + No-Op GATE)
# ============================================================
function Test-FirewallCoreAlreadyInstalled {
    $flagPath = Join-Path $StateDir "installed.flag"
    if (-not (Test-Path -LiteralPath $flagPath)) { return $false }

    if (-not (Test-Path -LiteralPath $DefenderScript)) { return $false }

    $haveDefTask = $false
    try {
 $haveDefTask = [bool](Get-ScheduledTask -TaskName "Firewall-Defender-Integration" -ErrorAction SilentlyContinue) }
catch {}
    if (-not $haveDefTask) { return $false }

    $haveCert = $false
    try {

        $cert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object Thumbprint -EQ $CertThumbprint
        $haveCert = [bool]$cert
    }
catch {}
    if (-not $haveCert) { return $false }

    $haveEventSource = $false
    try {

        if ([System.Diagnostics.EventLog]::SourceExists($InstallerEventSource)) {
            $ln = [System.Diagnostics.EventLog]::LogNameFromSourceName($InstallerEventSource, ".")
            $haveEventSource = ($ln -eq $InstallerEventLogName)
        }
    }
catch {}
    if (-not $haveEventSource) { return $false }

    return $true
}

Initialize-InstallerAuditLog

$startMsg = "INSTALL START | mode=$ModeNormalized | user=$RunUser | computer=$RunComputer | elevated=$ElevatedText | start=$($RunStart.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-InstallerAuditLine $startMsg
Ensure-InstallerEventSource
Write-InstallerEvent -EventId 1000 -Message $startMsg -EntryType Information

try {

    Write-Output "================================================="
    Write-Output "Firewall Core Installer Invocation"
    Write-Output "Start     : $($RunStart.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Output "Mode      : $ModeNormalized"
    Write-Output "User      : $RunUser"
    Write-Output "Computer  : $RunComputer"
    Write-Output "Elevated  : $ElevatedText"
    Write-Output "AuditLog  : $InstallerAuditFile"
    Write-Output "================================================="
    Write-Output ""

    if (Test-FirewallCoreAlreadyInstalled) {
        $noopMsg = "INSTALL No-Op | mode=$ModeNormalized | reason=already-installed"
        Write-InstallerAuditLine $noopMsg
        Write-InstallerEvent -EventId 1003 -Message $noopMsg -EntryType Information
        Write-Host "[No-Op] Firewall Core already installed; no changes required." -ForegroundColor DarkGray
        return
    }

    Write-Host "[*] Starting Firewall Core installation..." -ForegroundColor Cyan

    # ============================================================
    # DIRECTORY PREP
    # ============================================================
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $LogsDir "Install") -Force | Out-Null
    New-Item -ItemType Directory -Path $LiveSystemDir -Force | Out-Null

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
# FIREWALL POLICY + BASELINES (module-owned; backward compatible)
# ============================================================
    try {

        $ProgramDataRoot = Join-Path $env:ProgramData 'FirewallCore'
        $baselineModule = Join-Path $InstallerRoot 'Firewall\Modules\Firewall-InstallerBaselines.psm1'
        if (-not (Test-Path -LiteralPath $baselineModule)) {
            throw "Missing installer baselines module: $baselineModule"
        }

        Import-Module -Name $baselineModule -Force -ErrorAction Stop

        Write-Host "[INSTALL] Applying FirewallCore policy + capturing PRE/POST baselines..." -ForegroundColor Cyan
        $b = Invoke-FirewallCorePolicyApplyWithBaselines -InstallerRoot $InstallerRoot -ProgramDataRoot $ProgramDataRoot -Stamp $InstallerAuditStamp -Mode $ModeNormalized

        $preOk  = if ($b.Pre.ManifestOk) { 'true' } else { 'false' }
        $postOk = if ($b.Post.ManifestOk) { 'true' } else { 'false' }
        $audit = "BASELINES | stamp=$InstallerAuditStamp | pre=$($b.Pre.Dir) | post=$($b.Post.Dir) | preManifestOk=$preOk | postManifestOk=$postOk"
        Write-InstallerAuditLine $audit
        Write-InstallerEvent -EventId 1011 -Message $audit -EntryType Information
        Write-Host "[OK] FirewallCore policy applied + baselines captured" -ForegroundColor Green
    }
catch {
        Write-Host ("[FATAL] Firewall policy/baseline step failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        throw
    }

# ============================================================
# CERTIFICATE
# ============================================================
    Write-Host "[CERT] Checking trusted certificate" -ForegroundColor Cyan

    $cert = Get-ChildItem Cert:\LocalMachine\Root 
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

    $DefenderArgs = "-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy AllSigned -File `"$DefenderScript`""
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $DefenderArgs

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
        $ToastArgs = "-NoLogo -STA -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy AllSigned -File `"$ToastScript`""
        $ToastAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $ToastArgs

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

    Write-Host "[SUCCESS] Firewall Core installation completed." -ForegroundColor Green

    # --- BEGIN FIREWALLCORE TOAST SELFHEAL INFRA ---
    # Self-healing Toast Listener infra (no console windows; background tasks)
    try {

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
        $UserTask = Get-ScheduledTask -TaskName "FirewallCore Toast Listener" -ErrorAction SilentlyContinue
        if ($UserTask) {
            try {

                $a = $UserTask.Actions[0]
                if ($a.Execute -match "powershell\.exe|pwsh\.exe") {
                    if ($a.Arguments -notmatch "-WindowStyle\s+Hidden") {
                        $newArgs = $a.Arguments.Trim()
                        # Add -WindowStyle Hidden near the front (safe)
                        $newArgs = $newArgs -replace "^-NoProfile", "-NoProfile -ExecutionPolicy AllSigned -WindowStyle Hidden"
                        if ($newArgs -eq $a.Arguments) {
                            $newArgs = "-WindowStyle Hidden " + $newArgs
                        }
                        $UserTask.Actions[0].Arguments = $newArgs
                        Set-ScheduledTask -TaskName "FirewallCore Toast Listener" -TaskPath $UserTask.TaskPath -Action $UserTask.Actions[0] | Out-Null
                        Write-Host "[OK] Updated listener task to run hidden"
                    }
                }
            }
catch {
                Write-Host "[WARN] Could not enforce hidden window on listener task"
            }
        }

    # ---- Create/Update SYSTEM watchdog task (every minute) ----
        $WatchdogScript = Join-Path $LiveSystem "FirewallToastWatchdog.ps1"
        if (Test-Path $WatchdogScript) {
            $tn = "FirewallCore Toast Watchdog"
            $tr = "powershell.exe -NoProfile -ExecutionPolicy AllSigned -WindowStyle Hidden -File `"$WatchdogScript`""
            # Use schtasks for rock-solid minute scheduling (avoids repetition duration formatting issues)
            schtasks.exe /Create /F /TN "$tn" /SC MINUTE /MO 1 /RU "SYSTEM" /RL HIGHEST /TR "$tr" | Out-Null
            Write-Host "[OK] Watchdog task ensured: $tn"
        } else {
            Write-Host "[WARN] Watchdog script missing at install time: $WatchdogScript"
        }

    # ---- Start tasks (background) ----
        try {
 $listener = Get-ScheduledTask -TaskName 'FirewallCore-ToastListener' -TaskPath '\' -ErrorAction SilentlyContinue
if ($listener) {
    Start-ScheduledTask -TaskPath $listener.TaskPath -TaskName $listener.TaskName
    auditLog -Level 'INFO' -Message "Started task: $($listener.TaskPath)$($listener.TaskName)"
} else {
    auditLog -Level 'WARN' -Message "Toast Listener task not found to start."
}
}
catch {}
        try {
 schtasks.exe /Run /TN "FirewallCore Toast Watchdog" | Out-Null }
catch {}

    }
catch {
        Write-Host "[WARN] Toast self-heal infra install block failed: $($_.Exception.Message)"
    }
    # --- END FIREWALLCORE TOAST SELFHEAL INFRA ---

    $endMsg = "INSTALL OK | mode=$ModeNormalized | end=$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-InstallerAuditLine $endMsg
    Write-InstallerEvent -EventId 1008 -Message $endMsg -EntryType Information

}
catch {
    $ex = $_.Exception
    $failMsg = "INSTALL FAIL | mode=$ModeNormalized | error=$($ex.Message)"
    Write-InstallerAuditLine $failMsg
    Write-InstallerAuditLine ("DETAILS | " + ($_ | Out-String).Trim())
    Write-InstallerEvent -EventId 1901 -Message $failMsg -EntryType Error
    throw
} finally {
    Stop-TranscriptSafe
}

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD6fiFZQ8AZAUNc
# 03g2h7cHGUfKbRX1XLzWlbgnwgjlaaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
# YA1JZL+WI1Yn9crpsTANBgkqhkiG9w0BAQsFADAnMSUwIwYDVQQDDBxGaXJld2Fs
# bENvcmUgT2ZmbGluZSBSb290IENBMB4XDTI2MDIwMzA3NTU1N1oXDTI5MDMwOTA3
# NTU1N1owWDELMAkGA1UEBhMCVVMxETAPBgNVBAsMCFNlY3VyaXR5MRUwEwYDVQQK
# DAxGaXJld2FsbENvcmUxHzAdBgNVBAMMFkZpcmV3YWxsQ29yZSBTaWduYXR1cmUw
# WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATEFkC5IO0Ns0zPmdtnHpeiy/QjGyR5
# XcfYjx8wjVhMYoyZ5gyGaXjRBAnBsRsbSL172kF3dMSv20JufNI5SmZMo28wbTAJ
# BgNVHRMEAjAAMAsGA1UdDwQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNV
# HQ4EFgQUqbvNi/eHRRZJy7n5n3zuXu/sSOwwHwYDVR0jBBgwFoAULCjMhE2sOk26
# qY28GVmu4DqwehMwDQYJKoZIhvcNAQELBQADggEBAJsvjHGxkxvAWGAH1xiR+SOb
# vLKaaqVwKme3hHAXmTathgWUjjDwHQgFohPy7Zig2Msu11zlReUCGdGu2easaECF
# dMyiKzfZIA4+MQHQWv+SMcm912OjDtwEtCjNC0/+Q1BDISPv7OA8w7TDrmLk00mS
# il/f6Z4ZNlfegdoDyeDYK8lf+9DO2ARrddRU+wYrgXcdRzhekkBs9IoJ4qfXokOv
# u2ZvVZrPE3f2IiFPbmuBgzdbJ/VdkeCoAOl+D33Qyddzk8J/z7WSDiWqISF1E7GZ
# KSjgQp8c9McTcW15Ym4MR+lbyn3+CigGOrl89lzhMymm6rj6vSbvSMml2AEQgH0x
# ggE0MIIBMAIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IJbBzRoqXGc15ZkFUth9hNZLM81kwDLm2Pj9Jx1Ne+DBMAsGByqGSM49AgEFAARH
# MEUCIQD1BGDOxU55eDG8TcIp+g3yTq0j9OIjeLMVu5LUg34wvAIgKUycJC/W8Y/G
# 2jx43MhAP3PUZf8TDNYADY63krLc6B0=
# SIG # End signature block
