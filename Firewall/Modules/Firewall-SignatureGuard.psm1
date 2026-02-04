# Firewall-SignatureGuard.psm1
# Verifies Authenticode signatures (tamper detection)

Set-StrictMode -Version Latest

function Test-FirewallScriptSignatures {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath,

        [switch]$EmitEvents
    )

    $violations = @()

    $files = Get-ChildItem $RootPath -Recurse -Include *.ps1,*.psm1 -File |
        Where-Object {
            $_.FullName -notmatch '\\Old\\'
        }

    foreach ($file in $files) {
        $sig = Get-AuthenticodeSignature $file.FullName

        if ($sig.Status -ne 'Valid') {
            $violations += [pscustomobject]@{
                Path   = $file.FullName
                Status = $sig.Status
            }
        }
    }

    if ($EmitEvents -and $violations.Count -gt 0) {
        foreach ($v in $violations) {
            Write-FirewallEvent `
                -EventId 4201 `
                -Type Error `
                -Message "Script signature violation detected. Path=$($v.Path) Status=$($v.Status)"
        }
    }

    return $violations
}

Export-ModuleMember -Function Test-FirewallScriptSignatures

# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB2h7khSy5d3rpP
# EDhImVrTg7tCB9fURepagvMQ+GI4nqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IDQUUszD3aBnjlWoQN0+1I/OUyEo7wM9/AvuV97gFsTJMAsGByqGSM49AgEFAARG
# MEQCIETI3jZHx9HRe8BtRFRN0fjOA2KD4lavGSgduNr5/WU8AiBtAlbGD4paE/H+
# cesZemiULQA453dmP9gqd/mj5fVEjQ==
# SIG # End signature block
