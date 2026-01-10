# Run-Forced-Dev-Tests.ps1
# Manifest-gated forced test runner (SchemaVersion 1.0)
#
# DEV: deterministic, simulated.
# LIVE: allowed only with -EnableLive (and manifest Modes).
#
# Per-test output under:
#   State\ForcedTests\<TestId>\results\forced-results_<stamp>.json
#   State\ForcedTests\<TestId>\metadata\forced-metadata_<stamp>.json
#   State\ForcedTests\<TestId>\logs\<TestId>.stdout/.stderr.txt
#
# Run-level output:
#   State\ForcedTests\forced-run-results_<stamp>.json
#   State\ForcedTests\metadata\forced-run-metadata_<stamp>.json
#
param(
    [ValidateSet("DEV","LIVE")]
    [string]$Mode = "DEV",

    [switch]$EnableLive,
    [switch]$FailFast,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$PSNativeCommandUseErrorActionPreference = $true

try {
    [System.Threading.Thread]::CurrentThread.CurrentCulture   = [System.Globalization.CultureInfo]::InvariantCulture
    [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::InvariantCulture
} catch {}

function Write-Info([string]$Msg) { if (-not $Quiet) { Write-Host $Msg } }

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Normalize-Array($Value) { if ($null -eq $Value) { @() } else { @($Value) } }

function New-RunStamp { (Get-Date).ToString("yyyyMMdd_HHmmss") }

function Load-Manifest([string]$Path) {
    if (-not (Test-Path $Path)) { throw "Manifest missing: $Path" }
    $m = Get-Content $Path -Raw | ConvertFrom-Json
    if ([string]$m.SchemaVersion -ne "1.0") { throw "Unsupported manifest schema (expected 1.0)" }
    return $m
}

function Get-ModeDefaults($Manifest, [string]$ModeName) {
    if ($Manifest.ModeDefaults -and $Manifest.ModeDefaults.PSObject.Properties.Match($ModeName).Count -gt 0) {
        return $Manifest.ModeDefaults.$ModeName
    }
    [pscustomobject]@{ Simulated = $true; AllowSkipped = $true }
}

function Get-TestsForMode($Manifest, [string]$ModeName) {
    $out = @()
    foreach ($t in Normalize-Array $Manifest.Tests) {
        if (-not $t) { continue }
        if (-not $t.Id -or -not $t.File) { continue }

        $modes = Normalize-Array $t.Modes
        $allowed = if ($modes.Length -eq 0) { $ModeName -eq "DEV" } else { $modes -contains $ModeName }
        if ($allowed) { $out += $t }
    }
    return $out
}

function Write-Status {
    param(
        [string]$Label,
        [ValidateSet("PASS","FAIL","SKIPPED","WARN","INFO")]
        [string]$Status
    )
    $color = switch ($Status) {
        "PASS"    { "Green" }
        "FAIL"    { "Red" }
        "SKIPPED" { "Yellow" }
        "WARN"    { "Yellow" }
        default   { "Gray" }
    }
    Write-Host $Label -ForegroundColor $color
}

function Invoke-ForcedTest {
    param(
        [Parameter(Mandatory)]$TestDef,
        [Parameter(Mandatory)][string]$ForcedDir,
        [Parameter(Mandatory)][string]$LogsDir,
        [Parameter(Mandatory)][string]$ModeName,
        [Parameter(Mandatory)][string]$RunStamp,
        [switch]$Quiet
    )

    $id   = [string]$TestDef.Id
    $file = [string]$TestDef.File
    $testPath = Join-Path $ForcedDir $file

    if (-not (Test-Path $testPath)) {
        return [pscustomobject]@{
            Test=$id; File=$file; Status="FAIL"; ExitCode=2; Duration=0
            StdOutPath=""; StdErrPath=""
            Timestamp=(Get-Date).ToString("o")
            Error="Missing test file: $testPath"
        }
    }

    Ensure-Dir $LogsDir
    $stdoutPath = Join-Path $LogsDir "$id.stdout.txt"
    $stderrPath = Join-Path $LogsDir "$id.stderr.txt"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy","Bypass",
        "-File", $testPath,
        "-Mode", $ModeName,
        "-RunStamp", $RunStamp,
        "-Invocation", "Runner"
    )
    if ($Quiet) { $args += "-Quiet" }

    $p = Start-Process "powershell.exe" -ArgumentList $args -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath

    $sw.Stop()

    $stdout = ""
    try { $stdout = Get-Content $stdoutPath -Raw -ErrorAction SilentlyContinue } catch {}

    $status =
        if ($p.ExitCode -ne 0) { "FAIL" }
        elseif ($stdout -match "\[FORCED-RESULT\]\s+SKIPPED") { "SKIPPED" }
        else { "PASS" }

    [pscustomobject]@{
        Test=$id
        File=$file
        Status=$status
        ExitCode=[int]$p.ExitCode
        Duration=[Math]::Round($sw.Elapsed.TotalSeconds,2)
        StdOutPath=$stdoutPath
        StdErrPath=$stderrPath
        Timestamp=(Get-Date).ToString("o")
    }
}

# ---------------- MAIN ----------------

$RootDir    = (Resolve-Path $PSScriptRoot).Path
$ForcedDir  = Join-Path $RootDir "Forced"
$StateRoot  = Join-Path $RootDir "State\ForcedTests"
$RunMetaDir = Join-Path $StateRoot "metadata"

Ensure-Dir $StateRoot
Ensure-Dir $RunMetaDir

$ManifestPath = Join-Path $RootDir "DEV-Test-Manifest.json"
$Manifest     = Load-Manifest $ManifestPath
$ModeDefaults = Get-ModeDefaults $Manifest $Mode

if ($Mode -eq "LIVE" -and -not $EnableLive) {
    Write-Host "[SKIP] LIVE mode not enabled"
    Write-Host "[FORCED-RESULT] SKIPPED"
    exit 0
}

$runStamp = New-RunStamp

Write-Info "[RUN] Mode=$Mode  SimulatedDefault=$($ModeDefaults.Simulated)  AllowSkipped=$($ModeDefaults.AllowSkipped)"
Write-Info "[RUN] Manifest=$ManifestPath"
Write-Info "[RUN] OutputRoot=$StateRoot"

$testsToRun = Get-TestsForMode $Manifest $Mode
if ($testsToRun.Length -eq 0) {
    Write-Host "[SKIP] No tests enabled"
    Write-Host "[FORCED-RESULT] SKIPPED"
    exit 0
}

$results = New-Object System.Collections.Generic.List[object]
$runTimer = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($t in $testsToRun) {
    $testId = [string]$t.Id
    $testBase = Join-Path $StateRoot $testId
    $logsDir  = Join-Path $testBase "logs"

    Write-Host ("[TEST] {0}" -f $testId) -ForegroundColor Cyan

    $r = Invoke-ForcedTest -TestDef $t -ForcedDir $ForcedDir -LogsDir $logsDir -ModeName $Mode -RunStamp $runStamp -Quiet:$Quiet
    $results.Add($r) | Out-Null

    $label = "[{0,-7}] {1,-35} ({2}s)" -f $r.Status, $r.Test, $r.Duration
    Write-Status $label $r.Status

    if ($FailFast -and $r.Status -eq "FAIL") { break }
}

$runTimer.Stop()
$totalSeconds = [Math]::Round($runTimer.Elapsed.TotalSeconds,2)

# Run-level results (holistic view)
$RunResultsPath = Join-Path $StateRoot ("forced-run-results_{0}.json" -f $runStamp)
$results | ConvertTo-Json -Depth 8 | Out-File $RunResultsPath -Encoding UTF8

# Run-level metadata (runner-only)
$RunMetadataPath = Join-Path $RunMetaDir ("forced-run-metadata_{0}.json" -f $runStamp)
@{
    RunTimestamp = $runStamp
    Mode         = $Mode
    Manifest     = $ManifestPath
    OutputRoot   = $StateRoot
    TestCount    = $results.Count
    Passed       = (@($results | Where-Object Status -eq "PASS")).Length
    Failed       = (@($results | Where-Object Status -eq "FAIL")).Length
    Skipped      = (@($results | Where-Object Status -eq "SKIPPED")).Length
    TotalSeconds = $totalSeconds
    Simulated    = $ModeDefaults.Simulated
    AllowSkipped = $ModeDefaults.AllowSkipped
} | ConvertTo-Json -Depth 5 | Out-File $RunMetadataPath -Encoding UTF8

# Summary
Write-Host ""
Write-Host "========== Forced Test Summary ==========" -ForegroundColor Cyan
Write-Host ("Total Tests : {0}" -f $results.Count)
Write-Host ("Passed      : {0}" -f (@($results | Where-Object Status -eq "PASS")).Length) -ForegroundColor Green
Write-Host ("Failed      : {0}" -f (@($results | Where-Object Status -eq "FAIL")).Length) -ForegroundColor Red
Write-Host ("Skipped     : {0}" -f (@($results | Where-Object Status -eq "SKIPPED")).Length) -ForegroundColor Yellow
Write-Host ("Total Time  : {0}s" -f $totalSeconds)
Write-Host "========================================"
Write-Host ""

$results |
    Select-Object Test, Status, @{Name="Time(s)";Expression={$_.Duration}} |
    Format-Table -AutoSize

Write-Host ""
Write-Host "[INFO] Run results (holistic view):" -ForegroundColor DarkGray
Write-Host ("       {0}" -f $RunResultsPath) -ForegroundColor DarkGray
Write-Host "[INFO] Runner metadata:" -ForegroundColor DarkGray
Write-Host ("       {0}" -f $RunMetadataPath) -ForegroundColor DarkGray
Write-Host "[INFO] Per-test authoritative results are stored under:" -ForegroundColor DarkGray
Write-Host ("       {0}\<TestId>\results\" -f $StateRoot) -ForegroundColor DarkGray
Write-Host ""
Write-Host "[INFO] For full event context and decisions, review the results JSON files." -ForegroundColor DarkGray
Write-Host ""

if ($results | Where-Object Status -eq "FAIL") { exit 1 }
exit 0
