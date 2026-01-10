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
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7SDZutS2mDp+7j9l7Bb5VHOz
# A2igggMcMIIDGDCCAgCgAwIBAgIQJzQwIFZoAq5JjY+vZKoYnzANBgkqhkiG9w0B
# AQsFADAkMSIwIAYDVQQDDBlGaXJld2FsbENvcmUgQ29kZSBTaWduaW5nMB4XDTI2
# MDEwNTE4NTkwM1oXDTI3MDEwNTE5MTkwM1owJDEiMCAGA1UEAwwZRmlyZXdhbGxD
# b3JlIENvZGUgU2lnbmluZzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# AO9vgGkuxnRNQ6dCFa0TeSA8dI6C3aapCB6GSxZB+3OZNMqvmYxZGZ9g4vZVtjJ4
# 6Ffulr3b/KUcxQRiSj9JlFcUB39uWHCZYpGfPlpA9JXiNJuwPNAaWdG1S5DnjLXh
# QH0PAGJH/QSYfVzVLf6yrAW5ID30Dz14DynBbVAQuM7iuOdTu9vhdcoAi37T9O4B
# RjflfXjaDDWfZ9nyF3X6o5Z5pUmC2mUKuTXc9iiUGkWQoLe3wGDQBWZxgTONOr6s
# d1EfeQ2OI6PPoM54iqv4s2offPxl2jBd2aESkT+MK88e1iQGRLT8CC3IMKEvWb4q
# sY0jodjxx/EFW7YvmMmM+aUCAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBTz2KaYa/9Nh8LQ78T5DHApaEhuYzAN
# BgkqhkiG9w0BAQsFAAOCAQEAxu2SpjRshKTSAWeQGtiCWbEVP7OT02vnkSfX7kr0
# bSkyKXaizhA6egp6YWdof86uHLyXRny28sQSMzRqIW7zLFqouvoc83CF4GRexPqH
# cwt55G2YU8ZbeFJQPpfVx8uQ/JIsTyaXQIo6fhBdm4qAA20K+H214C8JL7oUiZzu
# L+CUHFsSbvjx4FyAHVmkRSlRbrqSgETbwcMMB1corkKY990uyOJ6KHBXTd/iZLZi
# Lg4e2mtfV7Jn60ZlzO/kdOkYZTxv2ctNVRnzP3bD8zTjagRvvp7OlNJ6MSUZuJPJ
# 1Cfikoa43Cqw6BN0tLRP80UKTFB484N3bgGU9UAqCKeckDGCAdkwggHVAgEBMDgw
# JDEiMCAGA1UEAwwZRmlyZXdhbGxDb3JlIENvZGUgU2lnbmluZwIQJzQwIFZoAq5J
# jY+vZKoYnzAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU6/oDrnlDf7P0+BN7EKDbNWVhPAMwDQYJ
# KoZIhvcNAQEBBQAEggEAWHcyWLV48SHzlvZHGVk7XP+ypJqUzHstBQxNEhh3XVlf
# 5RCTWPLwc9Y8SZRZHFNM/TZoLbr/C84gcckcRyeLsn4s6qxUmJrouT+froD3sTm2
# hHRIGztEl/WLcCzry3FWr+0tjyslcCs7frqJmo1LI3KuTVhHqd1aw8k+6ZovS7aU
# f1qdCEhn1K85b6W4xzFpXRvnbxdUZjoQ0xg/UEqLC5SOuFIKGL1lLFDc6fHOi+ND
# IS2dro4C9jgDFzux6gsWVzSb0exSv7KgKWEahsWM8OGMSdmfChxL9xzqCgTojWhV
# a8c+B6R9KlBBNqZt76aaOSP+AY3UuWmgQmJUURbHDg==
# SIG # End signature block
