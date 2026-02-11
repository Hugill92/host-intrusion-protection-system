#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\..\Tools\V2\_shared\FirewallCore-V2Shared.psm1') -Force

function Test-FirewallCoreMaintenanceMode {
  $flag = 'C:\ProgramData\FirewallCore\Config\MaintenanceMode.enabled'
  return (Test-Path -LiteralPath $flag)
}

function Assert-FirewallCoreGates {
  param(
    [Parameter(Mandatory)][pscustomobject]$Action,
    [Parameter(Mandatory)][ValidateSet('Analyze','Apply')][string]$Mode
  )

  if ($Action.RequiresAdmin -and -not (Test-FirewallCoreIsAdmin)) {
    throw "Action '$($Action.ActionId)' requires elevation (Administrator)."
  }

  if ($Action.RequiresMaintenanceMode -and -not (Test-FirewallCoreMaintenanceMode)) {
    throw "Action '$($Action.ActionId)' requires Maintenance Mode."
  }

  if ($Action.RequiresDevLab) {
    $devFlag = 'C:\ProgramData\FirewallCore\Config\DevLab.enabled'
    if (-not (Test-Path -LiteralPath $devFlag)) {
      throw "Action '$($Action.ActionId)' requires Dev/Lab gate."
    }
  }

  if ($Mode -eq 'Apply' -and $Action.Mode -eq 'AnalyzeOnly') {
    throw "Action '$($Action.ActionId)' is AnalyzeOnly."
  }
}

function New-FirewallCoreReportBase {
  param(
    [Parameter(Mandatory)][string]$RunId,
    [Parameter(Mandatory)][ValidateSet('Optimizer','Telemetry','Maintenance')][string]$Module,
    [Parameter(Mandatory)][ValidateSet('Analyze','Apply')][string]$Mode,
    [Parameter(Mandatory)][ValidateSet('Home','Gaming','Lab')][string]$Profile,
    [Parameter(Mandatory)][string[]]$SelectedActionIds,
    [Parameter(Mandatory)][string]$RunRoot
  )

  $hostInfo = Get-FirewallCoreHostInfo
  $isAdmin = Test-FirewallCoreIsAdmin

  return [pscustomobject]@{
    RunId = $RunId
    EngineVersion = '2.0.0-skeleton'
    Module = $Module
    UiMode = 'Optimize'
    Mode = $Mode
    Profile = $Profile
    StartedUtc = (Get-Date).ToUniversalTime().ToString('o')
    CompletedUtc = $null
    IsElevated = $isAdmin
    Gates = [pscustomobject]@{
      IsAdmin = $isAdmin
      MaintenanceMode = (Test-FirewallCoreMaintenanceMode)
      DevLab = (Test-Path -LiteralPath 'C:\ProgramData\FirewallCore\Config\DevLab.enabled')
    }
    Host = $hostInfo
    SelectedActionIds = $SelectedActionIds
    Results = @()
    Totals = [pscustomobject]@{ BytesFound = 0; BytesFreed = 0 }
    Evidence = [pscustomobject]@{ RunRoot=$RunRoot; ReportPath=(Join-Path $RunRoot 'report.json'); ArchivePath=$null; LogPath=(Join-Path $RunRoot 'run.log'); EtlPath=$null }
  }
}

function Invoke-FirewallCoreActionSet {
  param(
    [Parameter(Mandatory)][ValidateSet('Optimizer','Telemetry','Maintenance')][string]$Module,
    [Parameter(Mandatory)][ValidateSet('Analyze','Apply')][string]$Mode,
    [Parameter(Mandatory)][ValidateSet('Home','Gaming','Lab')][string]$Profile,
    [Parameter(Mandatory)][string[]]$SelectedActionIds,
    [switch]$AllowLocalFallback
  )

  $prefix = switch ($Module) {
    'Optimizer'   { 'OPT' }
    'Telemetry'   { 'TEL' }
    'Maintenance' { 'MAINT' }
  }

  $runId = New-FirewallCoreRunId -Prefix $prefix
  $runRoot = Get-FirewallCoreRunRoot -Module $Module -RunId $runId -AllowLocalFallback:$AllowLocalFallback

  $report = New-FirewallCoreReportBase -RunId $runId -Module $Module -Mode $Mode -Profile $Profile -SelectedActionIds $SelectedActionIds -RunRoot $runRoot

  $catalogFn = switch ($Module) {
    'Optimizer'   { 'Get-FirewallCoreOptimizerActionCatalog' }
    'Telemetry'   { 'Get-FirewallCoreTelemetryActionCatalog' }
    'Maintenance' { 'Get-FirewallCoreMaintenanceActionCatalog' }
  }

  if (-not (Get-Command $catalogFn -ErrorAction SilentlyContinue)) {
    throw "Missing catalog function: $catalogFn. Import the module that defines it."
  }

  $all = & $catalogFn -Profile $Profile
  $selected = @($all | Where-Object { $SelectedActionIds -contains $_.ActionId })

  if ($selected.Count -eq 0) {
    throw 'No actions selected (SelectedActionIds empty or not found in catalog).'
  }

  $ev = switch ($Module) {
    'Optimizer' { @{ Provider='FirewallCore.Optimizer'; StartId=2600; EndId=2601; ApplyStart=2610; ApplyEnd=2611; Fail=2612; Report=2630 } }
    'Telemetry' { @{ Provider='FirewallCore.Telemetry'; StartId=2700; EndId=2701; ApplyStart=2710; ApplyEnd=2711; Fail=2712; Report=2730 } }
    'Maintenance' { @{ Provider='FirewallCore.Maintenance'; StartId=2800; EndId=2801; ApplyStart=2800; ApplyEnd=2801; Fail=2802; Report=2830 } }
  }

  $startMsg = "RunId=$runId Mode=$Mode Profile=$Profile Actions=$($SelectedActionIds -join ',')"
  if ($Mode -eq 'Analyze') {
    Write-FirewallCoreEventSafe -Provider $ev.Provider -EventId $ev.StartId -Level Information -Message $startMsg
  } else {
    Write-FirewallCoreEventSafe -Provider $ev.Provider -EventId $ev.ApplyStart -Level Information -Message $startMsg
  }

  $logPath = $report.Evidence.LogPath
  Add-Content -LiteralPath $logPath -Value ("{0} START {1}" -f (Get-Date).ToString('s'), $startMsg) -Encoding UTF8

  foreach ($a in $selected) {
    try {
      Assert-FirewallCoreGates -Action $a -Mode $Mode

      $res = [ordered]@{ ActionId=$a.ActionId; DisplayName=$a.DisplayName; Risk=$a.Risk; Analyze=$null; Apply=$null }

      $an = & $a.AnalyzeScript -RunRoot $runRoot
      $res.Analyze = $an

      if ($an -and $an.BytesFound) {
        $report.Totals.BytesFound = [int64]$report.Totals.BytesFound + [int64]$an.BytesFound
      }

      if ($Mode -eq 'Apply') {
        $ap = & $a.ApplyScript -RunRoot $runRoot
        $res.Apply = $ap
        if ($ap -and $ap.BytesFreed) {
          $report.Totals.BytesFreed = [int64]$report.Totals.BytesFreed + [int64]$ap.BytesFreed
        }
      }

      $report.Results += [pscustomobject]$res

    } catch {
      $err = $_.Exception.Message
      $report.Results += [pscustomobject]@{ ActionId=$a.ActionId; DisplayName=$a.DisplayName; Risk=$a.Risk; Analyze=$null; Apply=$null; Error=$err }
      Add-Content -LiteralPath $logPath -Value ("{0} ERROR ActionId={1} {2}" -f (Get-Date).ToString('s'), $a.ActionId, $err) -Encoding UTF8
      Write-FirewallCoreEventSafe -Provider $ev.Provider -EventId $ev.Fail -Level Error -Message ("RunId=$runId ActionId=$($a.ActionId) Error=$err")
    }
  }

  $report.CompletedUtc = (Get-Date).ToUniversalTime().ToString('o')
  Write-FirewallCoreJson -Path $report.Evidence.ReportPath -Object $report -Depth 10

  Write-FirewallCoreEventSafe -Provider $ev.Provider -EventId $ev.Report -Level Information -Message ("RunId=$runId ReportPath=$($report.Evidence.ReportPath)")
  if ($Mode -eq 'Analyze') {
    Write-FirewallCoreEventSafe -Provider $ev.Provider -EventId $ev.EndId -Level Information -Message ("RunId=$runId BytesFound=$($report.Totals.BytesFound)")
  } else {
    Write-FirewallCoreEventSafe -Provider $ev.Provider -EventId $ev.ApplyEnd -Level Information -Message ("RunId=$runId BytesFreed=$($report.Totals.BytesFreed)")
  }

  Add-Content -LiteralPath $logPath -Value ("{0} DONE BytesFound={1} BytesFreed={2}" -f (Get-Date).ToString('s'), $report.Totals.BytesFound, $report.Totals.BytesFreed) -Encoding UTF8
  return $report
}

Export-ModuleMember -Function Test-FirewallCoreMaintenanceMode, Assert-FirewallCoreGates, Invoke-FirewallCoreActionSet, New-FirewallCoreReportBase
