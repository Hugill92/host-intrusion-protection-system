<#
Snapshot-System.psm1
System / installer audit snapshot module for Firewall Core

Exports:
- Save-SystemSnapshot
- Compare-SystemSnapshots

Purpose:
- Capture human-readable system state snapshots
- Support install / uninstall audits
- Provide rollback safety and forensic visibility
#>

Set-StrictMode -Version Latest

#region Helpers

function Get-FwRuleFingerprint {
    param([string]$PolicyStore = 'ActiveStore')

    try {
        $rules = Get-NetFirewallRule -PolicyStore $PolicyStore -ErrorAction Stop
    } catch {
        return [pscustomobject]@{
            Count  = -1
            Sha256 = '<error>'
            Error  = $_.Exception.Message
        }
    }

    $lines = foreach ($r in $rules) {
        "{0}|{1}|{2}|{3}|{4}|{5}" -f `
            $r.DisplayName,
            $r.Direction,
            $r.Action,
            $r.Enabled,
            $r.Profile,
            $r.Group
    }

    $sorted = $lines | Sort-Object
    $joined = ($sorted -join "`n")

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
    $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
    $sha.Dispose()

    [pscustomobject]@{
        Count  = $lines.Count
        Sha256 = $hash
        Error  = $null
    }
}

function Get-SchtasksLine {
    param([string]$TaskName)

    try {
        $out = & schtasks.exe /Query /TN $TaskName /V /FO LIST 2>$null
        if (-not $out) { return "${TaskName}: missing" }

        $next = ($out | Select-String '^Next Run Time:' | Select-Object -First 1).Line.Trim()
        $last = ($out | Select-String '^Last Run Time:' | Select-Object -First 1).Line.Trim()
        $res  = ($out | Select-String '^Last Result:'   | Select-Object -First 1).Line.Trim()

        return "${TaskName}: present; $next; $last; $res"
    } catch {
        return "${TaskName}: error ($($_.Exception.Message))"
    }
}


function Get-CertPresenceLine {
    param([string]$Thumbprint)

    if (-not $Thumbprint) {
        return "ScriptSigningCert: thumbprint not provided"
    }

    try {
        $c = Get-ChildItem Cert:\LocalMachine\Root |
             Where-Object Thumbprint -EQ $Thumbprint |
             Select-Object -First 1

        if ($c) {
            return "ScriptSigningCert: present in LocalMachine\Root ($Thumbprint)"
        }

        return "ScriptSigningCert: NOT present in LocalMachine\Root ($Thumbprint)"
    } catch {
        return "ScriptSigningCert: error ($($_.Exception.Message))"
    }
}

#endregion Helpers

#region Public Functions

function Save-SystemSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Phase,

        [Parameter(Mandatory)]
        [string]$OutDir,

        [string]$Root = 'C:\FirewallInstaller\Firewall',
        [string]$InstallerRoot = 'C:\FirewallInstaller',
        [string]$CertThumbprint = ''
    )

    $null = New-Item -ItemType Directory -Path $OutDir -Force -ErrorAction SilentlyContinue

    $ts   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $file = Join-Path $OutDir "Snapshot-System-$Phase-$ts.txt"

    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("=== FIREWALL SYSTEM SNAPSHOT ===")
    $lines.Add("Phase     : $Phase")
    $lines.Add("Timestamp : $(Get-Date -Format o)")
    $lines.Add("Computer  : $env:COMPUTERNAME")
    $lines.Add("User      : $env:USERNAME")
    $lines.Add("PSVersion : $($PSVersionTable.PSVersion)")
    $lines.Add("")

    $lines.Add("== Paths ==")
    $paths = @(
        $Root,
        (Join-Path $Root 'Monitor\Firewall-Core.ps1'),
        (Join-Path $Root 'State'),
        (Join-Path $Root 'Snapshots'),
        (Join-Path $InstallerRoot '_internal\Install-Firewall.ps1'),
        (Join-Path $InstallerRoot '_internal\Uninstall-Firewall.ps1')
    )

    foreach ($p in $paths) {
        if (Test-Path $p) { $lines.Add("$p : present") }
        else              { $lines.Add("$p : missing") }
    }

    $lines.Add("")
    $lines.Add("== Scheduled Tasks ==")
    $lines.Add((Get-SchtasksLine -TaskName 'Firewall Core Monitor'))
    $lines.Add((Get-SchtasksLine -TaskName 'Firewall WFP Monitor'))

    $lines.Add("")
    $lines.Add("== Execution Policy ==")
    $lines.Add("Effective     : $(Get-ExecutionPolicy)")
    $lines.Add("LocalMachine  : $(Get-ExecutionPolicy -Scope LocalMachine)")
    $lines.Add("CurrentUser   : $(Get-ExecutionPolicy -Scope CurrentUser)")
    $lines.Add("Process       : $(Get-ExecutionPolicy -Scope Process)")

    $lines.Add("")
    $lines.Add("== Firewall Rules Fingerprint ==")
    $fp = Get-FwRuleFingerprint
    $lines.Add("RuleCount : $($fp.Count)")
    $lines.Add("SHA256    : $($fp.Sha256)")
    if ($fp.Error) { $lines.Add("Error     : $($fp.Error)") }

    $lines.Add("")
    $lines.Add("== Certificate ==")
    $lines.Add((Get-CertPresenceLine -Thumbprint $CertThumbprint))

    $lines.Add("")
    $lines.Add("=== END SNAPSHOT ===")

    $lines -join "`r`n" | Set-Content -Path $file -Encoding UTF8

    return $file
}

function Compare-SystemSnapshots {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Before,

        [Parameter(Mandatory)]
        [string]$After,

        [Parameter(Mandatory)]
        [string]$OutFile
    )

    $b = Get-Content -Path $Before -ErrorAction Stop
    $a = Get-Content -Path $After  -ErrorAction Stop

    $diff = Compare-Object -ReferenceObject $b -DifferenceObject $a -PassThru

    $header = @(
        "=== SNAPSHOT DIFF ===",
        "Before    : $Before",
        "After     : $After",
        "Timestamp : $(Get-Date -Format o)",
        ""
    )

    ($header + $diff) -join "`r`n" | Set-Content -Path $OutFile -Encoding UTF8

    return $OutFile
}

#endregion Public Functions

Export-ModuleMember -Function Save-SystemSnapshot, Compare-SystemSnapshots

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB6Ly7PIaPOOfO6
# eEut/bd9nfcZHt8L479hiDS2NsRVa6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ILdWYXyif/OUF7TwT5pMm2t45EbycIjf7KRpmuH9EW9bMAsGByqGSM49AgEFAARH
# MEUCIDzm2I+V84xTIXpSxvyi6S7+EbHUPlEHvt9oBnvDQVowAiEA1nBe4BOpLEnV
# a9YWhUHueoh7xyLzLlqfmCSKVcB1los=
# SIG # End signature block
