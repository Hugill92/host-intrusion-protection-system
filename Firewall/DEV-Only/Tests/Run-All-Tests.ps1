$ErrorActionPreference = "Stop"

# --- Run metadata ---
$StartTime = Get-Date
$Results   = @()

# --- Output directory (DEV state sync) ---
$OutDir = "C:\FirewallInstaller\Firewall\DEV-Only\State"
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$JsonOut = Join-Path $OutDir ("test-results_{0}.json" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"))

Write-Host "=== Firewall Core DEV Test Suite ==="

# --- Discover tests ---
$Tests = Get-ChildItem -Path $PSScriptRoot -Filter "Test-*.ps1" |
    Where-Object { $_.Name -ne "Run-All-Tests.ps1" } |
    Sort-Object Name

$Failures = @()

foreach ($Test in $Tests) {

    Write-Host ""
    Write-Host ">>> RUNNING $($Test.Name)"

    $TestStart = Get-Date
    $Status = "PASS"
    $Message = ""

    try {
        & $Test.FullName
        Write-Host "[PASS] $($Test.Name)" -ForegroundColor Green
    }
    catch {
        $Status  = "FAIL"
        $Message = $_.Exception.Message
        Write-Host "[FAIL] $($Test.Name)" -ForegroundColor Red
        Write-Host $Message
        $Failures += $Test.Name
    }

    $Results += [pscustomobject]@{
        TestName   = $Test.Name
        Status     = $Status
        Message    = $Message
        StartTime  = $TestStart.ToString("o")
        EndTime    = (Get-Date).ToString("o")
        DurationMs = [int]((Get-Date) - $TestStart).TotalMilliseconds
    }
}

# --- Summary ---
Write-Host ""
Write-Host "=== TEST SUMMARY ==="

$Summary = [pscustomobject]@{
    RunStarted = $StartTime.ToString("o")
    RunEnded   = (Get-Date).ToString("o")
    TotalTests = $Tests.Count
    Passed     = ($Results | Where-Object Status -eq "PASS").Count
    Failed     = ($Results | Where-Object Status -eq "FAIL").Count
}

if ($Failures.Count -eq 0) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
    $ExitCode = 0
}
else {
    Write-Host "FAILED TESTS:" -ForegroundColor Red
    foreach ($F in $Failures) {
        Write-Host " - $F" -ForegroundColor Red
    }
    $ExitCode = 1
}

# --- Write JSON artifact (FINAL) ---
[pscustomobject]@{
    Summary = $Summary
    Results = $Results
} | ConvertTo-Json -Depth 5 |
    Out-File -Encoding UTF8 -FilePath $JsonOut

Write-Host ""
Write-Host "[INFO] JSON results written to:" -ForegroundColor Cyan
Write-Host "       $JsonOut" -ForegroundColor Cyan

exit $ExitCode
