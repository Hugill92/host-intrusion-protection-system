#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'FirewallCore-ActionRegistry.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\..\Tools\V2\_shared\FirewallCore-V2Shared.psm1') -Force

function Write-TelemetryJson {
  param([Parameter(Mandatory)][string]$RunRoot,[Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][object]$Object)
  $p = Join-Path $RunRoot $Name
  Write-FirewallCoreJson -Path $p -Object $Object -Depth 10
  return $p
}

function Get-FirewallCoreTelemetryActionCatalog {
  param([Parameter(Mandatory)][ValidateSet('Home','Gaming','Lab')][string]$Profile)

  $actions = @()

  $actions += [pscustomobject]@{
    ActionId='TEL.NET.SNAPSHOT'; DisplayName='Network Snapshot'; Module='Telemetry'; TileGroup='NetworkTelemetry'; Risk='Low'; Mode='AnalyzeOnly';
    RequiresAdmin=$false; RequiresMaintenanceMode=$false; RequiresDevLab=$false; ProfileVisibility=@('Home','Gaming','Lab');
    Notes='Captures adapters, IPs, DNS, routes, listening ports, established connections.';
    AnalyzeScript={
      param([string]$RunRoot)
      $snap = [ordered]@{
        Timestamp=(Get-Date).ToString('o')
        Adapters=@(Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name,Status,LinkSpeed,MacAddress,ifIndex)
        IP=@(Get-NetIPAddress -ErrorAction SilentlyContinue | Select-Object InterfaceAlias,InterfaceIndex,AddressFamily,IPAddress,PrefixLength)
        DNS=@(Get-DnsClientServerAddress -ErrorAction SilentlyContinue | Select-Object InterfaceAlias,AddressFamily,ServerAddresses)
        Routes=@(Get-NetRoute -ErrorAction SilentlyContinue | Select-Object InterfaceAlias,DestinationPrefix,NextHop,RouteMetric,ifIndex)
        TcpListen=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess)
        TcpEstablished=@(Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,OwningProcess)
        UdpEndpoints=@(Get-NetUDPEndpoint -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess)
        FirewallProfiles=@(Get-NetFirewallProfile -ErrorAction SilentlyContinue | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction,LogFileName,LogMaxSizeKilobytes,LogAllowed,LogBlocked)
      }
      $path = Write-TelemetryJson -RunRoot $RunRoot -Name 'telemetry_snapshot.json' -Object $snap
      [pscustomobject]@{ BytesFound=0; ItemCount=0; Sample=@($path) }
    };
    ApplyScript=$null
  }

  $actions += [pscustomobject]@{
    ActionId='TEL.WFP.CAPTURE.START'; DisplayName='Start ETW Network Trace (time-boxed)'; Module='Telemetry'; TileGroup='NetworkTelemetry'; Risk='Medium'; Mode='AnalyzeApply';
    RequiresAdmin=$true; RequiresMaintenanceMode=$true; RequiresDevLab=$false; ProfileVisibility=@('Home','Gaming','Lab');
    Notes='Starts netsh trace with an ETL file in the run folder. Stop with TEL.WFP.CAPTURE.STOP.';
    AnalyzeScript={ param([string]$RunRoot) [pscustomobject]@{ BytesFound=0; ItemCount=0; Sample=@() } };
    ApplyScript={
      param([string]$RunRoot)
      $etl = Join-Path $RunRoot 'wfp_trace.etl'
      $stdout = Join-Path $RunRoot 'netsh_trace_start.out.txt'
      $stderr = Join-Path $RunRoot 'netsh_trace_start.err.txt'
      $statePath = Join-Path $RunRoot 'trace_state.json'
      Write-FirewallCoreJson -Path $statePath -Object ([pscustomobject]@{ StartedUtc=(Get-Date).ToUniversalTime().ToString('o'); EtlPath=$etl }) -Depth 6
      $args = @('trace','start',"tracefile=$etl",'capture=yes','report=no','persistent=no','maxsize=256','filemode=circular')
      $r = Invoke-FirewallCoreProcess -FilePath 'netsh.exe' -ArgumentList $args -WorkingDirectory $RunRoot -StdOutPath $stdout -StdErrPath $stderr
      [pscustomobject]@{ BytesFreed=0; DeletedCount=0; SkippedInUse=0; SkippedDenied=0; Archived=$false; Errors=@(); ExitCode=$r.ExitCode; EtlPath=$etl; StatePath=$statePath }
    }
  }

  $actions += [pscustomobject]@{
    ActionId='TEL.WFP.CAPTURE.STOP'; DisplayName='Stop ETW Network Trace'; Module='Telemetry'; TileGroup='NetworkTelemetry'; Risk='Medium'; Mode='AnalyzeApply';
    RequiresAdmin=$true; RequiresMaintenanceMode=$true; RequiresDevLab=$false; ProfileVisibility=@('Home','Gaming','Lab');
    Notes='Stops netsh trace.';
    AnalyzeScript={ param([string]$RunRoot) [pscustomobject]@{ BytesFound=0; ItemCount=0; Sample=@() } };
    ApplyScript={
      param([string]$RunRoot)
      $stdout = Join-Path $RunRoot 'netsh_trace_stop.out.txt'
      $stderr = Join-Path $RunRoot 'netsh_trace_stop.err.txt'
      $r = Invoke-FirewallCoreProcess -FilePath 'netsh.exe' -ArgumentList @('trace','stop') -WorkingDirectory $RunRoot -StdOutPath $stdout -StdErrPath $stderr
      [pscustomobject]@{ BytesFreed=0; DeletedCount=0; SkippedInUse=0; SkippedDenied=0; Archived=$false; Errors=@(); ExitCode=$r.ExitCode }
    }
  }

  return $actions
}

Export-ModuleMember -Function Get-FirewallCoreTelemetryActionCatalog
