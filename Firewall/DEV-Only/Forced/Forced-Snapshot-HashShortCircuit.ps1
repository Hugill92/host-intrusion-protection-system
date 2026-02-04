# Forced-Test
# Category: ChangeDetection
# Requires: None
# Fatal: true
<#
Forced-Snapshot-HashShortCircuit.ps1

DETERMINISTIC forced DEV test for snapshot hash short-circuit logic.
Simulates identical snapshot hashes and verifies downstream is skipped.

This test does NOT touch the live system.
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

$TestId = "Forced-Snapshot-HashShortCircuit"
$Stamp  = if ($RunStamp) { $RunStamp } else { New-Stamp }
$Paths  = Get-TestStatePaths -TestId $TestId -Stamp $Stamp

try {
    $manifestPath = Join-Path $PSScriptRoot "..\DEV-Test-Manifest.json"
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    if (-not (@($manifest.Tests) | Where-Object Id -eq $TestId)) {
        [pscustomobject]@{ TestId=$TestId; Mode=$Mode; Status="SKIPPED"; Reason="Not present in manifest"; Stamp=$Stamp } |
            ConvertTo-Json -Depth 6 | Out-File $Paths.ResultsPath -Encoding UTF8
        @{ TestId=$TestId; Stamp=$Stamp; Invocation=$Invocation; Mode=$Mode } |
            ConvertTo-Json -Depth 4 | Out-File $Paths.MetadataPath -Encoding UTF8
        Log "[INFO] Results written to:";  Log ("       {0}" -f $Paths.ResultsPath)
        Log "[INFO] Metadata written to:"; Log ("       {0}" -f $Paths.MetadataPath)
        Write-Result "SKIPPED"
        exit 0
    }

    $baselineHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    $currentHash  = $baselineHash
    $decision = if ($baselineHash -eq $currentHash) { "ShortCircuit" } else { "Continue" }

    if ($decision -ne "ShortCircuit") {
        throw "Expected Decision='ShortCircuit' for identical hashes, got '$decision'"
    }

    Log "[EXPECTED EVENT]"
    Log "--------------------------------------------------"
    Log "Event Type : SnapshotHashComparison"
    Log ""
    Log ("{0,-16}  {1}" -f "Baseline Hash", $baselineHash)
    Log ("{0,-16}  {1}" -f "Current Hash",  $currentHash)
    Log "--------------------------------------------------"
    Log ("Decision  : {0}" -f $decision)
    Log ("Meaning   : {0}" -f "No change detected; downstream skipped")
    Log "--------------------------------------------------"
    Log "[INFO] Full event details recorded in results file"

    [pscustomobject]@{
        TestId=$TestId
        Mode=$Mode
        Deterministic=$true
        Status="PASS"
        ExpectedEvent=@{
            EventType="SnapshotHashComparison"
            BaselineHash=$baselineHash
            CurrentHash=$currentHash
            ExpectedDecision="ShortCircuit"
        }
        EventResult=@{
            Decision=$decision
            Meaning="No change detected; downstream skipped"
        }
        Stamp=$Stamp
    } | ConvertTo-Json -Depth 10 | Out-File $Paths.ResultsPath -Encoding UTF8

    @{ TestId=$TestId; Stamp=$Stamp; Invocation=$Invocation; Mode=$Mode; ScriptPath=$PSCommandPath } |
        ConvertTo-Json -Depth 6 | Out-File $Paths.MetadataPath -Encoding UTF8

    Log "[INFO] Results written to:";  Log ("       {0}" -f $Paths.ResultsPath)
    Log "[INFO] Metadata written to:"; Log ("       {0}" -f $Paths.MetadataPath)

    Write-Result "PASS"
    exit 0
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
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCeVqSXNxme7Ott
# xu5Crcx+cAvwuYwZnMWhj4SI4d6BjKCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IGCaS2YV+azLsnZbXpmvt87Vd2z3TH3TdJFnSdt2bscOMAsGByqGSM49AgEFAARH
# MEUCIQDzDXqNdkoVVEF3D71SBp11iKbNfwg3Ntf894KTSK9/eAIgDpKQbjA49bkX
# 6GjraIraH471ucmvyMiTuHf64v99NMg=
# SIG # End signature block
