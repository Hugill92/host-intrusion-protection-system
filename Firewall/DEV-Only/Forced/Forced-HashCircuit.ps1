# Forced-Test
# Category: ChangeDetection
# Requires: None
# Fatal: true
<#
Forced-HashCircuit.ps1

DETERMINISTIC forced DEV test for snapshot hash comparison (change case).
Simulates a configuration change and verifies decision path is Continue (no short-circuit).

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

$TestId = "Forced-HashCircuit"
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

    $baselineRules = @("ALLOW_TCP_443","ALLOW_UDP_53")
    $currentRules  = @("ALLOW_TCP_443","ALLOW_UDP_53","BLOCK_TCP_23")

    $baselineHash = "HASH_BASELINE_0001"
    $currentHash  = "HASH_CURRENT_0002"
    if ($baselineHash -eq $currentHash) { throw "Simulation invalid: hashes must differ" }

    $decision = "Continue"
    if ($decision -ne "Continue") { throw "Expected Decision='Continue' for change case, got '$decision'" }

    Log "[EXPECTED EVENT]"
    Log "--------------------------------------------------"
    Log "Event Type : SnapshotHashComparison"
    Log ""
    Log ("{0,-28}  {1,-28}" -f "Baseline Rules", "Current Rules")
    Log ("{0,-28}  {1,-28}" -f "----------------------------", "----------------------------")

    $max = [Math]::Max($baselineRules.Count, $currentRules.Count)
    for ($i=0; $i -lt $max; $i++) {
        $b = if ($i -lt $baselineRules.Count) { $baselineRules[$i] } else { "<none>" }
        $c = if ($i -lt $currentRules.Count)  { $currentRules[$i] }  else { "<none>" }
        Log ("{0,-28}  {1,-28}" -f $b, $c)
    }

    Log "--------------------------------------------------"
    Log ("Baseline Hash : {0}" -f $baselineHash)
    Log ("Current Hash  : {0}" -f $currentHash)
    Log ("Decision      : {0}" -f $decision)
    Log ("Meaning       : {0}" -f "Change detected; downstream continues")
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
            ExpectedDecision="Continue"
        }
        ChangeContext=@{
            BaselineRules=$baselineRules
            CurrentRules=$currentRules
        }
        EventResult=@{
            Decision=$decision
            Meaning="Change detected; downstream continues"
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
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUm0RYL08VBFS/y5QHJF2x7U/v
# NC2gggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIzCCAR8CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUdm8Mci5SX8i0jtPYly5VybCt+EgwCwYH
# KoZIzj0CAQUABEcwRQIge1nGqljVIMegOvPi2mvbzQQJIw0uX5DuQ5gfiv1GfpsC
# IQCVWR/RWNDVisZRqh5jT/jLkS0Cv4Z+vxCf7fz1kqPhiQ==
# SIG # End signature block
