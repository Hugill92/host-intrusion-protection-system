# Install-Firewall.ps1
# One-shot installer for Firewall Core system
# MUST be run as admin (auto-elevates)

param(
  [ValidateSet('DEV','LIVE')]
  [string]$Mode = 'LIVE'
)

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
    try { Stop-Transcript | Out-Null } catch {}
}

function Initialize-InstallerAuditLog {
    try { New-Item -ItemType Directory -Path $InstallerAuditDir -Force | Out-Null } catch {}
    try {
        if (-not (Test-Path -LiteralPath $InstallerAuditFile)) {
            New-Item -ItemType File -Path $InstallerAuditFile -Force | Out-Null
        }
    } catch {}
    try {
Start-Transcript -Path $InstallerTranscriptFile -Append | Out-Null
        $script:__TranscriptStarted = $true
    } catch {}
}

function Write-InstallerAuditLine {
    param([Parameter(Mandatory=$true)][string]$Line)
    try {
        Add-Content -LiteralPath $InstallerAuditFile -Value $Line -Encoding Unicode
    } catch {}
}

function Ensure-InstallerEventSource {
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($InstallerEventSource)) {
            New-EventLog -LogName $InstallerEventLogName -Source $InstallerEventSource
        }
    } catch {}
}

function Write-InstallerEvent {
    param(
        [Parameter(Mandatory=$true)][int]$EventId,
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('Information','Warning','Error')]
        [string]$EntryType = 'Information'
    )
    try {
        Write-EventLog -LogName $InstallerEventLogName -Source $InstallerEventSource -EventId $EventId -EntryType $EntryType -Message $Message
    } catch {}
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
    try { $haveDefTask = [bool](Get-ScheduledTask -TaskName "Firewall-Defender-Integration" -ErrorAction SilentlyContinue) } catch {}
    if (-not $haveDefTask) { return $false }

    $haveCert = $false
    try {
        $cert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object Thumbprint -EQ $CertThumbprint
        $haveCert = [bool]$cert
    } catch {}
    if (-not $haveCert) { return $false }

    $haveEventSource = $false
    try {
        if ([System.Diagnostics.EventLog]::SourceExists($InstallerEventSource)) {
            $ln = [System.Diagnostics.EventLog]::LogNameFromSourceName($InstallerEventSource, ".")
            $haveEventSource = ($ln -eq $InstallerEventLogName)
        }
    } catch {}
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
    } catch {
        Write-Host ("[FATAL] Firewall policy/baseline step failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        throw
    }

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
            } catch {
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
        try { Start-ScheduledTask -TaskName "FirewallCore Toast Listener" | Out-Null } catch {}
        try { schtasks.exe /Run /TN "FirewallCore Toast Watchdog" | Out-Null } catch {}

    } catch {
        Write-Host "[WARN] Toast self-heal infra install block failed: $($_.Exception.Message)"
    }
    # --- END FIREWALLCORE TOAST SELFHEAL INFRA ---

    $endMsg = "INSTALL OK | mode=$ModeNormalized | end=$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-InstallerAuditLine $endMsg
    Write-InstallerEvent -EventId 1008 -Message $endMsg -EntryType Information

} catch {
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
# MIIa9wYJKoZIhvcNAQcCoIIa6DCCGuQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCl8bknOcWqk2d1
# 1AM9lqjifeejtjfDnWsyX0a7eVlmiaCCFe8wggKxMIIBmaADAgECAhQD4857cPuq
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
# KSjgQp8c9McTcW15Ym4MR+lbyn3+CigGOrl89lzhMymm6rj6vSbvSMml2AEQgH0w
# ggWNMIIEdaADAgECAhAOmxiO+dAt5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9v
# dCBDQTAeFw0yMjA4MDEwMDAwMDBaFw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskh
# PfKK2FnC4SmnPVirdprNrnsbhA3EMB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIP
# Uh/GnhWlfr6fqVcWWVVyr2iTcMKyunWZanMylNEQRBAu34LzB4TmdDttceItDBvu
# INXJIB1jKS3O7F5OyJP4IWGbNOsFxl7sWxq868nPzaw0QF+xembud8hIqGZXV59U
# WI4MK7dPpzDZVu7Ke13jrclPXuU15zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4
# AxCN2NQ3pC4FfYj1gj4QkXCrVYJBMtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJoz
# QL8I11pJpMLmqaBn3aQnvKFPObURWBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw
# 4KISG2aadMreSx7nDmOu5tTvkpI6nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sE
# AMx9HJXDj/chsrIRt7t/8tWMcCxBYKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZD
# pBi4pncB4Q+UDCEdslQpJYls5Q5SUUd0viastkF13nqsX40/ybzTQRESW+UQUOsx
# xcpyFiIJ33xMdT9j7CFfxCBRa2+xq4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+Y
# HS312amyHeUbAgMBAAGjggE6MIIBNjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW
# BBTs1+OC0nFdZEzfLmc/57qYrhwPTzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYun
# pyGd823IDzAOBgNVHQ8BAf8EBAMCAYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUF
# BzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6
# Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5j
# cnQwRQYDVR0fBD4wPDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJ
# KoZIhvcNAQEMBQADggEBAHCgv0NcVec4X6CjdBs9thbX979XB72arKGHLOyFXqka
# uyL4hxppVCLtpIh3bb0aFPQTSnovLbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP
# +fT3rDB6mouyXtTP0UNEm0Mh65ZyoUi0mcudT6cGAxN3J0TU53/oWajwvy8Lpuny
# NDzs9wPHh6jSTEAZNUZqaVSwuKFWjuyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiE
# n2/K2yCNNWAcAgPLILCsWKAOQGPFmCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4
# VC0nftg62fC2h5b9W9FcrBjDTZ9ztwGpn1eqXijiuZQwgga0MIIEnKADAgECAhAN
# x6xXBf8hmS5AQyIMOkmGMA0GCSqGSIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# ITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yNTA1MDcwMDAw
# MDBaFw0zODAxMTQyMzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdp
# Q2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3Rh
# bXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQC0eDHTCphBcr48RsAcrHXbo0ZodLRRF51NrY0NlLWZloMs
# VO1DahGPNRcybEKq+RuwOnPhof6pvF4uGjwjqNjfEvUi6wuim5bap+0lgloM2zX4
# kftn5B1IpYzTqpyFQ/4Bt0mAxAHeHYNnQxqXmRinvuNgxVBdJkf77S2uPoCj7GH8
# BLuxBG5AvftBdsOECS1UkxBvMgEdgkFiDNYiOTx4OtiFcMSkqTtF2hfQz3zQSku2
# Ws3IfDReb6e3mmdglTcaarps0wjUjsZvkgFkriK9tUKJm/s80FiocSk1VYLZlDwF
# t+cVFBURJg6zMUjZa/zbCclF83bRVFLeGkuAhHiGPMvSGmhgaTzVyhYn4p0+8y9o
# HRaQT/aofEnS5xLrfxnGpTXiUOeSLsJygoLPp66bkDX1ZlAeSpQl92QOMeRxykvq
# 6gbylsXQskBBBnGy3tW/AMOMCZIVNSaz7BX8VtYGqLt9MmeOreGPRdtBx3yGOP+r
# x3rKWDEJlIqLXvJWnY0v5ydPpOjL6s36czwzsucuoKs7Yk/ehb//Wx+5kMqIMRvU
# BDx6z1ev+7psNOdgJMoiwOrUG2ZdSoQbU2rMkpLiQ6bGRinZbI4OLu9BMIFm1UUl
# 9VnePs6BaaeEWvjJSjNm2qA+sdFUeEY0qVjPKOWug/G6X5uAiynM7Bu2ayBjUwID
# AQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU729TSunk
# Bnx6yuKQVvYv1Ensy04wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08w
# DgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEB
# BGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsG
# AQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVz
# dGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNVHSAEGTAXMAgG
# BmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBABfO+xaAHP4H
# PRF2cTC9vgvItTSmf83Qh8WIGjB/T8ObXAZz8OjuhUxjaaFdleMM0lBryPTQM2qE
# JPe36zwbSI/mS83afsl3YTj+IQhQE7jU/kXjjytJgnn0hvrV6hqWGd3rLAUt6vJy
# 9lMDPjTLxLgXf9r5nWMQwr8Myb9rEVKChHyfpzee5kH0F8HABBgr0UdqirZ7bowe
# 9Vj2AIMD8liyrukZ2iA/wdG2th9y1IsA0QF8dTXqvcnTmpfeQh35k5zOCPmSNq1U
# H410ANVko43+Cdmu4y81hjajV/gxdEkMx1NKU4uHQcKfZxAvBAKqMVuqte69M9J6
# A47OvgRaPs+2ykgcGV00TYr2Lr3ty9qIijanrUR3anzEwlvzZiiyfTPjLbnFRsjs
# Yg39OlV8cipDoq7+qNNjqFzeGxcytL5TTLL4ZaoBdqbhOhZ3ZRDUphPvSRmMThi0
# vw9vODRzW6AxnJll38F0cuJG7uEBYTptMSbhdhGQDpOXgpIUsWTjd6xpR6oaQf/D
# Jbg3s6KCLPAlZ66RzIg9sC+NJpud/v4+7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx9yHb
# xtl5TPau1j/1MIDpMPx0LckTetiSuEtQvLsNz3Qbp7wGWqbIiOWCnb5WqxL3/BAP
# vIXKUjPSxyZsq8WhbaM2tszWkPZPubdcMIIG7TCCBNWgAwIBAgIQCoDvGEuN8QWC
# 0cR2p5V0aDANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMO
# RGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGlt
# ZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMB4XDTI1MDYwNDAwMDAw
# MFoXDTM2MDkwMzIzNTk1OVowYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBTSEEyNTYgUlNBNDA5NiBUaW1l
# c3RhbXAgUmVzcG9uZGVyIDIwMjUgMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCC
# AgoCggIBANBGrC0Sxp7Q6q5gVrMrV7pvUf+GcAoB38o3zBlCMGMyqJnfFNZx+wvA
# 69HFTBdwbHwBSOeLpvPnZ8ZN+vo8dE2/pPvOx/Vj8TchTySA2R4QKpVD7dvNZh6w
# W2R6kSu9RJt/4QhguSssp3qome7MrxVyfQO9sMx6ZAWjFDYOzDi8SOhPUWlLnh00
# Cll8pjrUcCV3K3E0zz09ldQ//nBZZREr4h/GI6Dxb2UoyrN0ijtUDVHRXdmncOOM
# A3CoB/iUSROUINDT98oksouTMYFOnHoRh6+86Ltc5zjPKHW5KqCvpSduSwhwUmot
# uQhcg9tw2YD3w6ySSSu+3qU8DD+nigNJFmt6LAHvH3KSuNLoZLc1Hf2JNMVL4Q1O
# pbybpMe46YceNA0LfNsnqcnpJeItK/DhKbPxTTuGoX7wJNdoRORVbPR1VVnDuSeH
# VZlc4seAO+6d2sC26/PQPdP51ho1zBp+xUIZkpSFA8vWdoUoHLWnqWU3dCCyFG1r
# oSrgHjSHlq8xymLnjCbSLZ49kPmk8iyyizNDIXj//cOgrY7rlRyTlaCCfw7aSURO
# wnu7zER6EaJ+AliL7ojTdS5PWPsWeupWs7NpChUk555K096V1hE0yZIXe+giAwW0
# 0aHzrDchIc2bQhpp0IoKRR7YufAkprxMiXAJQ1XCmnCfgPf8+3mnAgMBAAGjggGV
# MIIBkTAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBTkO/zyMe39/dfzkXFjGVBDz2GM
# 6DAfBgNVHSMEGDAWgBTvb1NK6eQGfHrK4pBW9i/USezLTjAOBgNVHQ8BAf8EBAMC
# B4AwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwgZUGCCsGAQUFBwEBBIGIMIGFMCQG
# CCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wXQYIKwYBBQUHMAKG
# UWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRp
# bWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNydDBfBgNVHR8EWDBWMFSg
# UqBQhk5odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRU
# aW1lU3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcmwwIAYDVR0gBBkwFzAI
# BgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQBlKq3xHCcE
# ua5gQezRCESeY0ByIfjk9iJP2zWLpQq1b4URGnwWBdEZD9gBq9fNaNmFj6Eh8/Ym
# RDfxT7C0k8FUFqNh+tshgb4O6Lgjg8K8elC4+oWCqnU/ML9lFfim8/9yJmZSe2F8
# AQ/UdKFOtj7YMTmqPO9mzskgiC3QYIUP2S3HQvHG1FDu+WUqW4daIqToXFE/JQ/E
# ABgfZXLWU0ziTN6R3ygQBHMUBaB5bdrPbF6MRYs03h4obEMnxYOX8VBRKe1uNnzQ
# VTeLni2nHkX/QqvXnNb+YkDFkxUGtMTaiLR9wjxUxu2hECZpqyU1d0IbX6Wq8/gV
# utDojBIFeRlqAcuEVT0cKsb+zJNEsuEB7O7/cuvTQasnM9AWcIQfVjnzrvwiCZ85
# EE8LUkqRhoS3Y50OHgaY7T/lwd6UArb+BOVAkg2oOvol/DJgddJ35XTxfUlQ+8Hg
# gt8l2Yv7roancJIFcbojBcxlRcGG0LIhp6GvReQGgMgYxQbV1S3CrWqZzBt1R9xJ
# gKf47CdxVRd/ndUlQ05oxYy2zRWVFjF7mcr4C34Mj3ocCVccAvlKV9jEnstrniLv
# UxxVZE/rptb7IRE2lskKPIJgbaP5t2nGj/ULLi49xTcBZU8atufk+EMF/cWuiC7P
# OGT75qaL6vdCvHlshtjdNXOCIUjsarfNZzGCBF4wggRaAgEBMD8wJzElMCMGA1UE
# AwwcRmlyZXdhbGxDb3JlIE9mZmxpbmUgUm9vdCBDQQIUA+POe3D7qmANSWS/liNW
# J/XK6bEwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKA
# ADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYK
# KwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgM8XHLa9KHo80gUfxm/Uqy+ubnaNN
# oBksHvl09xudn4cwCwYHKoZIzj0CAQUABEcwRQIhAKV+EUmfkVz2QQrl1oScsz3Y
# ohrwydK8Bv7lxg3SB+nCAiBQ96pcuVIA4stMP+4Mqak7uD2z57boXycd0QiXaeQO
# PqGCAyYwggMiBgkqhkiG9w0BCQYxggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVT
# MRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1
# c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA
# 7xhLjfEFgtHEdqeVdGgwDQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJ
# KoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yNjAyMDQxMTAxMzlaMC8GCSqGSIb3
# DQEJBDEiBCCMS6JKVa1WCnYLQwQSbDzliX39v/IdPzl7xT0lOQtRNDANBgkqhkiG
# 9w0BAQEFAASCAgBIg/9fGE4ldANJoNstFWqA2wmuLuJ6Q4MvuNGJAZrnjwuNpnPQ
# sQB2w3cLVDCmTgYyULEcDfYVsMeDE8DA35NPoXbz/lZZv+Pjq5Te/1e9xBq3MOPZ
# b6G2zg5FO+rO+Js9DT+ZFgJflz/fGyivl54RAmKxSfBSHeFQRAItqgM1yPH/92tE
# 9Ksh2i9xsHrVteC6Zbh8q5sFR53HFCh/K0CwVmKKhFXP2tEKOvzZFIuisYWga+yG
# PF7NPjgsmqTFnvtRFaat41pek6xpH7RPS0QEg3iKcKsrvwNIjqRi/8LFd70n3Fuf
# 0CQOaif2k5q3bQvhjPa7coM2gFb83fRfUkHa/fR1uuDqVkHHpGN6zIOpS0Rh97t3
# 17LtmHNlXMYPhTlm+NL5B+oG6cZbhAq+4lOLgVim56HW5FVLCYs7zDEFSXVLEOpa
# bvdpVRtn7nvkYqlR93knYwnJSP4CQJu3XurPUerbAJT0jColhSVu/EZvJIw4pqoH
# BWpb6NbbQMeN6L2+F7ox57kj6/qH6bCxyzISgIb9YD5g9VWe9n9LxdfGHBID5kPR
# d0Sp3Kwlbnk+Y1L1DL4ij1RekhI2uhdYo6T4CQ/rY6N3mu9em1KNpBRRrMjIlSXm
# JckfZwXSoUhebfaqcPL7GqYk5jU74k8qxFzd1ZmeYmzM4Yku3AjiJ2PQWA==
# SIG # End signature block
