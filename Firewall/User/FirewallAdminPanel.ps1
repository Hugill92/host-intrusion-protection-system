param(
  [int]$DefaultRefreshMs = 5000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-PreferredShellExe {
  param([switch]$AllowPwsh)
  $powershellExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
  if (Test-Path -LiteralPath $powershellExe) {
    if ($AllowPwsh) {
      $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
      if ($pwsh) { return $pwsh }
    }
    return $powershellExe
  }
  $fallback = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
  if ($fallback) { return $fallback }
  if ($AllowPwsh) {
    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if ($pwsh) { return $pwsh }
  }
  return 'powershell.exe'
}

# Ensure STA (WPF)
try {
  if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne "STA") {
    $self = $PSCommandPath
    if (-not $self) { throw "Cannot resolve script path for STA relaunch." }
    $psExe = Resolve-PreferredShellExe
    Start-Process $psExe -WindowStyle Normal -ArgumentList @(
      "-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-STA",
      "-File", $self,
      "-DefaultRefreshMs", $DefaultRefreshMs
    ) | Out-Null
    return
  }
} catch {
  throw
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml | Out-Null
try { Add-Type -AssemblyName Microsoft.VisualBasic | Out-Null } catch { }

$script:AdminPanelMutex = $null
try {
  $mutexName = 'Local\\FirewallCore.AdminPanel'
  $createdNew = $false
  $script:AdminPanelMutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
  if (-not $createdNew) {
    try {
      [System.Windows.MessageBox]::Show('FirewallCore Admin Panel is already running.','FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information) | Out-Null
    } catch {
      Write-Host 'FirewallCore Admin Panel is already running.'
    }
    return
  }
} catch [System.Threading.AbandonedMutexException] {
  # Treat abandoned mutex as acquired.
} catch {
  # If mutex creation fails, continue without blocking.
}

$script:UseGlyphIcons = $false
try {
  $mdl2 = [System.Windows.Media.Fonts]::SystemFontFamilies |
    Where-Object { $_.Source -eq 'Segoe MDL2 Assets' } |
    Select-Object -First 1
  if ($mdl2) { $script:UseGlyphIcons = $true }
} catch {
  $script:UseGlyphIcons = $false
}
$global:UseGlyphIcons = $script:UseGlyphIcons

function Get-StatusIconFont {
  $useGlyph = $script:UseGlyphIcons
  if ($null -eq $useGlyph) {
    try { $useGlyph = $global:UseGlyphIcons } catch { $useGlyph = $false }
  }
  if ($useGlyph) { return 'Segoe MDL2 Assets' }
  return 'Segoe UI'
}

function Get-StatusIcon {
  param([string]$Status)
  $key = if ($Status) { $Status.ToUpperInvariant() } else { '' }

  $useGlyph = $script:UseGlyphIcons
  if ($null -eq $useGlyph) {
    try { $useGlyph = $global:UseGlyphIcons } catch { $useGlyph = $false }
  }
  if ($useGlyph) {
    switch ($key) {
      'PASS' { return [char]0xE73E }
      'WARN' { return [char]0xE7BA }
      'FAIL' { return [char]0xE711 }
      'RUNNING' { return [char]0xE823 }
      default { return '' }
    }
  }

  switch ($key) {
    'PASS' { return '[OK]' }
    'WARN' { return '[!]' }
    'FAIL' { return '[X]' }
    'RUNNING' { return '[~]' }
    default { return '' }
  }
}

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-TaskState {
  param([string]$Name)
  $t = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
  if (-not $t) { return $null }
  return $t.State.ToString()
}

function Get-TaskLastResult {
  param([string]$Name)
  try {
    $i = Get-ScheduledTaskInfo -TaskName $Name -ErrorAction Stop
    return [pscustomobject]@{
      LastRunTime   = $i.LastRunTime
      LastTaskResult= $i.LastTaskResult
      NextRunTime   = $i.NextRunTime
    }
  } catch { return $null }
}

function Get-ToastListenerPid {
  $p = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'FirewallToastListener\.ps1' } |
    Select-Object -First 1
  if ($p) { return $p.ProcessId }
  return $null
}

function Get-LatestWindowsFirewallLoggingSnapshot {
  param([string]$ReportsPath = 'C:\ProgramData\FirewallCore\Reports')
  try {
    if (Test-Path -LiteralPath $ReportsPath) {
      return Get-ChildItem -Path $ReportsPath -Filter 'WindowsFirewallLogging_*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    }
  } catch { }
  return $null
}

function Get-OptionalValue {
  param(
    [Parameter(Mandatory=$false)] [object] $Obj,
    [Parameter(Mandatory=$true)]  [string] $Key,
    [Parameter(Mandatory=$false)] $Default = $null
  )
  if ($null -eq $Obj) { return $Default }

  if ($Obj -is [hashtable]) {
    if ($Obj.ContainsKey($Key)) { return $Obj[$Key] }
    return $Default
  }

  $p = $Obj.PSObject.Properties.Match($Key) | Select-Object -First 1
  if ($p) { return $p.Value }
  return $Default
}

function Show-InputPrompt {
  param(
    [Parameter(Mandatory)][string]$Prompt,
    [Parameter(Mandatory)][string]$Title
  )
  try {
    return [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, $Title, '')
  } catch {
    return $null
  }
}

function Get-DevUnlockHashPath {
  return (Join-Path $env:ProgramData 'FirewallCore\DevMode.unlockhash')
}

function Get-StringHash {
  param([Parameter(Mandatory)][string]$Value)
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash($bytes)
    $sha.Dispose()
    return ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
  } catch {
    return $null
  }
}

function Read-DevUnlockHash {
  param([Parameter(Mandatory)][string]$Path)
  try {
    if (Test-Path -LiteralPath $Path) {
      return (Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue).Trim()
    }
  } catch { }
  return $null
}

function Write-DevUnlockHash {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Hash
  )
  try {
    $dir = Split-Path -Parent $Path
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Set-Content -LiteralPath $Path -Value $Hash -Encoding ASCII
  } catch { }
}

function Test-DevUnlock {
  param([Parameter(Mandatory)][string]$HashPath)
  $title = 'FirewallCore Admin Panel'
  $stored = Read-DevUnlockHash -Path $HashPath

  if (-not $stored) {
    $first = Show-InputPrompt -Prompt 'Set a Dev/Lab unlock passphrase:' -Title $title
    if ([string]::IsNullOrWhiteSpace($first)) {
      return [pscustomobject]@{ Ok = $false; Message = 'Passphrase setup cancelled.' }
    }
    $second = Show-InputPrompt -Prompt 'Re-enter passphrase to confirm:' -Title $title
    if ($first -ne $second) {
      return [pscustomobject]@{ Ok = $false; Message = 'Passphrase mismatch.' }
    }
    $hash = Get-StringHash -Value $first
    if (-not $hash) {
      return [pscustomobject]@{ Ok = $false; Message = 'Passphrase setup failed.' }
    }
    Write-DevUnlockHash -Path $HashPath -Hash $hash
    return [pscustomobject]@{ Ok = $true; Message = 'Passphrase set.' }
  }

  $entered = Show-InputPrompt -Prompt 'Enter Dev/Lab passphrase to unlock:' -Title $title
  if ([string]::IsNullOrWhiteSpace($entered)) {
    return [pscustomobject]@{ Ok = $false; Message = 'Passphrase entry cancelled.' }
  }
  $hash = Get-StringHash -Value $entered
  if ($hash -and ($hash -eq $stored)) {
    return [pscustomobject]@{ Ok = $true; Message = 'Passphrase verified.' }
  }
  return [pscustomobject]@{ Ok = $false; Message = 'Passphrase mismatch.' }
}

function New-Row {
  param(
    [string]$Check,
    [string]$Status,
    [string]$Details,
    [string]$SuggestedAction,
    [string]$HelpLabel,
    [string]$HelpAction,
    [string]$HelpTarget,
    [string[]]$HelpScriptCandidates,
    [object[]]$HelpMenu,
    [string]$HelpStatus,
    [bool]$DetailsWrap = $false
  )
  $statusText = if ($Status) { $Status.ToUpperInvariant() } else { '' }
  [pscustomobject]@{
    Check          = $Check
    Status         = $statusText
    StatusIcon     = (Get-StatusIcon -Status $statusText)
    StatusIconFont = (Get-StatusIconFont)
    Details        = $Details
    SuggestedAction= $SuggestedAction
    HelpLabel      = if ($HelpLabel) { $HelpLabel } else { '' }
    HelpAction     = if ($HelpAction) { $HelpAction } else { '' }
    HelpTarget     = if ($HelpTarget) { $HelpTarget } else { $null }
    HelpScripts    = if ($HelpScriptCandidates) { $HelpScriptCandidates } else { @() }
    HelpMenu       = if ($HelpMenu) { @($HelpMenu) } else { @() }
    HelpStatus     = if ($HelpStatus) { $HelpStatus } else { '' }
    RowHighlight   = $false
    DetailsWrap    = [bool]$DetailsWrap
  }
}

function Copy-RowWithHighlight {
  param(
    [Parameter(Mandatory)][object]$Row,
    [bool]$Highlight
  )
  [pscustomobject]@{
    Check          = $Row.Check
    Status         = $Row.Status
    StatusIcon     = $Row.StatusIcon
    StatusIconFont = $Row.StatusIconFont
    Details        = $Row.Details
    SuggestedAction= $Row.SuggestedAction
    HelpLabel      = $Row.HelpLabel
    HelpAction     = $Row.HelpAction
    HelpTarget     = $Row.HelpTarget
    HelpScripts    = $Row.HelpScripts
    HelpMenu       = $Row.HelpMenu
    HelpStatus     = $Row.HelpStatus
    RowHighlight   = [bool]$Highlight
    DetailsWrap    = $Row.DetailsWrap
  }
}

function Invoke-Checklist {
  $rows = @()

  # Paths (installer-root based)
  $logsPath = 'C:\ProgramData\FirewallCore\Logs'
  $paths = @(
    @{
      Label = "Defender integration script"
      Path = "C:\Firewall\Maintenance\Enable-DefenderIntegration.ps1"
      HelpLabel = "Open Logs"
      HelpAction = "OpenFolder"
      HelpTarget = $logsPath
    },
    @{
      Label = "User alert notifications"
      Path = "C:\Firewall\User\FirewallToastListener.ps1"
      HelpLabel = "Open Logs"
      HelpAction = "OpenFolder"
      HelpTarget = $logsPath
    },
    @{
      Label = "User alert action handler"
      Path = "C:\Firewall\User\FirewallToastActivate.ps1"
      HelpLabel = "Open Event Viewer"
      HelpAction = "OpenEventViewer"
      HelpTarget = "eventvwr.msc"
    }
  )

  # Admin
  if (Test-IsAdmin) {
    $rows += New-Row "Admin session" "PASS" "Running elevated" "None"
  } else {
    $rows += New-Row -Check "Admin session" -Status "FAIL" -Details "Not elevated" -SuggestedAction "Relaunch as Administrator" -HelpLabel "Open Logs" -HelpAction "OpenFolder" -HelpTarget $logsPath
  }

  foreach ($p in $paths) {
    if (Test-Path -LiteralPath $p.Path) {
      $rows += New-Row $p.Label "PASS" "Present" "None"
    } else {
      $detail = "Missing. Run Install or Repair to stage."
      $rows += New-Row -Check $p.Label -Status "FAIL" -Details $detail -SuggestedAction $p.HelpLabel -HelpLabel $p.HelpLabel -HelpAction $p.HelpAction -HelpTarget $p.HelpTarget
    }
  }

  # Tasks
  $taskNames = @(
    "Firewall Tamper Guard",
    "Firewall User Notifier",
    "Firewall-Defender-Integration",
    "FirewallCore Toast Listener",
    "FirewallCore Toast Watchdog"
  )

  $taskDisplayNames = @{
    "FirewallCore Toast Listener" = "FirewallCore Notification Listener"
    "FirewallCore Toast Watchdog" = "FirewallCore Notification Watchdog"
  }

  foreach ($tn in $taskNames) {
    $displayName = if ($taskDisplayNames.ContainsKey($tn)) { $taskDisplayNames[$tn] } else { $tn }
    $state = Get-TaskState -Name $tn
    if (-not $state) {
      $rows += New-Row -Check ("Scheduled task: " + $displayName) -Status "FAIL" -Details "Not registered. Run Repair to register." -SuggestedAction "Open Task Scheduler" -HelpLabel "Open Task Scheduler" -HelpAction "OpenTaskScheduler" -HelpTarget "taskschd.msc"
      continue
    }

    if ($state -eq "Ready" -or $state -eq "Running") {
      $rows += New-Row ("Scheduled task: " + $displayName) "PASS" ("State: " + $state) "None"
    } else {
      $warnDetail = "State: " + $state + ". Run Repair if needed."
      $rows += New-Row -Check ("Scheduled task: " + $displayName) -Status "WARN" -Details $warnDetail -SuggestedAction "Open Task Scheduler" -HelpLabel "Open Task Scheduler" -HelpAction "OpenTaskScheduler" -HelpTarget "taskschd.msc"
    }
  }

  # Rules count (inventory only)
  $reportsFolder = 'C:\ProgramData\FirewallCore\Reports'
  $reportScripts = @(
    'C:\Firewall\Tools\Run-RulesReport.ps1',
    'C:\Firewall\Tools\Run-InboundRiskReport.ps1'
  )
  $rulesSuggested = "Run Rules Report"
  try {
    $rules = Get-NetFirewallRule -ErrorAction Stop
    $ruleList = @($rules)
    $cnt = @($ruleList).Count

    $v1 = @($ruleList | Where-Object { $_.Group -match '(?i)FirewallCore\\s*v1|FirewallCorev1' }).Count
    $v2 = @($ruleList | Where-Object { $_.Group -match '(?i)FirewallCore\\s*v2|FirewallCorev2' }).Count
    $v3 = @($ruleList | Where-Object { $_.Group -match '(?i)FirewallCore\\s*v3|FirewallCorev3' }).Count
    $owned = $v1 + $v2 + $v3
    $nonOwned = [Math]::Max(0, ($cnt - $owned))

    $details = "Total: $cnt | Owned: FirewallCorev1=$v1, FirewallCorev2=$v2, FirewallCorev3=$v3 | Non-owned: $nonOwned"
    if ($cnt -gt 0) {
      $rows += New-Row -Check "Firewall rules inventory" -Status "PASS" -Details $details -SuggestedAction $rulesSuggested -HelpLabel $rulesSuggested -HelpAction "RunRulesReport" -HelpTarget $reportsFolder -HelpScriptCandidates $reportScripts -DetailsWrap $true
    } else {
      $rows += New-Row -Check "Firewall rules inventory" -Status "WARN" -Details $details -SuggestedAction $rulesSuggested -HelpLabel $rulesSuggested -HelpAction "RunRulesReport" -HelpTarget $reportsFolder -HelpScriptCandidates $reportScripts -DetailsWrap $true
    }
  } catch {
    $rows += New-Row -Check "Firewall rules inventory" -Status "WARN" -Details ("Query failed: " + $_.Exception.Message) -SuggestedAction $rulesSuggested -HelpLabel $rulesSuggested -HelpAction "RunRulesReport" -HelpTarget $reportsFolder -HelpScriptCandidates $reportScripts -DetailsWrap $true
  }

  # Firewall traffic logging (WFAS)
  $profileLogDir = 'C:\ProgramData\FirewallCore\Logs\WindowsFirewall'
  $expectedLogFiles = @{
    Domain  = (Join-Path $profileLogDir 'domainfirewall.log')
    Private = (Join-Path $profileLogDir 'privatefirewall.log')
    Public  = (Join-Path $profileLogDir 'publicfirewall.log')
  }
  $expectedAllowed = $true
  $expectedBlocked = $true
  $expectedMaxKb = 16384
  $wfasHelpMenu = @(
    [pscustomobject]@{
      Check = 'Firewall traffic logging (WFAS)'
      HelpLabel = 'Open firewall traffic logs'
      HelpAction = 'OpenWindowsFirewallLogs'
      HelpTarget = $profileLogDir
      HelpScripts = @()
    },
    [pscustomobject]@{
      Check = 'Firewall traffic logging (WFAS)'
      HelpLabel = 'Apply firewall logging baseline'
      HelpAction = 'RunScript'
      HelpTarget = $null
      HelpScripts = @(
        'C:\Firewall\Tools\Configure-WFASProfileLogging.ps1',
        'C:\FirewallInstaller\Tools\Configure-WFASProfileLogging.ps1'
      )
    },
    [pscustomobject]@{
      Check = 'Firewall traffic logging (WFAS)'
      HelpLabel = 'Open WFAS properties'
      HelpAction = 'OpenFile'
      HelpTarget = 'wf.msc'
      HelpScripts = @()
    }
  )
  try {
    $profiles = @('Domain','Private','Public')
    $profileSummaries = @()
    $hasIssue = $false
    foreach ($profile in $profiles) {
      $p = Get-NetFirewallProfile -Profile $profile -ErrorAction Stop
      $logFile = $p.LogFileName
      $allowed = [bool]$p.LogAllowed
      $blocked = [bool]$p.LogBlocked
      $maxKb = [int]$p.LogMaxSizeKilobytes
      $expectedFile = $expectedLogFiles[$profile]

      $pathOk = $false
      if ($logFile) {
        $prefix = $profileLogDir.TrimEnd('\') + '\'
        $pathOk = $logFile.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
      }

      $fileOk = $false
      if ($logFile -and $expectedFile) {
        if ($logFile -ieq $expectedFile) { $fileOk = $true }
      }

      $sizeOk = ($maxKb -ge $expectedMaxKb)
      $trafficOk = ($allowed -eq $expectedAllowed) -and ($blocked -eq $expectedBlocked)
      if (-not ($pathOk -and $fileOk -and $sizeOk -and $trafficOk)) { $hasIssue = $true }

      $trafficLabel = if ($allowed -and $blocked) {
        'allowed+blocked'
      } elseif ($allowed) {
        'allowed only'
      } elseif ($blocked) {
        'blocked only'
      } else {
        'off'
      }
      $sizeLabel = if ($maxKb -ge 1024) { "{0}MB" -f [Math]::Round(($maxKb / 1024), 0) } else { "{0}KB" -f $maxKb }
      $fileLabel = if ($logFile) { Split-Path -Leaf $logFile } else { '<unset>' }
      $profileSummaries += ("{0}: {1} | {2} | {3}" -f $profile, $trafficLabel, $sizeLabel, $fileLabel)
    }
    $details = $profileSummaries -join ' | '
    $status = if ($hasIssue) { 'WARN' } else { 'PASS' }
    $suggestedAction = if ($hasIssue) { 'Apply firewall logging baseline' } else { 'None' }
    $rows += New-Row -Check "Firewall traffic logging (WFAS)" -Status $status -Details $details -SuggestedAction $suggestedAction -HelpLabel "Actions" -HelpAction "OpenWindowsFirewallLogs" -HelpTarget $profileLogDir -HelpMenu $wfasHelpMenu -DetailsWrap $true
  } catch {
    $rows += New-Row -Check "Firewall traffic logging (WFAS)" -Status "FAIL" -Details ("Query failed: " + $_.Exception.Message) -SuggestedAction "Apply firewall logging baseline" -HelpLabel "Actions" -HelpAction "OpenWindowsFirewallLogs" -HelpTarget $profileLogDir -HelpMenu $wfasHelpMenu -DetailsWrap $true
  }

  # Notification listener PID
  $toastPid = Get-ToastListenerPid
  if ($toastPid) {
    $rows += New-Row "User alert engine process" "PASS" ("PID: " + $toastPid) "None"
  } else {
    $rows += New-Row -Check "User alert engine process" -Status "WARN" -Details "Not detected. Run Repair to restart notifications." -SuggestedAction "Open Logs" -HelpLabel "Open Logs" -HelpAction "OpenFolder" -HelpTarget $logsPath
  }

  return $rows
}

# XAML (Phase B UI + wiring)
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="FirewallCore Admin Panel (Sprint 2 - Phase B)"
        Height="820" Width="1200" MinHeight="720" MinWidth="1000"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResize"
        ShowActivated="True" ShowInTaskbar="True"
        Background="{DynamicResource PanelBackground}"
        Foreground="{DynamicResource PanelForeground}">
  <Window.Resources>
    <SolidColorBrush x:Key="PanelBackground" Color="#F5F6F8"/>
    <SolidColorBrush x:Key="PanelForeground" Color="#1C1E21"/>
    <SolidColorBrush x:Key="PanelBorder" Color="#C8CCD4"/>
    <SolidColorBrush x:Key="ControlBackground" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="ControlBorder" Color="#C8CCD4"/>
    <SolidColorBrush x:Key="ControlForeground" Color="#1C1E21"/>
    <SolidColorBrush x:Key="AccentBrush" Color="#2B6CB0"/>

    <Style TargetType="GroupBox">
      <Setter Property="Background" Value="{DynamicResource PanelBackground}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource PanelForeground}"/>
      <Setter Property="HeaderTemplate">
        <Setter.Value>
          <DataTemplate>
            <TextBlock Text="{Binding}" Foreground="{DynamicResource AccentBrush}"/>
          </DataTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="Button">
      <Setter Property="Background" Value="{DynamicResource ControlBackground}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource ControlForeground}"/>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Background" Value="{DynamicResource ControlBackground}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource ControlForeground}"/>
    </Style>
    <Style TargetType="DataGrid">
      <Setter Property="Background" Value="{DynamicResource ControlBackground}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource PanelBorder}"/>
      <Setter Property="Foreground" Value="{DynamicResource ControlForeground}"/>
      <Setter Property="RowBackground" Value="{DynamicResource ControlBackground}"/>
    </Style>
  </Window.Resources>

  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Grid Grid.Row="0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBlock Grid.Column="0" FontSize="16" FontWeight="Bold"
                 VerticalAlignment="Center"
                 Text="System checklist and actions" />
      <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
        <TextBlock Text="Theme:" Margin="0,0,6,0" VerticalAlignment="Center"/>
        <ComboBox x:Name="ThemeSelect" Width="120" Margin="0,0,12,0">
          <ComboBoxItem Content="System"/>
          <ComboBoxItem Content="Light"/>
          <ComboBoxItem Content="Dark"/>
        </ComboBox>
        <TextBlock Text="Accent:" Margin="0,0,6,0" VerticalAlignment="Center"/>
        <ComboBox x:Name="AccentSelect" Width="120">
          <ComboBoxItem Content="Blue"/>
          <ComboBoxItem Content="Gray"/>
          <ComboBoxItem Content="Green"/>
          <ComboBoxItem Content="Teal"/>
        </ComboBox>
      </StackPanel>
    </Grid>

    <ScrollViewer Grid.Row="1" Margin="0,10,0,10" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
      <StackPanel>
        <TextBlock x:Name="TxtRefreshStatus" Margin="0,0,0,6" Opacity="0.75"/>
        <ProgressBar x:Name="ProgressRefresh" Height="6" Margin="0,0,0,8" Minimum="0" Maximum="100" Value="0" Visibility="Collapsed"/>
        <DataGrid x:Name="GridChecklist" Margin="0,0,0,12"
                  AutoGenerateColumns="False" CanUserAddRows="False" IsReadOnly="True" MinRowHeight="28"
                  HeadersVisibility="Column" GridLinesVisibility="All"
                  CanUserResizeColumns="True" CanUserReorderColumns="True"
                  EnableRowVirtualization="True" EnableColumnVirtualization="True"
                  VirtualizingPanel.IsVirtualizing="True" VirtualizingPanel.VirtualizationMode="Recycling"
                  ScrollViewer.CanContentScroll="True"
                  ScrollViewer.VerticalScrollBarVisibility="Disabled"
                  ScrollViewer.HorizontalScrollBarVisibility="Auto">
          <DataGrid.RowStyle>
            <Style TargetType="DataGridRow">
              <Setter Property="MinHeight" Value="28"/>
              <Setter Property="VerticalContentAlignment" Value="Center"/>
              <Style.Triggers>
                <DataTrigger Binding="{Binding RowHighlight}" Value="True">
                  <Setter Property="Background" Value="#FFF9E5"/>
                </DataTrigger>
              </Style.Triggers>
            </Style>
          </DataGrid.RowStyle>
          <DataGrid.ColumnHeaderStyle>
            <Style TargetType="DataGridColumnHeader">
              <Setter Property="FontWeight" Value="Bold"/>
              <Setter Property="Foreground" Value="{DynamicResource AccentBrush}"/>
            </Style>
          </DataGrid.ColumnHeaderStyle>
          <DataGrid.Columns>
            <DataGridTextColumn Header="Check" Binding="{Binding Check}" Width="200" MinWidth="180" MaxWidth="320">
              <DataGridTextColumn.ElementStyle>
                <Style TargetType="TextBlock">
                  <Setter Property="TextWrapping" Value="Wrap"/>
                  <Setter Property="MaxHeight" Value="36"/>
                  <Setter Property="TextTrimming" Value="CharacterEllipsis"/>
                  <Setter Property="VerticalAlignment" Value="Center"/>
                  <Setter Property="ToolTip" Value="{Binding Check}"/>
                </Style>
              </DataGridTextColumn.ElementStyle>
            </DataGridTextColumn>
            <DataGridTemplateColumn Header="Status" Width="100">
              <DataGridTemplateColumn.CellStyle>
                <Style TargetType="DataGridCell">
                  <Setter Property="FontWeight" Value="Bold"/>
                  <Setter Property="Background" Value="White"/>
                  <Setter Property="Foreground" Value="Black"/>
                  <Style.Triggers>
                    <DataTrigger Binding="{Binding Status}" Value="PASS">
                      <Setter Property="Background" Value="#E2F3E8"/>
                      <Setter Property="Foreground" Value="#1B5E20"/>
                    </DataTrigger>
                    <DataTrigger Binding="{Binding Status}" Value="WARN">
                      <Setter Property="Background" Value="#FFF4D2"/>
                      <Setter Property="Foreground" Value="#8A5A00"/>
                    </DataTrigger>
                    <DataTrigger Binding="{Binding Status}" Value="FAIL">
                      <Setter Property="Background" Value="#FBE3E3"/>
                      <Setter Property="Foreground" Value="#8B0000"/>
                    </DataTrigger>
                  </Style.Triggers>
                </Style>
              </DataGridTemplateColumn.CellStyle>
              <DataGridTemplateColumn.CellTemplate>
                <DataTemplate>
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="{Binding StatusIcon}" FontFamily="{Binding StatusIconFont}" FontSize="14" Margin="0,0,6,0"/>
                    <TextBlock Text="{Binding Status}"/>
                  </StackPanel>
                </DataTemplate>
              </DataGridTemplateColumn.CellTemplate>
            </DataGridTemplateColumn>
            <DataGridTextColumn Header="Details" Binding="{Binding Details}" Width="360" MinWidth="280" MaxWidth="520">
              <DataGridTextColumn.ElementStyle>
                <Style TargetType="TextBlock">
                  <Setter Property="TextWrapping" Value="Wrap"/>
                  <Setter Property="MaxHeight" Value="48"/>
                  <Setter Property="TextTrimming" Value="CharacterEllipsis"/>
                  <Setter Property="VerticalAlignment" Value="Center"/>
                  <Setter Property="ToolTip" Value="{Binding Details}"/>
                </Style>
              </DataGridTextColumn.ElementStyle>
            </DataGridTextColumn>
            <DataGridTextColumn Header="Suggested Action" Binding="{Binding SuggestedAction}" Width="220" MinWidth="200" MaxWidth="320">
              <DataGridTextColumn.ElementStyle>
                <Style TargetType="TextBlock">
                  <Setter Property="TextWrapping" Value="Wrap"/>
                  <Setter Property="MaxHeight" Value="36"/>
                  <Setter Property="TextTrimming" Value="CharacterEllipsis"/>
                  <Setter Property="VerticalAlignment" Value="Center"/>
                  <Setter Property="ToolTip" Value="{Binding SuggestedAction}"/>
                </Style>
              </DataGridTextColumn.ElementStyle>
            </DataGridTextColumn>
            <DataGridTemplateColumn Header="Help" Width="240">
              <DataGridTemplateColumn.CellTemplate>
                <DataTemplate>
                  <Grid VerticalAlignment="Center">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Button Grid.Column="0" Content="{Binding HelpLabel}" Tag="{Binding}" Padding="6,2">
                      <Button.Style>
                        <Style TargetType="Button">
                          <Setter Property="Visibility" Value="Visible"/>
                          <Style.Triggers>
                            <DataTrigger Binding="{Binding HelpLabel}" Value="">
                              <Setter Property="Visibility" Value="Collapsed"/>
                            </DataTrigger>
                          </Style.Triggers>
                        </Style>
                      </Button.Style>
                    </Button>
                    <TextBlock Grid.Column="1" Text="{Binding HelpStatus}" Margin="6,0,0,0" VerticalAlignment="Center" TextTrimming="CharacterEllipsis">
                      <TextBlock.Style>
                        <Style TargetType="TextBlock">
                          <Setter Property="Visibility" Value="Visible"/>
                          <Style.Triggers>
                            <DataTrigger Binding="{Binding HelpStatus}" Value="">
                              <Setter Property="Visibility" Value="Collapsed"/>
                            </DataTrigger>
                          </Style.Triggers>
                        </Style>
                      </TextBlock.Style>
                    </TextBlock>
                  </Grid>
                </DataTemplate>
              </DataGridTemplateColumn.CellTemplate>
            </DataGridTemplateColumn>
          </DataGrid.Columns>
        </DataGrid>

        <Grid x:Name="ActionPanels">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>

          <GroupBox Grid.Row="0" Grid.Column="0" Header="Repair Options" Margin="0,0,6,8">
            <StackPanel Margin="10">
              <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                <TextBlock VerticalAlignment="Center" Text="Refresh interval:" Margin="0,0,8,0"/>
                <ComboBox x:Name="IntervalCombo" Width="160" SelectedIndex="1" IsEnabled="False">
                  <ComboBoxItem Content="2 sec" Tag="2000"/>
                  <ComboBoxItem Content="5 sec" Tag="5000"/>
                  <ComboBoxItem Content="10 sec" Tag="10000"/>
                  <ComboBoxItem Content="15 sec" Tag="15000"/>
                </ComboBox>
                <CheckBox x:Name="ChkAutoRefresh" Margin="12,0,0,0" VerticalAlignment="Center" Content="Auto-refresh" IsChecked="False" IsEnabled="False"/>
              </StackPanel>

              <StackPanel Margin="0,8,0,0">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                  <TextBlock VerticalAlignment="Center" Text="Repair options:" Margin="0,0,8,0"/>
                  <CheckBox x:Name="ChkRestartNotifications" Margin="0,0,12,0" VerticalAlignment="Center" Content="Restart notifications" IsChecked="True"/>
                  <CheckBox x:Name="ChkArchiveQueue" Margin="0,0,12,0" VerticalAlignment="Center" Content="Archive queue" IsChecked="True"/>
                  <CheckBox x:Name="ChkReapplyPolicy" Margin="0,0,12,0" VerticalAlignment="Center" Content="Re-apply policy"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,6,0,0">
                  <Button x:Name="BtnApplyRepair" Width="120" Margin="0,0,6,0" Content="Apply Selected"/>
                  <Button x:Name="BtnResetRepair" Width="120" Margin="6,0,0,0" Content="Reset Defaults"/>
                </StackPanel>
              </StackPanel>

              <TextBlock x:Name="TxtRepairStatus" Margin="0,6,0,0" Opacity="0.75"/>
            </StackPanel>
          </GroupBox>

          <GroupBox Grid.Row="0" Grid.Column="1" Header="System Actions" Margin="6,0,0,8">
            <StackPanel Margin="10">
              <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                <TextBlock Text="Action:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                <ComboBox x:Name="SystemActionSelect" Width="220"/>
                <Button x:Name="BtnRunAction" Width="120" Margin="8,0,0,0" Content="Run Action"/>
              </StackPanel>
              <TextBlock x:Name="TxtActionStatus" Margin="0,6,0,0" Opacity="0.75"/>
            </StackPanel>
          </GroupBox>

          <ContentControl x:Name="TestsHost" Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="2"/>
        </Grid>
      </StackPanel>
    </ScrollViewer>

    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,4,0,0">
      <Button x:Name="BtnClose" Width="110" Content="Close"/>
    </StackPanel>
  </Grid>
</Window>
"@

# Build window safely
$win = [Windows.Markup.XamlReader]::Parse($xaml)
$win.Add_Closed({
  if ($script:AdminPanelMutex) {
    try { $script:AdminPanelMutex.ReleaseMutex() | Out-Null } catch { }
    try { $script:AdminPanelMutex.Dispose() } catch { }
    $script:AdminPanelMutex = $null
  }
})
$script:FocusApplied = $false
$win.Add_Loaded({
  if ($script:FocusApplied) { return }
  $script:FocusApplied = $true
  try {
    $win.ShowInTaskbar = $true
    $win.ShowActivated = $true
    $null = $win.Activate()
    $win.Topmost = $true
    $win.Topmost = $false
    $null = $win.Focus()
  } catch { }
  try {
    $null = $win.Dispatcher.BeginInvoke([Action]{
      try {
        $null = $win.Activate()
        $win.Topmost = $true
        $win.Topmost = $false
        $null = $win.Focus()
      } catch { }
    }, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle)
  } catch { }
})
$grid = $win.FindName("GridChecklist")
$txtRefreshStatus = $win.FindName("TxtRefreshStatus")
$progressRefresh = $win.FindName("ProgressRefresh")
$themeSelect = $win.FindName("ThemeSelect")
$accentSelect = $win.FindName("AccentSelect")
$btnClose   = $win.FindName("BtnClose")
$chkAuto    = $win.FindName("ChkAutoRefresh")
$combo      = $win.FindName("IntervalCombo")
$chkRestart = $win.FindName("ChkRestartNotifications")
$chkArchive = $win.FindName("ChkArchiveQueue")
$chkReapply = $win.FindName("ChkReapplyPolicy")
$btnApplyRepair = $win.FindName("BtnApplyRepair")
$btnResetRepair = $win.FindName("BtnResetRepair")
$txtRepairStatus = $win.FindName("TxtRepairStatus")
$systemActionSelect = $win.FindName("SystemActionSelect")
$btnRunAction = $win.FindName("BtnRunAction")
$txtActionStatus = $win.FindName("TxtActionStatus")

$script:ThemeInitializing = $true
if ($themeSelect -and $accentSelect) {
  $settings = Load-ThemeSettings
  Select-ComboValue -Combo $themeSelect -Value $settings.Theme
  Select-ComboValue -Combo $accentSelect -Value $settings.Accent
  Apply-Theme -ThemeName $settings.Theme -AccentName $settings.Accent
  $script:ThemeInitializing = $false

  $themeSelect.Add_SelectionChanged({
    if ($script:ThemeInitializing) { return }
    $theme = $themeSelect.SelectedItem.Content
    $accent = $accentSelect.SelectedItem.Content
    Apply-Theme -ThemeName $theme -AccentName $accent
    Save-ThemeSettings -Theme $theme -Accent $accent
  })

  $accentSelect.Add_SelectionChanged({
    if ($script:ThemeInitializing) { return }
    $theme = $themeSelect.SelectedItem.Content
    $accent = $accentSelect.SelectedItem.Content
    Apply-Theme -ThemeName $theme -AccentName $accent
    Save-ThemeSettings -Theme $theme -Accent $accent
  })
} else {
  Apply-Theme -ThemeName 'System' -AccentName 'Blue'
  $script:ThemeInitializing = $false
}

$ActionScripts = @{
  Refresh       = @("C:\Firewall\Tools\Run-QuickHealthCheck.ps1")
  Install       = @("C:\FirewallInstaller\Install.cmd","C:\Firewall\Install.cmd")
  Repair        = @("C:\Firewall\Repair.cmd","C:\FirewallInstaller\Repair.cmd","C:\Firewall\Tools\Repair-FirewallCore.ps1")
  Maintenance   = @("C:\Firewall\Tools\Maintenance-FirewallCore.ps1","C:\FirewallInstaller\Tools\Maintenance-FirewallCore.ps1")
  Uninstall     = @("C:\Firewall\Uninstall.cmd","C:\FirewallInstaller\Uninstall.cmd")
  CleanUninstall= @("C:\Firewall\Uninstall-Clean.cmd","C:\FirewallInstaller\Uninstall-Clean.cmd")
}

$ChecklistRefreshLock = 0
$script:SystemActions = @(
  @{ Name = 'Refresh'; ScriptCandidates = $ActionScripts.Refresh; Confirm = $false; ApplyChecklist = $true },
  @{ Name = 'Install'; ScriptCandidates = $ActionScripts.Install; Confirm = $false; ApplyChecklist = $false },
  @{ Name = 'Repair'; ScriptCandidates = $ActionScripts.Repair; Confirm = $false; ApplyChecklist = $false },
  @{ Name = 'Maintenance'; ScriptCandidates = $ActionScripts.Maintenance; Confirm = $false; ApplyChecklist = $false },
  @{ Name = 'Uninstall'; ScriptCandidates = $ActionScripts.Uninstall; Confirm = $true; ApplyChecklist = $false },
  @{ Name = 'Clean Uninstall'; ScriptCandidates = $ActionScripts.CleanUninstall; Confirm = $true; ApplyChecklist = $false }
)

$script:RepairDefaults = @{
  RestartNotifications = $true
  ArchiveQueue = $true
  ReapplyPolicy = $false
}

function Set-RepairStatusText {
  param([string]$Text)
  try {
    if ($txtRepairStatus) { $txtRepairStatus.Text = $Text }
  } catch { }
}

function Set-TestStatusText {
  param([string]$Text)
  try {
    if ($Text) {
      $testsHost = $win.FindName('TestsHost')
      if ($testsHost -and $testsHost.Content) {
        $status = $testsHost.Content.FindName('TxtTestStatus')
        if ($status) { $status.Text = $Text }
      }
    }
  } catch { }
}

function Set-DevStatusText {
  param([string]$Text)
  try {
    if ($Text) {
      $testsHost = $win.FindName('TestsHost')
      if ($testsHost -and $testsHost.Content) {
        $status = $testsHost.Content.FindName('TxtDevStatus')
        if ($status) { $status.Text = $Text }
      }
    }
  } catch { }
}

function Set-ActionStatusText {
  param([string]$Text)
  try {
    if ($txtActionStatus) { $txtActionStatus.Text = $Text }
  } catch { }
}

function Set-RefreshStatusText {
  param([string]$Text)
  try {
    if ($txtRefreshStatus) { $txtRefreshStatus.Text = $Text }
  } catch { }
}

function Get-ThemeSettingsPath {
  return (Join-Path $env:ProgramData 'FirewallCore\User\Settings\AdminPanelTheme.json')
}

function Get-SystemThemeName {
  try {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    $value = (Get-ItemProperty -Path $key -Name 'AppsUseLightTheme' -ErrorAction SilentlyContinue).AppsUseLightTheme
    if ($value -eq 0) { return 'Dark' }
  } catch { }
  return 'Light'
}

$script:ThemePalettes = @{
  Light = @{
    PanelBackground  = '#F5F6F8'
    PanelForeground  = '#1C1E21'
    PanelBorder      = '#C8CCD4'
    ControlBackground= '#FFFFFF'
    ControlBorder    = '#C8CCD4'
    ControlForeground= '#1C1E21'
  }
  Dark = @{
    PanelBackground  = '#1E1F22'
    PanelForeground  = '#E6E6E6'
    PanelBorder      = '#3A3D44'
    ControlBackground= '#2A2C30'
    ControlBorder    = '#3A3D44'
    ControlForeground= '#E6E6E6'
  }
}

$script:AccentPalette = @{
  Blue  = '#2B6CB0'
  Gray  = '#6B7280'
  Green = '#2F855A'
  Teal  = '#0F766E'
}

function Convert-HexToColor {
  param([Parameter(Mandatory)][string]$Hex)
  $value = $Hex.Trim().TrimStart('#')
  if ($value.Length -ne 6) { return [System.Windows.Media.Colors]::Transparent }
  $r = [Convert]::ToByte($value.Substring(0,2), 16)
  $g = [Convert]::ToByte($value.Substring(2,2), 16)
  $b = [Convert]::ToByte($value.Substring(4,2), 16)
  return [System.Windows.Media.Color]::FromRgb($r,$g,$b)
}

function Set-ThemeBrush {
  param(
    [Parameter(Mandatory)][string]$Key,
    [Parameter(Mandatory)][string]$Hex
  )
  try {
    $color = Convert-HexToColor -Hex $Hex
    $brush = $win.Resources[$Key]
    if ($brush -is [System.Windows.Media.SolidColorBrush]) {
      $brush.Color = $color
    } else {
      $win.Resources[$Key] = New-Object System.Windows.Media.SolidColorBrush($color)
    }
  } catch { }
}

function Apply-Theme {
  param(
    [Parameter(Mandatory)][string]$ThemeName,
    [Parameter(Mandatory)][string]$AccentName
  )
  $resolvedTheme = if ($ThemeName -eq 'System') { Get-SystemThemeName } else { $ThemeName }
  $palette = $script:ThemePalettes[$resolvedTheme]
  if (-not $palette) { $palette = $script:ThemePalettes['Light'] }
  $accent = $script:AccentPalette[$AccentName]
  if (-not $accent) { $accent = $script:AccentPalette['Blue'] }

  Set-ThemeBrush -Key 'PanelBackground' -Hex $palette.PanelBackground
  Set-ThemeBrush -Key 'PanelForeground' -Hex $palette.PanelForeground
  Set-ThemeBrush -Key 'PanelBorder' -Hex $palette.PanelBorder
  Set-ThemeBrush -Key 'ControlBackground' -Hex $palette.ControlBackground
  Set-ThemeBrush -Key 'ControlBorder' -Hex $palette.ControlBorder
  Set-ThemeBrush -Key 'ControlForeground' -Hex $palette.ControlForeground
  Set-ThemeBrush -Key 'AccentBrush' -Hex $accent
}

function Load-ThemeSettings {
  $settingsPath = Get-ThemeSettingsPath
  if (Test-Path -LiteralPath $settingsPath) {
    try {
      $raw = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop
      $obj = $raw | ConvertFrom-Json -ErrorAction Stop
      $theme = Get-OptionalValue -Obj $obj -Key 'Theme' -Default 'System'
      $accent = Get-OptionalValue -Obj $obj -Key 'Accent' -Default 'Blue'
      return [pscustomobject]@{ Theme = [string]$theme; Accent = [string]$accent }
    } catch { }
  }
  return [pscustomobject]@{ Theme = 'System'; Accent = 'Blue' }
}

function Save-ThemeSettings {
  param(
    [Parameter(Mandatory)][string]$Theme,
    [Parameter(Mandatory)][string]$Accent
  )
  try {
    $settingsPath = Get-ThemeSettingsPath
    $dir = Split-Path -Parent $settingsPath
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $payload = [pscustomobject]@{
      Theme  = $Theme
      Accent = $Accent
    } | ConvertTo-Json -Depth 3
    Set-Content -LiteralPath $settingsPath -Value $payload -Encoding ASCII
  } catch { }
}

function Select-ComboValue {
  param(
    [Parameter(Mandatory)][object]$Combo,
    [Parameter(Mandatory)][string]$Value
  )
  try {
    for ($i = 0; $i -lt $Combo.Items.Count; $i++) {
      $item = $Combo.Items[$i]
      if ($item -and ($item.Content -eq $Value)) {
        $Combo.SelectedIndex = $i
        return
      }
    }
    if ($Combo.Items.Count -gt 0) { $Combo.SelectedIndex = 0 }
  } catch { }
}

function Set-RowHelpStatus {
  param(
    [Parameter(Mandatory)][string]$Check,
    [string]$StatusText
  )
  try {
    if (-not $grid) { return }
    $collection = $grid.ItemsSource
    if (-not ($collection -is [System.Collections.ObjectModel.ObservableCollection[object]])) { return }
    for ($i = 0; $i -lt $collection.Count; $i++) {
      $row = $collection[$i]
      if ($row -and ($row.Check -eq $Check)) {
        $collection[$i] = [pscustomobject]@{
          Check          = $row.Check
          Status         = $row.Status
          StatusIcon     = $row.StatusIcon
          StatusIconFont = $row.StatusIconFont
          Details        = $row.Details
          SuggestedAction= $row.SuggestedAction
          HelpLabel      = $row.HelpLabel
          HelpAction     = $row.HelpAction
          HelpTarget     = $row.HelpTarget
          HelpScripts    = $row.HelpScripts
          HelpMenu       = $row.HelpMenu
          HelpStatus     = if ($StatusText) { $StatusText } else { '' }
          RowHighlight   = $row.RowHighlight
          DetailsWrap    = $row.DetailsWrap
        }
        break
      }
    }
  } catch { }
}

function Show-RowHelpMenu {
  param(
    [Parameter(Mandatory)][System.Windows.Controls.Button]$Button,
    [Parameter(Mandatory)][object]$Row
  )
  try {
    $items = @($Row.HelpMenu)
    if (-not $items -or $items.Count -eq 0) { return }
    $menu = New-Object System.Windows.Controls.ContextMenu
    foreach ($item in $items) {
      if (-not $item) { continue }
      $label = $item.HelpLabel
      if ([string]::IsNullOrWhiteSpace($label)) { continue }
      $menuItem = New-Object System.Windows.Controls.MenuItem
      $menuItem.Header = $label
      $menuItem.Tag = $item
      $menuItem.Add_Click({
        param($sender,$e)
        try {
          $entry = $sender.Tag
          if ($entry) { Invoke-RowHelpAction -Row $entry }
        } catch { }
      })
      $menu.Items.Add($menuItem) | Out-Null
    }
    if ($menu.Items.Count -eq 0) { return }
    $menu.PlacementTarget = $Button
    $menu.IsOpen = $true
  } catch { }
}

function Get-SelectedRepairOptions {
  $options = @()
  if ($chkRestart -and $chkRestart.IsChecked) {
    $options += @{ Name = 'Restart notifications'; Arg = '-RestartToast' }
  }
  if ($chkArchive -and $chkArchive.IsChecked) {
    $options += @{ Name = 'Archive queue'; Arg = '-ArchiveQueue' }
  }
  if ($chkReapply -and $chkReapply.IsChecked) {
    $options += @{ Name = 'Re-apply policy'; Arg = '-ApplyPolicy' }
  }
  return $options
}

function Set-RepairDefaults {
  if ($chkRestart) { $chkRestart.IsChecked = $script:RepairDefaults.RestartNotifications }
  if ($chkArchive) { $chkArchive.IsChecked = $script:RepairDefaults.ArchiveQueue }
  if ($chkReapply) { $chkReapply.IsChecked = $script:RepairDefaults.ReapplyPolicy }
}

function Initialize-SystemActions {
  if (-not $systemActionSelect) { return }
  $systemActionSelect.Items.Clear()
  $placeholder = New-Object System.Windows.Controls.ComboBoxItem
  $placeholder.Content = 'Select an action...'
  $placeholder.Tag = $null
  $systemActionSelect.Items.Add($placeholder) | Out-Null
  foreach ($action in $script:SystemActions) {
    $item = New-Object System.Windows.Controls.ComboBoxItem
    $item.Content = $action.Name
    $item.Tag = $action
    $systemActionSelect.Items.Add($item) | Out-Null
  }
  if ($systemActionSelect.Items.Count -gt 0) { $systemActionSelect.SelectedIndex = 0 }
}

function Start-ChecklistRender {
  param(
    [Parameter(Mandatory)][object[]]$Rows,
    [bool]$LogAction
  )

  $rows = @($Rows)
  $rowCount = $rows.Count

  if (-not $rows) {
    try { $grid.ItemsSource = @() } catch { }
    if ($progressRefresh) { $progressRefresh.Visibility = 'Collapsed' }
    Set-RefreshStatusText "Refresh failed."
    [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
    if ($LogAction) {
      Write-AdminPanelActionLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Fail' -Details 'Refresh failed'
    }
    return
  }

  try {
    Set-RefreshStatusText ("Refreshing... (0/{0})" -f $rowCount)
    if ($progressRefresh) {
      $progressRefresh.IsIndeterminate = $false
      $progressRefresh.Maximum = [Math]::Max($rowCount, 1)
      $progressRefresh.Value = 0
      $progressRefresh.Visibility = 'Visible'
    }

    $collection = $grid.ItemsSource
    if (-not ($collection -is [System.Collections.ObjectModel.ObservableCollection[object]])) {
      $collection = New-Object System.Collections.ObjectModel.ObservableCollection[object]
      $grid.ItemsSource = $collection
    }

    $delayMs = 25
    $highlightMs = 200
    $index = 0

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds($delayMs)
    $timer.Add_Tick({
      try {
        if ($index -ge $rows.Count) {
          $timer.Stop()
          while ($collection.Count -gt $rows.Count) { $collection.RemoveAt($collection.Count - 1) }
          if ($progressRefresh) { $progressRefresh.Visibility = 'Collapsed' }
          Set-RefreshStatusText ("Refresh complete: " + (Get-Date -Format 'HH:mm:ss'))
          [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
          if ($LogAction) {
            Write-AdminPanelActionLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Ok' -Details ("Rows=" + $rowCount)
          }
          return
        }

        $row = $rows[$index]
        $highlighted = Copy-RowWithHighlight -Row $row -Highlight $true
        if ($index -lt $collection.Count) {
          $collection[$index] = $highlighted
        } else {
          $collection.Add($highlighted) | Out-Null
        }

        $currentIndex = $index
        $index++
        Set-RefreshStatusText ("Refreshing... ({0}/{1})" -f $index, $rowCount)
        if ($progressRefresh) { $progressRefresh.Value = $index }
        $clearTimer = New-Object System.Windows.Threading.DispatcherTimer
        $clearTimer.Interval = [TimeSpan]::FromMilliseconds($highlightMs)
        $clearTimer.Add_Tick({
          $clearTimer.Stop()
          try {
            if ($currentIndex -lt $collection.Count) {
              $collection[$currentIndex] = Copy-RowWithHighlight -Row $row -Highlight $false
            }
          } catch { }
        })
        $clearTimer.Start()
      } catch {
          $timer.Stop()
          if ($progressRefresh) { $progressRefresh.Visibility = 'Collapsed' }
        Set-RefreshStatusText "Refresh failed."
        [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
        if ($LogAction) {
          Write-AdminPanelActionLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Fail' -Details $_.Exception.Message
        }
      }
    })
    $timer.Start()
  } catch {
    if ($progressRefresh) { $progressRefresh.Visibility = 'Collapsed' }
    Set-RefreshStatusText "Refresh failed."
    [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
    if ($LogAction) {
      Write-AdminPanelActionLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Fail' -Details $_.Exception.Message
    }
  }
}

function Apply-Checklist {
  param([switch]$LogAction)
  if ([System.Threading.Interlocked]::CompareExchange([ref]$ChecklistRefreshLock, 1, 0) -ne 0) {
    if ($LogAction) {
      $runId = New-AdminPanelRunId
      Write-AdminPanelAsyncLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Start' -RunId $runId -BusyCount (Get-UiBusyCount) -Details 'Skipped: already running'
      Write-AdminPanelAsyncLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Fail' -RunId $runId -BusyCount (Get-UiBusyCount) -Error 'Skipped' -Details 'Skipped: already running'
    }
    return
  }
  if (-not $grid) {
    [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
    return
  }

  try { Set-RefreshStatusText "Refreshing..." } catch { }

  $logDetails = if ($LogAction) { 'Async refresh' } else { $null }

  $ok = Invoke-UiAsyncAction -Action 'Checklist refresh' -ScriptLabel 'Invoke-Checklist' -LogDetails $logDetails -BusyKey 'ChecklistRefresh' -ProgressMode 'None' -EnableLogging:([bool]$LogAction) -ScriptBlock {
    $rows = Invoke-Checklist
    if (-not $rows) { throw "Refresh failed." }
    return $rows
  } -OnOk {
    param($rows, $state)
    $rowList = @($rows)
    if (-not $rowList -or $rowList.Count -le 0) {
      Set-RefreshStatusText "Refresh failed."
      [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
      if ($LogAction) { $state.LogDetails = 'Refresh failed' }
      return
    }
    Start-ChecklistRender -Rows $rowList -LogAction:$false
    if ($LogAction) { $state.LogDetails = ("Rows=" + $rowList.Count) }
  } -OnFail {
    param($err, $state)
    Set-RefreshStatusText "Refresh failed."
    [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
    if ($LogAction) { $state.LogDetails = $err }
  } -OnTimeout {
    param($elapsedSec, $state)
    Set-RefreshStatusText "Refresh timed out."
    [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
  }

  if (-not $ok) {
    [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
  }
}

# Auto-refresh timer removed (manual refresh only)

# Events
$btnApplyRepair.Add_Click({
  $options = Get-SelectedRepairOptions
  if (-not $options -or $options.Count -eq 0) {
    Set-RepairStatusText "Applied: none (no options selected)."
    Write-AdminPanelActionLog -Action 'Repair Options: Apply Selected' -Script $null -Status 'Start' -Details 'No options selected'
    Write-AdminPanelActionLog -Action 'Repair Options: Apply Selected' -Script $null -Status 'Ok' -Details 'No options selected'
    return
  }

  $optionNames = $options | ForEach-Object { $_.Name }
  $detail = "Options=" + ($optionNames -join ', ')
  $args = $options | ForEach-Object { $_.Arg }

  $ok = Invoke-AdminPanelScript -Action 'Repair Options: Apply Selected' -ScriptCandidates $ActionScripts.Repair -Arguments $args -LogDetails $detail
  if ($ok) {
    Set-RepairStatusText ("Applied: " + ($optionNames -join ', '))
  } else {
    Set-RepairStatusText "Apply failed. See AdminPanel-Actions.log."
  }
})

$btnResetRepair.Add_Click({
  $defaults = @()
  if ($script:RepairDefaults.RestartNotifications) { $defaults += 'Restart notifications' }
  if ($script:RepairDefaults.ArchiveQueue) { $defaults += 'Archive queue' }
  if ($script:RepairDefaults.ReapplyPolicy) { $defaults += 'Re-apply policy' }
  $detail = if ($defaults.Count -gt 0) { "Defaults=" + ($defaults -join ', ') } else { 'Defaults=none' }

  Write-AdminPanelActionLog -Action 'Repair Options: Reset Defaults' -Script $null -Status 'Start' -Details $detail
  try {
    Set-RepairDefaults
    if ($defaults.Count -gt 0) {
      Set-RepairStatusText ("Defaults restored: " + ($defaults -join ', '))
    } else {
      Set-RepairStatusText "Defaults restored: none"
    }
    Write-AdminPanelActionLog -Action 'Repair Options: Reset Defaults' -Script $null -Status 'Ok' -Details $detail
  } catch {
    Write-AdminPanelActionLog -Action 'Repair Options: Reset Defaults' -Script $null -Status 'Fail' -Details $_.Exception.Message
    Set-RepairStatusText "Reset failed. See AdminPanel-Actions.log."
  }
})

$btnRunAction.Add_Click({
  if (-not $systemActionSelect) { return }
  $item = $systemActionSelect.SelectedItem
  if (-not $item -or -not $item.Tag) {
    Set-ActionStatusText "Select an action to run."
    Write-AdminPanelActionLog -Action 'System Action' -Script $null -Status 'Start' -Details 'No selection'
    Write-AdminPanelActionLog -Action 'System Action' -Script $null -Status 'Fail' -Details 'No selection'
    return
  }

  $meta = $item.Tag
  if (-not $meta) { return }
  $actionName = "System Action: " + $meta.Name
  if ($meta.Confirm) {
    $confirmText = "Run " + $meta.Name + "?"
    if ($meta.Name -eq 'Uninstall') {
      $confirmText = "Uninstall FirewallCore and remove installed components?"
    } elseif ($meta.Name -eq 'Clean Uninstall') {
      $confirmText = "Clean Uninstall will remove FirewallCore and local data. Continue?"
    }
    $confirm = [System.Windows.MessageBox]::Show(
      $confirmText,
      "FirewallCore Admin Panel",
      [System.Windows.MessageBoxButton]::YesNo,
      [System.Windows.MessageBoxImage]::Warning
    )
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
      Set-ActionStatusText ("Cancelled: " + $meta.Name)
      Write-AdminPanelActionLog -Action $actionName -Script $null -Status 'Start' -Details 'User cancelled'
      Write-AdminPanelActionLog -Action $actionName -Script $null -Status 'Fail' -Details 'User cancelled'
      return
    }
    if ($meta.Name -eq 'Clean Uninstall') {
      $phrase = 'DELETE'
      $entry = Show-InputPrompt -Prompt ("Type {0} to confirm Clean Uninstall." -f $phrase) -Title 'FirewallCore Admin Panel'
      $confirmAction = "Confirm: " + $meta.Name
      Write-AdminPanelActionLog -Action $confirmAction -Script $null -Status 'Start' -Details 'confirmation requested'
      if ($entry -cne $phrase) {
        Set-ActionStatusText "Cancelled: Clean Uninstall (confirmation failed)"
        Write-AdminPanelActionLog -Action $confirmAction -Script $null -Status 'Fail' -Details 'confirmed=false'
        return
      }
      Write-AdminPanelActionLog -Action $confirmAction -Script $null -Status 'Ok' -Details 'confirmed=true'
    }
  }

  Set-ActionStatusText ("Running: " + $meta.Name + "...")
  $null = Invoke-AdminPanelActionAsync `
    -Action $actionName `
    -ScriptCandidates $meta.ScriptCandidates `
    -LogDetails $meta.Name `
    -BusyKey 'SystemAction' `
    -DisableControls @($btnRunAction, $systemActionSelect) `
    -OnOk {
      if ($meta.ApplyChecklist) { Apply-Checklist -LogAction }
      Set-ActionStatusText ("OK: " + $meta.Name + " at " + (Get-Date -Format 'HH:mm:ss'))
    } `
    -OnFail {
      Set-ActionStatusText ("FAIL: " + $meta.Name + " (see AdminPanel-Actions.log)")
    }
})

$btnClose.Add_Click({ $win.Close() })

$win.Add_Closed({
  try {
    if ($script:AsyncTimer) {
      $script:AsyncTimer.Stop()
      $script:AsyncTimer = $null
    }
  } catch { }
})

$grid.Add_MouseDoubleClick({
  param($sender,$e)
  try {
    $row = $grid.SelectedItem
    if ($row -and $row.HelpAction -and ($row.Status -eq 'WARN' -or $row.Status -eq 'FAIL')) {
      Invoke-RowHelpAction -Row $row
    }
  } catch { }
})

$grid.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent,
  [System.Windows.RoutedEventHandler]{
    param($sender,$e)
    try {
      $btn = $e.OriginalSource
      if ($btn -is [System.Windows.Controls.Button]) {
        $row = $btn.DataContext
        if ($row -and $row.HelpMenu -and $row.HelpMenu.Count -gt 0) {
          Show-RowHelpMenu -Button $btn -Row $row
          $e.Handled = $true
          return
        }
        if ($row -and $row.HelpAction) {
          Invoke-RowHelpAction -Row $row
          $e.Handled = $true
        }
      }
    } catch { }
  })

# --- Mount external XAML views (InstallProgress + Tests) ----------------------
function Get-AdminPanelScriptRoot {
  if ($PSScriptRoot) { return $PSScriptRoot }
  $p = $MyInvocation.MyCommand.Path
  if ($p) { return (Split-Path -Parent $p) }
  return (Get-Location).Path
}

function Load-XamlViewFromFile {
  param([Parameter(Mandatory)][string]$Path)

  if (-not (Test-Path $Path)) { throw "XAML view not found: $Path" }

  $xaml = Get-Content -Path $Path -Raw
  $sr = New-Object System.IO.StringReader($xaml)
  $xr = [System.Xml.XmlReader]::Create($sr)
  return [System.Windows.Markup.XamlReader]::Load($xr)
}

function Mount-AdminPanelViews {
  param([Parameter(Mandatory)][object]$Window)

  $root = Get-AdminPanelScriptRoot
  $viewsRoot = Join-Path $root 'UI\Views'

  $testsHost = $Window.FindName('TestsHost')

  if ($testsHost) {
    $testsView = Load-XamlViewFromFile -Path (Join-Path $viewsRoot 'Tests.xaml')
    $testsHost.Content = $testsView

    Initialize-TestsUI -WindowOrRoot $testsView
  }
}







# --- Admin Panel helpers ----------------------------------------------------
$script:AdminPanelLogPath = $null

function Initialize-AdminPanelLog {
  $dir = 'C:\ProgramData\FirewallCore\Logs'
  $logPath = Join-Path $dir 'AdminPanel-Actions.log'
  try {
    New-Item -Path $dir -ItemType Directory -Force | Out-Null
  } catch { }

  try {
    if (-not (Test-Path -LiteralPath $logPath)) {
      New-Item -Path $logPath -ItemType File -Force | Out-Null
    }
  } catch { }

  $script:AdminPanelLogPath = $logPath
  return $logPath
}

function Write-AdminPanelStartupLog {
  $logPath = Initialize-AdminPanelLog
  $line = $null
  try {
    $psVersion = 'Unknown'
    try {
      if ($PSVersionTable -and $PSVersionTable.PSVersion) {
        $psVersion = $PSVersionTable.PSVersion.ToString()
      }
    } catch { }
    $userName = 'Unknown'
    try {
      $userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    } catch {
      try {
        if ($env:USERNAME) { $userName = $env:USERNAME }
      } catch { }
    }
    $isElevated = $false
    try { $isElevated = Test-IsAdmin } catch { }
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "START | AdminPanelLaunch | PID=$PID | User=$userName | Elevated=$isElevated | PS=$psVersion | $timestamp"

    if ($logPath) {
      Add-Content -Path $logPath -Value $line
    } else {
      Write-Host $line
    }
  } catch {
    try {
      if ($line) { Write-Host $line }
    } catch { }
  }
}

function Write-AdminPanelActionLog {
  param(
    [Parameter(Mandatory)][string]$Action,
    [AllowNull()][AllowEmptyString()][string]$Script,
    [string]$Status,
    [string]$Details,
    [AllowNull()][Nullable[int]]$ExitCode
  )

  $line = $null
  try {
    if (-not $Status) { $Status = 'Info' }
    switch ($Status.ToString().ToLowerInvariant()) {
      'started' { $Status = 'Start' }
      'start'   { $Status = 'Start' }
      'failed'  { $Status = 'Fail' }
      'fail'    { $Status = 'Fail' }
      'ok'      { $Status = 'Ok' }
    }

    if (-not $script:AdminPanelLogPath) { $script:AdminPanelLogPath = Initialize-AdminPanelLog }
    $logPath = $script:AdminPanelLogPath
    if ([string]::IsNullOrWhiteSpace($Script)) { $Script = '<none>' }
    $escapedDetails = if ($Details) { $Details -replace '"', '""' } else { $null }
    if ($escapedDetails) {
      $detailsText = " Details=`"{0}`"" -f $escapedDetails
    } else {
      $detailsText = ''
    }
    $exitText = ''
    if ($PSBoundParameters.ContainsKey('ExitCode') -and $null -ne $ExitCode) {
      $exitText = " ExitCode=$ExitCode"
    }
    $line = '[{0}] Action="{1}" Script="{2}" Status={3}{4}{5}' -f (
      Get-Date -Format 'yyyy-MM-dd HH:mm:ss',
      $Action,
      $Script,
      $Status,
      $detailsText,
      $exitText
    )
    if ($logPath) {
      Add-Content -Path $logPath -Value $line
    } else {
      Write-Host ("[AdminPanel] {0}" -f $line)
    }
  } catch {
    try {
      if ($line) { Write-Host ("[AdminPanel] {0}" -f $line) }
    } catch { }
  }
}

# --- Async helpers (runspace pool + UI-safe callbacks) -----------------------
$script:AsyncPool = $null
$script:AsyncTasks = @{}
$script:AsyncTimer = $null
$script:UiBusyCount = 0
$script:UiProgressRequests = @()

function New-AdminPanelRunId {
  return ([guid]::NewGuid().ToString())
}

function Format-AdminPanelError {
  param([string]$ErrorText)
  if ([string]::IsNullOrWhiteSpace($ErrorText)) { return $null }
  return ($ErrorText -replace '\s+', ' ').Trim()
}

function Write-AdminPanelAsyncLog {
  param(
    [Parameter(Mandatory)][string]$Action,
    [AllowNull()][AllowEmptyString()][string]$Script,
    [Parameter(Mandatory)][string]$Status,
    [Parameter(Mandatory)][string]$RunId,
    [AllowNull()][Nullable[int]]$DurationMs,
    [AllowNull()][Nullable[int]]$BusyCount,
    [string]$Error,
    [string]$Details
  )

  $parts = @("Action=$Action","RunId=$RunId",$Status)
  if ($DurationMs -ne $null) { $parts += ("DurationMs=" + $DurationMs) }
  if ($BusyCount -ne $null) { $parts += ("BusyCount=" + $BusyCount) }
  $cleanError = Format-AdminPanelError -ErrorText $Error
  if ($cleanError) { $parts += ("Error=" + $cleanError) }
  if ($Details) { $parts += $Details }
  $detailText = $parts -join ' '
  Write-AdminPanelActionLog -Action $Action -Script $Script -Status $Status -Details $detailText
}

function Get-UiBusyCount {
  try { return [Math]::Max(0, [int]$script:UiBusyCount) } catch { return 0 }
}

function Increment-UiBusy {
  try {
    return [System.Threading.Interlocked]::Increment([ref]$script:UiBusyCount)
  } catch {
    $script:UiBusyCount++
    return [int]$script:UiBusyCount
  }
}

function Decrement-UiBusy {
  $count = 0
  try {
    $count = [System.Threading.Interlocked]::Decrement([ref]$script:UiBusyCount)
  } catch {
    $script:UiBusyCount--
    $count = [int]$script:UiBusyCount
  }
  if ($count -lt 0) {
    $script:UiBusyCount = 0
    $count = 0
  }
  return $count
}

function Update-UiProgressDisplay {
  try {
    if (-not $progressRefresh) { return }
    $mode = 'None'
    if ($script:UiProgressRequests -and ($script:UiProgressRequests | Where-Object { $_.Mode -eq 'Determinate' })) {
      $mode = 'Determinate'
    } elseif ($script:UiProgressRequests -and ($script:UiProgressRequests | Where-Object { $_.Mode -eq 'Indeterminate' })) {
      $mode = 'Indeterminate'
    }
    if ($mode -eq 'None') {
      $progressRefresh.Visibility = 'Collapsed'
    } else {
      $progressRefresh.Visibility = 'Visible'
      $progressRefresh.IsIndeterminate = ($mode -eq 'Indeterminate')
    }
  } catch { }
}

function Add-UiProgressRequest {
  param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][ValidateSet('Indeterminate','Determinate')] [string]$Mode
  )
  if (-not $script:UiProgressRequests) { $script:UiProgressRequests = @() }
  $script:UiProgressRequests += [pscustomobject]@{ Owner = $Owner; Mode = $Mode }
  Update-UiProgressDisplay
}

function Remove-UiProgressRequest {
  param([Parameter(Mandatory)][string]$Owner)
  if ($script:UiProgressRequests) {
    $script:UiProgressRequests = @($script:UiProgressRequests | Where-Object { $_.Owner -ne $Owner })
  }
  Update-UiProgressDisplay
}

function Initialize-AsyncInfrastructure {
  if ($script:AsyncPool) { return }
  try {
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $fnNames = @(
      'Get-StatusIconFont',
      'Get-StatusIcon',
      'Test-IsAdmin',
      'Get-TaskState',
      'Get-TaskLastResult',
      'Get-ToastListenerPid',
      'Get-LatestWindowsFirewallLoggingSnapshot',
      'Get-OptionalValue',
      'New-Row',
      'Copy-RowWithHighlight',
      'Invoke-Checklist'
    )
    foreach ($name in $fnNames) {
      try {
        $cmd = Get-Command $name -CommandType Function -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.ScriptBlock) {
          $iss.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($name, $cmd.ScriptBlock.ToString())))
        }
      } catch { }
    }
    $iss.Variables.Add((New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry('UseGlyphIcons', $script:UseGlyphIcons, '')))
    $script:AsyncPool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, 4, $iss, $Host)
    $script:AsyncPool.ApartmentState = 'MTA'
    $script:AsyncPool.ThreadOptions = 'ReuseThread'
    $script:AsyncPool.Open()
  } catch {
    $script:AsyncPool = $null
  }

  if (-not $script:AsyncTimer) {
    $script:AsyncTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:AsyncTimer.Interval = [TimeSpan]::FromMilliseconds(120)
    $script:AsyncTimer.Add_Tick({ Process-AsyncTasks })
    $script:AsyncTimer.Start()
  }
}

function Start-AsyncTask {
  param(
    [Parameter(Mandatory)][string]$Key,
    [Parameter(Mandatory)][scriptblock]$ScriptBlock,
    [object[]]$Arguments,
    [scriptblock]$OnSuccess,
    [scriptblock]$OnFail,
    [scriptblock]$OnFinally,
    [scriptblock]$OnTimeout,
    [int]$TimeoutSec = 0
  )

  Initialize-AsyncInfrastructure
  if (-not $script:AsyncPool) { return $false }
  if ($script:AsyncTasks.ContainsKey($Key)) { return $false }

  $ps = [PowerShell]::Create()
  $ps.RunspacePool = $script:AsyncPool
  $null = $ps.AddScript($ScriptBlock)
  if ($Arguments) {
    foreach ($arg in $Arguments) { $null = $ps.AddArgument($arg) }
  }
  $handle = $ps.BeginInvoke()
  $script:AsyncTasks[$Key] = @{
    PowerShell = $ps
    Handle     = $handle
    OnSuccess  = $OnSuccess
    OnFail     = $OnFail
    OnFinally  = $OnFinally
    OnTimeout  = $OnTimeout
    TimeoutSec = $TimeoutSec
    StartTime  = (Get-Date)
    TimeoutHandled = $false
    CompletionHandled = $false
    FinallyHandled = $false
  }
  return $true
}

function Process-AsyncTasks {
  if (-not $script:AsyncTasks -or $script:AsyncTasks.Count -eq 0) { return }
  foreach ($key in @($script:AsyncTasks.Keys)) {
    $task = $script:AsyncTasks[$key]
    if (-not $task) { continue }
    if (-not $task.Handle) { continue }

    if (-not $task.TimeoutHandled -and $task.TimeoutSec -gt 0) {
      try {
        $elapsed = (Get-Date) - $task.StartTime
        if ($elapsed.TotalSeconds -ge $task.TimeoutSec) {
          $task.TimeoutHandled = $true
          if ($task.OnTimeout) {
            try { & $task.OnTimeout $elapsed.TotalSeconds } catch { }
          }
          try {
            if ($task.PowerShell) {
              $null = $task.PowerShell.BeginStop($null, $null)
            }
          } catch { }
        }
      } catch { }
    }

    if (-not $task.Handle.IsCompleted) { continue }

    $ps = $task.PowerShell
    $result = $null
    $errorMessage = $null
    try {
      $result = $ps.EndInvoke($task.Handle)
      if ($ps.Streams.Error.Count -gt 0) {
        $errorMessage = ($ps.Streams.Error | Select-Object -First 1).Exception.Message
      }
    } catch {
      $errorMessage = $_.Exception.Message
    }

    if (-not $task.CompletionHandled) {
      try {
        if (-not $task.TimeoutHandled) {
          if ($errorMessage) {
            if ($task.OnFail) { & $task.OnFail $errorMessage }
          } else {
            if ($task.OnSuccess) { & $task.OnSuccess $result }
          }
        }
      } catch { }
      $task.CompletionHandled = $true
    }

    if (-not $task.FinallyHandled) {
      try {
        if ($task.OnFinally) { & $task.OnFinally }
      } catch { }
      $task.FinallyHandled = $true
    }

    try { $ps.Dispose() } catch { }
    $script:AsyncTasks.Remove($key) | Out-Null
  }
}

function Set-ControlsEnabled {
  param(
    [Parameter(Mandatory)][object[]]$Controls,
    [Parameter(Mandatory)][bool]$Enabled
  )
  foreach ($c in $Controls) {
    try { if ($c) { $c.IsEnabled = $Enabled } } catch { }
  }
}

function Resolve-AdminPanelScriptPath {
  param([Parameter(Mandatory)][string[]]$Candidates)
  foreach ($candidate in $Candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
  }
  return $null
}

function Invoke-UiAsyncAction {
  param(
    [Parameter(Mandatory)][string]$Action,
    [Parameter(Mandatory)][scriptblock]$ScriptBlock,
    [object[]]$Arguments,
    [string]$LogDetails,
    [string]$BusyKey,
    [AllowNull()][AllowEmptyString()][string]$ScriptLabel,
    [object[]]$DisableControls,
    [int]$TimeoutSec = 120,
    [ValidateSet('None','Indeterminate','Determinate')] [string]$ProgressMode = 'Indeterminate',
    [bool]$EnableLogging = $true,
    [scriptblock]$OnOk,
    [scriptblock]$OnFail,
    [scriptblock]$OnTimeout
  )

  if (-not $ScriptBlock) { return $false }

  $key = if ($BusyKey) { $BusyKey } else { $Action }
  $runId = New-AdminPanelRunId
  $startTime = Get-Date
  $state = [pscustomobject]@{
    Action = $Action
    RunId = $runId
    ScriptLabel = $ScriptLabel
    LogDetails = $LogDetails
    Outcome = $null
    Error = $null
    Result = $null
    Finalized = $false
    DeferFinalize = $false
  }

  if ($script:AsyncTasks.ContainsKey($key)) {
    $existing = $script:AsyncTasks[$key]
    if ($existing -and $existing.TimeoutHandled) {
      $key = $key + "-" + $runId
    } else {
      $skipDetails = if ($LogDetails) { "Skipped: already running | $LogDetails" } else { 'Skipped: already running' }
      if ($EnableLogging) {
        Write-AdminPanelAsyncLog -Action $Action -Script $ScriptLabel -Status 'Start' -RunId $runId -BusyCount (Get-UiBusyCount) -Details $skipDetails
        Write-AdminPanelAsyncLog -Action $Action -Script $ScriptLabel -Status 'Fail' -RunId $runId -BusyCount (Get-UiBusyCount) -Error 'Skipped' -Details $skipDetails
      }
      if ($OnFail) { & $OnFail "Skipped: already running" $state }
      return $false
    }
  }

  $finalize = {
    param([string]$OverrideStatus, [string]$OverrideError)
    if ($state.Finalized) { return }
    $state.Finalized = $true

    $status = if ($OverrideStatus) { $OverrideStatus } elseif ($state.Outcome) { $state.Outcome } else { 'Fail' }
    $errorText = if ($OverrideError) { $OverrideError } else { $state.Error }
    $durationMs = [int]([Math]::Round(((Get-Date) - $startTime).TotalMilliseconds))

    try {
      if ($DisableControls) { Set-ControlsEnabled -Controls $DisableControls -Enabled:$true }
    } catch { }
    try {
      if ($ProgressMode -ne 'None') { Remove-UiProgressRequest -Owner $runId }
    } catch { }
    $busyCount = Decrement-UiBusy
    if ($EnableLogging) {
      Write-AdminPanelAsyncLog -Action $Action -Script $ScriptLabel -Status $status -RunId $runId -DurationMs $durationMs -BusyCount $busyCount -Error $errorText -Details $state.LogDetails
    }
  }
  $state | Add-Member -MemberType NoteProperty -Name Finalize -Value $finalize

  $busyCount = Increment-UiBusy
  if ($DisableControls) { Set-ControlsEnabled -Controls $DisableControls -Enabled:$false }
  if ($ProgressMode -ne 'None') { Add-UiProgressRequest -Owner $runId -Mode $ProgressMode }
  if ($EnableLogging) {
    Write-AdminPanelAsyncLog -Action $Action -Script $ScriptLabel -Status 'Start' -RunId $runId -BusyCount $busyCount -Details $LogDetails
  }

  $timeoutValue = if ($TimeoutSec -gt 0) { $TimeoutSec } else { 0 }
  $ok = Start-AsyncTask -Key $key -ScriptBlock $ScriptBlock -Arguments $Arguments -OnSuccess {
    param($result)
    $state.Outcome = 'Ok'
    $state.Result = $result
    if ($OnOk) { & $OnOk $result $state }
  } -OnFail {
    param($err)
    $state.Outcome = 'Fail'
    $state.Error = $err
    if ($OnFail) { & $OnFail $err $state }
  } -OnFinally {
    if ($state.Finalized) { return }
    if ($state.DeferFinalize) { return }
    $finalize.Invoke($null, $null)
  } -OnTimeout {
    param($elapsedSec)
    if (-not $state.Outcome) { $state.Outcome = 'Fail' }
    $state.Error = 'Timeout'
    $timeoutDetail = "TimeoutSec=$TimeoutSec"
    if ($state.LogDetails) { $state.LogDetails = ($state.LogDetails + " " + $timeoutDetail) } else { $state.LogDetails = $timeoutDetail }
    if ($OnTimeout) {
      & $OnTimeout $elapsedSec $state
    } elseif ($OnFail) {
      $timeoutMsg = "Timeout after {0}s" -f [Math]::Round($elapsedSec, 0)
      & $OnFail $timeoutMsg $state
    }
    $finalize.Invoke('Fail', 'Timeout')
  } -TimeoutSec $timeoutValue

  if (-not $ok) {
    $state.Outcome = 'Fail'
    $state.Error = 'Async dispatch failed'
    if ($OnFail) { & $OnFail $state.Error $state }
    $finalize.Invoke('Fail', $state.Error)
    return $false
  }
  return $true
}

function Invoke-AdminPanelActionAsync {
  param(
    [Parameter(Mandatory)][string]$Action,
    [Parameter(Mandatory)][string[]]$ScriptCandidates,
    [string[]]$Arguments,
    [string]$LogDetails,
    [string]$BusyKey,
    [object[]]$DisableControls,
    [switch]$AllowPwsh,
    [scriptblock]$OnOk,
    [scriptblock]$OnFail
  )

  $scriptPath = Resolve-AdminPanelScriptPath -Candidates $ScriptCandidates
  if (-not $scriptPath) {
    $detail = 'Missing mapping'
    $runId = New-AdminPanelRunId
    Write-AdminPanelAsyncLog -Action $Action -Script $null -Status 'Start' -RunId $runId -BusyCount (Get-UiBusyCount) -Details $detail
    Show-NotImplementedMessage
    Write-AdminPanelAsyncLog -Action $Action -Script $null -Status 'Fail' -RunId $runId -BusyCount (Get-UiBusyCount) -Error $detail -Details $detail
    if ($OnFail) { & $OnFail $detail }
    return $false
  }

  $exe = Resolve-PreferredShellExe -AllowPwsh:$AllowPwsh
  $args = @(
    '-NoLogo','-NoProfile','-NonInteractive','-WindowStyle','Hidden',
    '-ExecutionPolicy','Bypass',
    '-File',$scriptPath
  )
  if ($Arguments) { $args += $Arguments }

  $ok = Invoke-UiAsyncAction -Action $Action -ScriptLabel $scriptPath -LogDetails $LogDetails -BusyKey $BusyKey -DisableControls $DisableControls -ProgressMode 'Indeterminate' -ScriptBlock {
    param($exePath, $argList)
    Start-Process -FilePath $exePath -ArgumentList $argList -WindowStyle Hidden | Out-Null
    return $true
  } -Arguments @($exe, $args) -OnOk {
    param($result, $state)
    $state.LogDetails = if ($state.LogDetails) { "Launched. " + $state.LogDetails } else { 'Launched' }
    if ($OnOk) { & $OnOk $result }
  } -OnFail {
    param($err, $state)
    $state.LogDetails = if ($state.LogDetails) { "$err. " + $state.LogDetails } else { $err }
    if ($OnFail) { & $OnFail $err }
    if ($err -ne 'Skipped: already running' -and $err -ne 'Async dispatch failed') {
      [System.Windows.MessageBox]::Show("Action failed:`n$err",'FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
    }
  } -OnTimeout {
    param($elapsedSec, $state)
    $timeoutMsg = "Timeout after {0}s" -f [Math]::Round($elapsedSec, 0)
    if ($OnFail) { & $OnFail $timeoutMsg }
    [System.Windows.MessageBox]::Show("Action timed out:`n$timeoutMsg",'FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
  }

  return $ok
}

function Invoke-RowHelpAction {
  param([object]$Row)
  if (-not $Row -or -not $Row.HelpAction) { return }

  $actionLabel = if ($Row.HelpLabel) { $Row.HelpLabel } else { 'Help Action' }

  if ($Row.HelpAction -eq 'RunRulesReport') {
    $scriptPath = $null
    try {
      if ($Row.HelpScripts -and $Row.HelpScripts.Count -gt 0) {
        $scriptPath = Resolve-AdminPanelScriptPath -Candidates $Row.HelpScripts
      }
    } catch { $scriptPath = $null }

    $reportsFolder = if ($Row.HelpTarget) { $Row.HelpTarget } else { 'C:\ProgramData\FirewallCore\Reports' }
    $outputHint = if ($scriptPath) { 'RulesReport_*.json' } else { $reportsFolder }
    $logDetails = if ($Row.Check) { $Row.Check + " | OutputHint=" + $outputHint } else { "OutputHint=" + $outputHint }

    Set-RowHelpStatus -Check $Row.Check -StatusText 'Starting...'

    if ($scriptPath) {
      $ok = Invoke-UiAsyncAction -Action $actionLabel -ScriptLabel $scriptPath -LogDetails $logDetails -BusyKey 'RulesReport' -ProgressMode 'Indeterminate' -ScriptBlock {
        param($path, $reportsRoot)
        try {
          Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force | Out-Null
        } catch { }
        & $path | Out-Null
        $latest = Get-ChildItem -Path $reportsRoot -Filter 'RulesReport_*.json' -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending |
          Select-Object -First 1
        return [pscustomobject]@{
          ReportFile = if ($latest) { $latest.FullName } else { $null }
          ReportsRoot = $reportsRoot
        }
      } -Arguments @($scriptPath, $reportsFolder) -OnOk {
        param($result, $state)
        $reportFile = if ($result -and $result.ReportFile) { $result.ReportFile } else { $null }
        $statusText = if ($reportFile) {
          "Done: Generated " + (Split-Path -Leaf $reportFile)
        } else {
          "Done: Generated RulesReport_*.json"
        }
        Set-RowHelpStatus -Check $Row.Check -StatusText $statusText
        $detailPrefix = if ($Row.Check) { $Row.Check + " | " } else { '' }
        $state.LogDetails = if ($reportFile) { $detailPrefix + "OutputHint=$reportFile" } else { $detailPrefix + "OutputHint=$outputHint" }
      } -OnFail {
        param($err, $state)
        if ($err -eq 'Skipped: already running') {
          Set-RowHelpStatus -Check $Row.Check -StatusText 'Busy...'
          return
        }
        Set-RowHelpStatus -Check $Row.Check -StatusText ("Failed: " + $err)
        $detailPrefix = if ($Row.Check) { $Row.Check + " | " } else { '' }
        $state.LogDetails = ($detailPrefix + $err + " | OutputHint=" + $outputHint)
        [System.Windows.MessageBox]::Show("Help action failed:`n$err",'FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
      } -OnTimeout {
        param($elapsedSec, $state)
        Set-RowHelpStatus -Check $Row.Check -StatusText ("Timed out after {0}s" -f [Math]::Round($elapsedSec, 0))
      }
      return
    }

    try { New-Item -ItemType Directory -Force -Path $reportsFolder | Out-Null } catch { }
    $ok = Invoke-UiAsyncAction -Action $actionLabel -ScriptLabel $null -LogDetails $logDetails -BusyKey 'RulesReport' -ProgressMode 'Indeterminate' -ScriptBlock {
      param($reportsRoot)
      Start-Process explorer.exe -ArgumentList $reportsRoot | Out-Null
      return $reportsRoot
    } -Arguments @($reportsFolder) -OnOk {
      param($result, $state)
      $statusText = "Missing script - opened Reports folder"
      Set-RowHelpStatus -Check $Row.Check -StatusText $statusText
      $detailPrefix = if ($Row.Check) { $Row.Check + " | " } else { '' }
      $state.LogDetails = ($detailPrefix + "OutputHint=" + $result)
    } -OnFail {
      param($err, $state)
      if ($err -eq 'Skipped: already running') {
        Set-RowHelpStatus -Check $Row.Check -StatusText 'Busy...'
        return
      }
      Set-RowHelpStatus -Check $Row.Check -StatusText ("Failed: " + $err)
      $detailPrefix = if ($Row.Check) { $Row.Check + " | " } else { '' }
      $state.LogDetails = ($detailPrefix + $err + " | OutputHint=" + $outputHint)
      [System.Windows.MessageBox]::Show("Help action failed:`n$err",'FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
    } -OnTimeout {
      param($elapsedSec, $state)
      Set-RowHelpStatus -Check $Row.Check -StatusText ("Timed out after {0}s" -f [Math]::Round($elapsedSec, 0))
    }
    return
  }

  if ($Row.HelpAction -eq 'OpenWindowsFirewallLogs') {
    $logDir = if ($Row.HelpTarget) { $Row.HelpTarget } else { 'C:\ProgramData\FirewallCore\Logs\WindowsFirewall' }
    Write-AdminPanelActionLog -Action $actionLabel -Script $logDir -Status 'Start' -Details $Row.Check
    try {
      Start-Process explorer.exe -ArgumentList $logDir | Out-Null
      Write-AdminPanelActionLog -Action $actionLabel -Script $logDir -Status 'Ok' -Details $Row.Check
    } catch {
      Write-AdminPanelActionLog -Action $actionLabel -Script $logDir -Status 'Fail' -Details $_.Exception.Message
      [System.Windows.MessageBox]::Show("Help action failed:`n$($_.Exception.Message)",'FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
    }
    return
  }

  if ($Row.HelpAction -eq 'RunScript') {
    Invoke-AdminPanelScript -Action $actionLabel -ScriptCandidates $Row.HelpScripts -LogDetails $Row.Check | Out-Null
    return
  }

  $target = $Row.HelpTarget
  if ($Row.HelpAction -eq 'OpenTaskScheduler' -and -not $target) { $target = 'taskschd.msc' }
  if ($Row.HelpAction -eq 'OpenEventViewer' -and -not $target) { $target = 'eventvwr.msc' }

  Write-AdminPanelActionLog -Action $actionLabel -Script $target -Status 'Start' -Details $Row.Check
  try {
    switch ($Row.HelpAction) {
      'OpenFolder' {
        if (-not $target) { throw "Missing folder target." }
        Start-Process explorer.exe -ArgumentList $target | Out-Null
      }
      'OpenFile' {
        if (-not $target) { throw "Missing file target." }
        Start-Process -FilePath $target | Out-Null
      }
      'OpenDoc' {
        if (-not $target) { throw "Missing documentation target." }
        Start-Process -FilePath $target | Out-Null
      }
      'OpenTaskScheduler' { Start-Process -FilePath $target | Out-Null }
      'OpenEventViewer' { Start-Process -FilePath $target | Out-Null }
      default { throw "Unsupported help action: $($Row.HelpAction)" }
    }
    Write-AdminPanelActionLog -Action $actionLabel -Script $target -Status 'Ok' -Details $Row.Check
  } catch {
    Write-AdminPanelActionLog -Action $actionLabel -Script $target -Status 'Fail' -Details $_.Exception.Message
    [System.Windows.MessageBox]::Show("Help action failed:`n$($_.Exception.Message)",'FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
  }
}

function Show-NotImplementedMessage {
  param([string]$Details)
  $message = if ($Details) {
    "Not implemented yet (v1).`n$Details"
  } else {
    "Not implemented yet (v1)."
  }
  [System.Windows.MessageBox]::Show($message,'FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information) | Out-Null
}

function Invoke-AdminPanelScript {
  param(
    [Parameter(Mandatory)][string]$Action,
    [Parameter(Mandatory)][string[]]$ScriptCandidates,
    [string[]]$Arguments,
    [string]$LogDetails,
    [switch]$AllowPwsh
  )

  [string[]]$cleanCandidates = @($ScriptCandidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if (-not $cleanCandidates -or $cleanCandidates.Count -eq 0) {
    Write-AdminPanelActionLog -Action $Action -Script $null -Status 'Start' -Details 'Missing mapping'
    Show-NotImplementedMessage
    Write-AdminPanelActionLog -Action $Action -Script $null -Status 'Fail' -Details 'Missing mapping'
    return $false
  }

  $scriptPath = Resolve-AdminPanelScriptPath -Candidates $cleanCandidates
  if (-not $scriptPath) {
    Write-AdminPanelActionLog -Action $Action -Script $null -Status 'Start' -Details 'Missing mapping'
    Show-NotImplementedMessage
    Write-AdminPanelActionLog -Action $Action -Script $null -Status 'Fail' -Details 'Missing mapping'
    return $false
  }

  Write-AdminPanelActionLog -Action $Action -Script $scriptPath -Status 'Start' -Details $LogDetails

  $exe = Resolve-PreferredShellExe -AllowPwsh:$AllowPwsh
  $args = @(
    '-NoLogo','-NoProfile','-NonInteractive','-WindowStyle','Hidden',
    '-ExecutionPolicy','Bypass',
    '-File',$scriptPath
  )
  if ($Arguments) { $args += $Arguments }

  try {
    Start-Process -FilePath $exe -ArgumentList $args -WindowStyle Hidden | Out-Null
    $okDetails = if ($LogDetails) { "Launched. $LogDetails" } else { 'Launched' }
    Write-AdminPanelActionLog -Action $Action -Script $scriptPath -Status 'Ok' -Details $okDetails
    return $true
  } catch {
    $err = $_.Exception.Message
    $failDetails = if ($LogDetails) { "$err. $LogDetails" } else { $err }
    Write-AdminPanelActionLog -Action $Action -Script $scriptPath -Status 'Fail' -Details $failDetails
    [System.Windows.MessageBox]::Show("Action failed:`n$err",'FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
    return $false
  }
}

function New-AdminPanelTestButton {
  param(
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Subtitle,
    [Parameter(Mandatory)][string[]]$ScriptCandidates
  )

  $btn = [System.Windows.Controls.Button]::new()
  $btn.Margin = '6'
  $btn.Padding = '10'
  $btn.MinWidth = 260
  $btn.MinHeight = 64
  $btn.HorizontalAlignment = 'Stretch'
  $btn.HorizontalContentAlignment = 'Left'

  $col = [System.Windows.Controls.StackPanel]::new()
  $col.Orientation = 'Vertical'

  $t1 = [System.Windows.Controls.TextBlock]::new()
  $t1.Text = $Title
  $t1.FontSize = 14
  $t1.FontWeight = 'SemiBold'

  $t2 = [System.Windows.Controls.TextBlock]::new()
  $t2.Text = $Subtitle
  $t2.Opacity = 0.75
  $t2.TextWrapping = 'Wrap'

  $col.Children.Add($t1) | Out-Null
  $col.Children.Add($t2) | Out-Null

  $btn.Content = $col
  $btn.Tag = [pscustomobject]@{
    Action = $Title
    ScriptCandidates = $ScriptCandidates
  }
  $btn.Add_Click({
    param($sender,$e)
    if (-not $sender -or -not $sender.Tag) { return }
    $meta = $sender.Tag
    Invoke-AdminPanelScript -Action $meta.Action -ScriptCandidates $meta.ScriptCandidates
  })
  return $btn
}

function Set-DevPanelVisibility {
  param(
    [Parameter(Mandatory)][object]$DevPanel,
    [object]$DevHeader,
    [object]$DevNote,
    [object]$DevSelect,
    [object]$DevRunButton,
    [bool]$Visible
  )
  $visibility = if ($Visible) { 'Visible' } else { 'Collapsed' }
  $DevPanel.Visibility = $visibility
  if ($DevHeader) { $DevHeader.Visibility = $visibility }
  if ($DevNote) { $DevNote.Visibility = $visibility }
  if ($DevSelect) { $DevSelect.IsEnabled = $Visible }
  if ($DevRunButton) { $DevRunButton.IsEnabled = $Visible }
}

function Initialize-TestsUI {
  param([Parameter(Mandatory)][object]$WindowOrRoot)

  $testSelect = $WindowOrRoot.FindName('TestActionSelect')
  $btnRunTest = $WindowOrRoot.FindName('BtnRunTest')
  $txtTestStatus = $WindowOrRoot.FindName('TxtTestStatus')
  $devSelect = $WindowOrRoot.FindName('DevActionSelect')
  $btnRunDev = $WindowOrRoot.FindName('BtnRunDevTest')
  $txtDevStatus = $WindowOrRoot.FindName('TxtDevStatus')
  $devPanel = $WindowOrRoot.FindName('DevActionRow')
  $devHeader = $WindowOrRoot.FindName('DevTestsHeader')
  $devNote = $WindowOrRoot.FindName('DevTestsNote')
  $devToggle = $WindowOrRoot.FindName('chkDeveloperMode')
  $devGateRow = $WindowOrRoot.FindName('DevGateRow')
  if (-not ($testSelect -and $btnRunTest -and $devToggle -and $devSelect -and $btnRunDev -and $devPanel)) { return }

  $testSelect.Items.Clear()
  $devSelect.Items.Clear()
  $placeholder = New-Object System.Windows.Controls.ComboBoxItem
  $placeholder.Content = 'Select a test...'
  $placeholder.Tag = $null
  $testSelect.Items.Add($placeholder) | Out-Null

  $tests = @(
    @{ Title = 'Quick Health Check'; Subtitle = 'Validate services, tasks, logs, and baseline.'; Script = @('C:\Firewall\Tools\Run-QuickHealthCheck.ps1'); OutputHint = 'C:\ProgramData\FirewallCore\Reports\QuickHealth_*' },
    @{ Title = 'Notification Demo'; Subtitle = 'Show Info, Warning, and Critical alerts.'; Script = @('C:\Firewall\Tools\Run-NotificationDemo.ps1') },
    @{ Title = 'Baseline Drift Check'; Subtitle = 'Read-only drift status and last baseline time.'; Script = @('C:\Firewall\Tools\Run-DriftCheck.ps1') },
    @{ Title = 'Inbound Allow Risk Report'; Subtitle = 'Audit inbound exposure (no changes).'; Script = @('C:\Firewall\Tools\Run-InboundRiskReport.ps1') },
    @{ Title = 'Rules Report'; Subtitle = 'Summarize rules and ownership tags.'; Script = @('C:\Firewall\Tools\Run-RulesReport.ps1'); OutputHint = 'C:\ProgramData\FirewallCore\Reports\RulesReport_*' },
    @{ Title = 'Export Diagnostics Bundle'; Subtitle = 'Package logs and snapshots for support.'; Script = @('C:\Firewall\Tools\Export-DiagnosticsBundle.ps1'); OutputHint = 'C:\ProgramData\FirewallCore\LifecycleExports\BUNDLE_*' }
  )

  foreach ($test in $tests) {
    if ($null -eq $test) { continue }
    $title = Get-OptionalValue -Obj $test -Key 'Title'
    if (-not $title) { continue }
    $scriptCandidates = Get-OptionalValue -Obj $test -Key 'Script' -Default @()
    if ($null -eq $scriptCandidates) { $scriptCandidates = @() }
    $outputHint = Get-OptionalValue -Obj $test -Key 'OutputHint'
    if ($null -ne $outputHint) { $outputHint = [string]$outputHint }

    $item = New-Object System.Windows.Controls.ComboBoxItem
    $item.Content = [string]$title
    $item.Tag = [pscustomobject]@{
      Action = [string]$title
      ScriptCandidates = @($scriptCandidates)
      OutputHint = $outputHint
      RequiresConfirm = $false
    }
    $testSelect.Items.Add($item) | Out-Null
  }
  if ($testSelect.Items.Count -gt 0) { $testSelect.SelectedIndex = 0 }

  $devPlaceholder = New-Object System.Windows.Controls.ComboBoxItem
  $devPlaceholder.Content = 'Select a Dev/Lab action...'
  $devPlaceholder.Tag = $null
  $devSelect.Items.Add($devPlaceholder) | Out-Null

  $devTests = @(
    @{ Title = 'DEV Test Suite'; Subtitle = 'Developer validation (requires Dev Mode).'; Script = @('C:\Firewall\Tools\Run-DevSuite.ps1') },
    @{ Title = 'Forced Test Suite'; Subtitle = 'Aggressive validation (requires Dev Mode).'; Script = @('C:\Firewall\Tools\Run-ForcedSuite.ps1') },
    @{ Title = 'Attack Simulation (Safe)'; Subtitle = 'Lab-only simulation (no exploitation/persistence). Validates detections, alerts, and logging.'; Script = @('C:\Firewall\Tools\Run-AttackSimSafe.ps1') },
    @{ Title = 'Attack Simulation (Advanced)'; Subtitle = 'Lab-only simulation (no exploitation/persistence). Stronger lab run; requires confirmation.'; Script = @('C:\Firewall\Tools\Run-AttackSimAdvanced.ps1') }
  )

  foreach ($dev in $devTests) {
    if ($null -eq $dev) { continue }
    $title = Get-OptionalValue -Obj $dev -Key 'Title'
    if (-not $title) { continue }
    $scriptCandidates = Get-OptionalValue -Obj $dev -Key 'Script' -Default @()
    if ($null -eq $scriptCandidates) { $scriptCandidates = @() }

    $item = New-Object System.Windows.Controls.ComboBoxItem
    $item.Content = [string]$title
    $item.Tag = [pscustomobject]@{
      Action = [string]$title
      ScriptCandidates = @($scriptCandidates)
      RequiresConfirm = ([string]$title -eq 'Attack Simulation (Advanced)')
    }
    $devSelect.Items.Add($item) | Out-Null
  }
  if ($devSelect.Items.Count -gt 0) { $devSelect.SelectedIndex = 0 }

  $devFlagPath = Join-Path $env:ProgramData 'FirewallCore\DevMode.enabled'
  $devUnlockHashPath = Get-DevUnlockHashPath
  $devModeEnabled = $false
  $devFlagPresent = Test-Path -LiteralPath $devFlagPath
  $canUnlock = Test-IsAdmin

  if ($devGateRow) { $devGateRow.Visibility = 'Visible' }
  $devToggle.IsEnabled = $canUnlock

  $devToggle.Tag = [pscustomobject]@{
    DevPanel = $devPanel
    DevHeader = $devHeader
    DevNote = $devNote
    DevSelect = $devSelect
    DevRunButton = $btnRunDev
    DevFlagPath = $devFlagPath
    UnlockHashPath = $devUnlockHashPath
    Busy = $false
  }

  $devToggle.IsChecked = $devModeEnabled
  if ($devFlagPresent) { $devToggle.ToolTip = 'Dev Mode flag present; check to enable actions.' }
  Set-DevPanelVisibility -DevPanel $devPanel -DevHeader $devHeader -DevNote $devNote -DevSelect $devSelect -DevRunButton $btnRunDev -Visible:$devModeEnabled

  $btnRunTest.Tag = [pscustomobject]@{
    Select = $testSelect
    StatusText = $txtTestStatus
  }
  $btnRunDev.Tag = [pscustomobject]@{
    Select = $devSelect
    StatusText = $txtDevStatus
  }

  $btnRunTest.Add_Click({
    param($sender,$e)
    if (-not $sender -or -not $sender.Tag) { return }
    $state = $sender.Tag
    $selected = $state.Select.SelectedItem
    if (-not $selected -or -not $selected.Tag) {
      Set-TestStatusText "Select a test to run."
      Write-AdminPanelActionLog -Action 'Test Run' -Script $null -Status 'Start' -Details 'No selection'
      Write-AdminPanelActionLog -Action 'Test Run' -Script $null -Status 'Fail' -Details 'No selection'
      return
    }
    $meta = $selected.Tag
    $actionLabel = "Test: " + $meta.Action
    $logDetails = if ($meta.OutputHint) { $meta.Action + " | OutputHint=" + $meta.OutputHint } else { $meta.Action }
    Set-TestStatusText ("Running: " + $meta.Action + "...")
    $null = Invoke-AdminPanelActionAsync `
      -Action $actionLabel `
      -ScriptCandidates $meta.ScriptCandidates `
      -LogDetails $logDetails `
      -BusyKey 'TestAction' `
      -DisableControls @($btnRunTest, $state.Select) `
      -OnOk {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $outputHint = if ($meta.OutputHint) { " | Output: " + $meta.OutputHint } else { '' }
        Set-TestStatusText ("Last run: OK | " + $timestamp + $outputHint)
      } `
      -OnFail {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Set-TestStatusText ("Last run: FAIL | " + $timestamp + " | See AdminPanel-Actions.log")
      }
  })

  if ($canUnlock) {
    $devToggle.Add_Checked({
      param($sender,$e)
      if (-not $sender -or -not $sender.Tag) { return }
      $state = $sender.Tag
      if ($state.Busy) { return }
      $state.Busy = $true
      Write-AdminPanelActionLog -Action 'Dev Mode: Unlock' -Script $state.UnlockHashPath -Status 'Start'
      $unlock = Test-DevUnlock -HashPath $state.UnlockHashPath
      if (-not $unlock -or -not $unlock.Ok) {
        $detail = if ($unlock -and $unlock.Message) { $unlock.Message } else { 'Unlock failed.' }
        Write-AdminPanelActionLog -Action 'Dev Mode: Unlock' -Script $state.UnlockHashPath -Status 'Fail' -Details $detail
        [System.Windows.MessageBox]::Show("Dev/Lab unlock failed:`n$detail",'FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
        $sender.IsChecked = $false
        $state.Busy = $false
        return
      }
      $unlockDetail = if ($unlock.Message) { $unlock.Message } else { 'Unlock granted.' }
      Write-AdminPanelActionLog -Action 'Dev Mode: Unlock' -Script $state.UnlockHashPath -Status 'Ok' -Details $unlockDetail
      Write-AdminPanelActionLog -Action 'Dev Mode: Enable' -Script $state.DevFlagPath -Status 'Start'
      try {
        New-Item -Path $state.DevFlagPath -ItemType File -Force | Out-Null
        Write-AdminPanelActionLog -Action 'Dev Mode: Enable' -Script $state.DevFlagPath -Status 'Ok'
        Set-DevPanelVisibility -DevPanel $state.DevPanel -DevHeader $state.DevHeader -DevNote $state.DevNote -DevSelect $state.DevSelect -DevRunButton $state.DevRunButton -Visible:$true
      } catch {
        $err = $_.Exception.Message
        Write-AdminPanelActionLog -Action 'Dev Mode: Enable' -Script $state.DevFlagPath -Status 'Fail' -Details $err
        [System.Windows.MessageBox]::Show("Developer mode change failed:`n$err",'FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
        $sender.IsChecked = $false
      } finally {
        $state.Busy = $false
      }
    })

    $devToggle.Add_Unchecked({
      param($sender,$e)
      if (-not $sender -or -not $sender.Tag) { return }
      $state = $sender.Tag
      if ($state.Busy) { return }
      $state.Busy = $true
      Write-AdminPanelActionLog -Action 'Dev Mode: Disable' -Script $state.DevFlagPath -Status 'Start'
      try {
        Remove-Item -Path $state.DevFlagPath -Force -ErrorAction SilentlyContinue
        Write-AdminPanelActionLog -Action 'Dev Mode: Disable' -Script $state.DevFlagPath -Status 'Ok'
        Set-DevPanelVisibility -DevPanel $state.DevPanel -DevHeader $state.DevHeader -DevNote $state.DevNote -DevSelect $state.DevSelect -DevRunButton $state.DevRunButton -Visible:$false
      } catch {
        $err = $_.Exception.Message
        Write-AdminPanelActionLog -Action 'Dev Mode: Disable' -Script $state.DevFlagPath -Status 'Fail' -Details $err
        [System.Windows.MessageBox]::Show("Developer mode change failed:`n$err",'FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
        $sender.IsChecked = $true
      } finally {
        $state.Busy = $false
      }
    })
  }

  $btnRunDev.Add_Click({
    param($sender,$e)
    if (-not $sender -or -not $sender.Tag) { return }
    $state = $sender.Tag
    $selected = $state.Select.SelectedItem
    if (-not $selected -or -not $selected.Tag) {
      Set-DevStatusText "Select a Dev/Lab action to run."
      Write-AdminPanelActionLog -Action 'Dev/Lab Run' -Script $null -Status 'Start' -Details 'No selection'
      Write-AdminPanelActionLog -Action 'Dev/Lab Run' -Script $null -Status 'Fail' -Details 'No selection'
      return
    }
    $meta = $selected.Tag
    if ($meta.RequiresConfirm) {
      $phrase = 'SIMULATE'
      $confirmAction = "Confirm: Dev/Lab " + $meta.Action
      $entry = Show-InputPrompt -Prompt ("Type {0} to confirm advanced lab simulation." -f $phrase) -Title 'FirewallCore Admin Panel'
      Write-AdminPanelActionLog -Action $confirmAction -Script $null -Status 'Start' -Details 'confirmation requested'
      if ($entry -cne $phrase) {
        Set-DevStatusText ("Cancelled: " + $meta.Action + " (confirmation failed)")
        Write-AdminPanelActionLog -Action $confirmAction -Script $null -Status 'Fail' -Details 'confirmed=false'
        return
      }
      Write-AdminPanelActionLog -Action $confirmAction -Script $null -Status 'Ok' -Details 'confirmed=true'
    }
    $actionLabel = "Dev/Lab: " + $meta.Action
    Set-DevStatusText ("Running: " + $meta.Action + "...")
    $null = Invoke-AdminPanelActionAsync `
      -Action $actionLabel `
      -ScriptCandidates $meta.ScriptCandidates `
      -LogDetails $meta.Action `
      -BusyKey 'DevAction' `
      -DisableControls @($btnRunDev, $state.Select) `
      -OnOk {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Set-DevStatusText ("Last run: OK | " + $timestamp)
      } `
      -OnFail {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Set-DevStatusText ("Last run: FAIL | " + $timestamp + " | See AdminPanel-Actions.log")
      }
  })
}

# Initial render
Write-AdminPanelStartupLog
Apply-Checklist
Initialize-SystemActions
Set-RepairDefaults
if ($txtRepairStatus) {
  $defaultLabels = @()
  if ($script:RepairDefaults.RestartNotifications) { $defaultLabels += 'Restart notifications' }
  if ($script:RepairDefaults.ArchiveQueue) { $defaultLabels += 'Archive queue' }
  if ($script:RepairDefaults.ReapplyPolicy) { $defaultLabels += 'Re-apply policy' }
  if ($defaultLabels.Count -gt 0) {
    Set-RepairStatusText ("Defaults: " + ($defaultLabels -join ', '))
  } else {
    Set-RepairStatusText "Defaults: none"
  }
}
Mount-AdminPanelViews -Window $win
$null = $win.ShowDialog()
