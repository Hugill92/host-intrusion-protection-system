Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$path = "C:\FirewallInstaller\Firewall\Modules\Firewall-InstallerBaselines.psm1"
if (-not (Test-Path -LiteralPath $path)) { throw "Missing file: $path" }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item -LiteralPath $path -Destination ($path + ".bak_" + $ts) -Force

$src = Get-Content -LiteralPath $path -Raw

$fixedFunc = @'
function Resolve-FirewallCoreProgramDataRoot {
  [CmdletBinding()]
  param()

  # StrictMode-safe: never touch script-scope ProgramDataRoot variable unless it exists
  $sv = Get-Variable -Name ProgramDataRoot -Scope Script -ErrorAction SilentlyContinue
  if ($sv -and -not [string]::IsNullOrWhiteSpace([string]$sv.Value)) {
    return [string]$sv.Value
  }

  $gv = Get-Variable -Name ProgramDataRoot -Scope Global -ErrorAction SilentlyContinue
  if ($gv -and -not [string]::IsNullOrWhiteSpace([string]$gv.Value)) {
    return [string]$gv.Value
  }

  return (Join-Path $env:ProgramData 'FirewallCore')
}
'@

# Replace existing Resolve-FirewallCoreProgramDataRoot definition (entire function block)
$pattern = "(?ms)function\s+Resolve-FirewallCoreProgramDataRoot\s*\{.*?\r?\n\}"
$patched = [regex]::Replace($src, $pattern, $fixedFunc, 1)

if ($patched -eq $src) {
}

Set-Content -LiteralPath $path -Value $patched -Encoding UTF8

# Parse gate (must be 0 errors)
$tok = $null; $err = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tok, [ref]$err)
if ($err.Count -gt 0) {
  Write-Host "[PARSE FAIL] $path" -ForegroundColor Red
  $err | ForEach-Object {
    $_.Message
    $_.Extent | Format-List StartLineNumber,StartColumnNumber,EndLineNumber,EndColumnNumber,Text
  }
  throw "Parse failed; see details above."
}

Write-Host "[FIX OK] Resolve-FirewallCoreProgramDataRoot is now StrictMode-safe." -ForegroundColor Green
Write-Host "Reminder: re-sign this module before AllSigned testing." -ForegroundColor Yellow


function Get-FirewallCoreSha256Hex {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$LiteralPath)

  if (Get-Command -Name Get-FileHash -ErrorAction SilentlyContinue) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $LiteralPath).Hash.ToLowerInvariant()
  }

  # Fallback: pure .NET (PS3+ safe)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $fs = [System.IO.File]::OpenRead($LiteralPath)
    try { $hashBytes = $sha.ComputeHash($fs) } finally { $fs.Dispose() }
  } finally { $sha.Dispose() }

  return ([BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
}
function Import-InstallerBaselineModule {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$InstallerRoot
  )

  $mod = Join-Path $InstallerRoot 'Tools\Modules\FirewallBaseline.psm1'
  if (-not (Test-Path -LiteralPath $mod)) {
    throw "Missing required baseline module: $mod"
  }

  Import-Module -Name $mod -Force -ErrorAction Stop
}

function Resolve-FirewallCoreProgramDataRoot {
  [CmdletBinding()]
  param()

  # StrictMode-safe: never touch script-scope ProgramDataRoot variable unless it exists
  $sv = Get-Variable -Name ProgramDataRoot -Scope Script -ErrorAction SilentlyContinue
  if ($sv -and -not [string]::IsNullOrWhiteSpace([string]$sv.Value)) {
    return [string]$sv.Value
  }

  $gv = Get-Variable -Name ProgramDataRoot -Scope Global -ErrorAction SilentlyContinue
  if ($gv -and -not [string]::IsNullOrWhiteSpace([string]$gv.Value)) {
    return [string]$gv.Value
  }

  return (Join-Path $env:ProgramData 'FirewallCore')
}



function Resolve-FirewallCorePolicySource {
  [CmdletBinding()]
  param(
    [Parameter()][string]$InstallerRoot
  )

  $root = $null

  if ($InstallerRoot) {
    try { $root = (Resolve-Path -LiteralPath $InstallerRoot).Path }
    catch { $root = $InstallerRoot }
  }

  if (-not $root) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..\..")).Path
  }

  $policyDir1 = Join-Path $root "Firewall\Policy"
  $policyDir2 = Join-Path $root "Policies"

  $candidates = @(
    (Join-Path $policyDir1 "FirewallCorePolicy_v1.wfw"),
    (Join-Path $policyDir1 "FirewallCorePolicy.wfw"),
    (Join-Path $policyDir2 "FirewallCorePolicy_v1.wfw"),
    (Join-Path $policyDir2 "FirewallCorePolicy.wfw"),
    (Join-Path $root "FirewallCorePolicy_v1.wfw"),
    (Join-Path $root "FirewallCorePolicy.wfw")
  ) | ForEach-Object { ($_ -as [string]).Trim() } | Where-Object { $_ }

  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) {
      return $c
    }
  }

  $expected = ($candidates | ForEach-Object { "  - $_" }) -join [Environment]::NewLine
  throw ("Missing FirewallCore policy file. Expected one of:" + [Environment]::NewLine + $expected)
}


function Export-NetshFirewallBaselineBundle {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$BaselineRoot,

    [Parameter(Mandatory)]
    [ValidateSet('PRE_INSTALL','POST_INSTALL')]
    [string]$Type,

    [Parameter(Mandatory)]
    [string]$Stamp,

    [string]$FileBaseName = $null,

    [string]$Mode = ''
  )

  if (-not $FileBaseName) {
    $FileBaseName = if ($Type -eq 'PRE_INSTALL') { 'Firewall_PRE.wfw' } else { 'Firewall_POST.wfw' }
  }

  New-Item -ItemType Directory -Path $BaselineRoot -Force | Out-Null

  $dir = Join-Path $BaselineRoot ("{0}_{1}" -f $Type, $Stamp)
  New-Item -ItemType Directory -Path $dir -Force | Out-Null

  $wfw = Join-Path $dir $FileBaseName
  & netsh.exe advfirewall export $wfw | Out-Null

  # Legacy (backward-compatible) hash evidence
  $legacySha = $wfw + '.sha256'
  $h = Get-FirewallCoreSha256Hex -LiteralPath $wfw
("{0} *{1}" -f $h, (Split-Path -Leaf $wfw)) |
    Out-File -LiteralPath $legacySha -Encoding ascii

  # ------------------------------------------------------------
  # JSON INVENTORY (deterministic rule + filter snapshot)
  # ------------------------------------------------------------
  $jsonName = if ($Type -eq 'PRE_INSTALL') { 'Firewall_PRE.rules.json' } else { 'Firewall_POST.rules.json' }
  $json = Join-Path $dir $jsonName

  $items = @()
  try {
    $rules = Get-NetFirewallRule -ErrorAction Stop | Sort-Object -Property Name
    foreach ($r in $rules) {

      $app  = $null
      $port = $null
      $addr = $null
      $svc  = $null
      $it   = $null
      $sec  = $null

      try { $app  = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $r -ErrorAction Stop } catch { }
      try { $port = Get-NetFirewallPortFilter        -AssociatedNetFirewallRule $r -ErrorAction Stop } catch { }
      try { $addr = Get-NetFirewallAddressFilter     -AssociatedNetFirewallRule $r -ErrorAction Stop } catch { }
      try { $svc  = Get-NetFirewallServiceFilter     -AssociatedNetFirewallRule $r -ErrorAction Stop } catch { }
      try { $it   = Get-NetFirewallInterfaceTypeFilter -AssociatedNetFirewallRule $r -ErrorAction Stop } catch { }
      try { $sec  = Get-NetFirewallSecurityFilter    -AssociatedNetFirewallRule $r -ErrorAction Stop } catch { }

      $items += [pscustomobject]@{
        Name        = $r.Name
        DisplayName = $r.DisplayName
        Group       = $r.Group
        Enabled     = $r.Enabled.ToString()
        Profile     = $r.Profile.ToString()
        Direction   = $r.Direction.ToString()
        Action      = $r.Action.ToString()

        # Common rule toggles
        EdgeTraversalPolicy = $r.EdgeTraversalPolicy.ToString()
        InterfaceAlias      = $r.InterfaceAlias
        InterfaceType       = if ($it) { $it.InterfaceType.ToString() } else { $null }

        # Filters
        Program     = if ($app)  { $app.Program } else { $null }
        Package     = if ($app)  { $app.Package } else { $null }
        Service     = if ($svc)  { $svc.Service } else { $null }

        Protocol    = if ($port) { $port.Protocol.ToString() } else { $null }
        LocalPort   = if ($port) { $port.LocalPort } else { $null }
        RemotePort  = if ($port) { $port.RemotePort } else { $null }
        IcmpType    = if ($port) { $port.IcmpType } else { $null }
        IcmpCode    = if ($port) { $port.IcmpCode } else { $null }

        LocalAddress  = if ($addr) { $addr.LocalAddress } else { $null }
        RemoteAddress = if ($addr) { $addr.RemoteAddress } else { $null }

        # Policy metadata
        PolicyStoreSource       = $r.PolicyStoreSource
        PolicyStoreSourceType   = $r.PolicyStoreSourceType.ToString()

        # Security filter (where available)
        Authentication = if ($sec) { $sec.Authentication.ToString() } else { $null }
        Encryption     = if ($sec) { $sec.Encryption.ToString() } else { $null }
      }
    }
  } catch {
    # If cmdlets unavailable (rare), still emit a file to keep bundle structure consistent
    $items = @([pscustomobject]@{ Error = $_.Exception.Message })
  }

  $payload = [pscustomobject]@{
    Type  = $Type
    Mode  = $Mode
    Stamp = $Stamp
    CapturedLocal = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
    TimeZone = [TimeZoneInfo]::Local.StandardName
    RuleCount = $items.Count
    Rules = $items
  }

  $payload | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $json -Encoding UTF8

  $jsonSha = $json + '.sha256'
  $jh = Get-FirewallCoreSha256Hex -LiteralPath $json
  ("{0} *{1}" -f $jh, (Split-Path -Leaf $json)) | Out-File -LiteralPath $jsonSha -Encoding ascii

  # ------------------------------------------------------------
  # JSON INVENTORY (deterministic rule + filter snapshot)
  # ------------------------------------------------------------
  $jsonName = if ($Type -eq 'PRE_INSTALL') { 'Firewall_PRE.rules.json' } else { 'Firewall_POST.rules.json' }
  $json = Join-Path $dir $jsonName

  $items = @()
  try {
    $rules = Get-NetFirewallRule -ErrorAction Stop | Sort-Object -Property Name
    foreach ($r in $rules) {

      $app  = $null
      $port = $null
      $addr = $null
      $svc  = $null
      $it   = $null
      $sec  = $null

      try { $app  = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $r -ErrorAction Stop } catch { }
      try { $port = Get-NetFirewallPortFilter        -AssociatedNetFirewallRule $r -ErrorAction Stop } catch { }
      try { $addr = Get-NetFirewallAddressFilter     -AssociatedNetFirewallRule $r -ErrorAction Stop } catch { }
      try { $svc  = Get-NetFirewallServiceFilter     -AssociatedNetFirewallRule $r -ErrorAction Stop } catch { }
      try { $it   = Get-NetFirewallInterfaceTypeFilter -AssociatedNetFirewallRule $r -ErrorAction Stop } catch { }
      try { $sec  = Get-NetFirewallSecurityFilter    -AssociatedNetFirewallRule $r -ErrorAction Stop } catch { }

      $items += [pscustomobject]@{
        Name        = $r.Name
        DisplayName = $r.DisplayName
        Group       = $r.Group
        Enabled     = $r.Enabled.ToString()
        Profile     = $r.Profile.ToString()
        Direction   = $r.Direction.ToString()
        Action      = $r.Action.ToString()

        # Common rule toggles
        EdgeTraversalPolicy = $r.EdgeTraversalPolicy.ToString()
        InterfaceAlias      = $r.InterfaceAlias
        InterfaceType       = if ($it) { $it.InterfaceType.ToString() } else { $null }

        # Filters
        Program     = if ($app)  { $app.Program } else { $null }
        Package     = if ($app)  { $app.Package } else { $null }
        Service     = if ($svc)  { $svc.Service } else { $null }

        Protocol    = if ($port) { $port.Protocol.ToString() } else { $null }
        LocalPort   = if ($port) { $port.LocalPort } else { $null }
        RemotePort  = if ($port) { $port.RemotePort } else { $null }
        IcmpType    = if ($port) { $port.IcmpType } else { $null }
        IcmpCode    = if ($port) { $port.IcmpCode } else { $null }

        LocalAddress  = if ($addr) { $addr.LocalAddress } else { $null }
        RemoteAddress = if ($addr) { $addr.RemoteAddress } else { $null }

        # Policy metadata
        PolicyStoreSource       = $r.PolicyStoreSource
        PolicyStoreSourceType   = $r.PolicyStoreSourceType.ToString()

        # Security filter (where available)
        Authentication = if ($sec) { $sec.Authentication.ToString() } else { $null }
        Encryption     = if ($sec) { $sec.Encryption.ToString() } else { $null }
      }
    }
  } catch {
    # If cmdlets unavailable (rare), still emit a file to keep bundle structure consistent
    $items = @([pscustomobject]@{ Error = $_.Exception.Message })
  }

  $payload = [pscustomobject]@{
    Type  = $Type
    Mode  = $Mode
    Stamp = $Stamp
    CapturedLocal = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
    TimeZone = [TimeZoneInfo]::Local.StandardName
    RuleCount = $items.Count
    Rules = $items
  }

  $payload | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $json -Encoding UTF8

  $jsonSha = $json + '.sha256'
  $jh = Get-FirewallCoreSha256Hex -LiteralPath $json
  ("{0} *{1}" -f $jh, (Split-Path -Leaf $json)) | Out-File -LiteralPath $jsonSha -Encoding ascii


  $manifestPath = $null
  $sumsPath = $null
  $verifyOk = $false

  try {
    $relFiles = @(
      (Split-Path -Leaf $wfw),
      (Split-Path -Leaf $legacySha),
      (Split-Path -Leaf $json),
      (Split-Path -Leaf $jsonSha)
    )

    $sumsPath = Write-FwBaselineSha256Sums -Root $dir -Files $relFiles -OutFile (Join-Path $dir 'SHA256SUMS.txt')
    $manifestPath = Write-FwBaselineManifest -Root $dir -Files $relFiles -Meta @{
      BundleId     = $Stamp
      Type         = $Type
      Mode         = $Mode
      ComputerName = $env:COMPUTERNAME
      UserName     = $env:USERNAME
      BuiltAtUtc   = (Get-Date).ToUniversalTime().ToString('o')
    } -OutFile (Join-Path $dir 'BaselineManifest.json')

    $v = Test-FwBaselineManifest -ManifestPath $manifestPath
    $verifyOk = [bool]$v.Valid
  } catch {
    # Best-effort: legacy artifacts remain authoritative if manifest generation fails.
    $verifyOk = $false
  }

  return [pscustomobject]@{
    Type         = $Type
    Stamp        = $Stamp
    Dir          = $dir
    WfwPath      = $wfw
    LegacySha256 = $legacySha
    JsonPath     = $json
    JsonLegacySha256 = $jsonSha
    Sha256Sums   = $sumsPath
    Manifest     = $manifestPath
    ManifestOk   = $verifyOk
  }
}

function Invoke-FirewallCorePolicyApplyWithBaselines {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$InstallerRoot,

    [string]$ProgramDataRoot,

    [Parameter(Mandatory)]
    [string]$Stamp,

    [string]$Mode = ''
  )

  # Resolve ProgramData root deterministically if caller did not provide it
  if (-not $PSBoundParameters.ContainsKey('ProgramDataRoot') -or [string]::IsNullOrWhiteSpace($ProgramDataRoot)) {
    $ProgramDataRoot = Resolve-FirewallCoreProgramDataRoot
  }

  Import-InstallerBaselineModule -InstallerRoot $InstallerRoot

  $policySrc = Resolve-FirewallCorePolicySource -InstallerRoot $InstallerRoot

  $policyDir = Join-Path $ProgramDataRoot 'Policy'
  $policyDst = Join-Path $policyDir 'FirewallCorePolicy.wfw'
  $baselineRoot = Join-Path $ProgramDataRoot 'Baselines'

  New-Item -ItemType Directory -Path $policyDir -Force | Out-Null
  New-Item -ItemType Directory -Path $baselineRoot -Force | Out-Null

  Copy-Item -LiteralPath $policySrc -Destination $policyDst -Force

  # Safety gate: refuse tiny/empty policy
  if ((Get-Item -LiteralPath $policyDst).Length -lt 10240) {
    throw "Policy file too small - refusing to apply. Path: $policyDst"
  }

  $pre = Export-NetshFirewallBaselineBundle -BaselineRoot $baselineRoot -Type PRE_INSTALL -Stamp $Stamp -Mode $Mode

  & netsh.exe advfirewall import $policyDst | Out-Null

  $post = Export-NetshFirewallBaselineBundle -BaselineRoot $baselineRoot -Type POST_INSTALL -Stamp $Stamp -Mode $Mode

  return [pscustomobject]@{
    PolicySrc    = $policySrc
    PolicyDst    = $policyDst
    BaselineRoot = $baselineRoot
    Pre          = $pre
    Post         = $post
  }
}


Export-ModuleMember -Function Invoke-FirewallCorePolicyApplyWithBaselines


