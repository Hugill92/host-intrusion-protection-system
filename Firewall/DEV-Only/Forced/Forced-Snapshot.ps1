# Forced-Test
# Category: CoreSnapshot
# Requires: None
# Fatal: true
<#
Forced-Snapshot.ps1

DETERMINISTIC forced DEV test for snapshot creation (SIMULATED).
Produces a stable snapshot object without touching live firewall state.

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

$TestId = "Forced-Snapshot"
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

    $snapshot = [pscustomobject]@{
        SnapshotId   = "DEV-SNAPSHOT-0001"
        CapturedUtc  = "1970-01-01T00:00:00Z"
        Source       = "SIMULATED"
        Rules        = @(
            [pscustomobject]@{ Name="ALLOW_TCP_443"; Direction="Outbound"; Action="Allow" },
            [pscustomobject]@{ Name="ALLOW_UDP_53";  Direction="Outbound"; Action="Allow" }
        )
    }

    Log "[EXPECTED EVENT]"
    Log "--------------------------------------------------"
    Log "Event Type : SnapshotCreated"
    Log ("Snapshot  : {0}" -f $snapshot.SnapshotId)
    Log ("Rules     : {0}" -f $snapshot.Rules.Count)
    Log "--------------------------------------------------"
    Log "[INFO] Full event details recorded in results file"

    [pscustomobject]@{
        TestId = $TestId
        Mode   = $Mode
        Deterministic = $true
        Status = "PASS"
        ExpectedEvent = @{
            EventType="SnapshotCreated"
            SnapshotId=$snapshot.SnapshotId
            ExpectedRuleCount=2
        }
        EventResult = @{
            Snapshot=$snapshot
        }
        Stamp = $Stamp
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
