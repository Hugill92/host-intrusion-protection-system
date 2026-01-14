[CmdletBinding()]
param(
  [ValidateSet("Install","OverlayOnly")]
  [string]$Mode = "Install",

  [string]$VmName = $env:COMPUTERNAME,

  [switch]$NoTag,
  [switch]$NoOverlay,
  [switch]$WhatIfOverlay
)

$ErrorActionPreference = "Stop"

function Fail([string]$m) { Write-Host $m -ForegroundColor Red; exit 2 }
function Ok([string]$m)   { Write-Host $m -ForegroundColor Green }
function Info([string]$m) { Write-Host $m -ForegroundColor Cyan }
function Warn([string]$m) { Write-Host $m -ForegroundColor Yellow }

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$Tools = Join-Path $RepoRoot "Tools"
$LifecycleRoot = Join-Path $env:ProgramData "FirewallCore\LifecycleExports"
$LogDir = Join-Path $env:ProgramData "FirewallCore\Logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$PipelineLog = Join-Path $LogDir "Install-Pipeline.log"

function LogLine([string]$s) {
  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Add-Content -LiteralPath $PipelineLog -Encoding UTF8 -Value ("[" + $stamp + "] " + $s)
}

function Require([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { Fail ("Missing required file: " + $p) }
}

function Resolve-Bundle([string]$label) {
  New-Item -ItemType Directory -Path $LifecycleRoot -Force | Out-Null
  $match = "BUNDLE_" + $label + "*"
  $b = Get-ChildItem -LiteralPath $LifecycleRoot -Directory |
    Where-Object { $_.Name -like $match } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (-not $b) { Fail ("Bundle not found for label: " + $label) }
  $b
}

$bundleScript = Join-Path $Tools "New-FirewallBundle.ps1"
$tagScript    = Join-Path $Tools "Tag-FirewallCoreRules.ps1"
$overlayScript = Join-Path $Tools "Invoke-V2OverlayHardening.ps1"
$auditScript  = Join-Path $Tools "Audit-OverlayChange.ps1"
$noRegress    = Join-Path $Tools "Test-PolicyNoRegression.ps1"
$notesScript  = Join-Path $Tools "Update-Sprint3Notes-V2Overlay.ps1"

Require $bundleScript
Require $overlayScript
Require $auditScript
Require $noRegress
Require $notesScript
if (-not $NoTag) { Require $tagScript }

$coreCmd = Join-Path $RepoRoot "install.core.cmd"
$installCmd = Join-Path $RepoRoot "install.cmd"

if (Test-Path -LiteralPath $coreCmd) {
  $CoreInstaller = $coreCmd
} elseif (Test-Path -LiteralPath $installCmd) {
  $CoreInstaller = $installCmd
} else {
  Fail ("Missing core installer: install.core.cmd or install.cmd in " + $RepoRoot)
}

$runTs = Get-Date -Format "yyyyMMdd_HHmmss"
$preInstallLabel = "PRE_INSTALL_" + $VmName + "_" + $runTs
$postPolicyLabel = "POST_POLICY_" + $VmName + "_" + $runTs
$preOverlayLabel = "PRE_V2_OVERLAY_" + $VmName + "_" + $runTs
$postOverlayLabel= "POST_V2_OVERLAY_" + $VmName + "_" + $runTs
$postInstallLabel= "POST_INSTALL_" + $VmName + "_" + $runTs

Info ("Mode: " + $Mode + " | VM: " + $VmName)
LogLine ("START Mode=" + $Mode + " VM=" + $VmName)

function NewBundle([string]$label) {
  Info ("Bundle: " + $label)
  LogLine ("BUNDLE " + $label)
  & $bundleScript -Label $label | Out-Null
  (Resolve-Bundle $label).FullName
}

if ($Mode -eq "Install") {

  $preInstallPath = NewBundle $preInstallLabel

  Info ("Running core install: " + $CoreInstaller)
  LogLine ("RUN core installer: " + $CoreInstaller)
  & cmd.exe /c ('"' + $CoreInstaller + '"')
  $exit = $LASTEXITCODE

  if ($exit -ne 0) {
    Warn ("Core install returned exit code: " + $exit)
    LogLine ("FAIL core install exit=" + $exit)

    $postFail = NewBundle ("POST_INSTALL_FAIL_" + $VmName + "_" + $runTs)
    Warn ("Captured failure POST bundle: " + $postFail)
    Fail ("Install failed (exit " + $exit + "). POST bundle captured for forensics.")
  }

  Ok "Core install completed successfully."
  $postPolicyPath = NewBundle $postPolicyLabel

  if (-not $NoTag) {
    Info "Tagging ownership..."
    LogLine ("TAG PreLabel=" + $preInstallLabel + " PostLabel=" + $postPolicyLabel)
    & $tagScript -PreLabel $preInstallLabel -PostLabel $postPolicyLabel -V1GroupTag "FirewallCorev1" -V2GroupTag "FirewallCorev2"
    Ok "Tagging complete."
  } else {
    Warn "Skipping tagging (NoTag)."
  }

  if (-not $NoOverlay) {
    Info "Running V2 overlay + gates..."
    $preOverlayPath = NewBundle $preOverlayLabel

    if ($WhatIfOverlay) {
      & $overlayScript -WhatIf
      Warn "Overlay ran in WHATIF mode; skipping gates."
    } else {
      & $overlayScript
      $postOverlayPath = NewBundle $postOverlayLabel

      $preJson  = Join-Path $preOverlayPath  "FirewallRules.json"
      $postJson = Join-Path $postOverlayPath "FirewallRules.json"
      & $noRegress -PreJson $preJson -PostJson $postJson -FailOnRemovals
      & $auditScript -PreBundle $preOverlayPath -PostBundle $postOverlayPath -FailOnRemovals -VerifyHashes

      $auditMd = Get-ChildItem -LiteralPath $postOverlayPath -File -Filter "AUDIT_OverlayChange_*.md" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

      if ($auditMd) {
        & $notesScript -PreBundle $preOverlayPath -PostBundle $postOverlayPath -AuditPath $auditMd.FullName -VmName $VmName
      } else {
        Warn "Audit markdown not found in POST overlay bundle (gates still ran)."
      }

      Ok "Overlay + gates PASS."
    }
  } else {
    Warn "Skipping overlay (NoOverlay)."
  }

  $postInstallPath = NewBundle $postInstallLabel
  Ok ("Install pipeline complete. Final bundle: " + $postInstallPath)
  LogLine ("DONE FinalBundle=" + $postInstallPath)
  exit 0
}

if ($Mode -eq "OverlayOnly") {
  if ($NoOverlay) { Fail "OverlayOnly mode cannot be used with -NoOverlay." }

  $preOverlayPath = NewBundle $preOverlayLabel

  if ($WhatIfOverlay) {
    & $overlayScript -WhatIf
    Warn "Overlay WHATIF complete; no gates run."
    exit 0
  }

  & $overlayScript
  $postOverlayPath = NewBundle $postOverlayLabel

  $preJson  = Join-Path $preOverlayPath  "FirewallRules.json"
  $postJson = Join-Path $postOverlayPath "FirewallRules.json"
  & $noRegress -PreJson $preJson -PostJson $postJson -FailOnRemovals
  & $auditScript -PreBundle $preOverlayPath -PostBundle $postOverlayPath -FailOnRemovals -VerifyHashes

  $auditMd = Get-ChildItem -LiteralPath $postOverlayPath -File -Filter "AUDIT_OverlayChange_*.md" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

  if ($auditMd) {
    & $notesScript -PreBundle $preOverlayPath -PostBundle $postOverlayPath -AuditPath $auditMd.FullName -VmName $VmName
  }

  Ok "OverlayOnly pipeline complete (PASS)."
  exit 0
}

Fail ("Unknown Mode: " + $Mode)
