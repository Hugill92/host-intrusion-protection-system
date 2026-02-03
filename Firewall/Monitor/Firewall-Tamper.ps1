# Firewall-Tamper.ps1
# Runs under SYSTEM
# Purpose:
#  - Detect firewall rule drift (inbound or outbound)
#  - Log tamper events with rule name(s)
#  - Hint Firewall-Core.ps1 which rule changed (for better logging)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root    = "C:\Firewall"
$Monitor = Join-Path $Root "Monitor"
$Modules = Join-Path $Root "Modules"
$State   = Join-Path $Root "State"
$Baseline= Join-Path $State "baseline.json"
$Core    = Join-Path $Monitor "Firewall-Core.ps1"

# Load Event Log helper
$EventModule = Join-Path $Modules "Firewall-EventLog.ps1"
if (Test-Path $EventModule) {
    try { . $EventModule } catch { }
}

Write-FirewallEvent -EventId 1000 -Type Information -Message "Firewall tamper monitor heartbeat."

if (-not (Test-Path $Baseline)) {
    Write-FirewallEvent -EventId 1100 -Type Information -Message "Baseline missing; tamper monitor deferring to core."
    exit 0
}

# Load baseline
$baselineObj = Get-Content $Baseline -Raw -Encoding utf8 | ConvertFrom-Json

# Extract baseline rule names
$baselineRules = @()
if ($baselineObj.rules) {
    $baselineRules = $baselineObj.rules | ForEach-Object { $_.Name }
} elseif ($baselineObj.Rules) {
    $baselineRules = $baselineObj.Rules | ForEach-Object { $_.Name }
}

# Get current firewall rule names
$currentRules = Get-NetFirewallRule | Select-Object -ExpandProperty Name

# Detect deleted rules
$deleted = $baselineRules | Where-Object { $_ -notin $currentRules }

foreach ($rule in $deleted) {
    Write-FirewallEvent -EventId 2002 -Type Warning -Message "Firewall rule deleted or missing: $rule"
}

# Detect modified / disabled rules
foreach ($rule in $baselineRules) {
    try {
        $r = Get-NetFirewallRule -Name $rule -ErrorAction Stop
        if ($r.Enabled -ne "True") {
            Write-FirewallEvent -EventId 2001 -Type Warning -Message "Firewall rule disabled: $rule"
        }
    } catch {
        # already handled as deleted
    }
}

$driftedRules = New-Object System.Collections.Generic.List[string]

# Deleted rules
foreach ($rule in $deleted) {
    Write-FirewallEvent -EventId 2002 -Type Warning -Message "Firewall rule deleted or missing: $rule"
    $driftedRules.Add($rule)
}

# Disabled rules
foreach ($rule in $baselineRules) {
    try {
        $r = Get-NetFirewallRule -Name $rule -ErrorAction Stop
        if ($r.Enabled -ne "True") {
            Write-FirewallEvent -EventId 2001 -Type Warning -Message "Firewall rule disabled: $rule"
            $driftedRules.Add($rule)
        }
    } catch {
        # already counted as deleted
    }
}

function Get-LastFirewallRuleChange {
    param([string]$RuleName)

    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        Id      = 4946,4947,4948,4950
    } -MaxEvents 20 -ErrorAction SilentlyContinue

    foreach ($e in $events) {
        if ($e.Message -match [regex]::Escape($RuleName)) {
            return $e
        }
    }
    return $null
}

function Get-ActorType {
    param($Event)

    if (-not $Event) { return "Unknown" }

    $sid = $Event.UserId.Value

    if ($sid -eq "S-1-5-18") { return "SYSTEM" }

    $admins = New-Object Security.Principal.SecurityIdentifier("S-1-5-32-544")
    if ($admins.IsWellKnown([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid)) {
        if ((New-Object Security.Principal.SecurityIdentifier($sid)).IsWellKnown(
            [Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid)) {
            return "Administrator"
        }
    }

    return "User"
}

foreach ($rule in $driftedRules) {

    $evt = Get-LastFirewallRuleChange -RuleName $rule
    $actor = Get-ActorType -Event $evt

    Write-FirewallEvent `
        -EventId 2003 `
        -Type Warning `
        -Message "Firewall rule changed: $rule | Actor: $actor"

    if ($actor -eq "User") {
        # 🔥 Users get healed
        Start-Process -FilePath "powershell.exe" `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File `"$Core`" -ChangedRuleName `"$rule`"" `
            -WindowStyle Hidden -NoNewWindow
    }
    else {
        # 🛡️ Admin / SYSTEM → log only
        Write-FirewallEvent `
            -EventId 2100 `
            -Type Information `
            -Message "Firewall change allowed (no self-heal): $rule | Actor: $actor"
    }
}


# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUBB1L6Z92+/9f4xajUEJFCCqU
# tDygggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUFF7fuFWil8nR2muheL1SUhAcbwAwCwYH
# KoZIzj0CAQUABEcwRQIgTWHF32l4fSIxtTWGth8qDhR9RkfXaMyZKPMHCU3GRsAC
# IQCkQQdtL5fOFM/FruRP4kGKeebbCoZ4aPZ0kgZu4iHUNw==
# SIG # End signature block
