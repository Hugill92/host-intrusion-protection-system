[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Always-on file logging (so "nothing happened" is never silent)
$LogDir = "C:\Firewall\Logs\AdminPanel"
try {
  if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
} catch {
  # fallback to ProgramData if C:\Firewall isn't ready yet
  $LogDir = "C:\ProgramData\FirewallCore\Logs"
  if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
}
$LogFile = Join-Path $LogDir ("FirewallAdminPanel_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

function Write-Log([string]$msg) {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
  ($ts + " " + $msg) | Out-File -LiteralPath $LogFile -Append -Encoding utf8
}

Write-Log "START Admin Panel (Phase A UI only)"
Write-Log ("User=" + [Environment]::UserName + " IsAdmin=" + (Test-IsAdmin))
Write-Log ("ApartmentState=" + [System.Threading.Thread]::CurrentThread.ApartmentState)

# WPF wants STA. If not STA, relaunch self in STA and exit.
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne "STA") {
  Write-Log "Not STA; relaunching with -STA"
  $self = $MyInvocation.MyCommand.Path
  Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
    "-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-STA",
    "-File",$self
  ) | Out-Null
  return
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null
Write-Log "WPF assemblies loaded OK"

function Get-ChecklistItems {
  $items = New-Object System.Collections.ArrayList

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

  [void]$items.Add([pscustomobject]@{
    Check="Running elevated (Admin)"
    Status=($(if (Test-IsAdmin) { "PASS" } else { "FAIL" }))
    Details=($(if (Test-IsAdmin) { "Admin context" } else { "Not elevated" }))
    Action="Relaunch as Admin (Phase B)"
  })

  foreach ($p in $needFiles) {
    $ok = Test-Path -LiteralPath $p
    [void]$items.Add([pscustomobject]@{
      Check=("File: " + $p)
      Status=($(if ($ok) { "PASS" } else { "WARN" }))
      Details=($(if ($ok) { "Present" } else { "Missing" }))
      Action="Stage/Repair (Phase B)"
    })
  }

  foreach ($t in $tasks) {
    $st = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($st) {
      $enabled = ($st.State -ne "Disabled")
      [void]$items.Add([pscustomobject]@{
        Check=("Task: " + $t)
        Status=($(if ($enabled) { "PASS" } else { "WARN" }))
        Details=("State=" + $st.State)
        Action="Repair enables/registers (Phase B)"
      })
    } else {
      [void]$items.Add([pscustomobject]@{
        Check=("Task: " + $t)
        Status="FAIL"
        Details="Missing"
        Action="Repair registers task (Phase B)"
      })
    }
  }

  # Rule inventory
  $rc = -1
  try { $rc = (Get-NetFirewallRule | Measure-Object).Count } catch { }
  [void]$items.Add([pscustomobject]@{
    Check="Firewall rule inventory"
    Status=($(if ($rc -gt 0) { "PASS" } else { "WARN" }))
    Details=("Count=" + $rc)
    Action="Install/Repair policy (Phase B)"
  })

  # Toast listener process check
  try {
    $p = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -match "FirewallToastListener\.ps1" } |
      Select-Object -First 1
    $okp = [bool]$p
    [void]$items.Add([pscustomobject]@{
      Check="Toast Listener process"
      Status=($(if ($okp) { "PASS" } else { "WARN" }))
      Details=($(if ($okp) { ("PID=" + $p.ProcessId) } else { "Not running" }))
      Action="Repair restart toast (Phase B)"
    })
  } catch {
    [void]$items.Add([pscustomobject]@{
      Check="Toast Listener process"
      Status="WARN"
      Details="Query failed"
      Action="Repair restart toast (Phase B)"
    })
  }

  return $items
}

# XAML UI
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="FirewallCore Admin Panel (Sprint 2 • Phase A UI only)"
        Height="680" Width="1000"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize">
  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <TextBlock Grid.Row="0" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,10"
               Text="System Checklist + Actions (Phase A: UI/UX only — no button wiring)"/>

    <DataGrid Grid.Row="1" Name="Grid"
              AutoGenerateColumns="False"
              IsReadOnly="True"
              HeadersVisibility="Column"
              RowHeight="28">
      <DataGrid.RowStyle>
        <Style TargetType="DataGridRow">
          <Style.Triggers>
            <DataTrigger Binding="{Binding Status}" Value="PASS">
              <Setter Property="Background" Value="#E8F5E9"/>
            </DataTrigger>
            <DataTrigger Binding="{Binding Status}" Value="WARN">
              <Setter Property="Background" Value="#FFF8E1"/>
            </DataTrigger>
            <DataTrigger Binding="{Binding Status}" Value="FAIL">
              <Setter Property="Background" Value="#FFEBEE"/>
            </DataTrigger>
          </Style.Triggers>
        </Style>
      </DataGrid.RowStyle>

      <DataGrid.Columns>
        <DataGridTextColumn Header="Check" Binding="{Binding Check}" Width="*"/>
        <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="110"/>
        <DataGridTextColumn Header="Details" Binding="{Binding Details}" Width="360"/>
        <DataGridTextColumn Header="Suggested Action" Binding="{Binding Action}" Width="240"/>
      </DataGrid.Columns>
    </DataGrid>

    <GroupBox Grid.Row="2" Header="Repair Options (Phase A UI only)" Margin="0,12,0,0">
      <Grid Margin="10">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="300"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <TextBlock Grid.Column="0" VerticalAlignment="Center" Text="Mode:" Margin="0,0,10,0"/>
        <ComboBox Grid.Column="1" Name="RepairMode" SelectedIndex="0" Height="26">
          <ComboBoxItem Content="Minimal Repair (tasks/health only)"/>
          <ComboBoxItem Content="Full Repair (ApplyPolicy + RestartToast + ArchiveQueue)"/>
        </ComboBox>

        <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="18,0,0,0" VerticalAlignment="Center">
          <CheckBox Name="OptRestartToast" Content="Restart Toast" IsChecked="True" Margin="0,0,14,0"/>
          <CheckBox Name="OptArchiveQueue" Content="Archive Queue" IsChecked="True" Margin="0,0,14,0"/>
          <CheckBox Name="OptApplyPolicy" Content="Re-Apply Policy" IsChecked="False"/>
          <TextBlock Text="  (not wired yet)" Foreground="#555" Margin="14,0,0,0"/>
        </StackPanel>
      </Grid>
    </GroupBox>

    <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
      <Button Name="BtnRefresh" Content="Refresh" MinWidth="90" Margin="0,0,10,0"/>
      <Button Name="BtnInstall" Content="Install" MinWidth="110" Margin="0,0,10,0"/>
      <Button Name="BtnRepair" Content="Repair" MinWidth="110" Margin="0,0,10,0"/>
      <Button Name="BtnMaint" Content="Maintenance" MinWidth="130" Margin="0,0,10,0"/>
      <Button Name="BtnUninstall" Content="Uninstall" MinWidth="110" Margin="0,0,10,0"/>
      <Button Name="BtnCleanUninstall" Content="Clean Uninstall" MinWidth="130" Margin="0,0,10,0"/>
      <Button Name="BtnClose" Content="Close" MinWidth="90"/>
    </StackPanel>
  </Grid>
</Window>
"@

try {
  $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
  $win = [Windows.Markup.XamlReader]::Load($reader)
  Write-Log "XAML loaded OK"
} catch {
  Write-Log ("XAML LOAD FAILED: " + ($_ | Out-String))
  throw
}

$grid         = $win.FindName("Grid")
$btnRefresh   = $win.FindName("BtnRefresh")
$btnInstall   = $win.FindName("BtnInstall")
$btnRepair    = $win.FindName("BtnRepair")
$btnMaint     = $win.FindName("BtnMaint")
$btnUninstall = $win.FindName("BtnUninstall")
$btnClean     = $win.FindName("BtnCleanUninstall")
$btnClose     = $win.FindName("BtnClose")
$repairMode   = $win.FindName("RepairMode")
$optRestart   = $win.FindName("OptRestartToast")
$optArchive   = $win.FindName("OptArchiveQueue")
$optApply     = $win.FindName("OptApplyPolicy")

function Refresh-Grid {
  Write-Log "Refresh clicked"
  $grid.ItemsSource = Get-ChecklistItems
}

function PhaseA-Toast([string]$which) {
  Write-Log ("Clicked: " + $which)
  [System.Windows.MessageBox]::Show(($which + " clicked (Phase A UI only). Wiring happens in Phase B."),"FirewallCore Admin Panel") | Out-Null
}

$btnRefresh.Add_Click({ Refresh-Grid })
$btnInstall.Add_Click({ PhaseA-Toast "Install" })
$btnMaint.Add_Click({ PhaseA-Toast "Maintenance" })
$btnUninstall.Add_Click({ PhaseA-Toast "Uninstall" })
$btnClean.Add_Click({ PhaseA-Toast "Clean Uninstall" })

$btnRepair.Add_Click({
  $mode  = $repairMode.SelectedItem.Content
  $flags = @()
  if ($optRestart.IsChecked) { $flags += "RestartToast" }
  if ($optArchive.IsChecked) { $flags += "ArchiveQueue" }
  if ($optApply.IsChecked)   { $flags += "ApplyPolicy" }
  Write-Log ("Repair clicked Mode=" + $mode + " Options=" + ($flags -join ","))
  [System.Windows.MessageBox]::Show(("Repair clicked (Phase A UI only).`r`nMode: " + $mode + "`r`nOptions: " + ($flags -join ", ")),"FirewallCore Admin Panel") | Out-Null
})

$btnClose.Add_Click({
  Write-Log "Close clicked"
  $win.Close()
})

# Initial load
Refresh-Grid
Write-Log "Showing window"
$win.ShowDialog() | Out-Null
Write-Log "Window closed"
