param (
    [Parameter(Mandatory = $true)]
    [string]$DesktopFolder,

    [switch]$ExpectCrossDeviceResumeDisabled
)

# =====================================================================
# Registry Optimizations – Verification (STRICT Desktop Folder)
# =====================================================================

if (-not (Test-Path $DesktopFolder)) {
    throw "DesktopFolder does not exist: $DesktopFolder"
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$FileName  = "RegistryOptimization_Verification_$Timestamp.log"

$DesktopLog = Join-Path $DesktopFolder $FileName

# --- ProgramData (audit trail) ---
$PDIRoot = 'C:\ProgramData\RegistryOptimizations'
if (-not (Test-Path $PDIRoot)) {
    New-Item -Path $PDIRoot -ItemType Directory -Force | Out-Null
}
$PDILog = Join-Path $PDIRoot $FileName

function Write-Log {
    param ([string]$Line)
    $Line | Tee-Object -FilePath $DesktopLog -Append |
            Tee-Object -FilePath $PDILog     -Append | Out-Null
}

function Test-RegValue {
    param (
        [string]$Path,
        [string]$Name,
        [object]$Expected
    )

    try {
        $Actual = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop |
                  Select-Object -ExpandProperty $Name

        if ($Actual -eq $Expected) {
            Write-Log "[PASS] $Path\$Name | Expected: $Expected | Actual: $Actual"
        } else {
            Write-Log "[FAIL] $Path\$Name | Expected: $Expected | Actual: $Actual"
        }
    }
    catch {
        Write-Log "[FAIL] $Path\$Name | Expected: $Expected | Actual: <NOT FOUND>"
    }
}

Write-Log "==== Registry Optimization Verification ===="
Write-Log "Timestamp : $(Get-Date)"
Write-Log "Machine   : $env:COMPUTERNAME"
Write-Log "User      : $env:USERNAME"
Write-Log ""

# --- Checks (unchanged) ---
$games = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
Test-RegValue $games 'GPU Priority'        8
Test-RegValue $games 'Priority'            2
Test-RegValue $games 'Scheduling Category' 'High'
Test-RegValue $games 'SFIO Priority'       'High'

Test-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' `
              'Win32PrioritySeparation' 38

$sys = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
Test-RegValue $sys 'NetworkThrottlingIndex' 0xFFFFFFFF
Test-RegValue $sys 'SystemResponsiveness'  0

Test-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control' `
              'SvcHostSplitThresholdInKB' 0x1000000

Test-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583' `
              'ValueMax' 0

# Optional: Cross-Device Resume (only if explicitly requested)
if ($ExpectCrossDeviceResumeDisabled) {
    $xdr = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'
    Test-RegValue $xdr 'IsResumeAllowed' 0
}

Write-Log ""
Write-Log "Verification complete."
Write-Log "Desktop Folder : $DesktopFolder"
Write-Log "ProgramData    : $PDILog"
