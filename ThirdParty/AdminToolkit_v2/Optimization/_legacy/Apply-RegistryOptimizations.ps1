# =====================================================================
# Registry Optimizations – Explicit Callouts Only
# Requires: Administrator
# PowerShell: 5.1+
# =====================================================================

# --- Admin Check ---
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required. Re-run PowerShell as Administrator."
    exit 1
}

function Set-RegValue {
    param (
        [string]$Path,
        [string]$Name,
        [ValidateSet('DWord','String')]
        [string]$Type,
        [object]$Value
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    switch ($Type) {
        'DWord'  { New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord  -Force | Out-Null }
        'String' { New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType String -Force | Out-Null }
    }
}

# ---------------------------------------------------------------------
# Multimedia SystemProfile – Games
# ---------------------------------------------------------------------
$gamesPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'

Set-RegValue $gamesPath 'GPU Priority'        'DWord'  8
Set-RegValue $gamesPath 'Priority'            'DWord'  2
Set-RegValue $gamesPath 'Scheduling Category' 'String' 'High'
Set-RegValue $gamesPath 'SFIO Priority'        'String' 'High'

# ---------------------------------------------------------------------
# Priority Control
# ---------------------------------------------------------------------
$priorityPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
Set-RegValue $priorityPath 'Win32PrioritySeparation' 'DWord' 38

# ---------------------------------------------------------------------
# Multimedia SystemProfile (Global)
# ---------------------------------------------------------------------
$sysProfilePath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'

Set-RegValue $sysProfilePath 'NetworkThrottlingIndex' 'DWord' 0xFFFFFFFF
Set-RegValue $sysProfilePath 'SystemResponsiveness'  'DWord' 0

# ---------------------------------------------------------------------
# Service Host Split Threshold
# ---------------------------------------------------------------------
$svcHostPath = 'HKLM:\SYSTEM\CurrentControlSet\Control'
Set-RegValue $svcHostPath 'SvcHostSplitThresholdInKB' 'DWord' 0x1000000

# ---------------------------------------------------------------------
# Power Settings – ValueMax
# ---------------------------------------------------------------------
$powerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583'
Set-RegValue $powerPath 'ValueMax' 'DWord' 0

# ---------------------------------------------------------------------
Write-Host "Registry optimizations applied successfully." -ForegroundColor Green
Write-Host "A reboot is recommended for full effect." -ForegroundColor Yellow
