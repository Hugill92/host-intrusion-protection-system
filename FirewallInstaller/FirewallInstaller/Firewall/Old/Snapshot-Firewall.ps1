param(
    [string]$SnapshotDir = "C:\Firewall\Snapshots"
)

New-Item -ItemType Directory -Path $SnapshotDir -Force | Out-Null

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$snapshotFile = "$SnapshotDir\firewall_$timestamp.json"
$latestFile   = "$SnapshotDir\latest.json"

$rules = Get-NetFirewallRule |
    ForEach-Object {
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
            LocalPort   = $port.LocalPort
            RemotePort  = $port.RemotePort
            LocalAddr   = $addr.LocalAddress
            RemoteAddr  = $addr.RemoteAddress
            Protocol    = $port.Protocol
        }
    }

$rules | ConvertTo-Json -Depth 5 | Out-File $snapshotFile -Encoding UTF8
Copy-Item $snapshotFile $latestFile -Force

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBPl7d0ewjs1wKf
# UeLcAjlR6uBY/gqXugv24ytVOCDKh6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ggE1MIIBMQIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IHH4MdRswkz/C5oEBJIx2L6R5GRen7FMQcX12UZXrI0OMAsGByqGSM49AgEFAARI
# MEYCIQDRjpOXCKOHTHZJwd8XWBQJPFkt2Xn5O8uhb89oNrHvYAIhAJKZOS7lrr0m
# ka7jWWZTXxiqnlpD+/JFoJTdRiQ3+2P6
# SIG # End signature block
