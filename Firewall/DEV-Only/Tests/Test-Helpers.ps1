# Test-Helpers.ps1
# Shared helpers for DEV test output (Forced-style)

Set-StrictMode -Version Latest

function Write-TestPass {
    param([Parameter(Mandatory=$true)][string]$Message)
    Write-Host ("[PASS] " + $Message) -ForegroundColor Green
}

function Write-TestFail {
    param([Parameter(Mandatory=$true)][string]$Message)
    Write-Host ("[FAIL] " + $Message) -ForegroundColor Red
    throw $Message
}

function Write-TestWarnPass {
    param([Parameter(Mandatory=$true)][string]$Message)
    Write-Warning $Message
    Write-Host ("[PASS] " + $Message) -ForegroundColor Green
}

function Write-TestInfo {
    param([Parameter(Mandatory=$true)][string]$Message)
    Write-Host ("[INFO] " + $Message) -ForegroundColor DarkGray
}
