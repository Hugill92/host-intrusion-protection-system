param(
  [switch]$OptionalReset,
  [switch]$PinProtectMgmtKey = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-Exe {
  param([Parameter(Mandatory)][string]$Name)
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  throw "Missing executable in PATH: $Name"
}

$ykman = Resolve-Exe -Name 'ykman'

Write-Host ''
Write-Host '=== PIV Prep (interactive) ==='
Write-Host 'Enter your chosen PIN/PUK at prompts. (Not printed.)'
Write-Host ''

if ($OptionalReset) {
  Write-Host '[STEP] Optional reset (ONLY if state is blocked/messy)'
  & $ykman piv reset
  if ($LASTEXITCODE -ne 0) { throw "ykman piv reset failed (exit=$LASTEXITCODE)" }
  Write-Host ''
}

Write-Host '[STEP] Change PIN'
& $ykman piv access change-pin
if ($LASTEXITCODE -ne 0) { throw "change-pin failed (exit=$LASTEXITCODE)" }

Write-Host ''
Write-Host '[STEP] Change PUK'
& $ykman piv access change-puk
if ($LASTEXITCODE -ne 0) { throw "change-puk failed (exit=$LASTEXITCODE)" }

if ($PinProtectMgmtKey) {
  Write-Host ''
  Write-Host '[STEP] Make Management Key PIN-protected (keep default; no hex)'
  Write-Host 'When asked for management key: press Enter to use default.'
  & $ykman piv access change-management-key --protect --touch
  if ($LASTEXITCODE -ne 0) { throw "change-management-key failed (exit=$LASTEXITCODE)" }
}

Write-Host ''
Write-Host '[VERIFY] ykman piv info'
& $ykman piv info
if ($LASTEXITCODE -ne 0) { throw "ykman piv info failed (exit=$LASTEXITCODE)" }

Write-Host ''
Write-Host '[OK] PIV prep complete.'
