[CmdletBinding()]
param(
  [ValidateSet('All','Info','Warning','Critical')]
  [string]$Severity = 'All',

  [int]$EventId = 0,

  [int]$SinceMinutes = 240,

  [string]$TestId = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogName      = 'FirewallCore'
$CoreRoot     = Join-Path $env:ProgramData 'FirewallCore'
$CoreViewsDir = Join-Path $CoreRoot 'User\Views'
$EvViewsDir   = Join-Path $env:ProgramData 'Microsoft\Event Viewer\Views'

New-Item -ItemType Directory -Force -Path $CoreViewsDir | Out-Null
New-Item -ItemType Directory -Force -Path $EvViewsDir   | Out-Null

function New-QueryListXml {
  param(
    [Parameter(Mandatory)][string]$Log,
    [Parameter(Mandatory)][string]$Select,
    [Parameter(Mandatory)][string]$OutPath
  )

  $xml = @"
<QueryList>
  <Query Id="0" Path="$Log">
    <Select Path="$Log">$Select</Select>
  </Query>
</QueryList>
"@

  Set-Content -LiteralPath $OutPath -Value $xml -Encoding UTF8 -Force
}

$ms = [int64]$SinceMinutes * 60 * 1000
$timeFilter = "TimeCreated[timediff(@SystemTime) <= $ms]"

# Deterministic selection:
# - If EventId provided: exact match.
# - Else: severity ranges (Info=3000-3999, Warning=4000-4999, Critical=9000-9999).
if ($EventId -gt 0) {
  $select = "*[System[(EventID=$EventId) and $timeFilter]]"
  $name   = "FirewallCore-EventId-$EventId"
} else {
  switch ($Severity) {
    'Info'     { $select = "*[System[(EventID &gt;= 3000) and (EventID &lt;= 3999) and $timeFilter]]"; $name='FirewallCore-Info' }
    'Warning'  { $select = "*[System[(EventID &gt;= 4000) and (EventID &lt;= 4999) and $timeFilter]]"; $name='FirewallCore-Warning' }
    'Critical' { $select = "*[System[(EventID &gt;= 9000) and (EventID &lt;= 9999) and $timeFilter]]"; $name='FirewallCore-Critical' }
    default    { $select = "*[System[$timeFilter]]"; $name='FirewallCore-All' }
  }
}

$coreView = Join-Path $CoreViewsDir ("{0}.xml" -f $name)
$evView   = Join-Path $EvViewsDir   ("{0}.xml" -f $name)

New-QueryListXml -Log $LogName -Select $select -OutPath $coreView
Copy-Item -LiteralPath $coreView -Destination $evView -Force

$eventvwr = Join-Path $env:SystemRoot 'System32\eventvwr.msc'

try {
  Start-Process -FilePath $eventvwr -ArgumentList ("/v:`"$coreView`"") | Out-Null
  return
} catch {
  try {
    Start-Process -FilePath $eventvwr -ArgumentList "`"$coreView`"" | Out-Null
    return
  } catch {
    Start-Process -FilePath $eventvwr -ArgumentList "/c:$LogName" | Out-Null
    return
  }
}