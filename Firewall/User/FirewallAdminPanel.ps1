[CmdletBinding()]
param()
$ErrorActionPreference="Stop"

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase -ErrorAction Stop | Out-Null
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue | Out-Null
Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue | Out-Null

function Is-Admin {
  $id=[Security.Principal.WindowsIdentity]::GetCurrent()
  $p=New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-Elevated([string]$ScriptPath) {
  Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList @(
    "-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-File", $ScriptPath
  ) | Out-Null
}

function Get-StatusItems {
  $items = New-Object System.Collections.ArrayList

  $repoRoot = "C:\FirewallInstaller"
  $liveRoot = "C:\Firewall"

  $needFiles = @(
    "C:\Firewall\Maintenance\Enable-DefenderIntegration.ps1",
    "C:\Firewall\User\FirewallToastListener.ps1",
    "C:\Firewall\User\FirewallToastActivate.ps1"
  )

  $tasks = @(
    "Firewall Tamper Guard",
    "Firewall User Notifier",
    "Firewall-Defender-Integration",
    "FirewallCore Toast Listener",
    "FirewallCore Toast Watchdog"
  )

  # Admin
  [void]$items.Add([pscustomobject]@{ Check="Running elevated (Admin)"; Status=($(if(Is-Admin){"PASS"}else{"FAIL"})); Details=$(if(Is-Admin){"Admin context"}else{"Not elevated"}); Action="Re-open as Admin" })

  # Paths
  foreach ($p in $needFiles) {
    $ok = Test-Path $p
    [void]$items.Add([pscustomobject]@{ Check=("File: " + $p); Status=($(if($ok){"PASS"}else{"FAIL"})); Details=$(if($ok){"Present"}else{"Missing"}); Action="Stage via Install/Repair" })
  }

  # Tasks
  foreach ($t in $tasks) {
    $st = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($st) {
      $en = $st.State -ne "Disabled"
      [void]$items.Add([pscustomobject]@{ Check=("Task: " + $t); Status=($(if($en){"PASS"}else{"WARN"})); Details=("State=" + $st.State); Action="Repair (re-register/enable)" })
    } else {
      [void]$items.Add([pscustomobject]@{ Check=("Task: " + $t); Status="FAIL"; Details="Missing"; Action="Repair (re-register)" })
    }
  }

  # Policy apply log
  $plog = "C:\Firewall\Logs\Install\ApplyPolicy.log"
  $has = Test-Path $plog
  [void]$items.Add([pscustomobject]@{ Check="Policy apply log"; Status=($(if($has){"PASS"}else{"WARN"})); Details=$(if($has){$plog}else{"Not found"}); Action="Repair (ApplyPolicy)" })

  # Rule count
  try { $rc = (Get-NetFirewallRule | Measure-Object).Count } catch { $rc = -1 }
  $okrc = ($rc -gt 0)
  [void]$items.Add([pscustomobject]@{ Check="Firewall rule inventory"; Status=($(if($okrc){"PASS"}else{"WARN"})); Details=("Count=" + $rc); Action="Install/Repair (ApplyPolicy)" })

  # Toast listener process
  try {
    $p = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "FirewallToastListener\.ps1" } | Select-Object -First 1
    $okp = [bool]$p
    [void]$items.Add([pscustomobject]@{ Check="Toast Listener process"; Status=($(if($okp){"PASS"}else{"WARN"})); Details=$(if($okp){("PID=" + $p.ProcessId)}else{"Not running"}); Action="Repair (RestartToast)" })
  } catch {
    [void]$items.Add([pscustomobject]@{ Check="Toast Listener process"; Status="WARN"; Details="Query failed"; Action="Repair (RestartToast)" })
  }

  return $items
}

$xaml = @
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="FirewallCore Admin Panel" Height="560" Width="940" WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize">
  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <TextBlock Grid.Row="0" FontSize="18" FontWeight="SemiBold" Text="System Checklist (Sprint 2: Uninstall / Repair / Admin Panel)" Margin="0,0,0,10"/>
    <DataGrid Grid.Row="1" Name="Grid" AutoGenerateColumns="False" IsReadOnly="True" CanUserResizeRows="False" HeadersVisibility="Column" RowHeight="28">
      <DataGrid.Columns>
        <DataGridTextColumn Header="Check" Binding="{Binding Check}" Width="*"/>
        <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="110"/>
        <DataGridTextColumn Header="Details" Binding="{Binding Details}" Width="320"/>
        <DataGridTextColumn Header="Suggested Action" Binding="{Binding Action}" Width="170"/>
      </DataGrid.Columns>
    </DataGrid>
    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
      <Button Name="BtnRefresh" Content="Refresh" MinWidth="90" Margin="0,0,10,0"/>
      <Button Name="BtnInstall" Content="Install" MinWidth="110" Margin="0,0,10,0"/>
      <Button Name="BtnUninstall" Content="Uninstall" MinWidth="110" Margin="0,0,10,0"/>
      <Button Name="BtnRepair" Content="Repair / Self-Heal" MinWidth="140" Margin="0,0,10,0"/>
      <Button Name="BtnMaint" Content="Maintenance Mode" MinWidth="140" Margin="0,0,10,0"/>
      <Button Name="BtnClose" Content="Close" MinWidth="90"/>
    </StackPanel>
  </Grid>
</Window>
@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$win = [Windows.Markup.XamlReader]::Load($reader)

$grid = $win.FindName("Grid")
$btnRefresh = $win.FindName("BtnRefresh")
$btnInstall = $win.FindName("BtnInstall")
$btnUninstall = $win.FindName("BtnUninstall")
$btnRepair = $win.FindName("BtnRepair")
$btnMaint = $win.FindName("BtnMaint")
$btnClose = $win.FindName("BtnClose")

function Refresh-Grid {
  $grid.ItemsSource = Get-StatusItems
}

$btnRefresh.Add_Click({ Refresh-Grid })

$btnInstall.Add_Click({
  if (-not (Is-Admin)) { Start-Elevated $MyInvocation.MyCommand.Path; $win.Close(); return }
  $cmd = "C:\FirewallInstaller\Install.cmd"
  if (Test-Path $cmd) { Start-Process -FilePath $cmd | Out-Null } else { [System.Windows.MessageBox]::Show("Install.cmd not found at C:\FirewallInstaller","Install") | Out-Null }
})

$btnUninstall.Add_Click({
  if (-not (Is-Admin)) { Start-Elevated $MyInvocation.MyCommand.Path; $win.Close(); return }
  $msg = "Choose uninstall type:`r`n`r`nYES = Uninstall (reinstall later)`r`nNO = CLEAN Uninstall (requires typing DELETE)`r`nCANCEL = abort"
  $r = [System.Windows.MessageBox]::Show($msg,"Uninstall", [System.Windows.MessageBoxButton]::YesNoCancel)
  if ($r -eq [System.Windows.MessageBoxResult]::Yes) {
    $cmd = "C:\FirewallInstaller\Uninstall.cmd"
    if (Test-Path $cmd) { Start-Process -FilePath $cmd | Out-Null } else { [System.Windows.MessageBox]::Show("Uninstall.cmd not found at C:\FirewallInstaller","Uninstall") | Out-Null }
  } elseif ($r -eq [System.Windows.MessageBoxResult]::No) {
    $confirm = [Microsoft.VisualBasic.Interaction]::InputBox("Type DELETE to confirm CLEAN uninstall.","Clean Uninstall","")
    if ($confirm -ne "DELETE") { [System.Windows.MessageBox]::Show("Cancelled.","Clean Uninstall") | Out-Null; return }
    $cmd2 = "C:\FirewallInstaller\Uninstall-Clean.cmd"
    if (Test-Path $cmd2) { Start-Process -FilePath $cmd2 | Out-Null } else { [System.Windows.MessageBox]::Show("Uninstall-Clean.cmd not found at C:\FirewallInstaller","Clean Uninstall") | Out-Null }
  }
})

$btnRepair.Add_Click({
  if (-not (Is-Admin)) { Start-Elevated $MyInvocation.MyCommand.Path; $win.Close(); return }
  $cmd = "C:\FirewallInstaller\Repair.cmd"
  if (Test-Path $cmd) { Start-Process -FilePath $cmd -ArgumentList @() | Out-Null } else { [System.Windows.MessageBox]::Show("Repair.cmd not found at C:\FirewallInstaller","Repair") | Out-Null }
})

$btnMaint.Add_Click({
  if (-not (Is-Admin)) { Start-Elevated $MyInvocation.MyCommand.Path; $win.Close(); return }
  $state = "C:\ProgramData\FirewallCore\maintenance.json"
  $enabled = $false
  if (Test-Path $state) {
    try { $j = Get-Content $state -Raw | ConvertFrom-Json; $enabled = [bool]$j.Enabled } catch {}
  }
  $target = if ($enabled) { "Off" } else { "On" }
  $ps1 = "C:\Firewall\Maintenance\Set-MaintenanceMode.ps1"
  if (Test-Path $ps1) {
    Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-File",$ps1,"-Mode",$target) -WindowStyle Hidden | Out-Null
    [System.Windows.MessageBox]::Show(("Maintenance mode set to: " + $target),"Maintenance Mode") | Out-Null
    Start-Sleep -Milliseconds 250
    Refresh-Grid
  } else {
    [System.Windows.MessageBox]::Show("Set-MaintenanceMode.ps1 missing under C:\Firewall\Maintenance","Maintenance Mode") | Out-Null
  }
})

$btnClose.Add_Click({ $win.Close() })

Refresh-Grid
$win.ShowDialog() | Out-Null

