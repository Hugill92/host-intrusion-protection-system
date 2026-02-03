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
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUPngPp5y+LA9MwZOR+5TUAhY7
# Z/SgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUd89G0HhbHZDU53quOEGD1h8SwckwCwYH
# KoZIzj0CAQUABEgwRgIhAPQpLgSi2GkXFFwqkFFHMbUBmMh+tmqgCRKS6aoMcsaL
# AiEA937odEFLNs7tACVSLwOoazXJxAJDkxYKQNSyWqChWDs=
# SIG # End signature block
