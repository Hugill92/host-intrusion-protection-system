[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Always-on file logging (never "silent")
$LogDir = "C:\Firewall\Logs\AdminPanel"
try {
  if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
} catch {
  $LogDir = "C:\ProgramData\FirewallCore\Logs"
  if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
}
$LogFile = Join-Path $LogDir ("FirewallAdminPanel_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

function Write-Log([string]$msg) {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
  ($ts + " " + $msg) | Out-File -LiteralPath $LogFile -Append -Encoding utf8
}

Write-Log "START Admin Panel (Phase A UI/UX + AutoRefresh + Status styling + Progress tab (Phase B-ready))"
Write-Log ("User=" + [Environment]::UserName + " IsAdmin=" + (Test-IsAdmin))
Write-Log ("ApartmentState=" + [System.Threading.Thread]::CurrentThread.ApartmentState)

# WPF wants STA. Relaunch self in STA if needed.
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

function Status-Icon([string]$s) {
  switch ($s) {
    "PASS" { return "✅" }
    "WARN" { return "⚠️" }
    "FAIL" { return "❌" }
    default { return "•" }
  }
}

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

  $isAdmin = Test-IsAdmin
  [void]$items.Add([pscustomobject]@{
    Icon   = (Status-Icon ($(if ($isAdmin) { "PASS" } else { "FAIL" })))
    Check  = "Running elevated (Admin)"
    Status = ($(if ($isAdmin) { "PASS" } else { "FAIL" }))
    Details= ($(if ($isAdmin) { "Admin context" } else { "Not elevated" }))
    Action = "Relaunch as Admin (Phase B)"
  })

  foreach ($p in $needFiles) {
    $ok = Test-Path -LiteralPath $p
    $st = $(if ($ok) { "PASS" } else { "WARN" })
    [void]$items.Add([pscustomobject]@{
      Icon   = (Status-Icon $st)
      Check  = ("File: " + $p)
      Status = $st
      Details= ($(if ($ok) { "Present" } else { "Missing" }))
      Action = "Stage/Repair (Phase B)"
    })
  }

  foreach ($t in $tasks) {
    $st = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($st) {
      $enabled = ($st.State -ne "Disabled")
      $s = $(if ($enabled) { "PASS" } else { "WARN" })
      [void]$items.Add([pscustomobject]@{
        Icon   = (Status-Icon $s)
        Check  = ("Task: " + $t)
        Status = $s
        Details= ("State=" + $st.State)
        Action = "Repair enables/registers (Phase B)"
      })
    } else {
      [void]$items.Add([pscustomobject]@{
        Icon   = (Status-Icon "FAIL")
        Check  = ("Task: " + $t)
        Status = "FAIL"
        Details= "Missing"
        Action = "Repair registers task (Phase B)"
      })
    }
  }

  # Rule inventory
  $rc = -1
  try { $rc = (Get-NetFirewallRule | Measure-Object).Count } catch { }
  $s2 = $(if ($rc -gt 0) { "PASS" } else { "WARN" })
  [void]$items.Add([pscustomobject]@{
    Icon   = (Status-Icon $s2)
    Check  = "Firewall rule inventory"
    Status = $s2
    Details= ("Count=" + $rc)
    Action = "Install/Repair policy (Phase B)"
  })

  # Toast listener process check
  try {
    $p = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -match "FirewallToastListener\.ps1" } |
      Select-Object -First 1
    $okp = [bool]$p
    $s3  = $(if ($okp) { "PASS" } else { "WARN" })
    [void]$items.Add([pscustomobject]@{
      Icon   = (Status-Icon $s3)
      Check  = "Toast Listener process"
      Status = $s3
      Details= ($(if ($okp) { ("PID=" + $p.ProcessId) } else { "Not running" }))
      Action = "Repair restart toast (Phase B)"
    })
  } catch {
    [void]$items.Add([pscustomobject]@{
      Icon   = (Status-Icon "WARN")
      Check  = "Toast Listener process"
      Status = "WARN"
      Details= "Query failed"
      Action = "Repair restart toast (Phase B)"
    })
  }

  return $items
}

# Phase B-ready: Progress Feed (panel reads, installer writes later)
$ProgressPath = "C:\Firewall\Logs\Install\InstallProgress.jsonl"

function Get-ProgressItems {
  $items = New-Object System.Collections.ArrayList

  if (-not (Test-Path -LiteralPath $ProgressPath)) {
    [void]$items.Add([pscustomobject]@{
      Icon   = (Status-Icon "WARN")
      Step   = "Install progress feed"
      Status = "WARN"
      Details= ("No file found: " + $ProgressPath)
      Time   = ""
    })
    return $items
  }

  try {
    $lines = Get-Content -LiteralPath $ProgressPath -ErrorAction Stop | Select-Object -Last 80
    foreach ($ln in $lines) {
      $lnTrim = ($ln + "").Trim()
      if (-not $lnTrim) { continue }

      # Try JSONL first
      $obj = $null
      if ($lnTrim.StartsWith("{") -and $lnTrim.EndsWith("}")) {
        try { $obj = $lnTrim | ConvertFrom-Json -ErrorAction Stop } catch { $obj = $null }
      }

      if ($obj) {
        $st = ($obj.Status + "").ToUpperInvariant()
        if ($st -notin @("PASS","WARN","FAIL","INFO")) { $st = "INFO" }
        $icon = $(if ($st -in @("PASS","WARN","FAIL")) { Status-Icon $st } else { "•" })
        [void]$items.Add([pscustomobject]@{
          Icon   = $icon
          Step   = ($obj.Step + "")
          Status = $st
          Details= ($obj.Details + "")
          Time   = ($obj.Time + "")
        })
      } else {
        # Fallback: pipe format "STATUS|STEP|DETAILS"
        $parts = $lnTrim.Split("|",3)
        if ($parts.Count -ge 2) {
          $st = ($parts[0] + "").Trim().ToUpperInvariant()
          if ($st -notin @("PASS","WARN","FAIL","INFO")) { $st = "INFO" }
          $icon = $(if ($st -in @("PASS","WARN","FAIL")) { Status-Icon $st } else { "•" })
          $step = ($parts[1] + "").Trim()
          $det  = $(if ($parts.Count -ge 3) { ($parts[2] + "").Trim() } else { "" })
          [void]$items.Add([pscustomobject]@{
            Icon   = $icon
            Step   = $step
            Status = $st
            Details= $det
            Time   = ""
          })
        }
      }
    }

    if ($items.Count -eq 0) {
      [void]$items.Add([pscustomobject]@{
        Icon   = "•"
        Step   = "Install progress feed"
        Status = "INFO"
        Details= "File present but no usable lines yet."
        Time   = ""
      })
    }

    return $items
  } catch {
    [void]$items.Add([pscustomobject]@{
      Icon   = (Status-Icon "FAIL")
      Step   = "Install progress feed"
      Status = "FAIL"
      Details= ("Read/parse failed: " + $_.Exception.Message)
      Time   = ""
    })
    return $items
  }
}

# XAML UI
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="FirewallCore Admin Panel (Sprint 2 • Phase A UI only)"
        Height="720" Width="1100"
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

    <TabControl Grid.Row="1" Name="Tabs">
      <TabItem Header="System Checklist">
        <Grid Margin="0,10,0,0">
          <DataGrid Name="Grid"
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
              <DataGridTextColumn Header="" Binding="{Binding Icon}" Width="50"/>

              <DataGridTextColumn Header="Check" Binding="{Binding Check}" Width="*"/>

              <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="120">
                <DataGridTextColumn.ElementStyle>
                  <Style TargetType="TextBlock">
                    <Setter Property="FontWeight" Value="Normal"/>
                    <Setter Property="Foreground" Value="Black"/>
                    <Style.Triggers>
                      <DataTrigger Binding="{Binding Status}" Value="PASS">
                        <Setter Property="Foreground" Value="#1B5E20"/>
                        <Setter Property="FontWeight" Value="Bold"/>
                      </DataTrigger>
                      <DataTrigger Binding="{Binding Status}" Value="WARN">
                        <Setter Property="Foreground" Value="#E65100"/>
                      </DataTrigger>
                      <DataTrigger Binding="{Binding Status}" Value="FAIL">
                        <Setter Property="Foreground" Value="#B71C1C"/>
                      </DataTrigger>
                    </Style.Triggers>
                  </Style>
                </DataGridTextColumn.ElementStyle>
              </DataGridTextColumn>

              <DataGridTextColumn Header="Details" Binding="{Binding Details}" Width="400"/>
              <DataGridTextColumn Header="Suggested Action" Binding="{Binding Action}" Width="260"/>
            </DataGrid.Columns>
          </DataGrid>
        </Grid>
      </TabItem>

      <TabItem Header="Progress Feed (Phase B-ready)">
        <Grid Margin="0,10,0,0">
          <TextBlock Margin="0,0,0,6" Foreground="#444"
                     Text="Reads: C:\Firewall\Logs\Install\InstallProgress.jsonl (installer will write this in Phase B)."/>
          <DataGrid Name="GridProgress"
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
              <DataGridTextColumn Header="" Binding="{Binding Icon}" Width="50"/>
              <DataGridTextColumn Header="Step" Binding="{Binding Step}" Width="*"/>
              <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="120">
                <DataGridTextColumn.ElementStyle>
                  <Style TargetType="TextBlock">
                    <Setter Property="FontWeight" Value="Normal"/>
                    <Setter Property="Foreground" Value="Black"/>
                    <Style.Triggers>
                      <DataTrigger Binding="{Binding Status}" Value="PASS">
                        <Setter Property="Foreground" Value="#1B5E20"/>
                        <Setter Property="FontWeight" Value="Bold"/>
                      </DataTrigger>
                      <DataTrigger Binding="{Binding Status}" Value="WARN">
                        <Setter Property="Foreground" Value="#E65100"/>
                      </DataTrigger>
                      <DataTrigger Binding="{Binding Status}" Value="FAIL">
                        <Setter Property="Foreground" Value="#B71C1C"/>
                      </DataTrigger>
                    </Style.Triggers>
                  </Style>
                </DataGridTextColumn.ElementStyle>
              </DataGridTextColumn>
              <DataGridTextColumn Header="Details" Binding="{Binding Details}" Width="460"/>
              <DataGridTextColumn Header="Time" Binding="{Binding Time}" Width="180"/>
            </DataGrid.Columns>
          </DataGrid>
        </Grid>
      </TabItem>
    </TabControl>

    <GroupBox Grid.Row="2" Header="Repair Options (Phase A UI only)" Margin="0,12,0,0">
      <Grid Margin="10">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="320"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <TextBlock Grid.Row="0" Grid.Column="0" VerticalAlignment="Center" Text="Mode:" Margin="0,0,10,0"/>
        <ComboBox Grid.Row="0" Grid.Column="1" Name="RepairMode" SelectedIndex="0" Height="26">
          <ComboBoxItem Content="Minimal Repair (tasks/health only)"/>
          <ComboBoxItem Content="Full Repair (ApplyPolicy + RestartToast + ArchiveQueue)"/>
        </ComboBox>

        <StackPanel Grid.Row="0" Grid.Column="2" Orientation="Horizontal" Margin="18,0,0,0" VerticalAlignment="Center">
          <CheckBox Name="OptRestartToast" Content="Restart Toast" IsChecked="True" Margin="0,0,14,0"/>
          <CheckBox Name="OptArchiveQueue" Content="Archive Queue" IsChecked="True" Margin="0,0,14,0"/>
          <CheckBox Name="OptApplyPolicy" Content="Re-Apply Policy" IsChecked="False"/>
          <TextBlock Text="  (not wired yet)" Foreground="#555" Margin="14,0,0,0"/>
        </StackPanel>

        <StackPanel Grid.Row="1" Grid.ColumnSpan="3" Orientation="Horizontal" Margin="0,10,0,0" VerticalAlignment="Center">
          <CheckBox Name="AutoRefresh" Content="Auto-refresh" IsChecked="True" Margin="0,0,14,0"/>
          <TextBlock Text="Interval:" VerticalAlignment="Center" Margin="0,0,8,0"/>
          <ComboBox Name="RefreshInterval" Width="140" SelectedIndex="2" Height="26">
            <ComboBoxItem Content="1 sec" Tag="1000"/>
            <ComboBoxItem Content="2 sec" Tag="2000"/>
            <ComboBoxItem Content="5 sec" Tag="5000"/>
            <ComboBoxItem Content="10 sec" Tag="10000"/>
            <ComboBoxItem Content="15 sec" Tag="15000"/>
          </ComboBox>
          <TextBlock Text="  (refreshes checklist + progress feed)" Foreground="#555" Margin="14,0,0,0" VerticalAlignment="Center"/>
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
$gridProg     = $win.FindName("GridProgress")

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

$autoRefresh  = $win.FindName("AutoRefresh")
$intervalBox  = $win.FindName("RefreshInterval")

function Refresh-All {
  Write-Log "Refresh invoked"
  $grid.ItemsSource     = Get-ChecklistItems
  $gridProg.ItemsSource = Get-ProgressItems
}

function PhaseA-Toast([string]$which) {
  Write-Log ("Clicked: " + $which)
  [System.Windows.MessageBox]::Show(($which + " clicked (Phase A UI only). Wiring happens in Phase B."),"FirewallCore Admin Panel") | Out-Null
}

$btnRefresh.Add_Click({ Refresh-All })
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

# Auto-refresh timer (default 5 sec)
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(5000)
$timer.Add_Tick({ Refresh-All })

function Read-IntervalMs {
  try {
    $sel = $intervalBox.SelectedItem
    if ($sel -and $sel.Tag) { return [int]$sel.Tag }
  } catch { }
  return 5000
}

function Apply-AutoRefreshState {
  $ms = Read-IntervalMs
  $timer.Interval = [TimeSpan]::FromMilliseconds($ms)
  if ($autoRefresh.IsChecked) {
    Write-Log ("AutoRefresh ON intervalMs=" + $ms)
    if (-not $timer.IsEnabled) { $timer.Start() }
  } else {
    Write-Log "AutoRefresh OFF"
    if ($timer.IsEnabled) { $timer.Stop() }
  }
}

$autoRefresh.Add_Click({ Apply-AutoRefreshState })
$intervalBox.Add_SelectionChanged({ Apply-AutoRefreshState })

# Initial load + start timer
Refresh-All
Apply-AutoRefreshState

Write-Log "Showing window"
$win.ShowDialog() | Out-Null
Write-Log "Window closed"
