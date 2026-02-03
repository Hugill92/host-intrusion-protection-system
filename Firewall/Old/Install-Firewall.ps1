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
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUSFMDzvUFNWYIla+llfwuYqy8
# YKCgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBJDCCASACAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUPU+AnBL8JhJCE5pC5hu5fYqOkg0wCwYH
# KoZIzj0CAQUABEgwRgIhAIft93z72qfe6ygY+ISWK370vcXgBAmLXD1Tx9jAvIJ1
# AiEA/ZQrE+X/3afKFHMXENaM+ArFsEsJOVQbAY/WEjmBQm4=
# SIG # End signature block
