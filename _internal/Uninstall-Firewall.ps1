<#
Uninstall-Firewall.ps1 (v4)
Production-grade uninstaller with:
- Snapshot + diff
- Tamper detection
- Rollback guardrails
- Optional cert removal
- Firewall reset to defaults
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Quiet,
    [switch]$RemoveCerts,
    [switch]$RemoveEventLog,
    [switch]$KeepLogs,
    [string]$InstallerRoot = "C:\FirewallInstaller",
    [string]$TargetRoot,
    [switch]$IgnoreTamper,
    [switch]$IgnoreDrift
)

# region PATH_HELPERS_SPRINT2
# Helpers required for uninstall safety + PS5.1 compatibility

try {
  if ($global:PSModuleAutoLoadingPreference -eq 'None') { $global:PSModuleAutoLoadingPreference = 'All' }
} catch {}

try { Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue } catch {}

function Normalize-Path {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
  $p = [Environment]::ExpandEnvironmentVariables($Path.Trim())
  $p = $p -replace '/', '\'
  try { $p = [System.IO.Path]::GetFullPath($p) } catch {}
  return $p.TrimEnd('\')
}

function Is-PathUnder {
  param(
    [Parameter(Mandatory)][string]$Child,
    [Parameter(Mandatory)][string]$Parent
  )
  $c = Normalize-Path $Child
  $p = Normalize-Path $Parent
  if ($p -eq '') { return $false }

  $cmp = [System.StringComparison]::OrdinalIgnoreCase
  if ($c.Equals($p, $cmp)) { return $true }

  $pWith = $p + '\'
  return $c.StartsWith($pWith, $cmp)
}

function Get-FileHashCompat {
  param(
    [Parameter(Mandatory)][string]$Path,
    [ValidateSet('SHA256','SHA1','SHA512','MD5')][string]$Algorithm = 'SHA256'
  )

  try { Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue } catch {}
  $cmd = Get-Command -Name Get-FileHash -ErrorAction SilentlyContinue
  if ($cmd) {
    return Microsoft.PowerShell.Utility\Get-FileHash -Algorithm $Algorithm -LiteralPath $Path
  }

  $stream = [System.IO.File]::OpenRead($Path)
  try {
    $alg = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
    if (-not $alg) { throw "Hash algorithm not available: $Algorithm" }
    $bytes = $alg.ComputeHash($stream)
    $hex = -join ($bytes | ForEach-Object { $_.ToString('x2') })
    return [pscustomobject]@{ Algorithm = $Algorithm; Hash = $hex; Path = $Path }
  } finally {
    $stream.Dispose()
  }
}
# endregion PATH_HELPERS_SPRINT2



# If InstallerRoot wasn't explicitly provided, derive it from this script location.
$InstallerRootSource = "param"
if (-not $PSBoundParameters.ContainsKey("InstallerRoot")) {
    $ThisDir = $PSScriptRoot
    $InstallerRoot = if ((Split-Path -Leaf $ThisDir) -ieq "_internal") {
        Split-Path -Parent $ThisDir
    } else {
        $ThisDir
    }
    $InstallerRootSource = "script"
}

# ================= DEV / INSTALLER CONTEXT =================
# Prefer live root; allow explicit override via -TargetRoot.
$IsInstallerContext = $false

$LiveFirewallRoot = "C:\Firewall"
$InstallerFirewallRoot = Join-Path $InstallerRoot "Firewall"
$InstallerPayloadAvailable = Test-Path -LiteralPath $InstallerFirewallRoot
$TargetRootSource = "default"

if ($PSBoundParameters.ContainsKey("TargetRoot") -and $TargetRoot) {
    $FirewallRoot = $TargetRoot
    $TargetRootSource = "param"
} else {
    $FirewallRoot = $LiveFirewallRoot
}

if ($InstallerPayloadAvailable -and (Normalize-Path $FirewallRoot) -eq (Normalize-Path $InstallerFirewallRoot)) {
    $IsInstallerContext = $true
}

if (Is-PathUnder $FirewallRoot $InstallerRoot) {
    throw "Unsafe target root: '$FirewallRoot' is under InstallerRoot '$InstallerRoot'. Refusing uninstall."
}

$ModulesDir    = Join-Path $FirewallRoot "Modules"
$SnapshotsDir  = Join-Path $FirewallRoot "Snapshots"
$DiffDir       = Join-Path $FirewallRoot "Diff"
$StateDir      = Join-Path $FirewallRoot "State"
$LogsDir       = Join-Path $FirewallRoot "Logs"
# ===========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:TamperDetected = $false
$script:DriftDetected = $false

# -------------------------
# Helpers
# -------------------------
function STEP($m){ Write-Host "[*] $m" }
function OK($m){ Write-Host "[OK] $m" }
function WARN($m){ Write-Warning $m }
function INFO($m){ Write-Host "[INFO] $m" }

function Ensure-Dir($p){
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
    }
}

Write-Output "================================================="
Write-Output "Firewall Core Uninstall Started"
Write-Output "Time      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "User      : $env:USERNAME"
Write-Output "Computer  : $env:COMPUTERNAME"
Write-Output "InstallerRoot ($InstallerRootSource): $InstallerRoot"
Write-Output "FirewallRoot: $FirewallRoot"
Write-Output "TargetRootSource: $TargetRootSource"
Write-Output "InstallerContext: $IsInstallerContext"
Write-Output "IgnoreTamper: $IgnoreTamper"
Write-Output "IgnoreDrift: $IgnoreDrift"
Write-Output "KeepLogs: $KeepLogs"
Write-Output "================================================="
Write-Output ""

# -------------------------
# Snapshot system
# -------------------------
$SnapshotDir = Join-Path $InstallerRoot "Tools\Snapshots"
Ensure-Dir $SnapshotDir
INFO "SnapshotDir: $SnapshotDir"

function Save-Snapshot {
    param([Parameter(Mandatory)][string]$OutFile)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("SnapshotTime: $(Get-Date -Format o)")
    $lines.Add("Computer: $env:COMPUTERNAME")
    $lines.Add("User: $env:USERNAME")
    $lines.Add("")

    $lines.Add("=== Firewall Profiles ===")
    try {
        Get-NetFirewallProfile | ForEach-Object {
            $lines.Add("Profile=$($_.Name) Enabled=$($_.Enabled) In=$($_.DefaultInboundAction) Out=$($_.DefaultOutboundAction)")
        }
    } catch {
        $lines.Add("ERROR: $($_.Exception.Message)")
    }

    $lines.Add("")
    $lines.Add("=== Scheduled Tasks ===")
    foreach ($t in @("Firewall Core Monitor","Firewall WFP Monitor")) {
        $task = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
        if ($null -ne $task) {
            $lines.Add("${t}: PRESENT")
        } else {
            $lines.Add("${t}: MISSING")
        }
    }

    $lines.Add("")
    $lines.Add("=== Firewall Rules (project) ===")
    try {
        $rules = Get-NetFirewallRule | Where-Object {
            $_.DisplayName -like "WFP-*"
        }
        if ($rules) {
            foreach ($r in $rules) {
                $lines.Add("RULE: $($r.DisplayName) Enabled=$($r.Enabled) Action=$($r.Action)")
            }
        } else {
            $lines.Add("(none)")
        }
    } catch {
        $lines.Add("ERROR: $($_.Exception.Message)")
    }

    Ensure-Dir (Split-Path $OutFile -Parent)
    $lines | Set-Content -Path $OutFile -Encoding UTF8
}

function Latest-Snapshot($pattern){
    Get-ChildItem $SnapshotDir -Filter $pattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

# -------------------------
# Tamper detection
# -------------------------
function Assert-NoTamper {
    param([switch]$Force)

    $manifest = "C:\Firewall\Golden\payload.manifest.sha256.json"
    if (-not (Test-Path $manifest)) {
        WARN "No payload manifest found"
        return
    }

    $m = Get-Content $manifest -Raw | ConvertFrom-Json
    $bad = @()

    $entries = @()
    if ($m -is [System.Array]) {
        $entries = $m
    } elseif ($m -is [pscustomobject]) {
        $props = $m.PSObject.Properties
        $metaKeys = @("BuiltAtUtc","Count","Items","Root","Schema")
        $collectionProp = $props | Where-Object { $_.Name -match '^(Files|Entries|Items)$' } | Select-Object -First 1
        $hasPath = $props.Name -contains "Path" -or $props.Name -contains "path"
        $hasSha = $props.Name -contains "Sha256" -or $props.Name -contains "sha256" -or $props.Name -contains "Hash" -or $props.Name -contains "hash"
        if ($collectionProp) {
            $entries = @($collectionProp.Value)
        } elseif ($hasPath -or $hasSha) {
            $entries = @($m)
        } else {
            foreach ($p in $props) {
                if ($metaKeys -contains $p.Name) { continue }
                $entries += [pscustomobject]@{ Path = $p.Name; Sha256 = [string]$p.Value }
            }
        }
    } else {
        $entries = @($m)
    }

    if ($entries.Count -eq 1 -and $entries[0] -is [System.Collections.IEnumerable] -and $entries[0] -isnot [string]) {
        $entries = @($entries[0])
    }

    if ($entries -is [System.Collections.IDictionary]) {
        $entries = @($entries.GetEnumerator() | ForEach-Object {
            [pscustomobject]@{ Path = $_.Key; Sha256 = [string]$_.Value }
        })
    }

    if (-not $entries -or $entries.Count -eq 0) {
        WARN "No manifest entries found; skipping tamper check"
        return
    }

    foreach ($e in $entries) {
        $path = $null
        $sha = $null

        if ($e -is [string]) {
            $path = $e
        } else {
            if ($e.PSObject.Properties["Path"]) { $path = $e.Path }
            elseif ($e.PSObject.Properties["path"]) { $path = $e.path }

            if ($e.PSObject.Properties["Sha256"]) { $sha = $e.Sha256 }
            elseif ($e.PSObject.Properties["sha256"]) { $sha = $e.sha256 }
            elseif ($e.PSObject.Properties["Hash"]) { $sha = $e.Hash }
            elseif ($e.PSObject.Properties["hash"]) { $sha = $e.hash }
        }

        if (-not $path) {
            WARN "Manifest entry missing Path; skipping"
            continue
        }

        if (-not (Test-Path $path)) {
            $bad += $path
            continue
        }

        if ($sha) {
            $h = (Get-FileHashCompat -Algorithm SHA256 -Path $path).Hash
            if ($h -ne $sha) {
                $bad += $path
            }
        } else {
            WARN "Manifest entry missing Sha256 for $path; skipping hash check"
        }
    }

    if ($bad.Count -gt 0) {
        $script:TamperDetected = $true
        $uniqueBad = $bad | Sort-Object -Unique
        if ($Force) {
            WARN "Tamper detected: $($uniqueBad.Count) file(s) differ from manifest (override enabled)"
        } else {
            WARN "Tamper detected: $($uniqueBad.Count) file(s) differ from manifest"
            WARN "Proceeding with uninstall despite tamper findings"
        }
        foreach ($p in ($uniqueBad | Select-Object -First 20)) {
            INFO "TAMPER: $p"
        }
        if ($uniqueBad.Count -gt 20) {
            INFO "TAMPER: ... $($uniqueBad.Count - 20) more"
        }
    } else {
        OK "Tamper check passed"
    }
}

# -------------------------
# Snapshot + drift gate
# -------------------------
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$preSnap = Join-Path $SnapshotDir "Snapshot-Before-Uninstall-$stamp.txt"
Save-Snapshot -OutFile $preSnap
OK "Snapshot saved: $preSnap"

if ($IgnoreTamper -or $Force) {
    WARN "Tamper check skipped (Force/IgnoreTamper)"
} else {
    Assert-NoTamper -Force:$Force
}

$expected = Latest-Snapshot "Snapshot-After-Install-*.txt"
if ($IgnoreDrift -or $Force) {
    WARN "System drift check skipped (Force/IgnoreDrift)"
} elseif ($expected) {
    $diff = Join-Path $SnapshotDir "SnapshotDiff-PreUninstall-$stamp.txt"
    Compare-Object (Get-Content $expected.FullName) (Get-Content $preSnap) |
        Set-Content $diff

    if ((Get-Item $diff).Length -gt 0) {
        $script:DriftDetected = $true
        WARN "System drift detected vs install snapshot: $diff"
        WARN "Proceeding with uninstall despite drift findings"
    }
}

if (-not $Force -and -not $Quiet) {
    $resp = Read-Host "Type UNINSTALL to proceed"
    if ($resp -ne "UNINSTALL") { throw "User aborted uninstall" }
}

# -------------------------
# UNINSTALL ACTIONS
# -------------------------
STEP "Stopping scheduled tasks"

$taskNames = @(
    "Firewall Core Monitor",
    "Firewall WFP Monitor",
    "Firewall-Defender-Integration",
    "FirewallCore Toast Listener",
    "FirewallCore Toast Watchdog",
    "FirewallCore-ToastListener",
    "FirewallCore User Notifier"
)
foreach ($name in $taskNames) {
    $tasks = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if ($tasks) {
        foreach ($task in $tasks) {
            try {
                Stop-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
                Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction Stop
                OK "Removed task: $($task.TaskPath)$($task.TaskName)"
            } catch {
                WARN "Failed to remove task ${name} ($($task.TaskPath)): $($_.Exception.Message)"
            }
        }
    } else {
        OK "Task not present: $name"
    }
}

OK "Scheduled tasks removed (including notifier/listener/watchdog if present)"

STEP "Stopping toast listener processes"
$toastPattern = 'FirewallToastListener(-Runner)?\.ps1|FirewallToastWatchdog\.ps1'
$toastProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -and $_.CommandLine -match $toastPattern
}
if ($toastProcs) {
    $pids = $toastProcs.ProcessId
    try {
        Stop-Process -Id $pids -Force -ErrorAction Stop
        OK "Stopped toast processes: $($pids -join ', ')"
    } catch {
        WARN "Failed to stop toast processes: $($_.Exception.Message)"
    }
} else {
    OK "No toast listener processes found"
}

STEP "Removing protocol handler keys"
$protocolKeys = @(
    "HKLM:\Software\Classes\firewallcore-review",
    "HKCU:\Software\Classes\firewallcore-review"
)
foreach ($key in $protocolKeys) {
    if (Test-Path -LiteralPath $key) {
        try {
            Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop
            OK "Removed protocol handler: $key"
        } catch {
            WARN "Failed to remove protocol handler ${key}: $($_.Exception.Message)"
        }
    } else {
        OK "Protocol handler not present: $key"
    }
}

STEP "Removing firewall rules"
Get-NetFirewallRule | Where-Object {
    $_.DisplayName -like "WFP-*"
} | Remove-NetFirewallRule -ErrorAction SilentlyContinue

STEP "Resetting Windows Firewall to defaults"
netsh advfirewall reset | Out-Null

if ($RemoveCerts) {
    STEP "Removing Firewall signing certificates"
    Get-ChildItem Cert:\LocalMachine\Root |
        Where-Object Subject -like "*Firewall*" |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

STEP "Removing installer-owned paths"
$programDataRoot = Join-Path $env:ProgramData "FirewallCore"
$ownedPaths = @(
    $FirewallRoot,
    $programDataRoot
)
foreach ($path in $ownedPaths) {
    if (Is-PathUnder $path $InstallerRoot) {
        WARN "Skipping unsafe path under InstallerRoot: $path"
        continue
    }
    if ($KeepLogs -and (Normalize-Path $path) -eq (Normalize-Path $programDataRoot)) {
        if (Test-Path -LiteralPath $path) {
            $logPath = Join-Path $path "Logs"
            $logPathNorm = Normalize-Path $logPath
            $children = Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue
            foreach ($child in $children) {
                $childPath = $child.FullName
                if ($logPathNorm -and (Normalize-Path $childPath) -eq $logPathNorm) {
                    OK "Preserved logs: $logPath"
                    continue
                }
                try {
                    Remove-Item -LiteralPath $childPath -Recurse -Force -ErrorAction Stop
                    OK "Removed: $childPath"
                } catch {
                    WARN "Failed to remove ${childPath}: $($_.Exception.Message)"
                }
            }
        } else {
            OK "Path not present: $path"
        }
        continue
    }
    if (Test-Path -LiteralPath $path) {
        try {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
            OK "Removed: $path"
        } catch {
            WARN "Failed to remove ${path}: $($_.Exception.Message)"
        }
    } else {
        OK "Path not present: $path"
    }
}

# -------------------------
# Post snapshot
# -------------------------
$postSnap = Join-Path $SnapshotDir "Snapshot-After-Uninstall-$stamp.txt"
Save-Snapshot -OutFile $postSnap
OK "Post-uninstall snapshot saved: $postSnap"

if ($RemoveEventLog) {
    STEP "Removing FirewallCore Event Log"
    try { Remove-EventLog -LogName "FirewallCore" -ErrorAction Stop; OK "FirewallCore Event Log removed" } catch { WARN "Could not remove FirewallCore Event Log: $($_.Exception.Message)" }
}

OK "Firewall Core successfully uninstalled"
Write-Output "================================================="
Write-Output "Firewall Core Uninstall Completed Successfully"
Write-Output "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "================================================="
