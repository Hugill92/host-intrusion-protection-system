# Forced-Test
# Category: TamperProtection
# Requires: ScheduledTasks
# Fatal: true
<#
Forced-Tamper-Protection.ps1

LIVE-only placeholder. In DEV, this is SKIPPED.
No live interaction is performed unless LIVE is explicitly enabled in the runner.
#>

param(
    [ValidateSet("DEV","LIVE")]
    [string]$Mode = "DEV",

    [string]$RunStamp,

    [ValidateSet("Runner","Standalone")]
    [string]$Invocation = "Standalone",

    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}
function New-Stamp { (Get-Date).ToString("yyyyMMdd_HHmmss") }
function Log([string]$Message) { if (-not $Quiet) { Write-Host $Message } }
function Write-Result { param([ValidateSet("PASS","FAIL","SKIPPED")]$Status)
    $color = @{ PASS="Green"; FAIL="Red"; SKIPPED="Yellow" }[$Status]
    Write-Host "[FORCED-RESULT] $Status" -ForegroundColor $color
}
function Get-TestStatePaths {
    param([string]$TestId,[string]$Stamp)
    $stateRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\State\ForcedTests")).Path
    $base      = Join-Path $stateRoot $TestId
    $results   = Join-Path $base "results"
    $metadata  = Join-Path $base "metadata"
    Ensure-Dir $results; Ensure-Dir $metadata
    [pscustomobject]@{
        ResultsPath  = (Join-Path $results  ("forced-results_{0}.json" -f $Stamp))
        MetadataPath = (Join-Path $metadata ("forced-metadata_{0}.json" -f $Stamp))
    }
}

$TestId = "Forced-Tamper-Protection"
$Stamp  = if ($RunStamp) { $RunStamp } else { New-Stamp }
$Paths  = Get-TestStatePaths -TestId $TestId -Stamp $Stamp

try {
    if ($Mode -ne "LIVE") {
        [pscustomobject]@{ TestId=$TestId; Mode=$Mode; Status="SKIPPED"; Reason="LIVE-only"; Stamp=$Stamp } |
            ConvertTo-Json -Depth 6 | Out-File $Paths.ResultsPath -Encoding UTF8
        @{ TestId=$TestId; Stamp=$Stamp; Invocation=$Invocation; Mode=$Mode; ScriptPath=$PSCommandPath } |
            ConvertTo-Json -Depth 6 | Out-File $Paths.MetadataPath -Encoding UTF8
        Log "[INFO] Results written to:";  Log ("       {0}" -f $Paths.ResultsPath)
        Log "[INFO] Metadata written to:"; Log ("       {0}" -f $Paths.MetadataPath)
        Write-Result "SKIPPED"
        exit 0
    }

    throw "LIVE implementation not yet wired for this test."
}
catch {
    [pscustomobject]@{ TestId=$TestId; Mode=$Mode; Status="FAIL"; Error=$_.Exception.Message; Stamp=$Stamp } |
        ConvertTo-Json -Depth 10 | Out-File $Paths.ResultsPath -Encoding UTF8
    @{ TestId=$TestId; Stamp=$Stamp; Invocation=$Invocation; Mode=$Mode; ScriptPath=$PSCommandPath } |
        ConvertTo-Json -Depth 6 | Out-File $Paths.MetadataPath -Encoding UTF8
    Write-Result "FAIL"
    Write-Error $_
    exit 1
}

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC2pSVJHHYmAnII
# or7J+0HPDgu9dRjcFPr38fqLPtZA1qCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IJ6kmXAl/XZSwO3mZunOXkqyS9FAYhGcB/wCWpgi2nyHMAsGByqGSM49AgEFAARI
# MEYCIQCwG0yc2mPuu4Jm7t8vByunRz6kl967DA0xKlNh/WDclQIhAMJD4GXAWTVK
# XfTC06sK5j6s+xwC4uSrhUSgQwl1LvRM
# SIG # End signature block
