# FirewallSnapshot.psm1
# Captures full Windows Firewall rule state

function Get-FirewallSnapshot {
    param(
        [string]$SnapshotDir = "C:\FirewallInstaller\Firewall\Snapshots"
    )

    if (-not (Test-Path $SnapshotDir)) {
        New-Item -ItemType Directory -Path $SnapshotDir -Force | Out-Null
    }

    $timestamp    = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $snapshotFile = Join-Path $SnapshotDir "firewall_$timestamp.json"
    $latestFile   = Join-Path $SnapshotDir "latest.json"

    Write-Output "[SNAPSHOT] Capturing firewall rules"

    $rules = Get-NetFirewallRule | ForEach-Object {
        $r = $_

        $port = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $r -ErrorAction SilentlyContinue
        $addr = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $r -ErrorAction SilentlyContinue
        $app  = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $r -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            Name        = $r.Name
            DisplayName = $r.DisplayName
            Group       = $r.Group
            Enabled     = $r.Enabled
            Direction   = $r.Direction
            Action      = $r.Action
            Profile     = $r.Profile
            Program     = $app.Program
            Protocol    = $port.Protocol
            LocalPort   = $port.LocalPort
            RemotePort  = $port.RemotePort
            LocalAddr   = $addr.LocalAddress
            RemoteAddr  = $addr.RemoteAddress
        }
    }

    $rules | ConvertTo-Json -Depth 6 | Out-File $snapshotFile -Encoding UTF8
    Copy-Item $snapshotFile $latestFile -Force

    Write-Output "[SNAPSHOT] Snapshot written: $snapshotFile"

    return $snapshotFile
}

Export-ModuleMember -Function Get-FirewallSnapshot

# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCOI1b86iYGG/gH
# VCDMwyP1xxyXFQd6iBIV1H8ZuX2nqKCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IAaPsVBz7EPsSwi7tyem2lNwd+dlYfOcaYvYhlDU0AgvMAsGByqGSM49AgEFAARG
# MEQCIAshLMPGc58QvJbtqEhDLh2dgqZ2gku0mgbasjl4OcWlAiB9f/GQ5adkIQDk
# H8mWZD9uxMJ5ElWiAbvFYK/P7hkXUw==
# SIG # End signature block
