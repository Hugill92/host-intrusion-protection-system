#requires -Version 5.1
param(
  [switch]$Apply,   # default is preview-only
  [switch]$Force    # allow overwrite if target exists
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "`n=== FirewallCore V2: Auto-place skeleton files (Preview-first) ===" -ForegroundColor Cyan

$repoRoot = (Get-Location).Path

# --- Target directories ---
$targets = [ordered]@{
  # Modules
  'FirewallCore-ActionRegistry.psm1' = 'Firewall\Modules\V2\ActionRegistry\FirewallCore-ActionRegistry.psm1'
  'FirewallCore-Optimizer.psm1'      = 'Firewall\Modules\V2\Optimizer\FirewallCore-Optimizer.psm1'
  'FirewallCore-Telemetry.psm1'      = 'Firewall\Modules\V2\Telemetry\FirewallCore-Telemetry.psm1'
  'FirewallCore-Maintenance.psm1'    = 'Firewall\Modules\V2\Maintenance\FirewallCore-Maintenance.psm1'

  # Tools
  'FirewallCore-V2Shared.psm1'       = 'Tools\V2\_shared\FirewallCore-V2Shared.psm1'
  'Invoke-FirewallCoreOptimizer.ps1' = 'Tools\V2\Optimizer\Invoke-FirewallCoreOptimizer.ps1'
  'Invoke-FirewallCoreTelemetry.ps1' = 'Tools\V2\Telemetry\Invoke-FirewallCoreTelemetry.ps1'
  'Invoke-FirewallCoreMaintenance.ps1'= 'Tools\V2\Maintenance\Invoke-FirewallCoreMaintenance.ps1'

  # Docs (optional, if present)
  'README_SKELETON.md'               = 'Docs\DEV\V2\README_SKELETON.md'
  'QUICKSTART.md'                    = 'Docs\DEV\V2\QUICKSTART.md'
}

# ThirdParty folder (Admin Toolkit)
$thirdPartyName = 'AdminToolkit_v2'
$thirdPartyDst  = Join-Path $repoRoot "ThirdParty\$thirdPartyName"

# --- Create folder structure ---
$foldersToEnsure = @(
  'Firewall\Modules\V2\ActionRegistry',
  'Firewall\Modules\V2\Optimizer',
  'Firewall\Modules\V2\Telemetry',
  'Firewall\Modules\V2\Maintenance',
  'Tools\V2\_shared',
  'Tools\V2\Optimizer',
  'Tools\V2\Telemetry',
  'Tools\V2\Maintenance',
  'Docs\DEV\V2',
  'ThirdParty',
  'Docs\_local\Moves'
)

foreach ($rel in $foldersToEnsure) {
  $full = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $full)) {
    if ($Apply) {
      New-Item -ItemType Directory -Path $full -Force | Out-Null
      Write-Host "Created: $rel"
    } else {
      Write-Host "[PREVIEW] Would create: $rel"
    }
  }
}

# --- Logging ---
$logDir = Join-Path $repoRoot 'Docs\_local\Moves'
$logPath = Join-Path $logDir ("v2_place_files_{0}.log" -f (Get-Date).ToString('yyyyMMdd_HHmmss'))
if ($Apply) {
  "Time: $(Get-Date -Format s)`nRepoRoot: $repoRoot`nApply: $Apply`nForce: $Force`n" | Set-Content -LiteralPath $logPath -Encoding UTF8
}
function Write-LogLine { param([string]$Line) if ($Apply) { Add-Content -LiteralPath $logPath -Value $Line -Encoding UTF8 } }

function Find-Candidates {
  param([Parameter(Mandatory)][string]$Name)
  Get-ChildItem -LiteralPath $repoRoot -Recurse -Force -File -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -ieq $Name -and
      $_.FullName -notmatch '\\\.git\\' -and
      $_.FullName -notmatch '\\bin\\|\\obj\\|\\node_modules\\' -and
      $_.FullName -notmatch '\\Docs\\_local\\'
    }
}

function Choose-BestCandidate {
  param(
    [Parameter(Mandatory)][System.IO.FileInfo[]]$Candidates,
    [Parameter(Mandatory)][string]$Name
  )

  # Prefer canonical lanes if duplicates exist
  $prefs = @()
  switch ($Name.ToLowerInvariant()) {
    'firewallcore-telemetry.psm1' {
      $prefs = @(
        '\\Firewall\\Modules\\V2\\Telemetry\\',
        '\\Firewall\\Modules\\Telemetry\\',
        '\\Firewall\\Modules\\V2\\Detection\\',
        '\\Firewall\\Modules\\Detection\\'
      )
    }
    default {
      $prefs = @(
        '\\Firewall\\Modules\\V2\\',
        '\\Firewall\\Modules\\',
        '\\Tools\\V2\\'
      )
    }
  }

  foreach ($p in $prefs) {
    $hit = $Candidates | Where-Object { $_.FullName -match $p } | Select-Object -First 1
    if ($hit) { return $hit }
  }

  return ($Candidates | Select-Object -First 1)
}

function Move-One {
  param(
    [Parameter(Mandatory)][System.IO.FileInfo]$Source,
    [Parameter(Mandatory)][string]$DestFull
  )

  $destDir = Split-Path -Parent $DestFull
  if (-not (Test-Path -LiteralPath $destDir)) {
    if ($Apply) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    else { Write-Host "[PREVIEW] Would create dir: $destDir" }
  }

  if (Test-Path -LiteralPath $DestFull) {
    if (-not $Force) {
      Write-Host "SKIP (exists): $DestFull" -ForegroundColor Yellow
      Write-LogLine "SKIP EXISTS: $($Source.FullName) -> $DestFull"
      return
    }
    if ($Apply) { Remove-Item -LiteralPath $DestFull -Force }
    else { Write-Host "[PREVIEW] Would overwrite: $DestFull" -ForegroundColor Yellow }
  }

  if ($Apply) {
    Move-Item -LiteralPath $Source.FullName -Destination $DestFull -Force
    Write-Host "MOVED: $($Source.FullName) -> $DestFull" -ForegroundColor Green
    Write-LogLine "MOVED: $($Source.FullName) -> $DestFull"
  } else {
    Write-Host "[PREVIEW] Would move: $($Source.FullName) -> $DestFull"
  }
}

# --- Place the known files ---
$foundAny = $false

foreach ($name in $targets.Keys) {
  $relDest = $targets[$name]
  $destFull = Join-Path $repoRoot $relDest

  $candidates = @(Find-Candidates -Name $name)
  if ($candidates.Count -eq 0) {
    Write-Host "NOT FOUND: $name" -ForegroundColor DarkGray
    continue
  }

  $chosen = $candidates | Where-Object { $_.FullName -ieq $destFull } | Select-Object -First 1
  if (-not $chosen) { $chosen = Choose-BestCandidate -Candidates $candidates -Name $name }

  if ($candidates.Count -gt 1) {
    Write-Host "MULTIPLE FOUND for $name (choosing: $($chosen.FullName))" -ForegroundColor Yellow
    foreach ($c in $candidates) { Write-Host "  - $($c.FullName)" }
    if ($Apply) {
      Write-LogLine "MULTIPLE: $name"
      foreach ($c in $candidates) { Write-LogLine "  - $($c.FullName)" }
      Write-LogLine "CHOSEN: $($chosen.FullName)"
    }
  }

  $foundAny = $true

  if ($chosen.FullName -ieq $destFull) {
    Write-Host "OK (already placed): $relDest" -ForegroundColor Green
    continue
  }

  Move-One -Source $chosen -DestFull $destFull
}

# --- Place ThirdParty\AdminToolkit_v2 folder if present somewhere else ---
Write-Host "`n--- ThirdParty: AdminToolkit_v2 ---" -ForegroundColor Cyan
$toolkitCandidates = @(Get-ChildItem -LiteralPath $repoRoot -Recurse -Force -Directory -ErrorAction SilentlyContinue |
  Where-Object {
    $_.Name -ieq $thirdPartyName -and
    $_.FullName -notmatch '\\\.git\\' -and
    $_.FullName -notmatch '\\bin\\|\\obj\\|\\node_modules\\' -and
    $_.FullName -notmatch '\\Docs\\_local\\'
  }

if ($toolkitCandidates.Count -eq 0) {
  Write-Host "NOT FOUND: folder '$thirdPartyName' (skip)" -ForegroundColor DarkGray
} else {
  $chosenFolder = $toolkitCandidates | Where-Object { $_.FullName -match '\\ThirdParty\\AdminToolkit_v2$' } | Select-Object -First 1
  if (-not $chosenFolder) { $chosenFolder = $toolkitCandidates | Select-Object -First 1 }

  if ($toolkitCandidates.Count -gt 1) {
    Write-Host "MULTIPLE FOUND for folder '$thirdPartyName' (choosing: $($chosenFolder.FullName))" -ForegroundColor Yellow
    foreach ($c in $toolkitCandidates) { Write-Host "  - $($c.FullName)" }
  }

  if ($chosenFolder.FullName -ieq $thirdPartyDst) {
    Write-Host "OK (already placed): ThirdParty\AdminToolkit_v2" -ForegroundColor Green
  } else {
    if (Test-Path -LiteralPath $thirdPartyDst) {
      if (-not $Force) {
        Write-Host "SKIP (target exists): $thirdPartyDst (use -Force to replace)" -ForegroundColor Yellow
      } else {
        if ($Apply) {
          Remove-Item -LiteralPath $thirdPartyDst -Recurse -Force
          Move-Item -LiteralPath $chosenFolder.FullName -Destination $thirdPartyDst -Force
          Write-Host "MOVED: $($chosenFolder.FullName) -> $thirdPartyDst" -ForegroundColor Green
          Write-LogLine "MOVED FOLDER: $($chosenFolder.FullName) -> $thirdPartyDst"
        } else {
          Write-Host "[PREVIEW] Would replace+move: $($chosenFolder.FullName) -> $thirdPartyDst"
        }
      }
    } else {
      if ($Apply) {
        Move-Item -LiteralPath $chosenFolder.FullName -Destination $thirdPartyDst -Force
        Write-Host "MOVED: $($chosenFolder.FullName) -> $thirdPartyDst" -ForegroundColor Green
        Write-LogLine "MOVED FOLDER: $($chosenFolder.FullName) -> $thirdPartyDst"
      } else {
        Write-Host "[PREVIEW] Would move folder: $($chosenFolder.FullName) -> $thirdPartyDst"
      }
    }
  }
}

Write-Host "`n=== COMPLETE ===" -ForegroundColor Cyan
if (-not $foundAny) {
  Write-Host "Nothing matched the expected filenames. If you extracted the zip elsewhere, copy it into repo first, then rerun." -ForegroundColor Yellow
}
if ($Apply) {
  Write-Host "Move log: $logPath" -ForegroundColor Green
} else {
  Write-Host "Preview only. Re-run with -Apply to perform moves." -ForegroundColor Yellow
}

