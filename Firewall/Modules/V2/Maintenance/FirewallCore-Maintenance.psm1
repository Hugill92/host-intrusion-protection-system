#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'FirewallCore-ActionRegistry.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\..\Tools\V2\_shared\FirewallCore-V2Shared.psm1') -Force

function Get-ToolkitRoot {
  return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\ThirdParty\AdminToolkit_v2')).Path
}

function Get-FirewallCoreMaintenanceActionCatalog {
  param([Parameter(Mandatory)][ValidateSet('Home','Gaming','Lab')][string]$Profile)

  $actions = @()

  $actions += [pscustomobject]@{
    ActionId='MAINT.SYSTEM.REPAIR'; DisplayName='System Repair (DISM + SFC)'; Module='Maintenance'; TileGroup='SystemRepair'; Risk='Medium'; Mode='AnalyzeApply';
    RequiresAdmin=$true; RequiresMaintenanceMode=$true; RequiresDevLab=$false; ProfileVisibility=@('Home','Gaming','Lab');
    Notes='Runs DISM RestoreHealth then SFC /scannow (via toolkit cmd). Copies toolkit logs into run folder.';
    AnalyzeScript={ param([string]$RunRoot) [pscustomobject]@{ BytesFound=0; ItemCount=0; Sample=@() } };
    ApplyScript={
      param([string]$RunRoot)
      $toolkit = Get-ToolkitRoot
      $cmd = Join-Path $toolkit 'System-Repair.cmd'
      $stdout = Join-Path $RunRoot 'system_repair.out.txt'
      $stderr = Join-Path $RunRoot 'system_repair.err.txt'
      $r = Invoke-FirewallCoreProcess -FilePath 'cmd.exe' -ArgumentList @('/c', $cmd) -WorkingDirectory $RunRoot -StdOutPath $stdout -StdErrPath $stderr

      $srcLogRoot = Join-Path $env:SystemRoot 'Logs\SystemRepair'
      $copied = @()
      try {
        if (Test-Path -LiteralPath $srcLogRoot) {
          $latest = Get-ChildItem -LiteralPath $srcLogRoot -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 6
          foreach ($f in $latest) {
            $dst = Join-Path $RunRoot $f.Name
            Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
            $copied += $dst
          }
        }
      } catch { }

      [pscustomobject]@{ BytesFreed=0; DeletedCount=0; SkippedInUse=0; SkippedDenied=0; Archived=$false; Errors=@(); ExitCode=$r.ExitCode; CopiedArtifacts=$copied }
    }
  }

  $actions += [pscustomobject]@{
    ActionId='MAINT.REGOPT.PREVIEW'; DisplayName='Registry Optimizations (Preview)'; Module='Maintenance'; TileGroup='RegistryOptimizations'; Risk='Medium'; Mode='AnalyzeOnly';
    RequiresAdmin=$true; RequiresMaintenanceMode=$true; RequiresDevLab=$false; ProfileVisibility=@('Home','Gaming','Lab');
    Notes='Runs Registry_Optimizations.ps1 with -WhatIf and generates run artifacts.';
    AnalyzeScript={
      param([string]$RunRoot)
      $toolkit = Get-ToolkitRoot
      $ps1 = Join-Path $toolkit 'Optimization\Registry_Optimizations.ps1'
      $stdout = Join-Path $RunRoot 'regopt_preview.out.txt'
      $stderr = Join-Path $RunRoot 'regopt_preview.err.txt'
      $args = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$ps1,'-OutputDir',$RunRoot,'-AlsoWriteProgramDataAudit','-WhatIf')
      $r = Invoke-FirewallCoreProcess -FilePath 'powershell.exe' -ArgumentList $args -WorkingDirectory $RunRoot -StdOutPath $stdout -StdErrPath $stderr
      $json = Get-ChildItem -LiteralPath (Join-Path $RunRoot 'Logs') -Filter 'RegistryOptimization_Run_*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
      $sample = @(); if ($json) { $sample += $json.FullName }
      [pscustomobject]@{ BytesFound=0; ItemCount=0; Sample=$sample; ExitCode=$r.ExitCode }
    };
    ApplyScript=$null
  }

  $actions += [pscustomobject]@{
    ActionId='MAINT.REGOPT.APPLY'; DisplayName='Registry Optimizations (Apply)'; Module='Maintenance'; TileGroup='RegistryOptimizations'; Risk='Medium'; Mode='AnalyzeApply';
    RequiresAdmin=$true; RequiresMaintenanceMode=$true; RequiresDevLab=$false; ProfileVisibility=@('Home','Gaming','Lab');
    Notes='Applies registry optimizations and runs verification.';
    AnalyzeScript={ param([string]$RunRoot) [pscustomobject]@{ BytesFound=0; ItemCount=0; Sample=@() } };
    ApplyScript={
      param([string]$RunRoot)
      $toolkit = Get-ToolkitRoot
      $ps1 = Join-Path $toolkit 'Optimization\Registry_Optimizations.ps1'
      $stdout = Join-Path $RunRoot 'regopt_apply.out.txt'
      $stderr = Join-Path $RunRoot 'regopt_apply.err.txt'
      $args = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$ps1,'-OutputDir',$RunRoot,'-AlsoWriteProgramDataAudit')
      $r = Invoke-FirewallCoreProcess -FilePath 'powershell.exe' -ArgumentList $args -WorkingDirectory $RunRoot -StdOutPath $stdout -StdErrPath $stderr

      $verify = Join-Path $toolkit 'Optimization\Verify-RegistryOptimizations.ps1'
      $vOut = Join-Path $RunRoot 'regopt_verify.out.txt'
      $vErr = Join-Path $RunRoot 'regopt_verify.err.txt'
      $vArgs = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$verify,'-DesktopFolder',$RunRoot)
      $vr = Invoke-FirewallCoreProcess -FilePath 'powershell.exe' -ArgumentList $vArgs -WorkingDirectory $RunRoot -StdOutPath $vOut -StdErrPath $vErr

      [pscustomobject]@{ BytesFreed=0; DeletedCount=0; SkippedInUse=0; SkippedDenied=0; Archived=$false; Errors=@(); ExitCode=$r.ExitCode; VerifyExitCode=$vr.ExitCode }
    }
  }

  return $actions
}

Export-ModuleMember -Function Get-FirewallCoreMaintenanceActionCatalog
