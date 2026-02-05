# Firewall-SnapshotHistory.psm1
# Append-only snapshot hash history for forensic timelines

Set-StrictMode -Version Latest

$HistoryPath = "C:\Firewall\State\snapshot.history.jsonl"

function Write-SnapshotHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Snapshot,
        [Parameter(Mandatory)]$Diff,
        [string]$RunId = "Unknown"
    )

    if (-not (Test-Path (Split-Path $HistoryPath))) {
        New-Item -ItemType Directory -Path (Split-Path $HistoryPath) -Force | Out-Null
    }

    $entry = [pscustomobject]@{
        ts            = (Get-Date).ToString("o")
        runId         = $RunId
        snapshotHash  = $Snapshot.Hash
        ruleCount     = $Snapshot.RuleCount
        snapshotPath  = $Snapshot.Path
        diffPath      = $Diff.DiffPath
        added         = $Diff.AddedCount
        removed       = $Diff.RemovedCount
        modified      = $Diff.ModifiedCount
        mode          = $Snapshot.Mode
        computer      = $env:COMPUTERNAME
    }

    # JSONL = append-only forensic log
    ($entry | ConvertTo-Json -Depth 5 -Compress) |
        Add-Content -Path $HistoryPath -Encoding UTF8
}

Export-ModuleMember -Function Write-SnapshotHistory

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBw/b7d6BMsMYfp
# 3fbNZDqa/Zp7SQG4IF4dLIXaed5QJaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IBAIs3MwpZhPMKR/hZRxAKCivuhMiGyOhvE0F6P0AtDJMAsGByqGSM49AgEFAARH
# MEUCIQC2bg+EZMajzCW2mruoItb8G3bhadHs9gMzzF9MP1LkhwIgIJtejUsA594P
# 4PsZYVUzfS41VbXDe/zZLmVkpyz2dNs=
# SIG # End signature block
