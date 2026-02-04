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

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCOL7G67TrjWUVM
# 87VDeAaRZY40h6uMN2sOoKRmzg32uKCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ICUFOXS6P2BArLrxyFgmV8SmJvbBBYCki8Lh0+VTqHX6MAsGByqGSM49AgEFAARH
# MEUCIQDMZo8DVYbGaMkiPsh+oM4Gr81NOtaIB5842kdsh82JpwIgHtCdQAvdvxh4
# C3mtfeE+W/TgBDsBt7W3OLL70wK3XpU=
# SIG # End signature block
