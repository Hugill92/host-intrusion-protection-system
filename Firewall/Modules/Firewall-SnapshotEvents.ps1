# Firewall-SnapshotEvents.psm1
# Emits Event Viewer records for firewall snapshots + diffs
# DEV-safe, LIVE-safe, forensic-grade

Set-StrictMode -Version Latest

function Emit-FirewallSnapshotEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Snapshot,
        [Parameter(Mandatory)]$Diff,
        [string]$RunId = ([guid]::NewGuid().ToString()),
        [ValidateSet("DEV","LIVE")]
        [string]$Mode = "LIVE"
    )

    # Defensive validation
    if (-not $Snapshot.Path -or -not $Snapshot.Hash) {
        return
    }

    $added    = $Diff.AddedCount
    $removed  = $Diff.RemovedCount
    $modified = $Diff.ModifiedCount

    $message = @"
Firewall snapshot diff detected.
Mode=$Mode
SnapshotHash=$($Snapshot.Hash)
RuleCount=$($Snapshot.RuleCount)
Added=$added
Removed=$removed
Modified=$modified
SnapshotFile=$($Snapshot.Path)
DiffFile=$($Diff.DiffPath)
RunId=$RunId
"@

    Write-FirewallEvent `
        -EventId 4100 `
        -Type Information `
        -Message $message
}

Export-ModuleMember -Function Emit-FirewallSnapshotEvent

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCV+gCBPJtHYNyt
# 03c8hbgy0uBeLzMrx6D6kactCMu1IqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IP6q9e2uqcj6cnUGfymSY7XjqcpfVMscph9QUewoNqCmMAsGByqGSM49AgEFAARH
# MEUCIFS4Wo7yaJ+79M2miYop+xwO5N3DC38k77uU3hSsqX6lAiEArY32Pbk3RfkB
# k+fw3IMaL7a8lI5EWgZFC7niUps/E7k=
# SIG # End signature block
