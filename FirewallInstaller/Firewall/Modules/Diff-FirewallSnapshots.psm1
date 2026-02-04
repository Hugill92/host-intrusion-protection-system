# Diff-FirewallSnapshots.psm1
# Forensic diff engine for firewall snapshots

Set-StrictMode -Version Latest

function Compare-FirewallSnapshots {
    [CmdletBinding()]
    param(
        [string]$SnapshotDir = "C:\Firewall\Snapshots",
        [string]$DiffDir     = "C:\Firewall\Diff"
    )

    if (!(Test-Path $SnapshotDir)) { return $null }
    if (!(Test-Path $DiffDir)) {
        New-Item -ItemType Directory -Path $DiffDir -Force | Out-Null
    }

    $snaps = Get-ChildItem $SnapshotDir -Filter "firewall_*.json" |
             Sort-Object LastWriteTime -Descending

    if ($snaps.Count -lt 2) { return $null }

    $newPath = $snaps[0].FullName
    $oldPath = $snaps[1].FullName

    $new = Get-Content $newPath -Raw | ConvertFrom-Json
    $old = Get-Content $oldPath -Raw | ConvertFrom-Json

    $newIdx = @{}; foreach ($r in $new) { if ($r.Name) { $newIdx[$r.Name] = $r } }
    $oldIdx = @{}; foreach ($r in $old) { if ($r.Name) { $oldIdx[$r.Name] = $r } }

    $added = @()
    $removed = @()
    $modified = @()

    foreach ($k in $newIdx.Keys) {
        if (-not $oldIdx.ContainsKey($k)) {
            $added += $newIdx[$k]
        }
        elseif ((ConvertTo-Json $newIdx[$k] -Depth 6) -ne (ConvertTo-Json $oldIdx[$k] -Depth 6)) {
            $modified += [pscustomobject]@{
                Name = $k
                Old  = $oldIdx[$k]
                New  = $newIdx[$k]
            }
        }
    }

    foreach ($k in $oldIdx.Keys) {
        if (-not $newIdx.ContainsKey($k)) {
            $removed += $oldIdx[$k]
        }
    }

    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $diffPath = Join-Path $DiffDir "firewall_diff_$ts.json"

    $diff = [pscustomobject]@{
        Timestamp     = (Get-Date).ToString("o")
        NewSnapshot   = $newPath
        OldSnapshot   = $oldPath
        DiffPath      = $diffPath
        AddedCount    = $added.Count
        RemovedCount  = $removed.Count
        ModifiedCount = $modified.Count
        Added         = $added
        Removed       = $removed
        Modified      = $modified
    }

    $diff | ConvertTo-Json -Depth 8 | Set-Content -Path $diffPath -Encoding UTF8
    return $diff
}

Export-ModuleMember -Function Compare-FirewallSnapshots

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCG9BORKGRaO56n
# 14q8LhmVTckHUC7uW+S+7PmzE5CxjKCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IHG6Unha0jDzowscMLSkIzHg2k17jOYww3uZzSTieBsjMAsGByqGSM49AgEFAARH
# MEUCIDeKbvzXhrTQANVNRvTsesNjyZ816zCjjfH3oMjNf8tQAiEA0iLXTMmRKaM6
# KZkqcUzNZgSpCSmk/onTKCqaAsAWU18=
# SIG # End signature block
