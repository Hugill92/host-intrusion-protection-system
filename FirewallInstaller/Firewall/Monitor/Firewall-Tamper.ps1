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
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAzt+jiyu6GaNbA
# Wg5IPbaU4t5GwGjb5HNA/h6tiPkgr6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ggEzMIIBLwIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IIxi7sFbkU0CArHgYhSXkXZ2w0in1SoPDceM8+u8ZNbpMAsGByqGSM49AgEFAARG
# MEQCIB+HpA+EOn/vx1DBdtKzMyeLJ/8nZN7aC8CZzp9O1i4mAiAOYIXbcb+rMYyx
# nPASQTre+t0enF+GzueG9LY+QTVajQ==
# SIG # End signature block
