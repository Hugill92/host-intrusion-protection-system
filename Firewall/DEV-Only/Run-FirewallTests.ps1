param(
    [ValidateSet("DEV","LIVE")]
    [string]$Mode = "DEV",

    [switch]$FailFast,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path $PSScriptRoot -Parent

if ($Mode -eq "DEV") {
    $TestRoot = Join-Path $Root "DEV-Only\Tests"
} else {
    $TestRoot = Join-Path $Root "Live\Tests"
}

Write-Host "[RUN] Mode=$Mode"
Write-Host "[RUN] TestRoot=$TestRoot"

$tests = Get-ChildItem $TestRoot -Filter "*.ps1" | Sort-Object Name
if (-not $tests) {
    Write-Host "[SKIP] No tests found"
    exit 0
}

$results = @()

foreach ($test in $tests) {
    Write-Host "`n[TEST] $($test.Name)" -ForegroundColor Cyan

    $sw = [Diagnostics.Stopwatch]::StartNew()
    & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File $test.FullName `
        -Mode $Mode
    $code = $LASTEXITCODE
    $sw.Stop()

    $status = if ($code -eq 0) { "PASS" } else { "FAIL" }

    Write-Host ("[{0}] {1} ({2}s)" -f $status,$test.Name,[math]::Round($sw.Elapsed.TotalSeconds,2)) `
        -ForegroundColor (if ($status -eq "PASS") {"Green"} else {"Red"})

    $results += [pscustomobject]@{
        Test   = $test.Name
        Status = $status
        Time   = $sw.Elapsed.TotalSeconds
    }

    if ($FailFast -and $status -eq "FAIL") { break }
}

Write-Host "`n[INFO] Review FirewallCore event log for authoritative results."
