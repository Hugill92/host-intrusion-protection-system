# =====================================================================
# Registry Optimizations – Explicit Callouts Only
# Requires: Administrator
# PowerShell: 5.1+
# =====================================================================

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param()

# Fail fast, deterministically.
$ErrorActionPreference = 'Stop'

# --- Admin Check ---
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required. Re-run PowerShell as Administrator."
    exit 1
}

function ConvertTo-DWordValue {
    <#
    .SYNOPSIS
    Converts common input formats to a registry DWORD-compatible Int32.

    .DESCRIPTION
    Registry DWORD values are 32-bit. PowerShell's New-ItemProperty with -PropertyType DWord
    expects an Int32. Values like 0xFFFFFFFF exceed Int32.MaxValue but are valid DWORDs.
    This function converts such values via UInt32 -> Int32 (unchecked), e.g. 0xFFFFFFFF -> -1.

    .PARAMETER Value
    The input value. Accepts int, uint, long, hex-string (e.g. "0xFFFFFFFF"), or decimal string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Value
    )

    if ($Value -is [int]) { return $Value }

    # Hex string like 0xFFFFFFFF
    if ($Value -is [string] -and $Value.Trim().ToLowerInvariant().StartsWith('0x')) {
        $u = [Convert]::ToUInt32($Value.Trim().Substring(2), 16)
        return [int]$u
    }

    # Numeric-ish string
    if ($Value -is [string]) {
        $s = $Value.Trim()
        if ($s -match '^-?\d+$') { return [int][uint32]([uint64]$s) }
        throw "Unsupported DWORD string value: '$Value'"
    }

    if ($Value -is [uint32]) { return [int]$Value }
    if ($Value -is [long] -or $Value -is [ulong] -or $Value -is [uint64]) {
        if ($Value -lt 0) { throw "DWORD cannot be negative outside Int32 range: $Value" }
        if ($Value -gt [uint32]::MaxValue) { throw "DWORD overflow (> 0xFFFFFFFF): $Value" }
        return [int][uint32]$Value
    }

    # Fallback: try to coerce to UInt32 then to Int32.
    try {
        $u2 = [uint32]$Value
        return [int]$u2
    } catch {
        throw "Unsupported DWORD value type: $($Value.GetType().FullName)"
    }
}

function Ensure-RegistryKey {
    <#
    .SYNOPSIS
    Ensures a full registry key path exists (creates missing intermediate keys).

    .PARAMETER Path
    Registry provider path, e.g. HKLM:\SOFTWARE\MyKey\SubKey
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) { return }

    # Normalize and split: "<Hive>:\<subkey...>"
    if ($Path -notmatch '^(?<hive>HKLM|HKCU|HKCR|HKU|HKCC):\\(?<sub>.+)$') {
        throw "Unsupported registry path format: '$Path'"
    }

    $hive = $Matches['hive']
    $sub  = $Matches['sub']

    $current = "$hive:\"
    foreach ($part in ($sub -split '\\')) {
        $current = Join-Path -Path $current -ChildPath $part
        if (-not (Test-Path -LiteralPath $current)) {
            if ($PSCmdlet.ShouldProcess($current, 'Create registry key')) {
                New-Item -Path $current -Force | Out-Null
            }
        }
    }
}

function Set-RegValue {
    <#
    .SYNOPSIS
    Creates/updates a registry value with deterministic error handling.

    .PARAMETER Path
    Registry key path.

    .PARAMETER Name
    Value name.

    .PARAMETER Type
    Value type (DWord or String).

    .PARAMETER Value
    Value data.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('DWord','String')][string]$Type,
        [Parameter(Mandatory)][object]$Value
    )

    Ensure-RegistryKey -Path $Path

    $propertyValue =
        if ($Type -eq 'DWord') { ConvertTo-DWordValue -Value $Value }
        else { [string]$Value }

    if ($PSCmdlet.ShouldProcess("$Path\$Name", "Set registry value ($Type)")) {
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $propertyValue -PropertyType $Type -Force | Out-Null
    }
}

# ---------------------------------------------------------------------
# Multimedia SystemProfile – Games
# ---------------------------------------------------------------------
$gamesPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'

Set-RegValue $gamesPath 'GPU Priority'        'DWord'  8
Set-RegValue $gamesPath 'Priority'            'DWord'  2
Set-RegValue $gamesPath 'Scheduling Category' 'String' 'High'
Set-RegValue $gamesPath 'SFIO Priority'       'String' 'High'

# ---------------------------------------------------------------------
# Priority Control
# ---------------------------------------------------------------------
$priorityPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
Set-RegValue $priorityPath 'Win32PrioritySeparation' 'DWord' 38

# ---------------------------------------------------------------------
# Multimedia SystemProfile (Global)
# ---------------------------------------------------------------------
$sysProfilePath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'

# DWORD 0xFFFFFFFF must be written as -1 (Int32) to avoid conversion errors.
Set-RegValue $sysProfilePath 'NetworkThrottlingIndex' 'DWord' -1
Set-RegValue $sysProfilePath 'SystemResponsiveness'   'DWord' 0

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

Write-Host "Registry optimizations applied successfully." -ForegroundColor Green
Write-Host "A reboot is recommended for full effect." -ForegroundColor Yellow
