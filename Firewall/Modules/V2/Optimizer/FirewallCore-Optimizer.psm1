#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'FirewallCore-ActionRegistry.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\..\Tools\V2\_shared\FirewallCore-V2Shared.psm1') -Force

function Get-FileInventory {
  param([Parameter(Mandatory)][string[]]$Paths,[int]$OlderThanDays = 7)
  $cutoff = (Get-Date).AddDays(-1 * $OlderThanDays)
  $files = @()
  foreach ($p in $Paths) {
    if (-not (Test-Path -LiteralPath $p)) { continue }
    $files += Get-ChildItem -LiteralPath $p -Force -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer -and $_.LastWriteTime -le $cutoff }
  }
  $bytes = 0
  foreach ($f in $files) { try { $bytes += [int64]$f.Length } catch { } }
  $sample = @($files | Select-Object -First 10 | ForEach-Object { $_.FullName })
  return [pscustomobject]@{ BytesFound=[int64]$bytes; ItemCount=[int]$files.Count; Sample=$sample; CutoffUtc=$cutoff.ToUniversalTime().ToString('o') }
}

function Remove-InventoryItems {
  param([Parameter(Mandatory)][string[]]$Paths,[int]$OlderThanDays = 7)
  $cutoff = (Get-Date).AddDays(-1 * $OlderThanDays)
  $deleted = 0; $skInUse = 0; $skDenied = 0; $bytesFreed = 0; $errors = @()
  foreach ($p in $Paths) {
    if (-not (Test-Path -LiteralPath $p)) { continue }
    $items = Get-ChildItem -LiteralPath $p -Force -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer -and $_.LastWriteTime -le $cutoff }
    foreach ($i in $items) {
      try {
        $len = [int64]$i.Length
        Remove-Item -LiteralPath $i.FullName -Force -ErrorAction Stop
        $deleted++; $bytesFreed += $len
      } catch {
        $msg = $_.Exception.Message
        if ($msg -match 'being used') { $skInUse++ }
        elseif ($msg -match 'denied') { $skDenied++ }
        else { $errors += $msg }
      }
    }
  }
  return [pscustomobject]@{ BytesFreed=[int64]$bytesFreed; DeletedCount=[int]$deleted; SkippedInUse=[int]$skInUse; SkippedDenied=[int]$skDenied; Archived=$false; Errors=$errors }
}

function Get-FirewallCoreOptimizerActionCatalog {
  param([Parameter(Mandatory)][ValidateSet('Home','Gaming','Lab')][string]$Profile)

  $actions = @()

  $actions += [pscustomobject]@{
    ActionId='OPT.STORAGE.TEMP.USER'; DisplayName='User Temp Files'; Module='Optimizer'; TileGroup='SystemJunk'; Risk='Low'; Mode='AnalyzeApply';
    RequiresAdmin=$false; RequiresMaintenanceMode=$false; RequiresDevLab=$false; ProfileVisibility=@('Home','Gaming','Lab');
    Notes='Deletes files older than 7 days under %LOCALAPPDATA%\\Temp.';
    AnalyzeScript={ param([string]$RunRoot) Get-FileInventory -Paths @(Join-Path $env:LOCALAPPDATA 'Temp') -OlderThanDays 7 };
    ApplyScript={ param([string]$RunRoot) Remove-InventoryItems -Paths @(Join-Path $env:LOCALAPPDATA 'Temp') -OlderThanDays 7 }
  }

  $actions += [pscustomobject]@{
    ActionId='OPT.STORAGE.TEMP.SYSTEM'; DisplayName='System Temp Files'; Module='Optimizer'; TileGroup='SystemJunk'; Risk='Low'; Mode='AnalyzeApply';
    RequiresAdmin=$true; RequiresMaintenanceMode=$true; RequiresDevLab=$false; ProfileVisibility=@('Home','Gaming','Lab');
    Notes='Deletes files older than 14 days under C:\\Windows\\Temp.';
    AnalyzeScript={ param([string]$RunRoot) Get-FileInventory -Paths @('C:\\Windows\\Temp') -OlderThanDays 14 };
    ApplyScript={ param([string]$RunRoot) Remove-InventoryItems -Paths @('C:\\Windows\\Temp') -OlderThanDays 14 }
  }

  $actions += [pscustomobject]@{
    ActionId='OPT.STORAGE.WER.QUEUES'; DisplayName='Windows Error Reporting Queues'; Module='Optimizer'; TileGroup='SystemJunk'; Risk='Low'; Mode='AnalyzeApply';
    RequiresAdmin=$true; RequiresMaintenanceMode=$true; RequiresDevLab=$false; ProfileVisibility=@('Home','Gaming','Lab');
    Notes='Cleans ProgramData WER queues older than 30 days.';
    AnalyzeScript={ param([string]$RunRoot) Get-FileInventory -Paths @('C:\\ProgramData\\Microsoft\\Windows\\WER\\ReportQueue','C:\\ProgramData\\Microsoft\\Windows\\WER\\ReportArchive') -OlderThanDays 30 };
    ApplyScript={ param([string]$RunRoot) Remove-InventoryItems -Paths @('C:\\ProgramData\\Microsoft\\Windows\\WER\\ReportQueue','C:\\ProgramData\\Microsoft\\Windows\\WER\\ReportArchive') -OlderThanDays 30 }
  }

  $actions += [pscustomobject]@{
    ActionId='OPT.STORAGE.RECYCLEBIN'; DisplayName='Recycle Bin'; Module='Optimizer'; TileGroup='RecycleBin'; Risk='Low'; Mode='AnalyzeApply';
    RequiresAdmin=$false; RequiresMaintenanceMode=$false; RequiresDevLab=$false; ProfileVisibility=@('Home','Gaming','Lab');
    Notes='Empties Recycle Bin.';
    AnalyzeScript={
      param([string]$RunRoot)
      $bytes=0; $count=0
      try {
        $rb = Get-ChildItem -LiteralPath 'C:\\$Recycle.Bin' -Force -Recurse -ErrorAction SilentlyContinue
        foreach ($i in $rb) { if (-not $i.PSIsContainer) { $count++; try { $bytes += [int64]$i.Length } catch { } } }
      } catch { }
      [pscustomobject]@{ BytesFound=[int64]$bytes; ItemCount=[int]$count; Sample=@() }
    };
    ApplyScript={
      param([string]$RunRoot)
      $before=0
      try {
        $rb = Get-ChildItem -LiteralPath 'C:\\$Recycle.Bin' -Force -Recurse -ErrorAction SilentlyContinue
        foreach ($i in $rb) { if (-not $i.PSIsContainer) { try { $before += [int64]$i.Length } catch { } } }
      } catch { }
      try {
        if (Get-Command Clear-RecycleBin -ErrorAction SilentlyContinue) { Clear-RecycleBin -Force -ErrorAction Stop | Out-Null }
      } catch { }
      [pscustomobject]@{ BytesFreed=[int64]$before; DeletedCount=0; SkippedInUse=0; SkippedDenied=0; Archived=$false; Errors=@() }
    }
  }

  return $actions
}

Export-ModuleMember -Function Get-FirewallCoreOptimizerActionCatalog
