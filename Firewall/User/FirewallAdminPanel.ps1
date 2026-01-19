# --- BEGIN ADMINPANEL CASCADE REFRESH UX ---
# Purpose: show deterministic refresh progress + cascade row status coloring (PASS/WARN/FAIL) row-by-row.
# This is UI-only (does not change checklist computation), PS5.1/PS7-safe.

param(
  [int]$DefaultRefreshMs = 5000
)

$script:ChecklistCascadeTimer = $null
$script:ChecklistCascadeState = $null

function Invoke-AdminPanelUi {
  param(
    [Parameter(Mandatory=$true)][object]$Window,
    [Parameter(Mandatory=$true)][scriptblock]$Code
  )

  try {
    if ($Window -and $Window.Dispatcher -and -not $Window.Dispatcher.CheckAccess()) {
      return $Window.Dispatcher.Invoke($Code)
    }
  } catch {}
  & $Code
}

function Find-AdminPanelControl {
  param(
    [Parameter(Mandatory=$true)][object]$Window,
    [Parameter(Mandatory=$true)][string[]]$Names
  )
  foreach ($n in $Names) {
    try {
      $c = $Window.FindName($n)
      if ($c) { return $c }
    } catch {}
  }
  return $null
}

function Set-AdminPanelRefreshText {
  param(
    [Parameter(Mandatory=$true)][object]$Window,
    [string]$Text
  )
  $tb = Find-AdminPanelControl -Window $Window -Names @('TxtRefreshStatus','TxtRefresh','TxtRefreshState')
  if (-not $tb) { return }
  Invoke-AdminPanelUi $Window { $tb.Text = $Text }
}

function Invoke-AdminPanelCascadeRefreshUI {
  param(
    [Parameter(Mandatory=$true)][object]$Window,
    [Parameter(Mandatory=$true)][object[]]$Rows,
    [int]$DelayMs = 35,
    [bool]$LogAction = $false
  )

  # Try common grid names
  $grid = Find-AdminPanelControl -Window $Window -Names @('GridChecklist','DgChecklist','ChecklistGrid','DataGridChecklist','DgHealth','DgStatus')
  if (-not $grid) { return $false }

  $items = @($Rows)
  if (-not $items -or $items.Count -lt 1) { return $false }

  if ($script:ChecklistCascadeTimer) {
    try { $script:ChecklistCascadeTimer.Stop() } catch { }
  }

  $ocType = [System.Collections.ObjectModel.ObservableCollection[object]]
  $oc = New-Object $ocType

  $script:ChecklistCascadeState = [pscustomobject]@{
    Window    = $Window
    Grid      = $grid
    Rows      = $items
    Collection= $oc
    Index     = 0
    Total     = $items.Count
    LogAction = $LogAction
  }

  Invoke-AdminPanelUi -Window $Window -Code { $grid.ItemsSource = $oc }
  Set-RefreshStatusText ("Refreshing... (0/" + $items.Count + ")")

  if (-not $script:ChecklistCascadeTimer) {
    $script:ChecklistCascadeTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:ChecklistCascadeTimer.Add_Tick({ Process-ChecklistCascade })
  }

  $intervalMs = [Math]::Max(15, $DelayMs)
  $script:ChecklistCascadeTimer.Interval = [TimeSpan]::FromMilliseconds($intervalMs)
  $script:ChecklistCascadeTimer.Start()
  return $true
}

function Process-ChecklistCascade {
  try {
    $state = $script:ChecklistCascadeState
    if (-not $state) { return }

    if ($state.Index -ge $state.Total) {
      if ($state.Total -gt 0) {
        $lastIndex = $state.Total - 1
        $last = $state.Collection[$lastIndex]
        $state.Collection[$lastIndex] = Copy-RowWithHighlight -Row $last -Highlight:$false -EvidencePath $last.EvidencePath
      }
      if ($progressRefresh) { $progressRefresh.Visibility = 'Collapsed' }
      Set-RefreshStatusText ("Refresh complete: " + (Get-Date -Format 'HH:mm:ss'))
      [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
      if ($state.LogAction) {
        Write-AdminPanelActionLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Ok' -Details ("Rows=" + $state.Total)
      }
      Exit-RefreshState -Reason 'Checklist refresh' -Status 'Ok' -Details ("Rows=" + $state.Total)
      try { $script:ChecklistCascadeTimer.Stop() } catch { }
      $script:ChecklistCascadeState = $null
      return
    }

    $row = $state.Rows[$state.Index]
    $overrideEvidence = $null
    if ($script:ChecklistEvidenceOverrides -and $script:ChecklistEvidenceOverrides.ContainsKey($row.Check)) {
      $overrideEvidence = $script:ChecklistEvidenceOverrides[$row.Check]
    }
    $rowOverride = $null
    if ($script:ChecklistRowOverrides -and $script:ChecklistRowOverrides.ContainsKey($row.Check)) {
      $rowOverride = $script:ChecklistRowOverrides[$row.Check]
    }
    $evidence = if ($rowOverride -and $rowOverride.EvidencePath) { $rowOverride.EvidencePath } elseif ($overrideEvidence) { $overrideEvidence } else { $row.EvidencePath }
    $newRow = Copy-RowWithHighlight -Row $row -Highlight:$true -EvidencePath $evidence
    if ($rowOverride) {
      if ($rowOverride.Status) {
        $newRow.Status = $rowOverride.Status
        $newRow.StatusIcon = Get-StatusIcon -Status $rowOverride.Status
        $newRow.StatusIconFont = Get-StatusIconFont
      }
      if ($rowOverride.Details) { $newRow.Details = $rowOverride.Details }
    }

    $state.Collection.Add($newRow) | Out-Null
    if ($state.Index -gt 0) {
      $prevIndex = $state.Index - 1
      $prev = $state.Collection[$prevIndex]
      $state.Collection[$prevIndex] = Copy-RowWithHighlight -Row $prev -Highlight:$false -EvidencePath $prev.EvidencePath
    }

    $state.Index++
    Set-RefreshStatusText ("Refreshing... (" + $state.Index + "/" + $state.Total + ")")
    Write-ActionOutputLine -Text ("Refresh: " + $newRow.Check + " => " + $newRow.Status) -Level 'Info' -SkipLog
  } catch {
    $err = $_.Exception.Message
    try { if ($script:ChecklistCascadeTimer) { $script:ChecklistCascadeTimer.Stop() } } catch { }
    $script:ChecklistCascadeState = $null
    if ($progressRefresh) { $progressRefresh.Visibility = 'Collapsed' }
    Set-RefreshStatusText ("Refresh failed: " + $err + " (see logs)")
    [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
    Write-AdminPanelActionLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Fail' -Details $err
    Exit-RefreshState -Reason 'Checklist refresh' -Status 'Fail' -Details $err
  }
}

# --- END ADMINPANEL CASCADE REFRESH UX ---
# --- BEGIN ADMINPANEL HARDENED RUNNER ---
# PS5.1/PS7-safe operation runner for Actions/Tests, output capture to UI or console.

function Get-AdminPanelPowerShellExe {
  $ps = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
  if (Test-Path $ps) { return $ps }
  $fallback = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
  if ($fallback) { return $fallback }
  throw "Could not resolve powershell.exe"
}

function Append-AdminPanelOutput {
  param(
    [Parameter(Mandatory=$true)][string]$Text,
    [ValidateSet('Info','Warn','Error','Ok')][string]$Level = 'Info'
  )

  $tb = $null
  foreach ($name in 'TxtActionOutput','TxtActionLog','TxtOutput','TxtActionStatus') {
    try { if ($script:Window -and $script:Window.FindName($name)) { $tb = $script:Window.FindName($name); break } } catch {}
  }

  $stamp = (Get-Date).ToString('HH:mm:ss')
  $line  = "[$stamp][$Level] $Text"

  if ($tb -and $tb.Dispatcher) {
    $null = $tb.Dispatcher.Invoke([Action]{
      $tb.AppendText($line + [Environment]::NewLine)
      $tb.ScrollToEnd()
    })
  } else {
    Write-ActionOutputLine -Text $line -Level $Level -SkipLog
  }
}

function Invoke-AdminPanelOp {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][scriptblock]$Work
  )

  Append-AdminPanelOutput -Text "$($Name): start" -Level Info
  try {
    & $Work
    Append-AdminPanelOutput -Text "$($Name): ok" -Level Ok
    return $true
  } catch {
    $msg = $_.Exception.Message
    Append-AdminPanelOutput -Text "$($Name): FAILED - $msg" -Level Error
    return $false
  }
}

function Start-AdminPanelCmd {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string[]]$Args = @(),
    [string]$WorkingDirectory
  )

  if (-not (Test-Path $Path)) { throw "Cmd/Bat not found: $Path" }

  $wd = if ($WorkingDirectory) { $WorkingDirectory } else { Split-Path -Parent $Path }
  $argLine = @('/c', "`"$Path`"") + $Args
  Append-AdminPanelOutput -Text ("cmd.exe " + ($argLine -join ' ')) -Level Info

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'cmd.exe'
  $psi.Arguments = ($argLine -join ' ')
  $psi.WorkingDirectory = $wd
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()

  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  if ($stdout) { Append-AdminPanelOutput -Text $stdout.TrimEnd() -Level Info }
  if ($stderr) { Append-AdminPanelOutput -Text $stderr.TrimEnd() -Level Warn }

  if ($p.ExitCode -ne 0) { throw "cmd.exe exit code $($p.ExitCode)" }
}

# --- END ADMINPANEL HARDENED RUNNER ---

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
# --- BEGIN ADMINPANEL_COMPAT_SHIM ---
# PS5.1-safe shims to prevent missing helper/order crashes.
# Must not use backticks inside double quotes (keeps parser happy).

# Ensure Select-ComboValue exists even if helper ordering changes
if (-not (Get-Command -Name Select-ComboValue -ErrorAction SilentlyContinue)) {
  function Select-ComboValue {
    param(
      [Parameter(Mandatory=$true)][object]$Combo,
      [Parameter(Mandatory=$true)][string]$Value
    )
    try {
      if ($null -eq $Combo) { return }
      if ($Combo.ItemsSource) {
        foreach ($item in $Combo.ItemsSource) {
          $label = if ($item -and $item.PSObject.Properties.Match('Content')) { $item.Content } else { $item }
          if ($label -eq $Value) { $Combo.SelectedItem = $item; return }
        }
      }
      if ($Combo.Items -and $Combo.Items.Count -gt 0) {
        foreach ($item in $Combo.Items) {
          $label = if ($item -and $item.PSObject.Properties.Match('Content')) { $item.Content } else { $item }
          if ($label -eq $Value) { $Combo.SelectedItem = $item; return }
        }
        $Combo.SelectedIndex = 0
      }
    } catch { }
  }
}

# Ensure a settings object always exists
if (-not (Get-Variable -Name settings -Scope Script -ErrorAction SilentlyContinue)) {
  $script:settings = @{ Theme = 'System'; Accent = 'Teal' }
}

# Guard Load-ThemeSettings if missing
if (-not (Get-Command -Name Load-ThemeSettings -ErrorAction SilentlyContinue)) {
  function Load-ThemeSettings { return $script:settings }
}

# Guard Apply-Theme if missing
if (-not (Get-Command -Name Apply-Theme -ErrorAction SilentlyContinue)) {
  function Apply-Theme { param($Theme,$Accent) return }
}

# Cascade hook: Codex should call this per-row as checks complete
if (-not (Get-Command -Name Invoke-ChecklistCascade -ErrorAction SilentlyContinue)) {
  function Invoke-ChecklistCascade {
    param(
      [Parameter(Mandatory=$true)][object]$Grid,
      [Parameter(Mandatory=$true)][object]$Rows
    )
    # NO-OP placeholder: wiring point for per-row visual cascade.
    # Codex should update: set RowHighlight + refresh ItemsSource per completed check.
  }
}
# --- END ADMINPANEL_COMPAT_SHIM ---
# --- Process Launch Contract (PS5.1-safe) ---
$script:PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$script:CmdExe = (Get-Command cmd.exe -ErrorAction Stop).Source
# ------------------------------------------

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

function Get-FirewallRoot {
  if ($PSScriptRoot) { return (Split-Path -Parent $PSScriptRoot) }
  $path = $PSCommandPath
  if ($path) { return (Split-Path -Parent (Split-Path -Parent $path)) }
  return (Get-Location).Path
}

$script:FirewallRoot = Get-FirewallRoot
$script:InstallerRoot = $null
try {
  if ($script:FirewallRoot) {
    $script:InstallerRoot = Split-Path -Parent $script:FirewallRoot
  }
} catch { }

# Ensure STA (WPF)
try {
  if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne "STA") {
    $self = $PSCommandPath
    if (-not $self) { throw "Cannot resolve script path for STA relaunch." }
    $psExe = Resolve-PreferredShellExe
    Start-Process $psExe -WindowStyle Hidden -ArgumentList @(
      "-NoLogo","-NoProfile","-NonInteractive","-WindowStyle","Hidden","-ExecutionPolicy","Bypass","-STA",
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
  $statusKey = if ($key -eq 'RUNNING') { 'WORKING' } else { $key }
  if ($useGlyph) {
    switch ($statusKey) {
      'PASS' { return [char]0xE73E }
      'WARN' { return [char]0xE7BA }
      'FAIL' { return [char]0xE711 }
      'WORKING' { return [char]0xE823 }
      'UNKNOWN' { return [char]0xE9CE }
      default { return '' }
    }
  }

  switch ($statusKey) {
    'PASS' { return '[OK]' }
    'WARN' { return '[!]' }
    'FAIL' { return '[X]' }
    'WORKING' { return '[~]' }
    'UNKNOWN' { return '[?]' }
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
  try {
    if (-not (Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue)) { return $null }
    $t = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
    if (-not $t) { return $null }
    return $t.State.ToString()
  } catch { return $null }
}

function Get-TaskLastResult {
  param([string]$Name)
  try {
    if (-not (Get-Command -Name Get-ScheduledTaskInfo -ErrorAction SilentlyContinue)) { return $null }
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

function Get-LatestRulesReportPath {
  param([string]$ReportsPath = 'C:\ProgramData\FirewallCore\Reports')
  try {
    if (Test-Path -LiteralPath $ReportsPath) {
      $latest = Get-ChildItem -Path $ReportsPath -Filter 'RulesReport_*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
      if ($latest) { return $latest.FullName }
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

function Show-PasswordPrompt {
  param(
    [Parameter(Mandatory)][string]$Prompt,
    [Parameter(Mandatory)][string]$Title
  )
  try {
    $dialog = New-Object System.Windows.Window
    $dialog.Title = $Title
    $dialog.WindowStartupLocation = 'CenterScreen'
    $dialog.ResizeMode = 'NoResize'
    $dialog.SizeToContent = 'WidthAndHeight'

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = '12'
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) | Out-Null
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) | Out-Null
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) | Out-Null

    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = $Prompt
    $text.Margin = '0,0,0,8'
    $grid.Children.Add($text) | Out-Null

    $password = New-Object System.Windows.Controls.PasswordBox
    $password.MinWidth = 280
    $password.Margin = '0,0,0,8'
    [System.Windows.Controls.Grid]::SetRow($password, 1)
    $grid.Children.Add($password) | Out-Null

    $buttons = New-Object System.Windows.Controls.StackPanel
    $buttons.Orientation = 'Horizontal'
    $buttons.HorizontalAlignment = 'Right'
    [System.Windows.Controls.Grid]::SetRow($buttons, 2)

    $ok = New-Object System.Windows.Controls.Button
    $ok.Content = 'OK'
    $ok.Width = 80
    $ok.Margin = '0,0,8,0'
    $ok.IsDefault = $true
    $ok.Add_Click({
      $dialog.DialogResult = $true
      $dialog.Close()
    })

    $cancel = New-Object System.Windows.Controls.Button
    $cancel.Content = 'Cancel'
    $cancel.Width = 80
    $cancel.IsCancel = $true
    $cancel.Add_Click({
      $dialog.DialogResult = $false
      $dialog.Close()
    })

    $buttons.Children.Add($ok) | Out-Null
    $buttons.Children.Add($cancel) | Out-Null
    $grid.Children.Add($buttons) | Out-Null

    $dialog.Content = $grid
    $null = $password.Focus()
    $result = $dialog.ShowDialog()
    if ($result -eq $true) {
      return $password.Password
    }
  } catch { }
  return $null
}

function Get-DevUnlockHashPath {
  return (Join-Path $env:ProgramData 'FirewallCore\AdminPanel\DevUnlock.hash')
}

$script:DevUnlockSalt = 'FirewallCore-AdminPanel-DevUnlock-Salt-v1'

function Get-StringHash {
  param(
    [Parameter(Mandatory)][string]$Value,
    [switch]$Legacy
  )
  try {
    $inputValue = if ($Legacy) { $Value } else { ($Value + '|' + $script:DevUnlockSalt) }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($inputValue)
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
    Set-AdminOnlyFileAcl -Path $Path
  } catch { }
}

function Set-AdminOnlyFileAcl {
  param([Parameter(Mandatory)][string]$Path)
  try {
    $acl = Get-Acl -LiteralPath $Path
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) {
      try { $null = $acl.RemoveAccessRule($rule) } catch { }
    }
    $admins = New-Object System.Security.AccessControl.FileSystemAccessRule('BUILTIN\Administrators','FullControl','Allow')
    $system = New-Object System.Security.AccessControl.FileSystemAccessRule('NT AUTHORITY\SYSTEM','FullControl','Allow')
    $acl.AddAccessRule($admins) | Out-Null
    $acl.AddAccessRule($system) | Out-Null
    Set-Acl -LiteralPath $Path -AclObject $acl
  } catch { }
}

function Get-DevUnlockFlagPath {
  return (Join-Path $env:ProgramData 'FirewallCore\AdminPanel\DevUnlock.expiry')
}

function Read-DevUnlockExpiry {
  param([Parameter(Mandatory)][string]$Path)
  try {
    if (Test-Path -LiteralPath $Path) {
      $raw = (Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue).Trim()
      if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
      return [DateTime]::Parse($raw, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
    }
  } catch { }
  return $null
}

function Write-DevUnlockExpiry {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][Nullable[datetime]]$ExpiresAt
  )
  try {
    $dir = Split-Path -Parent $Path
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Set-Content -LiteralPath $Path -Value $ExpiresAt.ToString('o') -Encoding ASCII
    Set-AdminOnlyFileAcl -Path $Path
  } catch { }
}

function Test-DevUnlock {
  param([Parameter(Mandatory)][string]$HashPath)
  $title = 'FirewallCore Admin Panel'
  $stored = Read-DevUnlockHash -Path $HashPath

  if (-not $stored) {
    $defaultSecret = 'admin'
    $first = Show-PasswordPrompt -Prompt 'Set a Dev/Lab unlock passphrase (leave blank to use default "admin"):' -Title $title
    if ($null -eq $first) {
      return [pscustomobject]@{ Ok = $false; Message = 'Passphrase setup cancelled.' }
    }
    if ([string]::IsNullOrWhiteSpace($first)) {
      $hash = Get-StringHash -Value $defaultSecret
      if (-not $hash) {
        return [pscustomobject]@{ Ok = $false; Message = 'Passphrase setup failed.' }
      }
      Write-DevUnlockHash -Path $HashPath -Hash $hash
      $stored = $hash
    } else {
      $second = Show-PasswordPrompt -Prompt 'Re-enter passphrase to confirm:' -Title $title
      if ($null -eq $second) {
        return [pscustomobject]@{ Ok = $false; Message = 'Passphrase setup cancelled.' }
      }
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
  }

  $entered = Show-PasswordPrompt -Prompt 'Enter Dev/Lab passphrase to unlock (default "admin"):' -Title $title
  if ($null -eq $entered -or [string]::IsNullOrWhiteSpace($entered)) {
    return [pscustomobject]@{ Ok = $false; Message = 'Passphrase entry cancelled.' }
  }
  $hash = Get-StringHash -Value $entered
  if ($hash -and ($hash -eq $stored)) {
    return [pscustomobject]@{ Ok = $true; Message = 'Passphrase verified.' }
  }
  $legacyHash = Get-StringHash -Value $entered -Legacy
  if ($legacyHash -and ($legacyHash -eq $stored)) {
    Write-DevUnlockHash -Path $HashPath -Hash $hash
    return [pscustomobject]@{ Ok = $true; Message = 'Passphrase verified (upgraded).' }
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
    [bool]$DetailsWrap = $false,
    [string]$EvidencePath,
    [string]$ComponentKey,
    [string]$Component,
    [string]$EvidenceAction,
    [string]$EvidenceTarget,
    [bool]$EvidenceAlwaysClickable = $false
  )
  $statusText = if ($Status) { $Status.ToUpperInvariant() } else { '' }
  $componentValue = if ($Component) { $Component } elseif ($Check) { $Check } else { '' }
  $keyValue = if ($ComponentKey) { $ComponentKey } elseif ($componentValue) { $componentValue } else { $Check }
  $helpActionValue = if ($HelpAction) { $HelpAction } elseif ($EvidenceAction) { $EvidenceAction } else { '' }
  $helpTargetValue = if ($HelpTarget) { $HelpTarget } elseif ($EvidenceTarget) { $EvidenceTarget } else { $null }
  [pscustomobject]@{
    ComponentKey   = $keyValue
    Component      = $componentValue
    Check          = $componentValue
    Status         = $statusText
    StatusIcon     = (Get-StatusIcon -Status $statusText)
    StatusIconFont = (Get-StatusIconFont)
    Details        = $Details
    SuggestedAction= $SuggestedAction
    HelpLabel      = if ($HelpLabel) { $HelpLabel } else { '' }
    HelpAction     = $helpActionValue
    HelpTarget     = $helpTargetValue
    HelpScripts    = if ($HelpScriptCandidates) { $HelpScriptCandidates } else { @() }
    HelpMenu       = if ($HelpMenu) { @($HelpMenu) } else { @() }
    HelpStatus     = if ($HelpStatus) { $HelpStatus } else { '' }
    RowHighlight   = $false
    DetailsWrap    = [bool]$DetailsWrap
    EvidencePath   = if ($EvidencePath) { $EvidencePath } else { '' }
    EvidenceAction = if ($EvidenceAction) { $EvidenceAction } else { $helpActionValue }
    EvidenceTarget = if ($EvidenceTarget) { $EvidenceTarget } else { $helpTargetValue }
    EvidenceAlwaysClickable = [bool]$EvidenceAlwaysClickable
  }
}

function Copy-RowWithHighlight {
  param(
    [Parameter(Mandatory)][object]$Row,
    [bool]$Highlight,
    [AllowNull()][AllowEmptyString()][string]$EvidencePath
  )
  $pathValue = if ($PSBoundParameters.ContainsKey('EvidencePath')) { $EvidencePath } else { $Row.EvidencePath }
  [pscustomobject]@{
    ComponentKey   = $Row.ComponentKey
    Component      = $Row.Component
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
    EvidencePath   = $pathValue
    EvidenceAction = $Row.EvidenceAction
    EvidenceTarget = $Row.EvidenceTarget
    EvidenceAlwaysClickable = $Row.EvidenceAlwaysClickable
  }
}

$script:InventoryBlueprint = $null
$script:InventoryInitialized = $false

function Get-FirstExistingPath {
  param([string[]]$Candidates)
  foreach ($candidate in @($Candidates)) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
  }
  return $null
}

function Get-InventoryBlueprint {
  param(
    [AllowNull()][AllowEmptyString()][string]$FirewallRoot,
    [AllowNull()][AllowEmptyString()][string]$InstallerRoot
  )
  if ($script:InventoryBlueprint) { return $script:InventoryBlueprint }

  $logsPath = 'C:\ProgramData\FirewallCore\Logs'
  $liveRoot = 'C:\Firewall'
  $queueRoot = Join-Path $env:ProgramData 'FirewallCore\NotifyQueue'
  $diagnosticsRoot = 'C:\ProgramData\FirewallCore\Diagnostics'

  $script:InventoryBlueprint = @(
    [pscustomobject]@{
      Key = 'Install State'
      Component = 'Install State'
      CheckKind = 'Install'
      ActionLabel = 'Run Repair'
      HelpLabel = 'Run Repair'
      HelpAction = 'RunRepair'
      EvidenceLabel = $liveRoot
      EvidenceAction = 'OpenFolder'
      EvidenceTarget = $liveRoot
      EvidenceAlwaysClickable = $false
    },
    [pscustomobject]@{
      Key = 'Scheduled Tasks'
      Component = 'Scheduled Tasks'
      CheckKind = 'Tasks'
      ActionLabel = 'Repair Task Action'
      HelpLabel = 'Repair Task Action'
      HelpAction = 'RepairScheduledTasks'
      EvidenceLabel = 'taskschd.msc'
      EvidenceAction = 'OpenTaskScheduler'
      EvidenceTarget = 'taskschd.msc'
      EvidenceAlwaysClickable = $false
    },
    [pscustomobject]@{
      Key = 'Firewall Rules Count'
      Component = 'Firewall Rules Count'
      CheckKind = 'RulesCount'
      ActionLabel = 'Open Firewall Rules View'
      HelpLabel = 'Open Firewall Rules View'
      HelpAction = 'OpenFirewallRulesView'
      EvidenceLabel = 'wf.msc'
      EvidenceAction = 'OpenFirewallRulesView'
      EvidenceTarget = 'wf.msc'
      EvidenceAlwaysClickable = $false
    },
    [pscustomobject]@{
      Key = 'Event Log Health'
      Component = 'Event Log Health'
      CheckKind = 'EventLog'
      ActionLabel = 'Open Event Viewer'
      HelpLabel = 'Open Event Viewer'
      HelpAction = 'OpenEventViewer'
      EvidenceLabel = 'eventvwr.msc'
      EvidenceAction = 'OpenEventViewer'
      EvidenceTarget = 'eventvwr.msc'
      EvidenceAlwaysClickable = $false
    },
    [pscustomobject]@{
      Key = 'Notify Queue Health'
      Component = 'Notify Queue Health'
      CheckKind = 'NotifyQueue'
      ActionLabel = 'Archive Queue'
      HelpLabel = 'Archive Queue'
      HelpAction = 'ArchiveNotifyQueue'
      EvidenceLabel = $queueRoot
      EvidenceAction = 'OpenFolder'
      EvidenceTarget = $queueRoot
      EvidenceAlwaysClickable = $false
    },
    [pscustomobject]@{
      Key = 'Last Test Summary'
      Component = 'Last Test Summary'
      CheckKind = 'LastTest'
      ActionLabel = 'Open Logs'
      HelpLabel = 'Open Logs'
      HelpAction = 'OpenFolder'
      EvidenceLabel = $logsPath
      EvidenceAction = 'OpenFolder'
      EvidenceTarget = $logsPath
      EvidenceAlwaysClickable = $false
    },
    [pscustomobject]@{
      Key = 'Last Diagnostics Bundle'
      Component = 'Last Diagnostics Bundle'
      CheckKind = 'LastDiagnostics'
      ActionLabel = 'Export Diagnostics Bundle'
      HelpLabel = 'Export Diagnostics Bundle'
      HelpAction = 'ExportDiagnosticsBundle'
      EvidenceLabel = $diagnosticsRoot
      EvidenceAction = 'OpenFolder'
      EvidenceTarget = $diagnosticsRoot
      EvidenceAlwaysClickable = $false
    }
  )

  return $script:InventoryBlueprint
}

function New-InventoryRowFromBlueprint {
  param(
    [Parameter(Mandatory)][object]$Entry,
    [AllowNull()][AllowEmptyString()][string]$Status,
    [AllowNull()][AllowEmptyString()][string]$Details,
    [AllowNull()][AllowEmptyString()][string]$SuggestedAction,
    [AllowNull()][AllowEmptyString()][string]$EvidencePath
  )
  $evidenceValue = if ($PSBoundParameters.ContainsKey('EvidencePath') -and $EvidencePath) { $EvidencePath } else { $Entry.EvidenceLabel }
  return New-Row -Check $Entry.Component `
    -Status $Status `
    -Details $Details `
    -SuggestedAction $SuggestedAction `
    -HelpLabel $Entry.HelpLabel `
    -HelpAction $Entry.HelpAction `
    -HelpTarget $Entry.HelpTarget `
    -HelpScriptCandidates $Entry.HelpScripts `
    -HelpMenu $Entry.HelpMenu `
    -DetailsWrap:([bool]$Entry.DetailsWrap) `
    -EvidencePath $evidenceValue `
    -ComponentKey $Entry.Key `
    -Component $Entry.Component `
    -EvidenceAction $Entry.EvidenceAction `
    -EvidenceTarget $Entry.EvidenceTarget `
    -EvidenceAlwaysClickable:([bool]$Entry.EvidenceAlwaysClickable)
}

function Initialize-InventoryGrid {
  param([Parameter(Mandatory)][object]$Grid)
  if ($script:InventoryInitialized) { return }
  $entries = Get-InventoryBlueprint -FirewallRoot $script:FirewallRoot -InstallerRoot $script:InstallerRoot
  $collection = New-Object System.Collections.ObjectModel.ObservableCollection[object]
  foreach ($entry in @($entries)) {
    $collection.Add((New-InventoryRowFromBlueprint -Entry $entry -Status 'UNKNOWN' -Details 'Not yet evaluated' -SuggestedAction '')) | Out-Null
  }
  $Grid.ItemsSource = $collection
  $script:InventoryInitialized = $true
}

function New-InventoryRow {
  param(
    [Parameter(Mandatory)][string]$Component,
    [AllowNull()][AllowEmptyString()][string]$Status,
    [AllowNull()][AllowEmptyString()][string]$Details,
    [AllowNull()][AllowEmptyString()][string]$SuggestedAction,
    [AllowNull()][AllowEmptyString()][string]$EvidencePath
  )
  $statusText = if ($Status) { $Status.ToUpperInvariant() } else { '' }
  [pscustomobject]@{
    Component      = $Component
    Status         = $statusText
    Details        = if ($Details) { $Details } else { '' }
    SuggestedAction= if ($SuggestedAction) { $SuggestedAction } else { '' }
    EvidencePath   = if ($EvidencePath) { $EvidencePath } else { '' }
  }
}

function Invoke-Inventory {
  param(
    [AllowNull()][AllowEmptyString()][string]$FirewallRoot,
    [AllowNull()][AllowEmptyString()][string]$InstallerRoot
  )

  $rows = @()
  $repoRoot = if ($FirewallRoot) { $FirewallRoot } elseif ($InstallerRoot) { Join-Path $InstallerRoot 'Firewall' } else { $null }
  $liveRoot = 'C:\Firewall'

  $scriptEntries = @(
    @{ Name = 'Admin Panel script'; RepoRel = 'User\FirewallAdminPanel.ps1'; LiveRel = 'User\FirewallAdminPanel.ps1' },
    @{ Name = 'User alert listener script'; RepoRel = 'User\FirewallToastListener.ps1'; LiveRel = 'User\FirewallToastListener.ps1' },
    @{ Name = 'User alert action handler'; RepoRel = 'User\FirewallToastActivate.ps1'; LiveRel = 'User\FirewallToastActivate.ps1' },
    @{ Name = 'Toast watchdog script'; RepoRel = 'System\FirewallToastWatchdog.ps1'; LiveRel = 'System\FirewallToastWatchdog.ps1' },
    @{ Name = 'User notifier entrypoint'; RepoRel = 'Monitor\Invoke-FirewallNotifier.ps1'; LiveRel = 'Monitor\Invoke-FirewallNotifier.ps1' },
    @{ Name = 'Defender integration script'; RepoRel = 'Maintenance\Enable-DefenderIntegration.ps1'; LiveRel = 'Maintenance\Enable-DefenderIntegration.ps1' }
  )

  foreach ($entry in $scriptEntries) {
    $candidates = @()
    if ($repoRoot) { $candidates += (Join-Path $repoRoot $entry.RepoRel) }
    $candidates += (Join-Path $liveRoot $entry.LiveRel)
    $candidates = @($candidates | Where-Object { $_ })
    $found = $null
    foreach ($candidate in $candidates) {
      if ($candidate -and (Test-Path -LiteralPath $candidate)) { $found = $candidate; break }
    }
    if ($found) {
      $rows += New-InventoryRow -Component $entry.Name -Status 'PASS' -Details ("Present: " + $found) -SuggestedAction 'None' -EvidencePath $found
    } else {
      $expected = if ($candidates.Count -gt 0) { $candidates -join [Environment]::NewLine } else { '(no candidates configured)' }
      $rows += New-InventoryRow -Component $entry.Name -Status 'FAIL' -Details 'Missing. Run Install or Repair.' -SuggestedAction 'Run Install/Repair' -EvidencePath $expected
    }
  }

  $taskEntries = @(
    @{ Name = 'Scheduled task: User Notifier'; TaskName = 'Firewall User Notifier' },
    @{ Name = 'Scheduled task: Notification Listener'; TaskName = 'FirewallCore Toast Listener' },
    @{ Name = 'Scheduled task: Notification Watchdog'; TaskName = 'FirewallCore Toast Watchdog' },
    @{ Name = 'Scheduled task: Tamper Guard'; TaskName = 'Firewall Tamper Guard' }
  )

  foreach ($entry in $taskEntries) {
    $state = Get-TaskState -Name $entry.TaskName
    if (-not $state) {
      $rows += New-InventoryRow -Component $entry.Name -Status 'FAIL' -Details 'Not registered.' -SuggestedAction 'Run Repair' -EvidencePath $entry.TaskName
      continue
    }
    $detail = "State: $state"
    $last = Get-TaskLastResult -Name $entry.TaskName
    if ($last) {
      $lastRun = if ($last.LastRunTime) { $last.LastRunTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'n/a' }
      $detail += (" | LastRun: " + $lastRun + " | LastResult: " + $last.LastTaskResult)
    }
    $status = if ($state -eq 'Ready' -or $state -eq 'Running') { 'PASS' } else { 'WARN' }
    $rows += New-InventoryRow -Component $entry.Name -Status $status -Details $detail -SuggestedAction 'Run Repair' -EvidencePath $entry.TaskName
  }

  $logName = 'FirewallCore'
  try {
    $log = Get-WinEvent -ListLog $logName -ErrorAction Stop
    $enabled = [bool]$log.IsEnabled
    $maxSizeMb = if ($log.MaximumSizeInBytes) { [Math]::Round(($log.MaximumSizeInBytes / 1MB), 0) } else { $null }
    $detail = "Enabled=$enabled"
    if ($maxSizeMb) { $detail += (" | MaxSizeMB=" + $maxSizeMb) }
    $status = if ($enabled) { 'PASS' } else { 'WARN' }
    $rows += New-InventoryRow -Component 'Event Log: FirewallCore' -Status $status -Details $detail -SuggestedAction 'Run Repair' -EvidencePath $logName
  } catch {
    $rows += New-InventoryRow -Component 'Event Log: FirewallCore' -Status 'FAIL' -Details 'Log not found or inaccessible.' -SuggestedAction 'Run Repair' -EvidencePath $logName
  }

  $queueRoot = Join-Path $env:ProgramData 'FirewallCore\NotifyQueue'
  if (Test-Path -LiteralPath $queueRoot) {
    $pendingPath = Join-Path $queueRoot 'Pending'
    $archivePath = Join-Path $queueRoot 'Archive'
    $pendingCount = @(Get-ChildItem -Path $pendingPath -File -ErrorAction SilentlyContinue).Count
    $archiveCount = @(Get-ChildItem -Path $archivePath -File -ErrorAction SilentlyContinue).Count
    $detail = "Pending=$pendingCount | Archive=$archiveCount"
    $rows += New-InventoryRow -Component 'Notify Queue' -Status 'PASS' -Details $detail -SuggestedAction 'Archive queue (optional)' -EvidencePath $queueRoot
  } else {
    $rows += New-InventoryRow -Component 'Notify Queue' -Status 'FAIL' -Details 'Queue directory missing.' -SuggestedAction 'Run Install/Repair' -EvidencePath $queueRoot
  }

  try {
    $rules = Get-NetFirewallRule -ErrorAction Stop
    $ruleList = @($rules)
    $v1 = @($ruleList | Where-Object { $_.Group -match '(?i)FirewallCore\\s*v1|FirewallCorev1' }).Count
    $v2 = @($ruleList | Where-Object { $_.Group -match '(?i)FirewallCore\\s*v2|FirewallCorev2' }).Count
    $v3 = @($ruleList | Where-Object { $_.Group -match '(?i)FirewallCore\\s*v3|FirewallCorev3' }).Count
    $total = @($ruleList).Count
    $detail = "Total=$total | FirewallCorev1=$v1 | FirewallCorev2=$v2 | FirewallCorev3=$v3"
    $rulesReport = Get-LatestRulesReportPath -ReportsPath 'C:\ProgramData\FirewallCore\Reports'
    $evidence = if ($rulesReport) { $rulesReport } else { $detail }
    $status = if ($total -gt 0) { 'PASS' } else { 'WARN' }
    $rows += New-InventoryRow -Component 'Firewall rules' -Status $status -Details $detail -SuggestedAction 'Run Rules Report' -EvidencePath $evidence
  } catch {
    $rows += New-InventoryRow -Component 'Firewall rules' -Status 'WARN' -Details ("Query failed: " + $_.Exception.Message) -SuggestedAction 'Run Rules Report' -EvidencePath '(failed)'
  }

  $certs = @()
  try { $certs += Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Where-Object { $_.Subject -match '(?i)FirewallCore' } } catch { }
  try { $certs += Get-ChildItem -Path Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | Where-Object { $_.Subject -match '(?i)FirewallCore' } } catch { }
  $certs = @($certs | Where-Object { $_ })
  if ($certs.Count -gt 0) {
    $thumbs = @($certs | Select-Object -First 3 | ForEach-Object { $_.Thumbprint })
    $detail = "Thumbprints: " + ($thumbs -join ', ')
    $rows += New-InventoryRow -Component 'Certificates (FirewallCore)' -Status 'PASS' -Details $detail -SuggestedAction 'None' -EvidencePath ($thumbs -join [Environment]::NewLine)
  } else {
    $rows += New-InventoryRow -Component 'Certificates (FirewallCore)' -Status 'WARN' -Details 'No FirewallCore certificates detected.' -SuggestedAction 'Install certificate if required' -EvidencePath 'Cert:\LocalMachine\My; Cert:\LocalMachine\Root'
  }

  $service = $null
  try { $service = Get-Service -Name 'FirewallCore*' -ErrorAction SilentlyContinue | Select-Object -First 1 } catch { }
  $pid = $null
  try { $pid = Get-ToastListenerPid } catch { }
  if ($service) {
    $status = if ($service.Status -eq 'Running') { 'PASS' } else { 'WARN' }
    $detail = "Service: " + $service.Name + " | Status: " + $service.Status
    $rows += New-InventoryRow -Component 'Core service/process' -Status $status -Details $detail -SuggestedAction 'Run Repair' -EvidencePath $service.Name
  } elseif ($pid) {
    $rows += New-InventoryRow -Component 'Core service/process' -Status 'PASS' -Details ("Listener PID: " + $pid) -SuggestedAction 'None' -EvidencePath ("PID=" + $pid)
  } else {
    $rows += New-InventoryRow -Component 'Core service/process' -Status 'WARN' -Details 'No FirewallCore service or listener process detected.' -SuggestedAction 'Run Repair' -EvidencePath 'Service/Process not found'
  }

  return $rows
}

function Apply-Inventory {
  param([AllowNull()][object[]]$Rows)
  try {
    if (-not $inventoryGrid) { return }
    $collection = New-Object System.Collections.ObjectModel.ObservableCollection[object]
    foreach ($row in @($Rows)) {
      if ($row) { $collection.Add($row) | Out-Null }
    }
    $inventoryGrid.ItemsSource = $collection
  } catch { }
}

# Legacy checklist (unused); replaced by the inventory blueprint.
function Invoke-Checklist-Deprecated {
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
    'C:\FirewallInstaller\Firewall\Tools\Run-RulesReport.ps1'
  )
  $latestRulesReport = Get-LatestRulesReportPath -ReportsPath $reportsFolder
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
      $rows += New-Row -Check "Firewall rules inventory" -Status "PASS" -Details $details -SuggestedAction $rulesSuggested -HelpLabel $rulesSuggested -HelpAction "RunRulesReport" -HelpTarget $reportsFolder -HelpScriptCandidates $reportScripts -DetailsWrap $true -EvidencePath $latestRulesReport
    } else {
      $rows += New-Row -Check "Firewall rules inventory" -Status "WARN" -Details $details -SuggestedAction $rulesSuggested -HelpLabel $rulesSuggested -HelpAction "RunRulesReport" -HelpTarget $reportsFolder -HelpScriptCandidates $reportScripts -DetailsWrap $true -EvidencePath $latestRulesReport
    }
  } catch {
    $rows += New-Row -Check "Firewall rules inventory" -Status "WARN" -Details ("Query failed: " + $_.Exception.Message) -SuggestedAction $rulesSuggested -HelpLabel $rulesSuggested -HelpAction "RunRulesReport" -HelpTarget $reportsFolder -HelpScriptCandidates $reportScripts -DetailsWrap $true -EvidencePath $latestRulesReport
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
    $latestWfas = Get-LatestWindowsFirewallLoggingSnapshot -ReportsPath $reportsFolder
    $wfasEvidence = if ($latestWfas) { $latestWfas.FullName } else { $profileLogDir }
    $rows += New-Row -Check "Firewall traffic logging (WFAS)" -Status $status -Details $details -SuggestedAction $suggestedAction -HelpLabel "Actions" -HelpAction "OpenWindowsFirewallLogs" -HelpTarget $profileLogDir -HelpMenu $wfasHelpMenu -DetailsWrap $true -EvidencePath $wfasEvidence
  } catch {
    $rows += New-Row -Check "Firewall traffic logging (WFAS)" -Status "FAIL" -Details ("Query failed: " + $_.Exception.Message) -SuggestedAction "Apply firewall logging baseline" -HelpLabel "Actions" -HelpAction "OpenWindowsFirewallLogs" -HelpTarget $profileLogDir -HelpMenu $wfasHelpMenu -DetailsWrap $true -EvidencePath $profileLogDir
  }

  # Notification listener PID
  $toastPid = Get-ToastListenerPid
  if ($toastPid) {
    $queuePath = Join-Path $env:ProgramData 'FirewallCore\NotifyQueue\Pending'
    $rows += New-Row "User alert engine process" "PASS" ("PID: " + $toastPid) "None" -EvidencePath $queuePath
  } else {
    $queuePath = Join-Path $env:ProgramData 'FirewallCore\NotifyQueue\Pending'
    $rows += New-Row -Check "User alert engine process" -Status "WARN" -Details "Not detected. Run Repair to restart notifications." -SuggestedAction "Open Logs" -HelpLabel "Open Logs" -HelpAction "OpenFolder" -HelpTarget $logsPath -EvidencePath $queuePath
  }

  # System actions status
  $rows += New-Row -Check "System action last run" -Status "WARN" -Details "No system action run yet." -SuggestedAction "Run a system action" -HelpLabel "Open Logs" -HelpAction "OpenFolder" -HelpTarget $logsPath -DetailsWrap $true -EvidencePath $logsPath

  # Reports / diagnostics artifacts
  $diagnosticsFolder = 'C:\ProgramData\FirewallCore\Diagnostics'
  $legacyDiagnosticsFolder = 'C:\ProgramData\FirewallCore\LifecycleExports'
  $reportRows = @(
    @{ Check = 'Quick Health Check'; Pattern = 'QuickHealth_*.json'; Folder = $reportsFolder; SuggestedAction = 'Run Quick Health Check'; HelpLabel = 'Open Reports'; HelpTarget = $reportsFolder },
    @{ Check = 'Baseline Drift Check'; Pattern = 'BaselineDrift_*.json'; Folder = $reportsFolder; SuggestedAction = 'Run Baseline Drift Check'; HelpLabel = 'Open Reports'; HelpTarget = $reportsFolder },
    @{ Check = 'Inbound Allow Risk Report'; Pattern = 'InboundAllowRisk_*.json'; Folder = $reportsFolder; SuggestedAction = 'Run Inbound Allow Risk Report'; HelpLabel = 'Open Reports'; HelpTarget = $reportsFolder },
    @{ Check = 'Export Diagnostics Bundle'; Pattern = 'BUNDLE_*.zip'; Folder = $diagnosticsFolder; Fallback = @($diagnosticsFolder, $legacyDiagnosticsFolder, $reportsFolder); SuggestedAction = 'Export Diagnostics Bundle'; HelpLabel = 'Open Diagnostics'; HelpTarget = $diagnosticsFolder }
  )

  foreach ($r in $reportRows) {
    $latest = $null
    $folders = @()
    if ($r.Fallback) {
      $folders = @($r.Fallback | Where-Object { $_ })
    } elseif ($r.Folder) {
      $folders = @($r.Folder)
    }
    foreach ($folder in $folders) {
      try {
        if (-not (Test-Path -LiteralPath $folder)) { continue }
        $candidate = Get-ChildItem -Path $folder -Filter $r.Pattern -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending |
          Select-Object -First 1
        if ($candidate) {
          if (-not $latest -or $candidate.LastWriteTime -gt $latest.LastWriteTime) { $latest = $candidate }
        }
      } catch { }
    }
    $status = if ($latest) { 'PASS' } else { 'WARN' }
    $details = if ($latest) { "Latest: " + $latest.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') } else { "No output found. Run " + $r.Check + "." }
    $evidence = if ($latest) { $latest.FullName } else { $r.Folder }
    $rows += New-Row -Check $r.Check -Status $status -Details $details -SuggestedAction $r.SuggestedAction -HelpLabel $r.HelpLabel -HelpAction "OpenFolder" -HelpTarget $r.HelpTarget -DetailsWrap $true -EvidencePath $evidence
  }

  return $rows
}

function Get-FirewallInstallState {
  $liveRoot = 'C:\Firewall'
  $coreScript = Join-Path $liveRoot 'Monitor\Firewall-Core.ps1'
  $monitorScript = Join-Path $liveRoot 'Monitor\Firewall-Monitor.ps1'
  $rootExists = Test-Path -LiteralPath $liveRoot
  $coreExists = Test-Path -LiteralPath $coreScript
  $monitorExists = Test-Path -LiteralPath $monitorScript

  if ($rootExists -and ($coreExists -or $monitorExists)) {
    $detail = 'Live root present'
    if ($coreExists) { $detail += (" | Core=" + $coreScript) }
    elseif ($monitorExists) { $detail += (" | Monitor=" + $monitorScript) }
    return [pscustomobject]@{
      Status = 'PASS'
      Details = $detail
      Evidence = $liveRoot
    }
  }

  $missing = @()
  if (-not $rootExists) { $missing += $liveRoot }
  if (-not $coreExists -and -not $monitorExists) { $missing += 'Monitor scripts missing' }
  $detailText = if ($missing.Count -gt 0) { "Missing: " + ($missing -join '; ') } else { 'Missing core components.' }
  return [pscustomobject]@{
    Status = 'FAIL'
    Details = $detailText
    Evidence = $liveRoot
  }
}

function Test-TaskActionContract {
  param([Parameter(Mandatory)][object]$Task)
  $missing = @()
  $mismatch = @()
  $actions = @($Task.Actions)
  if (-not $actions -or $actions.Count -eq 0) {
    return [pscustomobject]@{ Ok = $false; Missing = @(); Mismatch = @('NoActions') }
  }

  foreach ($action in $actions) {
    $execute = [string]$action.Execute
    if (-not $execute -or $execute -notmatch '(?i)powershell\.exe$') {
      $mismatch += ("Execute=" + $execute)
      continue
    }
    $args = [string]$action.Arguments
    if ($args -notmatch '(?i)(^|\\s)-NoLogo(\\s|$)') { $missing += '-NoLogo' }
    if ($args -notmatch '(?i)(^|\\s)-NoProfile(\\s|$)') { $missing += '-NoProfile' }
    if ($args -notmatch '(?i)(^|\\s)-NonInteractive(\\s|$)') { $missing += '-NonInteractive' }
    if ($args -match '(?i)-ExecutionPolicy\\s+\\S+' -and $args -notmatch '(?i)-ExecutionPolicy\\s+Bypass') {
      $mismatch += 'ExecutionPolicy'
    } elseif ($args -notmatch '(?i)(^|\\s)-ExecutionPolicy(\\s|$)') {
      $missing += '-ExecutionPolicy'
    }
    if ($args -match '(?i)-WindowStyle\\s+\\S+' -and $args -notmatch '(?i)-WindowStyle\\s+Hidden') {
      $mismatch += 'WindowStyle'
    } elseif ($args -notmatch '(?i)(^|\\s)-WindowStyle(\\s|$)') {
      $missing += '-WindowStyle'
    }
  }

  $missing = @($missing | Sort-Object -Unique)
  $mismatch = @($mismatch | Sort-Object -Unique)
  return [pscustomobject]@{
    Ok = ($missing.Count -eq 0 -and $mismatch.Count -eq 0)
    Missing = $missing
    Mismatch = $mismatch
  }
}

function Get-ScheduledTasksHealth {
  $taskNames = @(
    'Firewall Core Monitor',
    'Firewall WFP Monitor',
    'Firewall-Defender-Integration',
    'FirewallCore Toast Listener',
    'FirewallCore Toast Watchdog',
    'FirewallCore User Notifier',
    'Firewall Tamper Guard'
  )
  $missing = @()
  $badActions = @()
  $badResults = @()

  foreach ($name in $taskNames) {
    $task = $null
    try { $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue } catch { $task = $null }
    if (-not $task) {
      $missing += $name
      continue
    }

    $contract = Test-TaskActionContract -Task $task
    if (-not $contract.Ok) {
      $missingFlags = if ($contract.Missing -and $contract.Missing.Count -gt 0) { " Missing=" + ($contract.Missing -join ',') } else { '' }
      $mismatchFlags = if ($contract.Mismatch -and $contract.Mismatch.Count -gt 0) { " Mismatch=" + ($contract.Mismatch -join ',') } else { '' }
      $badActions += ($name + $missingFlags + $mismatchFlags)
    }

    $info = $null
    try { $info = Get-ScheduledTaskInfo -TaskName $name -ErrorAction SilentlyContinue } catch { $info = $null }
    if ($info -and $info.LastTaskResult -ne 0) {
      $lastRun = if ($info.LastRunTime) { $info.LastRunTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'n/a' }
      $badResults += ($name + " LastResult=" + $info.LastTaskResult + " LastRun=" + $lastRun)
    }
  }

  $issues = @()
  if ($missing.Count -gt 0) { $issues += ("Missing=" + ($missing -join ', ')) }
  if ($badActions.Count -gt 0) { $issues += ("ActionMismatch=" + ($badActions -join ' | ')) }
  if ($badResults.Count -gt 0) { $issues += ("LastResult=" + ($badResults -join ' | ')) }

  $status = if ($issues.Count -gt 0) { 'FAIL' } else { 'PASS' }
  $detail = if ($issues.Count -gt 0) { $issues -join ' || ' } else { 'All scheduled tasks healthy' }
  return [pscustomobject]@{
    Status = $status
    Details = $detail
  }
}

function Get-FirewallRuleCounts {
  try {
    $rules = Get-NetFirewallRule -ErrorAction Stop
    $ruleList = @($rules)
    $v1 = @($ruleList | Where-Object { $_.Group -match '(?i)FirewallCore\\s*v1|FirewallCorev1' }).Count
    $v2 = @($ruleList | Where-Object { $_.Group -match '(?i)FirewallCore\\s*v2|FirewallCorev2' }).Count
    $v3 = @($ruleList | Where-Object { $_.Group -match '(?i)FirewallCore\\s*v3|FirewallCorev3' }).Count
    $total = $ruleList.Count
    $detail = "Total=$total | FirewallCorev1=$v1 | FirewallCorev2=$v2 | FirewallCorev3=$v3"
    $status = if ($total -gt 0) { 'PASS' } else { 'FAIL' }
    return [pscustomobject]@{
      Status = $status
      Details = $detail
    }
  } catch {
    return [pscustomobject]@{
      Status = 'FAIL'
      Details = ("Query failed: " + $_.Exception.Message)
    }
  }
}

function Get-FirewallEventLogHealth {
  $logName = 'FirewallCore'
  try {
    $log = Get-WinEvent -ListLog $logName -ErrorAction Stop
    $enabled = [bool]$log.IsEnabled
    $providers = @('FirewallCore','FirewallCore-Pentest')
    $lastEvent = $null
    foreach ($provider in $providers) {
      try {
        $event = Get-WinEvent -FilterHashtable @{ LogName = $logName; ProviderName = $provider } -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($event) { $lastEvent = $event; break }
      } catch { }
    }
    $hasProviderEvent = [bool]$lastEvent
    $lastStamp = if ($lastEvent -and $lastEvent.TimeCreated) { $lastEvent.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss') } else { 'n/a' }
    $detail = "Enabled=$enabled | ProviderEvents=$hasProviderEvent | LastEvent=$lastStamp"
    $status = if ($enabled -and $hasProviderEvent) { 'PASS' } elseif ($enabled) { 'WARN' } else { 'FAIL' }
    return [pscustomobject]@{
      Status = $status
      Details = $detail
    }
  } catch {
    return [pscustomobject]@{
      Status = 'FAIL'
      Details = 'Log not found or inaccessible.'
    }
  }
}

function Get-NotifyQueueHealth {
  $queueRoot = Join-Path $env:ProgramData 'FirewallCore\NotifyQueue'
  if (-not (Test-Path -LiteralPath $queueRoot)) {
    return [pscustomobject]@{
      Status = 'FAIL'
      Details = 'Notify queue missing.'
      Evidence = $queueRoot
    }
  }

  $workingDirs = @('Pending','Processing','Working')
  $archiveDirs = @('Archive','Processed')
  $failedDir = 'Failed'
  $workingCount = 0
  foreach ($dir in $workingDirs) {
    $path = Join-Path $queueRoot $dir
    if (Test-Path -LiteralPath $path) {
      $workingCount += @(Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue).Count
    }
  }
  $failedPath = Join-Path $queueRoot $failedDir
  $failedCount = if (Test-Path -LiteralPath $failedPath) { @(Get-ChildItem -Path $failedPath -File -ErrorAction SilentlyContinue).Count } else { 0 }
  $archivedCount = 0
  foreach ($dir in $archiveDirs) {
    $path = Join-Path $queueRoot $dir
    if (Test-Path -LiteralPath $path) {
      $archivedCount += @(Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue).Count
    }
  }

  $detail = "Working=$workingCount | Failed=$failedCount | Archived=$archivedCount"
  $status = if ($failedCount -gt 0) { 'WARN' } else { 'PASS' }
  return [pscustomobject]@{
    Status = $status
    Details = $detail
    Evidence = $queueRoot
  }
}

function Archive-NotifyQueue {
  param([AllowNull()][AllowEmptyString()][string]$QueueRoot)
  $root = if ($QueueRoot) { $QueueRoot } else { Join-Path $env:ProgramData 'FirewallCore\NotifyQueue' }
  if (-not (Test-Path -LiteralPath $root)) {
    return [pscustomobject]@{ Archived = 0; ArchivePath = $root; Missing = $true }
  }
  $archivePath = Join-Path $root 'Archive'
  try { New-Item -ItemType Directory -Force -Path $archivePath | Out-Null } catch { }
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $dirs = @('Pending','Processing','Failed')
  $archived = 0

  foreach ($dir in $dirs) {
    $path = Join-Path $root $dir
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $files = Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
      $dest = Join-Path $archivePath ($file.BaseName + '_' + $stamp + '_' + ([guid]::NewGuid().ToString('N')) + $file.Extension)
      try {
        Move-Item -LiteralPath $file.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
        $archived++
      } catch { }
    }
  }

  return [pscustomobject]@{
    Archived = $archived
    ArchivePath = $archivePath
    Missing = $false
  }
}

function Get-LastAdminPanelTestSummary {
  $logPath = Join-Path $env:ProgramData 'FirewallCore\Logs\AdminPanel-Actions.log'
  if (-not (Test-Path -LiteralPath $logPath)) {
    return [pscustomobject]@{
      Status = 'WARN'
      Details = 'No test log found.'
      Evidence = $logPath
    }
  }

  $lines = @()
  try { $lines = Get-Content -LiteralPath $logPath -Tail 400 -ErrorAction SilentlyContinue } catch { $lines = @() }
  if (-not $lines -or $lines.Count -eq 0) {
    return [pscustomobject]@{
      Status = 'WARN'
      Details = 'No tests recorded yet.'
      Evidence = $logPath
    }
  }

  $line = ($lines | Where-Object { $_ -match 'Category=Test' } | Select-Object -Last 1)
  if (-not $line) {
    $line = ($lines | Where-Object { $_ -match 'Action="Test:' -or $_ -match 'Action="Dev/Lab:' } | Select-Object -Last 1)
  }
  if (-not $line) {
    return [pscustomobject]@{
      Status = 'WARN'
      Details = 'No tests recorded yet.'
      Evidence = $logPath
    }
  }

  $timestamp = $null
  if ($line -match '^\\[(?<ts>[^\\]]+)\\]') { $timestamp = $Matches.ts }
  $actionName = $null
  if ($line -match 'Action="(?<action>[^"]+)"') { $actionName = $Matches.action }
  $result = $null
  if ($line -match 'Result=(?<result>OK|FAIL)') { $result = $Matches.result }

  $status = if ($result -eq 'FAIL') { 'FAIL' } else { 'PASS' }
  $detail = if ($actionName -and $timestamp) { ($actionName + " | " + $timestamp) } elseif ($actionName) { $actionName } elseif ($timestamp) { "Last test at " + $timestamp } else { 'Last test recorded' }
  return [pscustomobject]@{
    Status = $status
    Details = $detail
    Evidence = $logPath
  }
}

function Get-LastDiagnosticsBundle {
  $root = 'C:\ProgramData\FirewallCore\Diagnostics'
  if (-not (Test-Path -LiteralPath $root)) {
    return [pscustomobject]@{
      Status = 'WARN'
      Details = 'Diagnostics folder missing.'
      Evidence = $root
    }
  }
  $latestZip = Get-ChildItem -Path $root -Filter 'BUNDLE_*.zip' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  $latestFolder = Get-ChildItem -Path $root -Directory -Filter 'BUNDLE_*' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  $latest = $latestZip
  if ($latestFolder -and (-not $latest -or $latestFolder.LastWriteTime -gt $latest.LastWriteTime)) { $latest = $latestFolder }
  if ($latest) {
    $detail = "Latest: " + $latest.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
    return [pscustomobject]@{
      Status = 'PASS'
      Details = $detail
      Evidence = $latest.FullName
    }
  }
  return [pscustomobject]@{
    Status = 'WARN'
    Details = 'No diagnostics bundle found.'
    Evidence = $root
  }
}

function Get-FirewallEventViewerViewPath {
  $candidates = @(
    'C:\ProgramData\Microsoft\Event Viewer\Views\FirewallCore-Events.xml',
    'C:\ProgramData\FirewallCore\User\Views\FirewallCore-Events.xml',
    'C:\Firewall\Monitor\EventViews\FirewallCore-Events.xml',
    'C:\FirewallInstaller\Firewall\Monitor\EventViews\FirewallCore-Events.xml'
  )
  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
  }
  return $null
}

function New-AdminPanelSnapshot {
  param([Parameter(Mandatory)][string]$Label)
  $root = Join-Path $env:ProgramData 'FirewallCore\Snapshots'
  try { New-Item -ItemType Directory -Force -Path $root | Out-Null } catch { }

  $safe = $Label -replace '[^A-Za-z0-9_-]', '-'
  if ([string]::IsNullOrWhiteSpace($safe)) { $safe = 'Snapshot' }
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $path = Join-Path $root ("AdminPanelSnapshot_{0}_{1}.txt" -f $safe, $stamp)

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("SnapshotLabel=$Label")
  $lines.Add("Timestamp=" + (Get-Date -Format 'o'))

  $install = Get-FirewallInstallState
  if ($install) { $lines.Add("InstallState=" + $install.Status + " | " + $install.Details) }

  $tasks = Get-ScheduledTasksHealth
  if ($tasks) { $lines.Add("ScheduledTasks=" + $tasks.Status + " | " + $tasks.Details) }

  $rules = Get-FirewallRuleCounts
  if ($rules) { $lines.Add("Rules=" + $rules.Status + " | " + $rules.Details) }

  $eventLog = Get-FirewallEventLogHealth
  if ($eventLog) { $lines.Add("EventLog=" + $eventLog.Status + " | " + $eventLog.Details) }

  $queue = Get-NotifyQueueHealth
  if ($queue) { $lines.Add("NotifyQueue=" + $queue.Status + " | " + $queue.Details) }

  try { $lines | Set-Content -Path $path -Encoding ASCII } catch { }
  return $path
}

function Invoke-Checklist {
  $rows = @()
  $entries = Get-InventoryBlueprint -FirewallRoot $script:FirewallRoot -InstallerRoot $script:InstallerRoot

  foreach ($entry in @($entries)) {
    $status = 'UNKNOWN'
    $details = 'Not yet evaluated'
    $suggested = if ($entry.ActionLabel) { [string]$entry.ActionLabel } else { '' }
    $evidence = $null

    switch ($entry.CheckKind) {
      'Install' {
        $result = Get-FirewallInstallState
        $status = $result.Status
        $details = $result.Details
        $evidence = $result.Evidence
      }
      'Tasks' {
        $result = Get-ScheduledTasksHealth
        $status = $result.Status
        $details = $result.Details
      }
      'RulesCount' {
        $result = Get-FirewallRuleCounts
        $status = $result.Status
        $details = $result.Details
      }
      'EventLog' {
        $result = Get-FirewallEventLogHealth
        $status = $result.Status
        $details = $result.Details
        $viewPath = Get-FirewallEventViewerViewPath
        if ($viewPath) { $evidence = $viewPath }
      }
      'NotifyQueue' {
        $result = Get-NotifyQueueHealth
        $status = $result.Status
        $details = $result.Details
        $evidence = $result.Evidence
      }
      'LastTest' {
        $result = Get-LastAdminPanelTestSummary
        $status = $result.Status
        $details = $result.Details
        $evidence = $result.Evidence
      }
      'LastDiagnostics' {
        $result = Get-LastDiagnosticsBundle
        $status = $result.Status
        $details = $result.Details
        $evidence = $result.Evidence
      }
      default {
        $status = 'UNKNOWN'
        $details = 'Not yet evaluated'
      }
    }

    if ($status -eq 'PASS') { $suggested = 'No action needed' }
    $rows += New-InventoryRowFromBlueprint -Entry $entry -Status $status -Details $details -SuggestedAction $suggested -EvidencePath $evidence
  }

  return $rows
}

# XAML (Phase B UI + wiring)
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="FirewallCore Admin Panel (Sprint 3 - Phase B)"
        Height="760" Width="1080" MinHeight="700" MinWidth="920"
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
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="0"/>
      <Setter Property="Foreground" Value="{DynamicResource PanelForeground}"/>
      <Setter Property="HeaderTemplate">
        <Setter.Value>
          <DataTemplate>
            <TextBlock Text="{Binding}" FontWeight="Bold" Foreground="{DynamicResource PanelForeground}" Margin="0,0,0,6"/>
          </DataTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="Button">
      <Setter Property="Background" Value="{DynamicResource ControlBackground}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource ControlForeground}"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Background" Value="{DynamicResource ControlBackground}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource ControlForeground}"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    </Style>
    <Style TargetType="DataGrid">
      <Setter Property="Background" Value="{DynamicResource ControlBackground}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource PanelBorder}"/>
      <Setter Property="Foreground" Value="{DynamicResource ControlForeground}"/>
      <Setter Property="RowBackground" Value="{DynamicResource ControlBackground}"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    </Style>
    <Style TargetType="DataGridCell">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
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
                 Text="Health / Status Checklist" />
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

    <Grid Grid.Row="1" Margin="0,8,0,8">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <StackPanel Grid.Row="0">
        <TextBlock x:Name="TxtRefreshStatus" Margin="0,0,0,6" Opacity="0.75"/>
        <ProgressBar x:Name="ProgressRefresh" Height="6" Margin="0,0,0,8" Minimum="0" Maximum="100" Value="0" Visibility="Collapsed"/>
        <DataGrid x:Name="GridChecklist" Margin="0,0,0,12"
                  AutoGenerateColumns="False" CanUserAddRows="False" IsReadOnly="True" MinRowHeight="32" RowHeight="NaN" FontSize="11"
                  HeadersVisibility="Column" GridLinesVisibility="All"
                  CanUserResizeColumns="True" CanUserReorderColumns="True"
                  EnableRowVirtualization="False" EnableColumnVirtualization="False"
                  VirtualizingPanel.IsVirtualizing="False"
                  ScrollViewer.CanContentScroll="False"
                  ScrollViewer.VerticalScrollBarVisibility="Disabled"
                  ScrollViewer.HorizontalScrollBarVisibility="Disabled">
          <DataGrid.CellStyle>
            <Style TargetType="DataGridCell">
              <Setter Property="Padding" Value="4,1"/>
              <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            </Style>
          </DataGrid.CellStyle>
          <DataGrid.RowStyle>
            <Style TargetType="DataGridRow">
              <Setter Property="MinHeight" Value="32"/>
              <Setter Property="VerticalContentAlignment" Value="Top"/>
              <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
              <Style.Triggers>
                <DataTrigger Binding="{Binding ComponentKey}" Value="Firewall Rules Count">
                  <Setter Property="MinHeight" Value="40"/>
                </DataTrigger>
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
              <Setter Property="Padding" Value="4,2"/>
              <Setter Property="FontSize" Value="11"/>
            </Style>
          </DataGrid.ColumnHeaderStyle>
          <DataGrid.Columns>
            <DataGridTextColumn Header="Component" Binding="{Binding Component}" Width="180" MinWidth="160" MaxWidth="300">
              <DataGridTextColumn.ElementStyle>
                <Style TargetType="TextBlock">
                  <Setter Property="TextWrapping" Value="NoWrap"/>
                  <Setter Property="MaxHeight" Value="20"/>
                  <Setter Property="TextTrimming" Value="CharacterEllipsis"/>
                  <Setter Property="VerticalAlignment" Value="Center"/>
                  <Setter Property="TextAlignment" Value="Left"/>
                  <Setter Property="HorizontalAlignment" Value="Left"/>
                  <Setter Property="ToolTip" Value="{Binding Component}"/>
                  <Style.Triggers>
                    <DataTrigger Binding="{Binding ComponentKey}" Value="Firewall rules inventory">
                      <Setter Property="TextWrapping" Value="Wrap"/>
                      <Setter Property="TextTrimming" Value="None"/>
                      <Setter Property="MaxHeight" Value="36"/>
                      <Setter Property="Width" Value="120"/>
                      <Setter Property="VerticalAlignment" Value="Top"/>
                    </DataTrigger>
                  </Style.Triggers>
                </Style>
              </DataGridTextColumn.ElementStyle>
            </DataGridTextColumn>
            <DataGridTemplateColumn Header="Status" Width="110" MinWidth="96">
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
                    <DataTrigger Binding="{Binding Status}" Value="WORKING">
                      <Setter Property="Background" Value="#E6F0FB"/>
                      <Setter Property="Foreground" Value="#1F4E79"/>
                    </DataTrigger>
                    <DataTrigger Binding="{Binding Status}" Value="UNKNOWN">
                      <Setter Property="Background" Value="#EFEFEF"/>
                      <Setter Property="Foreground" Value="#5A5A5A"/>
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
            <DataGridTemplateColumn Header="Details" Width="1.2*" MinWidth="220" MaxWidth="520">
              <DataGridTemplateColumn.CellTemplate>
                <DataTemplate>
                  <Expander IsExpanded="False">
                    <Expander.Header>
                      <TextBlock Text="{Binding Details}" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"
                                 VerticalAlignment="Top" ToolTip="{Binding Details}" MaxHeight="20"/>
                    </Expander.Header>
                    <TextBlock Text="{Binding Details}" TextWrapping="Wrap" Margin="0,4,0,0"/>
                  </Expander>
                </DataTemplate>
              </DataGridTemplateColumn.CellTemplate>
            </DataGridTemplateColumn>
            <DataGridTemplateColumn Header="Recommended Action" Width="170" MinWidth="150" MaxWidth="260">
              <DataGridTemplateColumn.CellTemplate>
                <DataTemplate>
                  <Grid>
                    <TextBlock x:Name="ActionText" Text="{Binding SuggestedAction}" TextWrapping="Wrap"
                               VerticalAlignment="Top" ToolTip="{Binding SuggestedAction}" MaxHeight="24"/>
                    <Button x:Name="ActionButton" Tag="HelpAction" Content="{Binding SuggestedAction}"
                            Padding="6,2" HorizontalAlignment="Left" VerticalAlignment="Top" Visibility="Collapsed"/>
                  </Grid>
                  <DataTemplate.Triggers>
                    <DataTrigger Binding="{Binding Status}" Value="PASS">
                      <Setter TargetName="ActionButton" Property="Visibility" Value="Collapsed"/>
                      <Setter TargetName="ActionText" Property="Text" Value="No action needed"/>
                      <Setter TargetName="ActionText" Property="Visibility" Value="Visible"/>
                    </DataTrigger>
                    <DataTrigger Binding="{Binding Status}" Value="FAIL">
                      <Setter TargetName="ActionButton" Property="Visibility" Value="Visible"/>
                      <Setter TargetName="ActionText" Property="Visibility" Value="Collapsed"/>
                    </DataTrigger>
                    <DataTrigger Binding="{Binding Status}" Value="WARN">
                      <Setter TargetName="ActionButton" Property="Visibility" Value="Visible"/>
                      <Setter TargetName="ActionText" Property="Visibility" Value="Collapsed"/>
                    </DataTrigger>
                    <DataTrigger Binding="{Binding SuggestedAction}" Value="">
                      <Setter TargetName="ActionButton" Property="Visibility" Value="Collapsed"/>
                      <Setter TargetName="ActionText" Property="Visibility" Value="Visible"/>
                    </DataTrigger>
                  </DataTemplate.Triggers>
                </DataTemplate>
              </DataGridTemplateColumn.CellTemplate>
            </DataGridTemplateColumn>
            <DataGridTemplateColumn Header="Evidence / Path" Width="2*" MinWidth="220" MaxWidth="700">
              <DataGridTemplateColumn.CellTemplate>
                <DataTemplate>
                  <Grid>
                    <TextBlock x:Name="EvidencePlaceholder" Text="" VerticalAlignment="Top"/>
                    <Button x:Name="EvidenceButton" Tag="EvidenceAction"
                            Background="Transparent" BorderThickness="0" Padding="0"
                            HorizontalAlignment="Left" VerticalAlignment="Top"
                            Foreground="{DynamicResource AccentBrush}">
                      <TextBlock Text="{Binding EvidencePath}" TextWrapping="Wrap" ToolTip="{Binding EvidencePath}" MaxHeight="32"/>
                    </Button>
                  </Grid>
                  <DataTemplate.Triggers>
                    <DataTrigger Binding="{Binding Status}" Value="PASS">
                      <Setter TargetName="EvidenceButton" Property="Visibility" Value="Collapsed"/>
                      <Setter TargetName="EvidencePlaceholder" Property="Visibility" Value="Visible"/>
                    </DataTrigger>
                    <DataTrigger Binding="{Binding Status}" Value="UNKNOWN">
                      <Setter TargetName="EvidenceButton" Property="Visibility" Value="Collapsed"/>
                      <Setter TargetName="EvidencePlaceholder" Property="Visibility" Value="Visible"/>
                    </DataTrigger>
                    <DataTrigger Binding="{Binding Status}" Value="WORKING">
                      <Setter TargetName="EvidenceButton" Property="Visibility" Value="Collapsed"/>
                      <Setter TargetName="EvidencePlaceholder" Property="Visibility" Value="Visible"/>
                    </DataTrigger>
                    <DataTrigger Binding="{Binding EvidenceAlwaysClickable}" Value="True">
                      <Setter TargetName="EvidenceButton" Property="Visibility" Value="Visible"/>
                      <Setter TargetName="EvidencePlaceholder" Property="Visibility" Value="Collapsed"/>
                    </DataTrigger>
                  </DataTemplate.Triggers>
                </DataTemplate>
              </DataGridTemplateColumn.CellTemplate>
            </DataGridTemplateColumn>
          </DataGrid.Columns>
        </DataGrid>
      </StackPanel>

      <Grid Grid.Row="1">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="12"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <GroupBox Header="Actions" Grid.Column="0">
          <StackPanel Margin="8">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <TextBlock Grid.Column="0" VerticalAlignment="Center" Text="Refresh interval:" Margin="0,0,8,0"/>
              <ComboBox Grid.Column="1" x:Name="IntervalCombo" Width="140" SelectedIndex="1">
                <ComboBoxItem Content="2 sec" Tag="2000"/>
                <ComboBoxItem Content="5 sec" Tag="5000"/>
                <ComboBoxItem Content="10 sec" Tag="10000"/>
                <ComboBoxItem Content="15 sec" Tag="15000"/>
              </ComboBox>
              <StackPanel Grid.Column="2" Margin="12,0,0,0" VerticalAlignment="Center">
                <CheckBox x:Name="ChkAutoRefresh" VerticalAlignment="Center" Content="Auto-refresh" IsChecked="False"/>
                <CheckBox x:Name="ChkReapplyPolicy" Margin="0,4,0,0" VerticalAlignment="Center" Content="Re-apply policy"/>
              </StackPanel>
              <Button Grid.Column="3" x:Name="BtnRefreshNow" Width="110" Margin="12,0,0,0" HorizontalAlignment="Left" Content="Refresh Now"/>
            </Grid>

            <StackPanel Orientation="Horizontal" Margin="0,6,0,0" VerticalAlignment="Center">
              <TextBlock VerticalAlignment="Center" Text="Repair options:" Margin="0,0,8,0"/>
              <CheckBox x:Name="ChkRestartNotifications" Margin="0,0,12,0" VerticalAlignment="Center" Content="Restart notifications" IsChecked="True"/>
              <CheckBox x:Name="ChkArchiveQueue" Margin="0,0,12,0" VerticalAlignment="Center" Content="Archive queue" IsChecked="True"/>
            </StackPanel>
            <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
              <Button x:Name="BtnApplyRepair" Width="120" Margin="0,0,6,0" Content="Repair"/>
              <Button x:Name="BtnResetRepair" Width="120" Margin="6,0,0,0" Content="Reset Defaults"/>
            </StackPanel>

            <TextBlock x:Name="TxtRepairStatus" Margin="0,4,0,0" Opacity="0.75"/>

            <Separator Margin="0,6,0,6"/>

            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <TextBlock Grid.Column="0" Text="Action:" VerticalAlignment="Center" Margin="0,0,8,0"/>
              <ComboBox Grid.Column="1" x:Name="SystemActionSelect" Width="220"/>
              <Button Grid.Column="2" x:Name="BtnRunAction" Width="120" Margin="8,0,0,0" Content="Run Action"/>
            </Grid>
            <TextBlock x:Name="TxtActionStatus" Margin="0,4,0,0" Opacity="0.75"/>

            <Separator Margin="0,6,0,6"/>
            <TextBlock Text="Quick Actions" FontWeight="SemiBold" Margin="0,0,0,4"/>
            <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
              <Button x:Name="BtnUninstall" Width="120" Content="Uninstall"/>
              <CheckBox x:Name="ChkKeepLogs" Content="Keep logs" Margin="8,4,0,0" VerticalAlignment="Center"/>
            </StackPanel>
            <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
              <Button x:Name="BtnOpenLogs" Width="120" Content="Open Logs"/>
              <Button x:Name="BtnOpenEventViewer" Width="160" Margin="8,0,0,0" Content="Open Event Viewer"/>
            </StackPanel>
            <StackPanel Orientation="Horizontal">
              <Button x:Name="BtnExportBaseline" Width="170" Content="Export Baseline + SHA256"/>
              <Button x:Name="BtnExportDiagnostics" Width="190" Margin="8,0,0,0" Content="Export Diagnostics Bundle"/>
            </StackPanel>

          </StackPanel>
        </GroupBox>

        <GroupBox Header="Admin Tests" Grid.Column="2">
          <Grid x:Name="TestsHost" Margin="10">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="2*"/>
              <ColumnDefinition Width="12"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <StackPanel Grid.Column="0">
              <TextBlock Text="Run health checks and reports to validate protection and logging."
                         Opacity="0.85"
                         Margin="0,0,0,8"/>

              <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                <TextBlock Text="Test:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                <ComboBox x:Name="TestActionSelect" Width="200" />
                <Button x:Name="BtnRunTest" Width="96" Margin="6,0,0,0" Content="Run Test"/>
              </StackPanel>

              <TextBlock x:Name="TxtTestStatus" Margin="0,6,0,0" Opacity="0.75"/>
            </StackPanel>

            <StackPanel Grid.Column="2">
              <StackPanel x:Name="DevGateRow" Orientation="Horizontal" VerticalAlignment="Center">
                <CheckBox x:Name="chkDeveloperMode" Content="Dev Mode" Margin="0,0,12,0"/>
                <TextBlock Text="Lab simulations (Dev Mode only; no exploitation/persistence)."
                           Opacity="0.75" TextWrapping="Wrap"/>
              </StackPanel>

              <TextBlock x:Name="TxtDevUnlockStatus" Margin="0,4,0,0" Opacity="0.75"/>

              <TextBlock x:Name="DevTestsHeader"
                         Text="Lab actions"
                         FontWeight="SemiBold"
                         Margin="0,10,0,2"/>
              <TextBlock x:Name="DevTestsNote"
                         Text="Lab-only simulation (no exploitation/persistence)"
                         Opacity="0.75"
                         Margin="0,0,0,6"/>

              <StackPanel x:Name="DevActionRow" Orientation="Horizontal" VerticalAlignment="Center">
                <TextBlock Text="Dev/Lab:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                <ComboBox x:Name="DevActionSelect" Width="260" />
                <Button x:Name="BtnRunDevTest" Width="150" Margin="8,0,0,0" Content="Run Dev/Lab Action"/>
              </StackPanel>

              <TextBlock x:Name="TxtDevStatus" Margin="0,6,0,0" Opacity="0.75"/>
            </StackPanel>
          </Grid>
        </GroupBox>
      </Grid>
    </Grid>

    <Grid Grid.Row="2">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <Button Grid.Column="1" x:Name="BtnClose" Width="110" Content="Close" Margin="0,6,0,0"/>
    </Grid>
  </Grid>
</Window>
"@

# Build window safely
$win = [Windows.Markup.XamlReader]::Parse($xaml)
$script:Window = $win
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
$inventoryGrid = $null
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
$txtActionOutput = $win.FindName("TxtActionOutput")
$systemActionSelect = $win.FindName("SystemActionSelect")
$btnRunAction = $win.FindName("BtnRunAction")
$btnRefreshNow = $win.FindName("BtnRefreshNow")
$txtActionStatus = $win.FindName("TxtActionStatus")
$btnUninstall = $win.FindName("BtnUninstall")
$chkKeepLogs = $win.FindName("ChkKeepLogs")
$btnOpenLogs = $win.FindName("BtnOpenLogs")
$btnOpenEventViewer = $win.FindName("BtnOpenEventViewer")
$btnExportBaseline = $win.FindName("BtnExportBaseline")
$btnExportDiagnostics = $win.FindName("BtnExportDiagnostics")

$ActionScripts = @{
  Refresh       = @(
    (Join-Path $script:FirewallRoot 'Tools\Run-QuickHealthCheck.ps1'),
    "C:\Firewall\Tools\Run-QuickHealthCheck.ps1"
  )
  Install       = @(
    (Join-Path $script:InstallerRoot 'Install.cmd'),
    "C:\FirewallInstaller\Install.cmd",
    "C:\Firewall\Install.cmd"
  )
  Repair        = @(
    (Join-Path $script:InstallerRoot 'Repair.cmd'),
    "C:\Firewall\Repair.cmd",
    "C:\FirewallInstaller\Repair.cmd",
    (Join-Path $script:FirewallRoot 'Tools\Repair-FirewallCore.ps1'),
    "C:\Firewall\Tools\Repair-FirewallCore.ps1"
  )
  Maintenance   = @(
    (Join-Path $script:InstallerRoot 'Tools\Maintenance-FirewallCore.ps1'),
    (Join-Path $script:FirewallRoot 'Tools\Maintenance-FirewallCore.ps1'),
    "C:\Firewall\Tools\Maintenance-FirewallCore.ps1",
    "C:\FirewallInstaller\Tools\Maintenance-FirewallCore.ps1"
  )
  Uninstall     = @(
    (Join-Path $script:InstallerRoot 'Uninstall.cmd'),
    "C:\Firewall\Uninstall.cmd",
    "C:\FirewallInstaller\Uninstall.cmd"
  )
  CleanUninstall= @(
    (Join-Path $script:InstallerRoot 'Uninstall-Clean.cmd'),
    "C:\Firewall\Uninstall-Clean.cmd",
    "C:\FirewallInstaller\Uninstall-Clean.cmd"
  )
}

$ChecklistRefreshLock = 0
$script:SystemActions = @(
  @{ Name = 'Install'; ScriptCandidates = $ActionScripts.Install; Confirm = $false; ApplyChecklist = $false; TimeoutSec = 180; RequireAdmin = $true; RecordSnapshots = $true },
  @{ Name = 'Repair'; ScriptCandidates = $ActionScripts.Repair; Confirm = $false; ApplyChecklist = $false; TimeoutSec = 180; RequireAdmin = $true; RecordSnapshots = $true },
  @{ Name = 'Maintenance'; ScriptCandidates = $ActionScripts.Maintenance; Confirm = $false; ApplyChecklist = $false; TimeoutSec = 120; RequireAdmin = $true; RecordSnapshots = $true },
  @{ Name = 'Uninstall'; ScriptCandidates = $ActionScripts.Uninstall; Confirm = $true; ApplyChecklist = $false; TimeoutSec = 180; RequireAdmin = $true; RecordSnapshots = $true },
  @{ Name = 'Clean Uninstall'; ScriptCandidates = $ActionScripts.CleanUninstall; Confirm = $true; ApplyChecklist = $false; TimeoutSec = 180; RequireAdmin = $true; RecordSnapshots = $true }
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

function Clear-ActionOutput {
  try {
    if ($txtActionOutput) { $txtActionOutput.Clear() }
  } catch { }
}

function Get-ActionOutputLevel {
  param(
    [string]$Text,
    [string]$Level
  )
  if ($Level) { return $Level }
  if ($Text -match '(?i)\bwarn(ing)?\b') { return 'WARN' }
  if ($Text -match '(?i)\b(error|fail|exception)\b') { return 'FAIL' }
  return 'PASS'
}

function Write-ActionOutputLineDirect {
  param(
    [string]$Text,
    [string]$Level,
    [switch]$SkipLog
  )
  if (-not $Text) { return }
  $status = Get-ActionOutputLevel -Text $Text -Level $Level
  $line = if ($status) { "$Text | $status" } else { $Text }

  try {
    if (-not $txtActionOutput) { return }
    if ($win -and $win.Dispatcher -and -not $win.Dispatcher.CheckAccess()) {
      $win.Dispatcher.Invoke([Action]{
        try {
          $txtActionOutput.AppendText($line + [Environment]::NewLine)
          $txtActionOutput.ScrollToEnd()
        } catch { }
      }) | Out-Null
      return
    }
    $txtActionOutput.AppendText($line + [Environment]::NewLine)
    $txtActionOutput.ScrollToEnd()
  } catch { }
  if (-not $SkipLog) {
    try {
      Write-AdminPanelActionLog -Action 'Action Output' -Script '<output>' -Status $status -Details $line
    } catch { }
  }
}

function Write-ActionOutputLine {
  param(
    [string]$Text,
    [string]$Level,
    [string]$ActionLabel,
    [switch]$SkipLog
  )
  if (-not $Text) { return }
  $status = Get-ActionOutputLevel -Text $Text -Level $Level
  $line = if ($status) { "$Text | $status" } else { $Text }

  Enqueue-ActionOutput -Text $line -Level $status -ActionLabel $ActionLabel
  if (-not $SkipLog) {
    try {
      Write-AdminPanelActionLog -Action 'Action Output' -Script '<output>' -Status $status -Details $line
    } catch { }
  }
}

$script:ActionOutputQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()

function Enqueue-ActionOutput {
  param(
    [Parameter(Mandatory)][string]$Text,
    [string]$Level,
    [string]$ActionLabel
  )
  if (-not $script:ActionOutputQueue) {
    $script:ActionOutputQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
  }
  $payload = [pscustomobject]@{
    Text = $Text
    Level = $Level
    Action = $ActionLabel
  }
  $null = $script:ActionOutputQueue.Enqueue($payload)
}

function Process-ActionOutputQueue {
  if (-not $script:ActionOutputQueue) { return }
  $limit = 80
  $count = 0
  while ($count -lt $limit) {
    $item = $null
    if (-not $script:ActionOutputQueue.TryDequeue([ref]$item)) { break }
    if (-not $item) { continue }
    $line = if ($item.Action) { ($item.Action + ": " + $item.Text) } else { $item.Text }
    Write-ActionOutputLineDirect -Text $line -Level $item.Level -SkipLog
    $count++
  }
}

function Set-RefreshStatusText {
  param([string]$Text)
  try {
    if (-not $txtRefreshStatus) { return }
    if ($win -and $win.Dispatcher -and -not $win.Dispatcher.CheckAccess()) {
      $win.Dispatcher.Invoke([Action]{ $txtRefreshStatus.Text = $Text }) | Out-Null
      return
    }
    $txtRefreshStatus.Text = $Text
  } catch { }
}

function Initialize-UiRefreshTimer {
  if ($script:UiRefreshTimer) { return }
  $script:UiRefreshTimer = New-Object System.Windows.Threading.DispatcherTimer
  $script:UiRefreshTimer.Interval = [TimeSpan]::FromMilliseconds(350)
  $script:UiRefreshTimer.Add_Tick({
    try {
      $script:UiRefreshTimer.Stop()
      $reason = if ($script:UiRefreshReason) { $script:UiRefreshReason } else { 'Action' }
      $script:UiRefreshReason = $null
      Apply-Checklist -Reason $reason
    } catch { }
  })
}

function Request-UiRefresh {
  param([AllowNull()][AllowEmptyString()][string]$Reason = 'Action')
  try {
    Initialize-UiRefreshTimer
    $now = Get-Date
    $deltaMs = 0
    if ($script:UiRefreshLastRequest) {
      $deltaMs = ($now - $script:UiRefreshLastRequest).TotalMilliseconds
    }
    $script:UiRefreshLastRequest = $now
    $script:UiRefreshReason = if ($Reason) { $Reason } else { 'Action' }
    if ($script:UiRefreshTimer) {
      $script:UiRefreshTimer.Stop()
      $script:UiRefreshTimer.Start()
    }
  } catch { }
}

function Set-DevUnlockStatusText {
  param(
    [object]$StatusControl,
    [Nullable[datetime]]$ExpiresAt
  )
  try {
    if (-not $StatusControl) { return }
    if ($ExpiresAt -and $ExpiresAt -gt (Get-Date)) {
      $StatusControl.Text = ("Dev Mode unlocked until " + $ExpiresAt.ToString('HH:mm:ss'))
    } else {
      $StatusControl.Text = "Dev Mode locked."
    }
  } catch { }
}

$script:ChecklistEvidenceOverrides = @{}
$script:ChecklistRowOverrides = @{}

function Set-ChecklistEvidenceOverride {
  param(
    [Parameter(Mandatory)][string]$Check,
    [AllowNull()][AllowEmptyString()][string]$EvidencePath
  )
  if (-not $script:ChecklistEvidenceOverrides) { $script:ChecklistEvidenceOverrides = @{} }
  $script:ChecklistEvidenceOverrides[$Check] = $EvidencePath
}

function Set-ChecklistRowOverride {
  param(
    [Parameter(Mandatory)][string]$Check,
    [string]$Status,
    [string]$Details,
    [AllowNull()][AllowEmptyString()][string]$EvidencePath
  )
  if (-not $script:ChecklistRowOverrides) { $script:ChecklistRowOverrides = @{} }
  $script:ChecklistRowOverrides[$Check] = [pscustomobject]@{
    Status = $Status
    Details = $Details
    EvidencePath = $EvidencePath
  }
  if ($PSBoundParameters.ContainsKey('EvidencePath')) {
    Set-ChecklistEvidenceOverride -Check $Check -EvidencePath $EvidencePath
  }
}

function Get-ChecklistRowOverride {
  param([Parameter(Mandatory)][string]$Check)
  if ($script:ChecklistRowOverrides -and $script:ChecklistRowOverrides.ContainsKey($Check)) {
    return $script:ChecklistRowOverrides[$Check]
  }
  return $null
}

function Test-InventoryRowKey {
  param(
    [AllowNull()][object]$Row,
    [AllowNull()][AllowEmptyString()][string]$Key
  )
  if (-not $Row -or -not $Key) { return $false }
  if ($Row.ComponentKey -and $Row.ComponentKey -eq $Key) { return $true }
  if ($Row.Component -and $Row.Component -eq $Key) { return $true }
  if ($Row.Check -and $Row.Check -eq $Key) { return $true }
  return $false
}

function Update-ChecklistEvidencePath {
  param(
    [Parameter(Mandatory)][string]$Check,
    [string]$EvidencePath
  )
  try {
    Set-ChecklistEvidenceOverride -Check $Check -EvidencePath $EvidencePath
    return
  } catch { }
}

function Set-ChecklistRowStatus {
  param(
    [Parameter(Mandatory)][string]$Check,
    [Parameter(Mandatory)][ValidateSet('PASS','WARN','FAIL','WORKING','UNKNOWN')] [string]$Status,
    [string]$Details,
    [string]$SuggestedAction,
    [AllowNull()][AllowEmptyString()][string]$EvidencePath,
    [switch]$Persist
  )
  $statusValue = if ($Status) { $Status.ToUpperInvariant() } else { '' }
  if ($PSBoundParameters.ContainsKey('EvidencePath')) {
    Set-ChecklistEvidenceOverride -Check $Check -EvidencePath $EvidencePath
  }
  if ($Persist) {
    Set-ChecklistRowOverride -Check $Check -Status $statusValue -Details $Details -EvidencePath $EvidencePath
  }
  try {
    if (-not $grid) { return }
    $collection = $grid.ItemsSource
    if (-not ($collection -is [System.Collections.ObjectModel.ObservableCollection[object]])) { return }
    for ($i = 0; $i -lt $collection.Count; $i++) {
      $row = $collection[$i]
      if (Test-InventoryRowKey -Row $row -Key $Check) {
        $newDetails = if ($PSBoundParameters.ContainsKey('Details')) { $Details } else { $row.Details }
        $newSuggested = if ($PSBoundParameters.ContainsKey('SuggestedAction')) { $SuggestedAction } else { $row.SuggestedAction }
        $collection[$i] = [pscustomobject]@{
          ComponentKey   = $row.ComponentKey
          Component      = $row.Component
          Check          = $row.Check
          Status         = $statusValue
          StatusIcon     = (Get-StatusIcon -Status $statusValue)
          StatusIconFont = (Get-StatusIconFont)
          Details        = $newDetails
          SuggestedAction= $newSuggested
          HelpLabel      = $row.HelpLabel
          HelpAction     = $row.HelpAction
          HelpTarget     = $row.HelpTarget
          HelpScripts    = $row.HelpScripts
          HelpMenu       = $row.HelpMenu
          HelpStatus     = $row.HelpStatus
          RowHighlight   = $row.RowHighlight
          DetailsWrap    = $row.DetailsWrap
          EvidencePath   = $row.EvidencePath
          EvidenceAction = $row.EvidenceAction
          EvidenceTarget = $row.EvidenceTarget
          EvidenceAlwaysClickable = $row.EvidenceAlwaysClickable
        }
        break
      }
    }
  } catch { }
}

function Invoke-RefreshNow {
  param(
    [switch]$LogAction,
    [AllowNull()][AllowEmptyString()][string]$Reason = 'Manual'
  )
  Apply-Checklist -LogAction:$LogAction -Reason $Reason
}

function Invoke-RulesReportAction {
  param(
    [Parameter(Mandatory)][string]$ActionLabel,
    [Parameter(Mandatory)][string[]]$ScriptCandidates,
    [string]$ReportsFolder,
    [string]$RowCheck,
    [object]$StatusText
  )

  $reportsPath = if ($ReportsFolder) { $ReportsFolder } else { 'C:\ProgramData\FirewallCore\Reports' }
  $checkName = if ($RowCheck) { $RowCheck } else { 'Firewall rules inventory' }
  $scriptPath = Resolve-AdminPanelScriptPath -Candidates $ScriptCandidates

  if (-not $scriptPath) {
    $expected = ($ScriptCandidates | Where-Object { $_ }) -join '; '
    $detail = if ($expected) { "Tool missing. Expected: $expected" } else { "Tool missing (no mapping)." }
    Update-ChecklistEvidencePath -Check $checkName -EvidencePath '(failed) see logs'
    Set-RowHelpStatus -Check $checkName -StatusText 'Tool missing'
    Set-ChecklistRowStatus -Check $checkName -Status 'WARN' -Details $detail -EvidencePath $expected
    Write-ActionOutputLine -Text ($ActionLabel + ": WARN (" + $detail + ")") -Level 'WARN'
    if ($StatusText) {
      $StatusText.Text = ("Last run: WARN | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | Tool missing")
    }
    Write-AdminPanelActionLog -Action $ActionLabel -Script $null -Status 'Start' -Details 'Missing mapping'
    Write-AdminPanelActionLog -Action $ActionLabel -Script $null -Status 'Warn' -Details 'Missing mapping'
    Show-NotImplementedMessage
    return $false
  }

  if ($StatusText) { $StatusText.Text = 'Running Rules Report...' }
  Set-RowHelpStatus -Check $checkName -StatusText 'Starting...'
  $logDetails = "OutputDir=" + $reportsPath

  return Invoke-UiAsyncAction -Action $ActionLabel -ScriptLabel 'Run-RulesReport' -LogDetails $logDetails -BusyKey 'RulesReport' -ProgressMode 'Indeterminate' -ScriptBlock {
    param($scriptPath, $reportsPath)

    try { New-Item -ItemType Directory -Force -Path $reportsPath | Out-Null } catch { }
    try {
      $null = Get-ChildItem -Path $reportsPath -Filter 'RulesReport_*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    } catch { }

    & $scriptPath | Out-Null

    $latest = Get-ChildItem -Path $reportsPath -Filter 'RulesReport_*.json' -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if (-not $latest) { throw "Rules Report output not found." }
    return $latest.FullName
  } -Arguments @($scriptPath, $reportsPath) -OnOk {
    param($outputPath, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $path = if ($outputPath) { [string]$outputPath } else { '' }
    Update-ChecklistEvidencePath -Check $checkName -EvidencePath $path
    if ($path) {
      Set-ChecklistRowStatus -Check $checkName -Status 'PASS' -Details ("Report generated: " + $path) -EvidencePath $path
      Set-RowHelpStatus -Check $checkName -StatusText ("Done: " + (Split-Path -Leaf $path))
    } else {
      Set-ChecklistRowStatus -Check $checkName -Status 'WARN' -Details "Report completed but output not found." -EvidencePath '(missing output)'
      Set-RowHelpStatus -Check $checkName -StatusText "Done: RulesReport_*.json"
    }
    if ($StatusText) {
      $detail = if ($path) { " | Output: " + $path } else { '' }
      $StatusText.Text = ("Last run: OK | " + $timestamp + $detail)
    }
    if ($path) { $state.LogDetails = "Output=" + $path }
  } -OnFail {
    param($err, $state)
    if ($err -eq 'Skipped: already running') {
      Set-RowHelpStatus -Check $checkName -StatusText 'Busy...'
      return
    }
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Update-ChecklistEvidencePath -Check $checkName -EvidencePath '(failed) see logs'
    Set-RowHelpStatus -Check $checkName -StatusText ("Failed: " + $err)
    Set-ChecklistRowStatus -Check $checkName -Status 'FAIL' -Details ("Failed: " + $err) -EvidencePath '(failed) see logs'
    Write-ActionOutputLine -Text ($ActionLabel + ": FAIL (" + $err + ")") -Level 'FAIL'
    if ($StatusText) {
      $StatusText.Text = ("Last run: FAIL | " + $timestamp + " | See AdminPanel-Actions.log")
    }
    if ($err) { $state.LogDetails = $err }
  } -OnTimeout {
    param($elapsedSec, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Update-ChecklistEvidencePath -Check $checkName -EvidencePath '(failed) see logs'
    Set-RowHelpStatus -Check $checkName -StatusText ("Timed out after {0}s" -f [Math]::Round($elapsedSec, 0))
    Set-ChecklistRowStatus -Check $checkName -Status 'FAIL' -Details ("Timeout after {0}s" -f [Math]::Round($elapsedSec, 0)) -EvidencePath '(timeout) see logs'
    $timeoutLine = "{0}: FAIL (Timeout after {1}s)" -f $ActionLabel, [Math]::Round($elapsedSec, 0)
    Write-ActionOutputLine -Text $timeoutLine -Level 'FAIL'
    if ($StatusText) {
      $StatusText.Text = ("Last run: FAIL | " + $timestamp + " | See AdminPanel-Actions.log")
    }
    $state.LogDetails = "TimeoutSec=" + [Math]::Round($elapsedSec, 0)
  }
}

function Invoke-DevUnlockExpiryCheck {
  $state = $script:DevUnlockState
  if (-not $state) { return }
  if (-not $state.DevUnlockExpiresAt) { return }
  if ((Get-Date) -lt $state.DevUnlockExpiresAt) { return }

  if ($state.Busy) { return }
  $state.Busy = $true
  Write-AdminPanelActionLog -Action 'Dev Mode: Auto-Relock' -Script $state.DevFlagPath -Status 'Start' -Details ("Expired at " + $state.DevUnlockExpiresAt.ToString('HH:mm:ss'))
  try {
    Remove-Item -Path $state.DevFlagPath -Force -ErrorAction SilentlyContinue
    $state.DevUnlockExpiresAt = $null
    Set-DevPanelVisibility -DevPanel $state.DevPanel -DevHeader $state.DevHeader -DevNote $state.DevNote -DevSelect $state.DevSelect -DevRunButton $state.DevRunButton -Visible:$false
    Set-DevUnlockStatusText -StatusControl $state.DevUnlockStatus -ExpiresAt $null
    if ($state.DevToggle) {
      $state.DevToggle.IsChecked = $false
      $state.DevToggle.ToolTip = $null
    }
    Write-AdminPanelActionLog -Action 'Dev Mode: Auto-Relock' -Script $state.DevFlagPath -Status 'Ok'
  } catch {
    Write-AdminPanelActionLog -Action 'Dev Mode: Auto-Relock' -Script $state.DevFlagPath -Status 'Fail' -Details $_.Exception.Message
  } finally {
    $state.Busy = $false
  }
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

function Get-ComboSelectionValue {
  param([AllowNull()][object]$Item)
  if ($null -eq $Item) { return $null }
  if ($Item.PSObject.Properties.Match('Content')) { return [string]$Item.Content }
  return [string]$Item
}

$script:ThemeInitializing = $true
if ($themeSelect -and $accentSelect) {
  if (Get-Command -Name Load-ThemeSettings -ErrorAction SilentlyContinue) {
    $settings = Load-ThemeSettings
  } else {
    $settings = [pscustomobject]@{ Theme = 'System'; Accent = 'Blue' }
  }
  if (-not $settings) {
    $settings = [pscustomobject]@{ Theme = 'System'; Accent = 'Blue' }
  }
if (-not (Get-Command -Name Select-ComboValue -ErrorAction SilentlyContinue)) {
  function Select-ComboValue {
    param([Parameter(Mandatory=$true)][object]$Combo,[Parameter(Mandatory=$true)][string]$Value)
    try {
      if ($null -eq $Combo) { return }
      # Prefer ItemsSource if present, else Items
      $src = $Combo.ItemsSource
      if ($null -eq $src) { $src = $Combo.Items }
      foreach ($item in $src) {
        if ($item -eq $Value) { $Combo.SelectedItem = $item; return }
      }
      if ($Combo.Items.Count -gt 0) { $Combo.SelectedIndex = 0 }
    } catch { }
  }
}

  Select-ComboValue -Combo $themeSelect -Value $settings.Theme
  Select-ComboValue -Combo $accentSelect -Value $settings.Accent
  try {
    Apply-Theme -ThemeName $settings.Theme -AccentName $settings.Accent
    $win.InvalidateVisual()
  } catch { }
  $script:ThemeInitializing = $false

  $themeSelect.Add_SelectionChanged({
    if ($script:ThemeInitializing) { return }
    $theme = Get-ComboSelectionValue -Item $themeSelect.SelectedItem
    $accent = Get-ComboSelectionValue -Item $accentSelect.SelectedItem
    if (-not $theme) { $theme = 'System' }
    if (-not $accent) { $accent = 'Blue' }
    try {
      Apply-Theme -ThemeName $theme -AccentName $accent
      $win.InvalidateVisual()
    } catch { }
    Save-ThemeSettings -Theme $theme -Accent $accent
  })

  $accentSelect.Add_SelectionChanged({
    if ($script:ThemeInitializing) { return }
    $theme = Get-ComboSelectionValue -Item $themeSelect.SelectedItem
    $accent = Get-ComboSelectionValue -Item $accentSelect.SelectedItem
    if (-not $theme) { $theme = 'System' }
    if (-not $accent) { $accent = 'Blue' }
    try {
      Apply-Theme -ThemeName $theme -AccentName $accent
      $win.InvalidateVisual()
    } catch { }
    Save-ThemeSettings -Theme $theme -Accent $accent
  })
} else {
  try {
    Apply-Theme -ThemeName 'System' -AccentName 'Blue'
    $win.InvalidateVisual()
  } catch { }
  $script:ThemeInitializing = $false
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
          ComponentKey   = $row.ComponentKey
          Component      = $row.Component
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
          EvidencePath   = $row.EvidencePath
          EvidenceAction = $row.EvidenceAction
          EvidenceTarget = $row.EvidenceTarget
          EvidenceAlwaysClickable = $row.EvidenceAlwaysClickable
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
    if ($progressRefresh) { $progressRefresh.Visibility = 'Collapsed' }
    Set-RefreshStatusText "Refresh failed: no rows (see logs)"
    [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
    Exit-RefreshState -Reason 'Checklist refresh' -Status 'Fail' -Details 'No rows returned'
    if ($LogAction) {
      Write-AdminPanelActionLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Fail' -Details 'No rows returned'
    }
    return
  }

  try {
    if ($progressRefresh) {
      $progressRefresh.Visibility = 'Visible'
      $progressRefresh.IsIndeterminate = $true
    }
    if (-not $script:InventoryInitialized -and $grid) { Initialize-InventoryGrid -Grid $grid }
    $selectedIndex = $null
    try {
      if ($grid -and $grid.SelectedIndex -ge 0) { $selectedIndex = $grid.SelectedIndex }
    } catch { }
    foreach ($row in $rows) {
      if (-not $row) { continue }
      $key = if ($row.ComponentKey) { $row.ComponentKey } elseif ($row.Component) { $row.Component } else { $row.Check }
      if (-not $key) { continue }
      Set-ChecklistRowStatus -Check $key -Status $row.Status -Details $row.Details -SuggestedAction $row.SuggestedAction
    }
    if ($selectedIndex -ne $null -and $grid) { $grid.SelectedIndex = $selectedIndex }
    if ($progressRefresh) { $progressRefresh.Visibility = 'Collapsed' }
    Set-RefreshStatusText ("Refresh complete: " + (Get-Date -Format 'HH:mm:ss'))
    [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
    if ($LogAction) {
      Write-AdminPanelActionLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Ok' -Details ("Rows=" + $rowCount)
    }
    Exit-RefreshState -Reason 'Checklist refresh' -Status 'Ok' -Details ("Rows=" + $rowCount)
  } catch {
    if ($progressRefresh) { $progressRefresh.Visibility = 'Collapsed' }
    Set-RefreshStatusText ("Refresh failed: " + $_.Exception.Message + " (see logs)")
    [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
    if ($LogAction) {
      Write-AdminPanelActionLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Fail' -Details $_.Exception.Message
    }
    Exit-RefreshState -Reason 'Checklist refresh' -Status 'Fail' -Details $_.Exception.Message
  }
}

function Apply-Checklist {
  param(
    [switch]$LogAction,
    [AllowNull()][AllowEmptyString()][string]$Reason = 'Manual'
  )
  if (-not (Assert-NotBusy -Context 'Checklist refresh' -StatusText $txtRefreshStatus)) { return }
  if (-not $grid) { return }
  if (-not (Enter-RefreshState -Reason $Reason)) { return }
  if ([System.Threading.Interlocked]::CompareExchange([ref]$ChecklistRefreshLock, 1, 0) -ne 0) {
    if ($LogAction) {
      $runId = New-AdminPanelRunId
      Write-AdminPanelAsyncLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Start' -RunId $runId -BusyCount (Get-UiBusyCount) -Details 'Skipped: already running'
      Write-AdminPanelAsyncLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Fail' -RunId $runId -BusyCount (Get-UiBusyCount) -Error 'Skipped' -Details 'Skipped: already running'
    }
    Exit-RefreshState -Reason $Reason -Status 'Warn' -Details 'Skipped: already running'
    return
  }

  try { Set-RefreshStatusText "Refreshing..." } catch { }

  $logDetails = if ($LogAction) { 'Async refresh' } else { $null }
  $root = $script:FirewallRoot
  $installerRoot = $script:InstallerRoot

  $ok = Invoke-UiAsyncAction -Action 'Checklist refresh' -ScriptLabel 'Invoke-Checklist' -LogDetails $logDetails -BusyKey 'ChecklistRefresh' -ProgressMode 'None' -UseBusyGate:$false -EnableLogging:([bool]$LogAction) -ScriptBlock {
    param($root, $installerRoot)
    $rows = Invoke-Checklist
    if (-not $rows) { throw "Refresh failed." }
    return $rows
  } -Arguments @($root, $installerRoot) -OnOk {
    param($result, $state)
    $rowList = @()
    if ($result) { $rowList = @($result) }
    if (-not $rowList -or $rowList.Count -le 0) {
      Set-RefreshStatusText "Refresh failed: no rows (see logs)"
      [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
      Exit-RefreshState -Reason $Reason -Status 'Fail' -Details 'No rows returned'
      if ($LogAction) { $state.LogDetails = 'No rows returned' }
      return
    }
    Start-ChecklistRender -Rows $rowList -LogAction:$LogAction
    if ($LogAction) { $state.LogDetails = ("Rows=" + $rowList.Count) }
  } -OnFail {
    param($err, $state)
    Set-RefreshStatusText ("Refresh failed: " + $err + " (see logs)")
    [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
    Exit-RefreshState -Reason $Reason -Status 'Fail' -Details $err
    if ($LogAction) { $state.LogDetails = $err }
  } -OnTimeout {
    param($elapsedSec, $state)
    Set-RefreshStatusText ("Refresh failed: timeout after " + [Math]::Round($elapsedSec, 0) + "s (see logs)")
    [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
    Exit-RefreshState -Reason $Reason -Status 'Fail' -Details ("Timeout after " + [Math]::Round($elapsedSec, 0) + "s")
  }

  if (-not $ok) {
    [System.Threading.Interlocked]::Exchange([ref]$ChecklistRefreshLock, 0) | Out-Null
    Set-RefreshStatusText "Refresh failed: dispatch error (see logs)"
    Exit-RefreshState -Reason $Reason -Status 'Fail' -Details 'Dispatch error'
  }
}

# Refresh + Dev unlock timer
$script:RefreshTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:RefreshTimer.Interval = [TimeSpan]::FromMilliseconds($DefaultRefreshMs)
$script:RefreshTimer.Add_Tick({
  if ($chkAuto -and $chkAuto.IsChecked -and -not $script:IsBusy -and -not $script:IsRefreshing -and (Get-UiBusyCount) -eq 0) {
    Invoke-RefreshNow -Reason 'Auto'
  }
  Invoke-DevUnlockExpiryCheck
})
$script:RefreshTimer.Start()

# Events
$btnRefreshNow.Add_Click({
  try {
    if (-not (Assert-NotBusy -Context 'Refresh Now' -StatusText $txtRefreshStatus)) { return }
    Invoke-RefreshNow -LogAction -Reason 'Manual'
  } catch {
    $err = $_.Exception.Message
    Set-RefreshStatusText ("Refresh failed: " + $err + " (see logs)")
    Write-ActionOutputLine -Text ("Refresh Now: FAIL (" + $err + ")") -Level 'FAIL'
    Write-AdminPanelActionLog -Action 'Checklist refresh' -Script 'Invoke-Checklist' -Status 'Fail' -Details $err
  }
})

$btnApplyRepair.Add_Click({
  try {
    if (-not (Assert-NotBusy -Context 'Repair Options: Apply Selected' -StatusText $txtRepairStatus)) { return }
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

    $logDetail = "Category=Action " + $detail
    $null = Invoke-AdminPanelProcessAction `
      -Action 'Repair Options: Apply Selected' `
      -ScriptCandidates $ActionScripts.Repair `
      -Arguments $args `
      -LogDetails $logDetail `
      -BusyKey 'AdminAction' `
      -TimeoutSec 180 `
      -StatusText $txtRepairStatus `
      -RequireAdmin `
      -RecordSnapshots `
      -UiRefreshReason 'Repair' `
      -OnOk {
        param($result, $state)
        $exitCode = if ($result -and $result.ExitCode -ne $null) { [int]$result.ExitCode } else { 0 }
        if ($exitCode -eq 0) {
          Set-RepairStatusText ("Applied: " + ($optionNames -join ', '))
        } else {
          Set-RepairStatusText "Apply failed. See AdminPanel-Actions.log."
        }
      } `
      -OnFail {
        param($err, $state)
        if ($err -eq 'Skipped: already running') { return }
        Set-RepairStatusText "Apply failed. See AdminPanel-Actions.log."
      }
  } catch {
    $err = $_.Exception.Message
    Write-ActionOutputLine -Text ("Repair Options: Apply Selected: FAIL (" + $err + ")") -Level 'FAIL'
    Write-AdminPanelActionLog -Action 'Repair Options: Apply Selected' -Script $null -Status 'Fail' -Details $err
    Set-RepairStatusText "Apply failed. See AdminPanel-Actions.log."
  }
})

$btnResetRepair.Add_Click({
  try {
    if (-not (Assert-NotBusy -Context 'Repair Options: Reset Defaults' -StatusText $txtRepairStatus)) { return }
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
  } catch {
    $err = $_.Exception.Message
    Write-ActionOutputLine -Text ("Repair Options: Reset Defaults: FAIL (" + $err + ")") -Level 'FAIL'
    Write-AdminPanelActionLog -Action 'Repair Options: Reset Defaults' -Script $null -Status 'Fail' -Details $err
    Set-RepairStatusText "Reset failed. See AdminPanel-Actions.log."
  }
})

$btnRunAction.Add_Click({
  try {
    if (-not (Assert-NotBusy -Context 'System Action' -StatusText $txtActionStatus)) { return }
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
      $phrase = 'delete'
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

    $timeoutSec = if ($meta.TimeoutSec) { [int]$meta.TimeoutSec } else { 900 }
    $logDetail = "Category=Action Name=" + $meta.Name
    $null = Invoke-AdminPanelProcessAction `
      -Action $actionName `
      -ScriptCandidates $meta.ScriptCandidates `
      -LogDetails $logDetail `
      -BusyKey 'AdminAction' `
      -TimeoutSec $timeoutSec `
      -StatusText $txtActionStatus `
      -RequireAdmin:$meta.RequireAdmin `
      -RecordSnapshots:$meta.RecordSnapshots `
      -UiRefreshReason $meta.Name
  } catch {
    $err = $_.Exception.Message
    Write-ActionOutputLine -Text ("System Action: FAIL (" + $err + ")") -Level 'FAIL'
    Write-AdminPanelActionLog -Action 'System Action' -Script $null -Status 'Fail' -Details $err
    Set-ActionStatusText ("Last run: FAIL | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | See AdminPanel-Actions.log")
  }
})
Initialize-AsyncInfrastructure

if ($btnUninstall) {
  $btnUninstall.Add_Click({
    try {
      if (-not (Assert-NotBusy -Context 'Uninstall' -StatusText $txtActionStatus)) { return }
      $keepLogs = $false
      if ($chkKeepLogs -and $chkKeepLogs.IsChecked) { $keepLogs = $true }
      $confirmText = if ($keepLogs) { 'Uninstall FirewallCore (keep logs)?' } else { 'Uninstall FirewallCore and remove logs?' }
      $confirm = [System.Windows.MessageBox]::Show(
        $confirmText,
        'FirewallCore Admin Panel',
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
      )
      if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
        Set-ActionStatusText "Cancelled: Uninstall"
        Write-AdminPanelActionLog -Action 'Uninstall' -Script $null -Status 'Warn' -Details 'User cancelled'
        return
      }

      $args = @()
      if ($keepLogs) { $args += '-KeepLogs' }
      $detail = "Category=Action KeepLogs=" + $keepLogs
      Invoke-AdminPanelProcessAction `
        -Action 'Uninstall' `
        -ScriptCandidates $ActionScripts.Uninstall `
        -Arguments $args `
        -LogDetails $detail `
        -BusyKey 'AdminAction' `
        -TimeoutSec 180 `
        -StatusText $txtActionStatus `
        -RequireAdmin `
        -RecordSnapshots `
        -UiRefreshReason 'Uninstall' | Out-Null
    } catch {
      $err = $_.Exception.Message
      Write-ActionOutputLine -Text ("Uninstall: FAIL (" + $err + ")") -Level 'FAIL'
      Write-AdminPanelActionLog -Action 'Uninstall' -Script $null -Status 'Fail' -Details $err
      Set-ActionStatusText ("Uninstall failed: " + $err)
    }
  })
}

if ($btnOpenLogs) {
  $btnOpenLogs.Add_Click({
    try {
      if (-not (Assert-NotBusy -Context 'Open Logs' -StatusText $txtActionStatus)) { return }
      $logDir = 'C:\ProgramData\FirewallCore\Logs'
      Invoke-UiAsyncAction -Action 'Open Logs' -ScriptLabel $logDir -LogDetails 'Category=Action' -BusyKey 'AdminAction' -DisableControls (Get-ActionDisableControls) -ProgressMode 'None' -UiRefreshReason 'Open Logs' -ScriptBlock {
        param($path)
        Start-Process explorer.exe -ArgumentList $path | Out-Null
      } -Arguments @($logDir) -OnOk {
        if ($txtActionStatus) { $txtActionStatus.Text = "Opened: " + $logDir }
      } -OnFail {
        param($err, $state)
        if ($txtActionStatus) { $txtActionStatus.Text = "Open logs failed. See AdminPanel-Actions.log." }
      } | Out-Null
    } catch {
      $err = $_.Exception.Message
      Write-ActionOutputLine -Text ("Open Logs: FAIL (" + $err + ")") -Level 'FAIL'
      Write-AdminPanelActionLog -Action 'Open Logs' -Script $null -Status 'Fail' -Details $err
    }
  })
}

if ($btnOpenEventViewer) {
  $btnOpenEventViewer.Add_Click({
    try {
      if (-not (Assert-NotBusy -Context 'Open Event Viewer' -StatusText $txtActionStatus)) { return }
      $viewPath = Get-FirewallEventViewerViewPath
      Invoke-UiAsyncAction -Action 'Open Event Viewer' -ScriptLabel $viewPath -LogDetails 'Category=Action' -BusyKey 'AdminAction' -DisableControls (Get-ActionDisableControls) -ProgressMode 'None' -UiRefreshReason 'Open Event Viewer' -ScriptBlock {
        param($path)
        if ($path -and (Test-Path -LiteralPath $path)) {
          $arg = '/c:"{0}"' -f $path
          Start-Process -FilePath 'eventvwr.msc' -ArgumentList $arg | Out-Null
        } else {
          Start-Process -FilePath 'eventvwr.msc' | Out-Null
        }
      } -Arguments @($viewPath) -OnOk {
        if ($txtActionStatus) { $txtActionStatus.Text = "Opened Event Viewer." }
      } -OnFail {
        param($err, $state)
        if ($txtActionStatus) { $txtActionStatus.Text = "Open Event Viewer failed. See AdminPanel-Actions.log." }
      } | Out-Null
    } catch {
      $err = $_.Exception.Message
      Write-ActionOutputLine -Text ("Open Event Viewer: FAIL (" + $err + ")") -Level 'FAIL'
      Write-AdminPanelActionLog -Action 'Open Event Viewer' -Script $null -Status 'Fail' -Details $err
    }
  })
}

if ($btnExportBaseline) {
  $btnExportBaseline.Add_Click({
    try {
      if (-not (Assert-NotBusy -Context 'Export Baseline + SHA256' -StatusText $txtActionStatus)) { return }
      Invoke-ExportBaselineAction -StatusText $txtActionStatus | Out-Null
    } catch {
      $err = $_.Exception.Message
      Write-ActionOutputLine -Text ("Export Baseline + SHA256: FAIL (" + $err + ")") -Level 'FAIL'
      Write-AdminPanelActionLog -Action 'Export Baseline + SHA256' -Script $null -Status 'Fail' -Details $err
      Set-ActionStatusText ("Export baseline failed: " + $err)
    }
  })
}

if ($btnExportDiagnostics) {
  $btnExportDiagnostics.Add_Click({
    try {
      if (-not (Assert-NotBusy -Context 'Export Diagnostics Bundle' -StatusText $txtActionStatus)) { return }
      Invoke-FallbackExportDiagnosticsBundle -ActionLabel 'Export Diagnostics Bundle' -StatusText $txtActionStatus -RowCheck 'Last Diagnostics Bundle' -LogCategory 'Action' | Out-Null
    } catch {
      $err = $_.Exception.Message
      Write-ActionOutputLine -Text ("Export Diagnostics Bundle: FAIL (" + $err + ")") -Level 'FAIL'
      Write-AdminPanelActionLog -Action 'Export Diagnostics Bundle' -Script $null -Status 'Fail' -Details $err
      Set-ActionStatusText ("Export diagnostics failed: " + $err)
    }
  })
}

$btnClose.Add_Click({ $win.Close() })

$combo.Add_SelectionChanged({
  try {
    $item = $combo.SelectedItem
    if (-not $item) { return }
    $ms = [int]$item.Tag
    if ($ms -lt 250) { $ms = 250 }
    if ($script:RefreshTimer) { $script:RefreshTimer.Interval = [TimeSpan]::FromMilliseconds($ms) }
  } catch { }
})

$win.Add_Closed({
  try {
    if ($script:AsyncTimer) {
      $script:AsyncTimer.Stop()
      $script:AsyncTimer = $null
    }
    if ($script:RefreshTimer) {
      $script:RefreshTimer.Stop()
      $script:RefreshTimer = $null
    }
  } catch { }
})

$grid.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent,
  [System.Windows.RoutedEventHandler]{
    # DISABLED_DUPLICATE_SCRIPT_PARAMBLOCK_BEGIN
# param($sender,$e)
# DISABLED_DUPLICATE_SCRIPT_PARAMBLOCK_END
    try {
      $btn = $e.OriginalSource
  if ($btn -is [System.Windows.Controls.Button]) {
    $row = $btn.DataContext
    if ($row) {
      $tag = $btn.Tag
      $action = $null
      if ($tag -eq 'HelpAction') {
        $action = $row.HelpAction
      } elseif ($tag -eq 'EvidenceAction') {
        $action = $row.EvidenceAction
      } else {
        $action = if ($row.EvidenceAction) { $row.EvidenceAction } else { $row.HelpAction }
      }
      $always = $false
      try { $always = [bool]$row.EvidenceAlwaysClickable } catch { $always = $false }
      $status = if ($row.Status) { $row.Status.ToUpperInvariant() } else { '' }
          $clickAllowed = $always -or $status -eq 'WARN' -or $status -eq 'FAIL'
          if ($action -and $clickAllowed) {
            Invoke-RowHelpAction -Row $row -ActionOverride $action
            $e.Handled = $true
          }
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

  Initialize-TestsUI -WindowOrRoot $Window
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
    $timestamp = Get-Date -Format 'o'
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

function Get-AdminPanelResult {
  param([AllowNull()][string]$Status)
  if (-not $Status) { return 'OK' }
  switch ($Status.ToLowerInvariant()) {
    'ok' { return 'OK' }
    'pass' { return 'OK' }
    'start' { return 'OK' }
    'warn' { return 'FAIL' }
    'fail' { return 'FAIL' }
    default { return 'OK' }
  }
}

function Write-AdminPanelActionLog {
  param(
    [Parameter(Mandatory)][string]$Action,
    [AllowNull()][AllowEmptyString()][string]$Script,
    [string]$Status,
    [string]$Details,
    [AllowNull()][Nullable[int]]$ExitCode,
    [AllowNull()][Nullable[int]]$DurationMs,
    [AllowNull()][AllowEmptyString()][string]$Evidence,
    [AllowNull()][AllowEmptyString()][string]$Error
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
    $detailsText = if ($escapedDetails) { (' Details="{0}"' -f $escapedDetails) } else { '' }
    $durationValue = if ($DurationMs -ne $null) { [int]$DurationMs } else { 0 }
    $evidenceValue = if ($Evidence) { $Evidence } else { '<none>' }
    $escapedEvidence = $evidenceValue -replace '"', '""'
    $errorValue = $Error
    if (-not $errorValue -and $Status -and $Status.ToLowerInvariant() -eq 'fail') { $errorValue = $Details }
    $errorText = ''
    if ($errorValue) {
      $escapedError = $errorValue -replace '"', '""'
      $errorText = (' Error="{0}"' -f $escapedError)
    }
    $exitText = ''
    if ($PSBoundParameters.ContainsKey('ExitCode') -and $null -ne $ExitCode) {
      $exitText = " ExitCode=$ExitCode"
    }
    $psVersion = 'Unknown'
    try {
      if ($PSVersionTable -and $PSVersionTable.PSVersion) {
        $psVersion = $PSVersionTable.PSVersion.ToString()
      }
    } catch { }
    $isElevated = $false
    try { $isElevated = Test-IsAdmin } catch { }
    $result = Get-AdminPanelResult -Status $Status
    $line = '[{0}] Action="{1}" Result={2} Status={3} DurationMs={4} Evidence="{5}" Script="{6}" Elevated={7} PS={8}{9}{10}{11}' -f (
      (Get-Date -Format 'o'),
      $Action,
      $result,
      $Status,
      $durationValue,
      $escapedEvidence,
      $Script,
      $isElevated,
      $psVersion,
      $detailsText,
      $errorText,
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
$script:IsBusy = $false
$script:IsRefreshing = $false
$script:RefreshTimerPaused = $false
$script:BusyReason = $null
$script:BusyDepth = 0
$script:UiProgressRequests = @()
$script:UiRefreshTimer = $null
$script:UiRefreshLastRequest = [datetime]::MinValue
$script:UiRefreshReason = $null
$script:BtnRunTest = $null
$script:BtnRunDevTest = $null
$script:TestActionSelect = $null
$script:DevActionSelect = $null

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
    [string]$Details,
    [AllowNull()][AllowEmptyString()][string]$Evidence
  )

  $durationValue = if ($DurationMs -ne $null) { [int]$DurationMs } else { 0 }
  $evidenceValue = if ($Evidence) { $Evidence } else { '<none>' }
  $parts = @("RunId=$RunId","Status=$Status","DurationMs=$durationValue","Evidence=$evidenceValue")
  if ($BusyCount -ne $null) { $parts += ("BusyCount=" + $BusyCount) }
  $cleanError = Format-AdminPanelError -ErrorText $Error
  if ($cleanError) { $parts += ("Error=" + $cleanError) }
  if ($Details) { $parts += $Details }
  $detailText = $parts -join ' '
  Write-AdminPanelActionLog -Action $Action -Script $Script -Status $Status -Details $detailText -DurationMs $durationValue -Evidence $evidenceValue -Error $cleanError
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
      'Get-LatestRulesReportPath',
      'Get-OptionalValue',
      'Get-AdminPanelPowerShellExe',
      'New-Row',
      'New-InventoryRow',
      'Copy-RowWithHighlight',
      'Get-FirewallInstallState',
      'Test-TaskActionContract',
      'Get-ScheduledTasksHealth',
      'Get-FirewallRuleCounts',
      'Get-FirewallEventLogHealth',
      'Get-NotifyQueueHealth',
      'Archive-NotifyQueue',
      'Normalize-PowerShellArguments',
      'Repair-ScheduledTaskActions',
      'Get-LastAdminPanelTestSummary',
      'Get-LastDiagnosticsBundle',
      'Get-FirewallEventViewerViewPath',
      'New-AdminPanelSnapshot',
      'Invoke-Checklist',
      'Invoke-Inventory'
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
  if (-not $script:AsyncTasks -or $script:AsyncTasks.Count -eq 0) {
    Process-ActionOutputQueue
    return
  }
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
  Process-ActionOutputQueue
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

function Get-BusyControls {
  $controls = @()
  if ($btnRunAction) { $controls += $btnRunAction }
  if ($script:BtnRunTest) { $controls += $script:BtnRunTest }
  if ($script:BtnRunDevTest) { $controls += $script:BtnRunDevTest }
  if ($btnApplyRepair) { $controls += $btnApplyRepair }
  if ($btnResetRepair) { $controls += $btnResetRepair }
  if ($btnRefreshNow) { $controls += $btnRefreshNow }
  if ($btnUninstall) { $controls += $btnUninstall }
  if ($btnOpenLogs) { $controls += $btnOpenLogs }
  if ($btnOpenEventViewer) { $controls += $btnOpenEventViewer }
  if ($btnExportBaseline) { $controls += $btnExportBaseline }
  if ($btnExportDiagnostics) { $controls += $btnExportDiagnostics }
  return $controls
}

function Update-BusyControls {
  $enabled = -not ($script:IsBusy -or $script:IsRefreshing)
  $controls = Get-BusyControls
  if ($controls -and $controls.Count -gt 0) {
    Set-ControlsEnabled -Controls $controls -Enabled:$enabled
  }
}

function Pause-RefreshTimer {
  param([string]$Reason)
  try {
    if ($script:RefreshTimer -and $script:RefreshTimer.IsEnabled) {
      $script:RefreshTimer.Stop()
      $script:RefreshTimerPaused = $true
      Write-AdminPanelActionLog -Action 'Refresh Timer' -Script $null -Status 'Start' -Details ("Paused: " + $Reason)
    }
  } catch { }
}

function Resume-RefreshTimer {
  param([string]$Reason)
  try {
    if (-not $script:RefreshTimer) { return }
    if ($script:IsBusy -or $script:IsRefreshing) { return }
    if (-not ($chkAuto -and $chkAuto.IsChecked)) { return }
    if (-not $script:RefreshTimer.IsEnabled) {
      $script:RefreshTimer.Start()
      $script:RefreshTimerPaused = $false
      Write-AdminPanelActionLog -Action 'Refresh Timer' -Script $null -Status 'Ok' -Details ("Resumed: " + $Reason)
    }
  } catch { }
}

function Enter-BusyState {
  param([AllowNull()][AllowEmptyString()][string]$Reason)
  try {
    $script:BusyDepth++
    if ($script:BusyDepth -lt 1) { $script:BusyDepth = 1 }
    if (-not $script:IsBusy) {
      $script:IsBusy = $true
      $script:BusyReason = if ($Reason) { $Reason } else { 'Busy' }
      Pause-RefreshTimer -Reason ("Busy: " + $script:BusyReason)
      Update-BusyControls
      Write-AdminPanelActionLog -Action 'Busy Gate' -Script $null -Status 'Start' -Details ("Reason=" + $script:BusyReason)
    }
  } catch { }
}

function Exit-BusyState {
  param([AllowNull()][AllowEmptyString()][string]$Reason)
  try {
    if ($script:BusyDepth -gt 0) { $script:BusyDepth-- }
    if ($script:BusyDepth -le 0) {
      $script:BusyDepth = 0
      $prevReason = $script:BusyReason
      $script:IsBusy = $false
      $script:BusyReason = $null
      Update-BusyControls
      Resume-RefreshTimer -Reason ("Busy done: " + (if ($Reason) { $Reason } else { $prevReason }))
      Write-AdminPanelActionLog -Action 'Busy Gate' -Script $null -Status 'Ok' -Details ("Reason=" + (if ($Reason) { $Reason } else { $prevReason }))
    }
  } catch { }
}

function Enter-RefreshState {
  param([AllowNull()][AllowEmptyString()][string]$Reason)
  if ($script:IsRefreshing) { return $false }
  $script:IsRefreshing = $true
  Pause-RefreshTimer -Reason ("Refresh: " + $Reason)
  Update-BusyControls
  Write-AdminPanelActionLog -Action 'Refresh Gate' -Script 'Invoke-Checklist' -Status 'Start' -Details ("Reason=" + $Reason)
  return $true
}

function Exit-RefreshState {
  param(
    [AllowNull()][AllowEmptyString()][string]$Reason,
    [ValidateSet('Ok','Warn','Fail')][string]$Status = 'Ok',
    [AllowNull()][AllowEmptyString()][string]$Details
  )
  if (-not $script:IsRefreshing) { return }
  $script:IsRefreshing = $false
  Update-BusyControls
  Resume-RefreshTimer -Reason ("Refresh done: " + $Reason)
  $detailText = if ($Details) { $Details } else { "Reason=" + $Reason }
  Write-AdminPanelActionLog -Action 'Refresh Gate' -Script 'Invoke-Checklist' -Status $Status -Details $detailText
}

function Assert-NotBusy {
  param(
    [Parameter(Mandatory)][string]$Context,
    [object]$StatusText
  )
  if ($script:IsRefreshing) {
    $reason = 'refresh in progress'
    if ($StatusText) { $StatusText.Text = ("Busy: " + $reason) }
    Write-ActionOutputLine -Text ($Context + ": Busy (" + $reason + ")") -Level 'WARN'
    Write-AdminPanelActionLog -Action $Context -Script $null -Status 'Warn' -Details ("BusyGate: " + $reason)
    return $false
  }
  if ($script:IsBusy) {
    $reason = if ($script:BusyReason) { $script:BusyReason } else { 'another action running' }
    if ($StatusText) { $StatusText.Text = ("Busy: " + $reason) }
    Write-ActionOutputLine -Text ($Context + ": Busy (" + $reason + ")") -Level 'WARN'
    Write-AdminPanelActionLog -Action $Context -Script $null -Status 'Warn' -Details ("BusyGate: " + $reason)
    return $false
  }
  return $true
}

function Resolve-AdminPanelScriptPath {
  param([Parameter(Mandatory)][string[]]$Candidates)
  foreach ($candidate in $Candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
  }
  return $null
}

function Format-ProcessArgument {
  param([AllowNull()][string]$Arg)
  if ($null -eq $Arg) { return '""' }
  if ($Arg -match '[\s"]') {
    $escaped = $Arg -replace '"', '\"'
    return '"' + $escaped + '"'
  }
  return $Arg
}

function Join-ProcessArguments {
  param([string[]]$Args)
  if (-not $Args) { return '' }
  return ($Args | ForEach-Object { Format-ProcessArgument -Arg $_ }) -join ' '
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
    [bool]$UseBusyGate = $true,
    [AllowNull()][AllowEmptyString()][string]$BusyReason,
    [bool]$EnableLogging = $true,
    [AllowNull()][AllowEmptyString()][string]$UiRefreshReason,
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
    Evidence = $null
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
        Write-AdminPanelAsyncLog -Action $Action -Script $ScriptLabel -Status 'Start' -RunId $runId -DurationMs 0 -BusyCount (Get-UiBusyCount) -Details $skipDetails -Evidence $state.Evidence
        Write-AdminPanelAsyncLog -Action $Action -Script $ScriptLabel -Status 'Fail' -RunId $runId -DurationMs 0 -BusyCount (Get-UiBusyCount) -Error 'Skipped' -Details $skipDetails -Evidence $state.Evidence
      }
      if ($OnFail) { & $OnFail "Skipped: already running" $state }
      return $false
    }
  }

  $busyEntered = $false
  if ($UseBusyGate) {
    Enter-BusyState -Reason (if ($BusyReason) { $BusyReason } else { $Action })
    $busyEntered = $true
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
    try {
      if ($busyEntered) { Exit-BusyState -Reason (if ($BusyReason) { $BusyReason } else { $Action }) }
    } catch { }
    $busyCount = Decrement-UiBusy
    if ($EnableLogging) {
      Write-AdminPanelAsyncLog -Action $Action -Script $ScriptLabel -Status $status -RunId $runId -DurationMs $durationMs -BusyCount $busyCount -Error $errorText -Details $state.LogDetails -Evidence $state.Evidence
    }
    if ($UiRefreshReason) {
      Request-UiRefresh -Reason $UiRefreshReason
    }
  }
  $state | Add-Member -MemberType NoteProperty -Name Finalize -Value $finalize

  $busyCount = Increment-UiBusy
  if ($DisableControls) { Set-ControlsEnabled -Controls $DisableControls -Enabled:$false }
  if ($ProgressMode -ne 'None') { Add-UiProgressRequest -Owner $runId -Mode $ProgressMode }
  if ($EnableLogging) {
    Write-AdminPanelAsyncLog -Action $Action -Script $ScriptLabel -Status 'Start' -RunId $runId -DurationMs 0 -BusyCount $busyCount -Details $LogDetails -Evidence $state.Evidence
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

  $useCmd = $false
  try {
    $ext = [System.IO.Path]::GetExtension($scriptPath)
    if ($ext) {
      $ext = $ext.ToLowerInvariant()
      if ($ext -eq '.cmd' -or $ext -eq '.bat') { $useCmd = $true }
    }
  } catch { }

  if ($useCmd) {
    $exe = if ($env:ComSpec) { $env:ComSpec } else { 'cmd.exe' }
    $args = @('/c', $scriptPath)
    if ($Arguments) { $args += $Arguments }
  } else {
    $exe = Resolve-PreferredShellExe -AllowPwsh:$AllowPwsh
    $args = @(
      '-NoLogo','-NoProfile','-NonInteractive','-WindowStyle','Hidden',
      '-ExecutionPolicy','Bypass',
      '-File',$scriptPath
    )
    if ($Arguments) { $args += $Arguments }
  }

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

function Get-ActionDisableControls {
  $controls = @()
  if ($btnRunAction) { $controls += $btnRunAction }
  if ($systemActionSelect) { $controls += $systemActionSelect }
  if ($script:BtnRunTest) { $controls += $script:BtnRunTest }
  if ($script:TestActionSelect) { $controls += $script:TestActionSelect }
  if ($script:BtnRunDevTest) { $controls += $script:BtnRunDevTest }
  if ($script:DevActionSelect) { $controls += $script:DevActionSelect }
  if ($btnUninstall) { $controls += $btnUninstall }
  if ($btnOpenLogs) { $controls += $btnOpenLogs }
  if ($btnOpenEventViewer) { $controls += $btnOpenEventViewer }
  if ($btnExportBaseline) { $controls += $btnExportBaseline }
  if ($btnExportDiagnostics) { $controls += $btnExportDiagnostics }
  return $controls
}

function Get-LatestOutputFromHint {
  param([string]$Hint)
  if (-not $Hint) { return $null }
  try {
    $dir = Split-Path -Parent $Hint
    $pattern = Split-Path -Leaf $Hint
    if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { return $null }
    $latest = Get-ChildItem -Path $dir -Filter $pattern -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if ($latest) { return $latest.FullName }
  } catch { }
  return $null
}

function Format-OutputHints {
  param([AllowNull()][object]$Hints)
  if ($null -eq $Hints) { return $null }
  if ($Hints -is [string]) { return $Hints }
  $list = @($Hints | Where-Object { $_ })
  if (-not $list -or $list.Count -eq 0) { return $null }
  return ($list -join '; ')
}

function Merge-ToolMissingEvidence {
  param(
    [AllowNull()][AllowEmptyString()][string]$PrimaryPath,
    [AllowNull()][object]$ExpectedTools
  )
  $lines = @()
  if ($PrimaryPath) { $lines += $PrimaryPath }
  $expectedText = Format-OutputHints -Hints $ExpectedTools
  if ($expectedText) {
    $expectedText = $expectedText -replace ';\\s*', [Environment]::NewLine
    $lines += $expectedText
  }
  if ($lines.Count -gt 0) { return ($lines -join [Environment]::NewLine) }
  return $PrimaryPath
}

function Get-LatestOutputFromHints {
  param([AllowNull()][object]$Hints)
  if ($null -eq $Hints) { return $null }
  $list = if ($Hints -is [string]) { @($Hints) } else { @($Hints) }
  $bestPath = $null
  $bestTime = [datetime]::MinValue
  foreach ($hint in $list) {
    if (-not $hint) { continue }
    $path = Get-LatestOutputFromHint -Hint $hint
    if ($path) {
      try {
        $time = (Get-Item -LiteralPath $path -ErrorAction SilentlyContinue).LastWriteTime
      } catch { $time = $null }
      if (-not $time) { $time = [datetime]::UtcNow }
      if ($time -gt $bestTime) {
        $bestTime = $time
        $bestPath = $path
      }
    }
  }
  return $bestPath
}

function Invoke-AdminPanelProcessAction {
  param(
    [Parameter(Mandatory)][string]$Action,
    [Parameter(Mandatory)][string[]]$ScriptCandidates,
    [string[]]$Arguments,
    [string]$LogDetails,
    [string]$BusyKey = 'AdminAction',
    [int]$TimeoutSec = 900,
    [object]$StatusText,
    [object]$OutputHint,
    [string]$RowCheck,
    [switch]$RequireAdmin,
    [switch]$RecordSnapshots,
    [AllowNull()][AllowEmptyString()][string]$UiRefreshReason,
    [scriptblock]$OnOk,
    [scriptblock]$OnFail
  )

  $scriptPath = Resolve-AdminPanelScriptPath -Candidates $ScriptCandidates
  $persistRow = $false
  if (-not $scriptPath) {
    $detail = 'Missing mapping'
    Write-AdminPanelActionLog -Action $Action -Script $null -Status 'Start' -Details $detail
    Write-AdminPanelActionLog -Action $Action -Script $null -Status 'Warn' -Details $detail
    if ($StatusText) { $StatusText.Text = ("Last run: WARN | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | Tool missing") }
    Clear-ActionOutput
    $expected = ($ScriptCandidates | Where-Object { $_ }) -join '; '
    $message = if ($expected) { "Tool missing. Expected: $expected" } else { "Tool missing (no mapping)." }
    Write-ActionOutputLine -Text ($Action + ": " + $message) -Level 'WARN'
    if ($RowCheck) {
      $evidence = if ($expected) { $expected -replace ';\\s*', [Environment]::NewLine } else { '(missing mapping)' }
      $detailText = if ($persistRow) { $Action + " | " + $message } else { $message }
      Set-ChecklistRowStatus -Check $RowCheck -Status 'WARN' -Details $detailText -EvidencePath $evidence -Persist:$persistRow
    }
    Show-NotImplementedMessage
    return $false
  }

  $useCmd = $false
  try {
    $ext = [System.IO.Path]::GetExtension($scriptPath)
    if ($ext) {
      $ext = $ext.ToLowerInvariant()
      if ($ext -eq '.cmd' -or $ext -eq '.bat') { $useCmd = $true }
    }
  } catch { }

  if ($useCmd) {
    $exe = if ($env:ComSpec) { $env:ComSpec } else { 'cmd.exe' }
    $args = @('/c', $scriptPath)
    if ($Arguments) { $args += $Arguments }
  } else {
    $exe = Resolve-PreferredShellExe
    $args = @(
      '-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-WindowStyle','Hidden',
      '-File', $scriptPath
    )
    if ($Arguments) { $args += $Arguments }
  }

  $argLine = Join-ProcessArguments -Args $args
  $disableControls = Get-ActionDisableControls
  $outputQueue = $script:ActionOutputQueue
  $refreshReasonValue = $null
  if ($PSBoundParameters.ContainsKey('UiRefreshReason')) {
    $refreshReasonValue = $UiRefreshReason
  } else {
    $refreshReasonValue = $Action
  }

  Clear-ActionOutput
  $startStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Write-ActionOutputLine -Text ($Action + ": START | " + $startStamp) -Level 'PASS'
  if ($StatusText) { $StatusText.Text = ("Running: " + $Action + "...") }

  $ok = Invoke-UiAsyncAction -Action $Action -ScriptLabel $scriptPath -LogDetails $LogDetails -BusyKey $BusyKey -DisableControls $disableControls -TimeoutSec $TimeoutSec -ProgressMode 'Indeterminate' -UiRefreshReason $refreshReasonValue -ScriptBlock {
    param($exePath, $argText, $actionLabel, $outputQueueRef, $recordSnapshots, $snapshotLabel)

    $stdoutCount = 0
    $stderrCount = 0
    $preSnap = $null
    $postSnap = $null

    if ($recordSnapshots) {
      try {
        $preSnap = New-AdminPanelSnapshot -Label ($snapshotLabel + '_Before')
      } catch { }
    }

    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $exePath
    $info.Arguments = $argText
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $info

    if (-not $proc.Start()) { throw "Failed to start process." }

    $stdout = $proc.StandardOutput
    $stderr = $proc.StandardError
    $stdoutTask = $stdout.ReadLineAsync()
    $stderrTask = $stderr.ReadLineAsync()

    while ($true) {
      $progressed = $false

      if ($stdoutTask -and $stdoutTask.IsCompleted) {
        $line = $stdoutTask.Result
        if ($line -ne $null) {
          [System.Threading.Interlocked]::Increment([ref]$stdoutCount) | Out-Null
          try {
            if ($outputQueueRef) {
              $null = $outputQueueRef.Enqueue([pscustomobject]@{ Text = $line; Level = $null; Action = $actionLabel })
            }
          } catch { }
          $stdoutTask = $stdout.ReadLineAsync()
        } else {
          $stdoutTask = $null
        }
        $progressed = $true
      }

      if ($stderrTask -and $stderrTask.IsCompleted) {
        $line = $stderrTask.Result
        if ($line -ne $null) {
          [System.Threading.Interlocked]::Increment([ref]$stderrCount) | Out-Null
          try {
            if ($outputQueueRef) {
              $null = $outputQueueRef.Enqueue([pscustomobject]@{ Text = $line; Level = 'FAIL'; Action = $actionLabel })
            }
          } catch { }
          $stderrTask = $stderr.ReadLineAsync()
        } else {
          $stderrTask = $null
        }
        $progressed = $true
      }

      if (-not $stdoutTask -and -not $stderrTask) { break }
      if (-not $progressed) { Start-Sleep -Milliseconds 40 }
    }

    $proc.WaitForExit() | Out-Null

    if ($recordSnapshots) {
      try {
        $postSnap = New-AdminPanelSnapshot -Label ($snapshotLabel + '_After')
      } catch { }
    }

    return [pscustomobject]@{
      ExitCode = $proc.ExitCode
      StdOutCount = $stdoutCount
      StdErrCount = $stderrCount
      SnapshotBefore = $preSnap
      SnapshotAfter = $postSnap
    }
  } -Arguments @($exe, $argLine, $Action, $outputQueue, [bool]$RecordSnapshots, $Action) -OnOk {
    param($result, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $exitCode = if ($result -and $result.ExitCode -ne $null) { [int]$result.ExitCode } else { 0 }
    $status = if ($exitCode -eq 0) { 'OK' } else { 'FAIL' }
    $outputPath = if ($OutputHint) { Get-LatestOutputFromHints -Hints $OutputHint } else { $null }
    $hintText = Format-OutputHints -Hints $OutputHint
    $snapshotBefore = if ($result -and $result.SnapshotBefore) { [string]$result.SnapshotBefore } else { $null }
    $snapshotAfter = if ($result -and $result.SnapshotAfter) { [string]$result.SnapshotAfter } else { $null }
    if ($outputPath) {
      Write-ActionOutputLine -Text ($Action + ": Evidence " + $outputPath) -Level 'PASS'
    } elseif ($hintText) {
      Write-ActionOutputLine -Text ($Action + ": Evidence " + $hintText) -Level 'WARN'
    }
    $finalLevel = if ($status -eq 'OK') { 'PASS' } else { 'FAIL' }
    Write-ActionOutputLine -Text ($Action + ": COMPLETE (ExitCode=" + $exitCode + ")") -Level $finalLevel
    if ($StatusText) {
      $detail = if ($outputPath) { " | Output: " + $outputPath } elseif ($hintText) { " | Output: " + $hintText } else { '' }
      $StatusText.Text = ("Last run: " + $status + " | " + $timestamp + $detail)
    }
    $evidenceParts = @()
    if ($outputPath) { $evidenceParts += $outputPath }
    elseif ($hintText) { $evidenceParts += $hintText }
    if ($snapshotBefore) { $evidenceParts += $snapshotBefore }
    if ($snapshotAfter) { $evidenceParts += $snapshotAfter }
    if ($evidenceParts.Count -gt 0) { $state.Evidence = ($evidenceParts -join '; ') }

    $detailParts = @()
    if ($outputPath) { $detailParts += ("Output=" + $outputPath) }
    if ($snapshotBefore) { $detailParts += ("SnapshotBefore=" + $snapshotBefore) }
    if ($snapshotAfter) { $detailParts += ("SnapshotAfter=" + $snapshotAfter) }
    if ($detailParts.Count -gt 0) {
      $state.LogDetails = if ($state.LogDetails) { ($state.LogDetails + ' ' + ($detailParts -join ' ')) } else { ($detailParts -join ' ') }
    }
    if ($RowCheck) {
      $detailText = if ($outputPath) { "Output: " + $outputPath } elseif ($hintText) { "Output: " + $hintText } else { "Completed: " + $timestamp }
      $rowStatus = if ($exitCode -eq 0) {
        if ($hintText -and -not $outputPath) { 'WARN' } else { 'PASS' }
      } else { 'FAIL' }
      $evidenceValue = if ($outputPath) { $outputPath } else { $hintText }
      if ($persistRow) { $detailText = $Action + " | " + $detailText }
      if ($evidenceValue) {
        Set-ChecklistRowStatus -Check $RowCheck -Status $rowStatus -Details $detailText -EvidencePath $evidenceValue -Persist:$persistRow
      } else {
        Set-ChecklistRowStatus -Check $RowCheck -Status $rowStatus -Details $detailText -Persist:$persistRow
      }
    }
    if ($OnOk) {
      try { & $OnOk $result $state } catch { }
    }
    if ($exitCode -ne 0) {
      if ($state) {
        if ($state.LogDetails) { $state.LogDetails = ($state.LogDetails + " ExitCode=" + $exitCode) } else { $state.LogDetails = ("ExitCode=" + $exitCode) }
      }
      if ($state -and $state.Finalize) {
        $state.Finalize.Invoke('Fail', ("ExitCode=" + $exitCode))
      }
    } elseif ($hintText -and -not $outputPath) {
      if ($state) {
        if ($state.LogDetails) { $state.LogDetails = ($state.LogDetails + " OutputMissing") } else { $state.LogDetails = "OutputMissing" }
      }
      if ($state -and $state.Finalize) {
        $state.Finalize.Invoke('Warn', $null)
      }
    }
  } -OnFail {
    param($err, $state)
    if ($err -eq 'Skipped: already running') {
      if ($StatusText) { $StatusText.Text = "Busy: another action is running." }
      Write-ActionOutputLine -Text ($Action + ": Busy (another action is running)") -Level 'WARN'
      if ($OnFail) { & $OnFail $err $state }
      return
    }
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $reason = if ($err) { $err } else { 'Unknown failure' }
    Write-ActionOutputLine -Text ($Action + ": FAIL (" + $reason + ")") -Level 'FAIL'
    if ($StatusText) { $StatusText.Text = ("Last run: FAIL | " + $timestamp + " | See AdminPanel-Actions.log") }
    if ($RowCheck) {
      $detailText = "Failed: " + $reason
      if ($persistRow) { $detailText = $Action + " | " + $detailText }
      Set-ChecklistRowStatus -Check $RowCheck -Status 'FAIL' -Details $detailText -EvidencePath '(failed) see logs' -Persist:$persistRow
    }
    if ($err -ne 'Async dispatch failed') {
      [System.Windows.MessageBox]::Show("Action failed:`n$reason",'FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
    }
    if ($OnFail) { & $OnFail $err $state }
  } -OnTimeout {
    param($elapsedSec, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $timeoutMsg = "Timeout after {0}s" -f [Math]::Round($elapsedSec, 0)
    Write-ActionOutputLine -Text ($Action + ": FAIL (" + $timeoutMsg + ")") -Level 'FAIL'
    if ($StatusText) { $StatusText.Text = ("Last run: FAIL | " + $timestamp + " | " + $timeoutMsg) }
    if ($RowCheck) {
      $detailText = "Timeout: " + $timeoutMsg
      if ($persistRow) { $detailText = $Action + " | " + $detailText }
      Set-ChecklistRowStatus -Check $RowCheck -Status 'FAIL' -Details $detailText -EvidencePath '(timeout) see logs' -Persist:$persistRow
    }
    [System.Windows.MessageBox]::Show("Action timed out:`n$timeoutMsg",'FirewallCore Admin Panel',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
    if ($OnFail) { & $OnFail $timeoutMsg $state }
  }

  return $ok
}

function Get-FirewallNotificationsModulePath {
  $candidates = @()
  if ($script:FirewallRoot) {
    $candidates += (Join-Path $script:FirewallRoot 'Modules\FirewallNotifications.psm1')
  }
  $candidates += 'C:\Firewall\Modules\FirewallNotifications.psm1'
  $candidates += 'C:\FirewallInstaller\Firewall\Modules\FirewallNotifications.psm1'
  foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  return $null
}

function Get-ToastListenerLogSummary {
  try {
    $logDir = Join-Path $env:ProgramData 'FirewallCore\Logs'
    if (-not (Test-Path -LiteralPath $logDir)) { return 'User alert notifications log: not found' }
    $latest = Get-ChildItem -Path $logDir -Filter '*ToastListener*' -File -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if ($latest) {
      return ("User alert notifications log: {0} @ {1}" -f $latest.FullName, $latest.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    }
  } catch { }
  return 'User alert notifications log: not found'
}

function Get-ToastActivateLogSummary {
  try {
    $logDir = Join-Path $env:ProgramData 'FirewallCore\Logs'
    if (-not (Test-Path -LiteralPath $logDir)) { return $null }
    $latest = Get-ChildItem -Path $logDir -Filter '*ToastActivate*' -File -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if ($latest) {
      return ("User alert action handler log: {0} @ {1}" -f $latest.FullName, $latest.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    }
  } catch { }
  return $null
}

function Invoke-DemoAllSeveritiesAction {
  param(
    [Parameter(Mandatory)][string]$ActionLabel,
    [object]$StatusText,
    [string]$RowCheck = 'Last Test Summary',
    [switch]$ToolMissing,
    [AllowNull()][object]$ExpectedTools
  )

  $modulePath = Get-FirewallNotificationsModulePath
  if (-not $modulePath) {
    $expectedModules = @()
    if ($script:FirewallRoot) { $expectedModules += (Join-Path $script:FirewallRoot 'Modules\FirewallNotifications.psm1') }
    $expectedModules += 'C:\Firewall\Modules\FirewallNotifications.psm1'
    $expectedModules += 'C:\FirewallInstaller\Firewall\Modules\FirewallNotifications.psm1'
    $expectedText = ($expectedModules | Where-Object { $_ }) -join '; '
    $message = "Tool missing: FirewallNotifications module"
    $logDetail = if ($expectedText) { "Missing module. Expected=" + $expectedText } else { "Missing module." }
    Write-AdminPanelActionLog -Action $ActionLabel -Script $null -Status 'Start' -Details $logDetail
    Write-AdminPanelActionLog -Action $ActionLabel -Script $null -Status 'Warn' -Details $logDetail
    Write-ActionOutputLine -Text ($ActionLabel + ": WARN (" + $message + ")") -Level 'WARN'
    if ($StatusText) { $StatusText.Text = ("Last run: WARN | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | Tool missing") }
    if ($RowCheck) {
      $evidence = if ($expectedText) { $expectedText -replace ';\\s*', [Environment]::NewLine } else { '(missing module)' }
      Set-ChecklistRowStatus -Check $RowCheck -Status 'WARN' -Details $message -EvidencePath $evidence
    }
    return $false
  }

  $sessionId = [guid]::NewGuid().ToString()
  $delayMs = 700

  Clear-ActionOutput
  if ($ToolMissing) {
    Write-ActionOutputLine -Text ($ActionLabel + ": WARN (Tool missing; fallback used)") -Level 'WARN'
  }
  Write-ActionOutputLine -Text ($ActionLabel + ": START | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Level 'PASS'
  if ($StatusText) { $StatusText.Text = ("Running: " + $ActionLabel + "...") }

  return Invoke-UiAsyncAction -Action $ActionLabel -ScriptLabel 'DemoAllSeverities' -LogDetails ("Category=Test SessionId=" + $sessionId) -BusyKey 'AdminAction' -ProgressMode 'Indeterminate' -UiRefreshReason 'Notification Demo' -ScriptBlock {
    param($modulePath, $sessionId, $delayMs)
    $archive = Archive-NotifyQueue
    $listenerPid = Get-ToastListenerPid
    if (-not $listenerPid) { throw "Notification listener not running." }
    Import-Module $modulePath -Force -ErrorAction Stop
    $results = @()
    $severities = @('Info','Warning','Critical')
    foreach ($sev in $severities) {
      $corrId = ($sessionId + "-" + $sev + "-" + ([guid]::NewGuid().ToString("N").Substring(0,6)))
      $title = "FirewallCore Demo " + $sev
      $message = "Demo notification pipeline. Severity=$sev SessionId=$sessionId CorrelationId=$corrId"
      $eid = Write-FirewallEvent -Severity $sev -Title $title -Message $message -TestId $corrId
      $payload = New-NotificationPayload -Severity $sev -Title $title -Message $message -EventId $eid -TestId $corrId -Mode 'Dev'
      $path = Enqueue-FirewallNotification -Payload $payload
      $results += [pscustomobject]@{
        Severity = $sev
        TestId = $corrId
        EventId = $eid
        PayloadPath = $path
      }
      if ($sev -ne 'Critical') { Start-Sleep -Milliseconds $delayMs }
    }
    return [pscustomobject]@{
      SessionId = $sessionId
      Results = $results
      Archive = $archive
      ListenerPid = $listenerPid
    }
  } -Arguments @($modulePath, $sessionId, $delayMs) -OnOk {
    param($result, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $lines = @()
    if ($result -and $result.Results) {
      foreach ($r in $result.Results) {
        $line = ("{0}: {1}" -f $r.Severity, $r.PayloadPath)
        $lines += $line
        Write-ActionOutputLine -Text ($ActionLabel + ": " + $line) -Level 'PASS'
      }
    }
    $evidenceParts = @()
    if ($result -and $result.Results) {
      foreach ($r in $result.Results) {
        if ($r.PayloadPath) { $evidenceParts += [string]$r.PayloadPath }
        if ($r.TestId) { $lines += ("TestId: " + $r.TestId) }
      }
    }
    if ($result -and $result.Archive -and $result.Archive.ArchivePath) {
      $archivePath = [string]$result.Archive.ArchivePath
      $archivedCount = [int]$result.Archive.Archived
      $lines += ("ArchiveQueue: " + $archivePath + " | Archived=" + $archivedCount)
      $evidenceParts += $archivePath
    }
    if ($result -and $result.ListenerPid) {
      $lines += ("ListenerPid: " + $result.ListenerPid)
    }
    if ($evidenceParts.Count -gt 0) { $state.Evidence = ($evidenceParts -join '; ') }
    $toastSummary = Get-ToastListenerLogSummary
    if ($toastSummary) { $lines += $toastSummary }
    $activateSummary = Get-ToastActivateLogSummary
    if ($activateSummary) { $lines += $activateSummary }
    if ($ToolMissing -and $ExpectedTools) {
      $expectedText = Format-OutputHints -Hints $ExpectedTools
      if ($expectedText) { $lines += ($expectedText -replace ';\\s*', [Environment]::NewLine) }
    }
    if ($RowCheck) {
      $rowStatus = if ($ToolMissing) { 'WARN' } else { 'PASS' }
      $detailText = $ActionLabel + " | " + $timestamp
      $evidenceText = if ($lines.Count -gt 0) { $lines -join [Environment]::NewLine } else { 'See logs' }
      Set-ChecklistRowStatus -Check $RowCheck -Status $rowStatus -Details $detailText -EvidencePath $evidenceText
    }
    $finalLevel = if ($ToolMissing) { 'WARN' } else { 'PASS' }
    Write-ActionOutputLine -Text ($ActionLabel + ": COMPLETE") -Level $finalLevel
    if ($StatusText) {
      $label = if ($ToolMissing) { 'WARN' } else { 'OK' }
      $StatusText.Text = ("Last run: " + $label + " | " + $timestamp)
    }
    if ($ToolMissing -and $state -and $state.Finalize) {
      if ($state.LogDetails) { $state.LogDetails = ($state.LogDetails + " ToolMissing") } else { $state.LogDetails = "ToolMissing" }
      $state.Finalize.Invoke('Warn', $null)
    }
  } -OnFail {
    param($err, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-ActionOutputLine -Text ($ActionLabel + ": FAIL (" + $err + ")") -Level 'FAIL'
    if ($RowCheck) {
      Update-ChecklistEvidencePath -Check $RowCheck -EvidencePath '(failed) see logs'
      Set-ChecklistRowStatus -Check $RowCheck -Status 'FAIL' -Details ("Failed: " + $err) -EvidencePath '(failed) see logs'
    }
    if ($StatusText) { $StatusText.Text = ("Last run: FAIL | " + $timestamp + " | See AdminPanel-Actions.log") }
  } -OnTimeout {
    param($elapsedSec, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $timeoutMsg = "Timeout after {0}s" -f [Math]::Round($elapsedSec, 0)
    Write-ActionOutputLine -Text ($ActionLabel + ": FAIL (" + $timeoutMsg + ")") -Level 'FAIL'
    if ($RowCheck) {
      Update-ChecklistEvidencePath -Check $RowCheck -EvidencePath '(failed) see logs'
      Set-ChecklistRowStatus -Check $RowCheck -Status 'FAIL' -Details ("Timeout: " + $timeoutMsg) -EvidencePath '(failed) see logs'
    }
    if ($StatusText) { $StatusText.Text = ("Last run: FAIL | " + $timestamp + " | " + $timeoutMsg) }
  }
}

function Invoke-FallbackQuickHealthCheck {
  param(
    [Parameter(Mandatory)][string]$ActionLabel,
    [object]$StatusText,
    [string]$RowCheck = 'Last Test Summary',
    [switch]$ToolMissing,
    [AllowNull()][object]$ExpectedTools
  )

  $reportsDir = 'C:\ProgramData\FirewallCore\Reports'
  Clear-ActionOutput
  if ($ToolMissing) {
    Write-ActionOutputLine -Text ($ActionLabel + ": WARN (Tool missing; fallback used)") -Level 'WARN'
  }
  Write-ActionOutputLine -Text ($ActionLabel + ": START | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Level 'PASS'
  if ($StatusText) { $StatusText.Text = "Running: Quick Health Check..." }

  return Invoke-UiAsyncAction -Action $ActionLabel -ScriptLabel 'QuickHealth-Fallback' -LogDetails 'Category=Test Fallback' -BusyKey 'AdminAction' -ProgressMode 'Indeterminate' -UiRefreshReason 'Quick Health Check' -ScriptBlock {
    param($reportsDir)
    try { New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null } catch { }
    $rows = Invoke-Checklist
    $rowList = @($rows)
    $pass = (@($rowList | Where-Object { $_.Status -eq 'PASS' })).Count
    $warn = (@($rowList | Where-Object { $_.Status -eq 'WARN' })).Count
    $fail = (@($rowList | Where-Object { $_.Status -eq 'FAIL' })).Count
    $issues = @($rowList | Where-Object { $_.Status -ne 'PASS' } |
      Select-Object Check,Status,Details,SuggestedAction,EvidencePath)
    $payload = [pscustomobject]@{
      Timestamp = (Get-Date).ToString('o')
      Summary = [pscustomobject]@{
        Pass = $pass
        Warn = $warn
        Fail = $fail
        Total = $rowList.Count
      }
      Issues = $issues
    }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $path = Join-Path $reportsDir ("QuickHealth_{0}.json" -f $stamp)
    $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $path -Encoding UTF8
    return $path
  } -Arguments @($reportsDir) -OnOk {
    param($outputPath, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $rowStatus = if ($ToolMissing) { 'WARN' } else { 'PASS' }
    $evidencePath = if ($ToolMissing) { Merge-ToolMissingEvidence -PrimaryPath $outputPath -ExpectedTools $ExpectedTools } else { $outputPath }
    if ($outputPath) {
      $state.Evidence = $outputPath
      $state.LogDetails = if ($state.LogDetails) { $state.LogDetails + ' Output=' + $outputPath } else { 'Output=' + $outputPath }
    }
    if ($outputPath) {
      Write-ActionOutputLine -Text ($ActionLabel + ": Evidence " + $outputPath) -Level 'PASS'
    }
    $finalLevel = if ($rowStatus -eq 'WARN') { 'WARN' } else { 'PASS' }
    Write-ActionOutputLine -Text ($ActionLabel + ": COMPLETE") -Level $finalLevel
    if ($StatusText) {
      $detail = if ($outputPath) { " | Output: " + $outputPath } else { '' }
      $label = if ($ToolMissing) { 'WARN' } else { 'OK' }
      $StatusText.Text = ("Last run: " + $label + " | " + $timestamp + $detail)
    }
    if ($RowCheck) {
      $prefix = if ($ToolMissing) { 'Tool missing; fallback used. ' } else { '' }
      $detailText = if ($outputPath) { $prefix + "Output: " + $outputPath } else { $prefix + "Completed: " + $timestamp }
      Set-ChecklistRowStatus -Check $RowCheck -Status $rowStatus -Details $detailText -EvidencePath $evidencePath
    }
    if ($rowStatus -eq 'WARN' -and $state -and $state.Finalize) {
      if ($state.LogDetails) { $state.LogDetails = ($state.LogDetails + " ToolMissing") } else { $state.LogDetails = "ToolMissing" }
      $state.Finalize.Invoke('Warn', $null)
    }
  } -OnFail {
    param($err, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-ActionOutputLine -Text ($ActionLabel + ": FAIL (" + $err + ")") -Level 'FAIL'
    if ($StatusText) { $StatusText.Text = ("Last run: FAIL | " + $timestamp + " | See AdminPanel-Actions.log") }
    if ($RowCheck) {
      Set-ChecklistRowStatus -Check $RowCheck -Status 'FAIL' -Details ("Failed: " + $err) -EvidencePath '(failed) see logs'
    }
  }
}

function Invoke-FallbackBaselineDriftCheck {
  param(
    [Parameter(Mandatory)][string]$ActionLabel,
    [object]$StatusText,
    [string]$RowCheck = 'Last Test Summary',
    [switch]$ToolMissing,
    [AllowNull()][object]$ExpectedTools
  )

  $reportsDir = 'C:\ProgramData\FirewallCore\Reports'
  $baselineCandidates = @()
  if ($script:FirewallRoot) {
    $baselineCandidates += (Join-Path $script:FirewallRoot 'State\Baseline\baseline.sha256.json')
    $baselineCandidates += (Join-Path $script:FirewallRoot 'State\baseline.json')
  }
  $baselineCandidates += 'C:\Firewall\State\Baseline\baseline.sha256.json'
  $baselineCandidates += 'C:\Firewall\State\baseline.json'

  Clear-ActionOutput
  if ($ToolMissing) {
    Write-ActionOutputLine -Text ($ActionLabel + ": WARN (Tool missing; fallback used)") -Level 'WARN'
  }
  Write-ActionOutputLine -Text ($ActionLabel + ": START | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Level 'PASS'
  if ($StatusText) { $StatusText.Text = "Running: Baseline Drift Check..." }

  return Invoke-UiAsyncAction -Action $ActionLabel -ScriptLabel 'BaselineDrift-Fallback' -LogDetails 'Category=Test Fallback' -BusyKey 'AdminAction' -ProgressMode 'Indeterminate' -UiRefreshReason 'Baseline Drift Check' -ScriptBlock {
    param($reportsDir, $baselineCandidates)
    try { New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null } catch { }
    $baselinePath = $null
    foreach ($c in $baselineCandidates) {
      if ($c -and (Test-Path -LiteralPath $c)) { $baselinePath = $c; break }
    }
    $status = 'PASS'
    $reason = $null
    $lastWrite = $null
    if (-not $baselinePath) {
      $status = 'FAIL'
      $reason = 'Baseline file not found.'
    } else {
      try { $lastWrite = (Get-Item -LiteralPath $baselinePath).LastWriteTime } catch { }
    }
    $payload = [pscustomobject]@{
      Timestamp = (Get-Date).ToString('o')
      Status = $status
      Reason = $reason
      BaselinePath = $baselinePath
      LastWriteTime = if ($lastWrite) { $lastWrite.ToString('o') } else { $null }
    }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $path = Join-Path $reportsDir ("BaselineDrift_{0}.json" -f $stamp)
    $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $path -Encoding UTF8
    return [pscustomobject]@{
      ReportPath = $path
      Status = $status
      Reason = $reason
      BaselinePath = $baselinePath
    }
  } -Arguments @($reportsDir, $baselineCandidates) -OnOk {
    param($result, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $status = if ($result -and $result.Status) { [string]$result.Status } else { 'OK' }
    $reportPath = if ($result -and $result.ReportPath) { [string]$result.ReportPath } else { $null }
    $baseStatus = if ($status -and $status -match '^(PASS|WARN|FAIL)$') { $status } elseif ($status -eq 'OK') { 'PASS' } else { 'PASS' }
    $rowStatus = if ($ToolMissing -and $baseStatus -eq 'PASS') { 'WARN' } else { $baseStatus }
    $evidencePath = if ($ToolMissing) { Merge-ToolMissingEvidence -PrimaryPath $reportPath -ExpectedTools $ExpectedTools } else { $reportPath }
    if ($reportPath) {
      Write-ActionOutputLine -Text ($ActionLabel + ": Evidence " + $reportPath) -Level 'PASS'
    }
    if ($result -and $result.BaselinePath) {
      Write-ActionOutputLine -Text ($ActionLabel + ": Baseline " + $result.BaselinePath) -Level 'PASS'
    } elseif ($result -and $result.Reason) {
      Write-ActionOutputLine -Text ($ActionLabel + ": " + $result.Reason) -Level 'WARN'
    }
    $finalLevel = if ($rowStatus -eq 'WARN') { 'WARN' } elseif ($rowStatus -eq 'FAIL') { 'FAIL' } else { 'PASS' }
    Write-ActionOutputLine -Text ($ActionLabel + ": COMPLETE (" + $status + ")") -Level $finalLevel
    if ($StatusText) {
      $detail = if ($reportPath) { " | Output: " + $reportPath } else { '' }
      $displayStatus = if ($ToolMissing -and $status -eq 'PASS') { 'WARN' } else { $status }
      $StatusText.Text = ("Last run: " + $displayStatus + " | " + $timestamp + $detail)
    }
    if ($RowCheck) {
      $prefix = if ($ToolMissing) { 'Tool missing; fallback used. ' } else { '' }
      $detailText = if ($reportPath) { $prefix + "Output: " + $reportPath } elseif ($result -and $result.Reason) { $prefix + $result.Reason } else { $prefix + "Completed: " + $timestamp }
      Set-ChecklistRowStatus -Check $RowCheck -Status $rowStatus -Details $detailText -EvidencePath $evidencePath
    }
    if ($rowStatus -eq 'WARN' -and $state -and $state.Finalize) {
      if ($ToolMissing) {
        if ($state.LogDetails) { $state.LogDetails = ($state.LogDetails + " ToolMissing") } else { $state.LogDetails = "ToolMissing" }
      }
      $state.Finalize.Invoke('Warn', $null)
    } elseif ($rowStatus -eq 'FAIL' -and $state -and $state.Finalize) {
      $state.Finalize.Invoke('Fail', $result.Reason)
    }
  } -OnFail {
    param($err, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-ActionOutputLine -Text ($ActionLabel + ": FAIL (" + $err + ")") -Level 'FAIL'
    if ($StatusText) { $StatusText.Text = ("Last run: FAIL | " + $timestamp + " | See AdminPanel-Actions.log") }
    if ($RowCheck) {
      Set-ChecklistRowStatus -Check $RowCheck -Status 'FAIL' -Details ("Failed: " + $err) -EvidencePath '(failed) see logs'
    }
  }
}

function Invoke-FallbackInboundRiskReport {
  param(
    [Parameter(Mandatory)][string]$ActionLabel,
    [object]$StatusText,
    [string]$RowCheck = 'Last Test Summary',
    [switch]$ToolMissing,
    [AllowNull()][object]$ExpectedTools
  )

  $reportsDir = 'C:\ProgramData\FirewallCore\Reports'
  Clear-ActionOutput
  if ($ToolMissing) {
    Write-ActionOutputLine -Text ($ActionLabel + ": WARN (Tool missing; fallback used)") -Level 'WARN'
  }
  Write-ActionOutputLine -Text ($ActionLabel + ": START | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Level 'PASS'
  if ($StatusText) { $StatusText.Text = "Running: Inbound Allow Risk Report..." }

  return Invoke-UiAsyncAction -Action $ActionLabel -ScriptLabel 'InboundRisk-Fallback' -LogDetails 'Category=Test Fallback' -BusyKey 'AdminAction' -ProgressMode 'Indeterminate' -UiRefreshReason 'Inbound Allow Risk Report' -ScriptBlock {
    param($reportsDir)
    try { New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null } catch { }
    $errorText = $null
    $results = @()
    try {
      $rules = Get-NetFirewallRule -ErrorAction Stop | Where-Object { $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' }
      foreach ($rule in $rules) {
        $addr = $null
        $port = $null
        $app = $null
        $svc = $null
        try { $addr = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $rule -ErrorAction SilentlyContinue } catch { }
        try { $port = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule -ErrorAction SilentlyContinue } catch { }
        try { $app = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $rule -ErrorAction SilentlyContinue } catch { }
        try { $svc = Get-NetFirewallServiceFilter -AssociatedNetFirewallRule $rule -ErrorAction SilentlyContinue } catch { }

        $remoteAddress = $null
        if ($addr -and $addr.RemoteAddress) { $remoteAddress = [string]$addr.RemoteAddress }
        $remoteScope = if ([string]::IsNullOrWhiteSpace($remoteAddress) -or $remoteAddress -eq 'Any' -or $remoteAddress -eq '*') { 'None' } else { 'Restricted' }

        $program = if ($app -and $app.Program) { [string]$app.Program } else { '' }
        $service = if ($svc -and $svc.Service) { [string]$svc.Service } else { '' }
        $programService = ($program + ';' + $service).Trim(';')

        $localPort = if ($port -and $port.LocalPort) { [string]$port.LocalPort } else { '' }
        $protocol = if ($port -and $port.Protocol) { [string]$port.Protocol } else { '' }

        $profile = if ($rule.Profile) { [string]$rule.Profile } else { '' }
        $edgeTraversal = if ($rule.EdgeTraversalPolicy) { [string]$rule.EdgeTraversalPolicy } else { [string]$rule.EdgeTraversal }

        $riskPublic = $profile -match '(?i)Public'
        $riskEdge = $edgeTraversal -match '(?i)Allow|Yes'
        $riskNoScope = ($remoteScope -eq 'None')
        $riskKeyService = $programService -match '(?i)spooler|wmi|mdns|ssdp|dosvc|hyper-v'

        $results += [pscustomobject]@{
          RuleName = [string]$rule.DisplayName
          Enabled = [string]$rule.Enabled
          Direction = [string]$rule.Direction
          Action = [string]$rule.Action
          Profile = $profile
          EdgeTraversal = $edgeTraversal
          RemoteAddressScope = $remoteScope
          RemoteAddress = $remoteAddress
          ProgramService = $programService
          LocalPort = $localPort
          Protocol = $protocol
          Risk_PublicAllow = [bool]$riskPublic
          Risk_EdgeTraversal = [bool]$riskEdge
          Risk_NoRemoteAddressScope = [bool]$riskNoScope
          Risk_KeyService = [bool]$riskKeyService
        }
      }
    } catch {
      $errorText = $_.Exception.Message
    }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $path = Join-Path $reportsDir ("InboundAllowRisk_{0}.csv" -f $stamp)
    $header = 'RuleName,Enabled,Direction,Action,Profile,EdgeTraversal,RemoteAddressScope,RemoteAddress,ProgramService,LocalPort,Protocol,Risk_PublicAllow,Risk_EdgeTraversal,Risk_NoRemoteAddressScope,Risk_KeyService'
    if ($results.Count -gt 0) {
      $results | Sort-Object RuleName | Export-Csv -Path $path -NoTypeInformation -Encoding ASCII
    } else {
      Set-Content -LiteralPath $path -Value $header -Encoding ASCII
    }
    return [pscustomobject]@{
      ReportPath = $path
      Total = $results.Count
      Error = $errorText
    }
  } -Arguments @($reportsDir) -OnOk {
    param($result, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $reportPath = if ($result -and $result.ReportPath) { [string]$result.ReportPath } else { $null }
    if ($reportPath) { $state.Evidence = $reportPath }
    if ($reportPath) {
      $state.LogDetails = if ($state.LogDetails) { $state.LogDetails + ' Output=' + $reportPath } else { 'Output=' + $reportPath }
    }
    if ($reportPath) {
      Write-ActionOutputLine -Text ($ActionLabel + ": Evidence " + $reportPath) -Level 'PASS'
    }
    $statusLabel = 'OK'
    if ($result -and $result.Error) {
      $statusLabel = 'WARN'
      Write-ActionOutputLine -Text ($ActionLabel + ": " + $result.Error) -Level 'WARN'
    } else {
      Write-ActionOutputLine -Text ($ActionLabel + ": Inbound allow rules=" + $result.Total) -Level 'PASS'
    }
    $rowStatus = if ($ToolMissing -and $statusLabel -eq 'OK') { 'WARN' } elseif ($statusLabel -eq 'WARN') { 'WARN' } else { 'PASS' }
    $evidencePath = if ($ToolMissing) { Merge-ToolMissingEvidence -PrimaryPath $reportPath -ExpectedTools $ExpectedTools } else { $reportPath }
    $finalLevel = if ($rowStatus -eq 'WARN') { 'WARN' } else { 'PASS' }
    Write-ActionOutputLine -Text ($ActionLabel + ": COMPLETE") -Level $finalLevel
    if ($StatusText) {
      $detail = if ($reportPath) { " | Output: " + $reportPath } else { '' }
      $displayStatus = if ($ToolMissing -and $statusLabel -eq 'OK') { 'WARN' } else { $statusLabel }
      $StatusText.Text = ("Last run: " + $displayStatus + " | " + $timestamp + $detail)
    }
    if ($reportPath) {
      $state.Evidence = $reportPath
      $state.LogDetails = if ($state.LogDetails) { $state.LogDetails + ' Output=' + $reportPath } else { 'Output=' + $reportPath }
    }
    if ($RowCheck) {
      $prefix = if ($ToolMissing) { 'Tool missing; fallback used. ' } else { '' }
      $detailText = if ($reportPath) { $prefix + "Output: " + $reportPath } elseif ($result -and $result.Error) { $prefix + $result.Error } else { $prefix + "Completed: " + $timestamp }
      Set-ChecklistRowStatus -Check $RowCheck -Status $rowStatus -Details $detailText -EvidencePath $evidencePath
    }
    if ($rowStatus -eq 'WARN' -and $state -and $state.Finalize) {
      if ($ToolMissing) {
        if ($state.LogDetails) { $state.LogDetails = ($state.LogDetails + " ToolMissing") } else { $state.LogDetails = "ToolMissing" }
      }
      $state.Finalize.Invoke('Warn', $null)
    }
  } -OnFail {
    param($err, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-ActionOutputLine -Text ($ActionLabel + ": FAIL (" + $err + ")") -Level 'FAIL'
    if ($StatusText) { $StatusText.Text = ("Last run: FAIL | " + $timestamp + " | See AdminPanel-Actions.log") }
    if ($RowCheck) {
      Set-ChecklistRowStatus -Check $RowCheck -Status 'FAIL' -Details ("Failed: " + $err) -EvidencePath '(failed) see logs'
    }
  }
}

function Invoke-FallbackExportDiagnosticsBundle {
  param(
    [Parameter(Mandatory)][string]$ActionLabel,
    [object]$StatusText,
    [string]$RowCheck = 'Last Diagnostics Bundle',
    [switch]$ToolMissing,
    [AllowNull()][object]$ExpectedTools,
    [string]$LogCategory = 'Test'
  )

  $exportDir = 'C:\ProgramData\FirewallCore\Diagnostics'
  Clear-ActionOutput
  if ($ToolMissing) {
    Write-ActionOutputLine -Text ($ActionLabel + ": WARN (Tool missing; fallback used)") -Level 'WARN'
  }
  Write-ActionOutputLine -Text ($ActionLabel + ": START | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Level 'PASS'
  if ($StatusText) { $StatusText.Text = "Running: Export Diagnostics Bundle..." }

  $categoryText = if ($LogCategory) { "Category=" + $LogCategory + " Fallback" } else { 'Fallback' }
  return Invoke-UiAsyncAction -Action $ActionLabel -ScriptLabel 'ExportDiagnostics-Fallback' -LogDetails $categoryText -BusyKey 'AdminAction' -ProgressMode 'Indeterminate' -UiRefreshReason 'Diagnostics Bundle' -ScriptBlock {
    param($exportDir)
    try { New-Item -ItemType Directory -Force -Path $exportDir | Out-Null } catch { }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bundleDir = Join-Path $exportDir ("BUNDLE_{0}" -f $stamp)
    $bundleZip = Join-Path $exportDir ("BUNDLE_{0}.zip" -f $stamp)
    try { New-Item -ItemType Directory -Force -Path $bundleDir | Out-Null } catch { }

    $sources = @(
      @{ Name = 'Logs'; Path = 'C:\ProgramData\FirewallCore\Logs' },
      @{ Name = 'LifecycleExports'; Path = 'C:\ProgramData\FirewallCore\LifecycleExports' },
      @{ Name = 'Policy'; Path = 'C:\Firewall\Policy' }
    )

    foreach ($source in $sources) {
      if (-not $source.Path) { continue }
      if (Test-Path -LiteralPath $source.Path) {
        $dest = Join-Path $bundleDir $source.Name
        try { New-Item -ItemType Directory -Force -Path $dest | Out-Null } catch { }
        try { Copy-Item -Path (Join-Path $source.Path '*') -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue } catch { }
      }
    }

    $hashFile = Join-Path $bundleDir 'hashes.sha256.txt'
    $hashLines = @()
    $files = Get-ChildItem -Path $bundleDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -ne $hashFile }
    foreach ($file in $files) {
      try {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash
        $rel = $file.FullName.Substring($bundleDir.Length + 1)
        $hashLines += ($hash + '  ' + $rel)
      } catch { }
    }
    try { $hashLines | Set-Content -Path $hashFile -Encoding ASCII } catch { }

    $usedCompress = $false
    if (Get-Command -Name Compress-Archive -ErrorAction SilentlyContinue) {
      Compress-Archive -Path (Join-Path $bundleDir '*') -DestinationPath $bundleZip -Force
      $usedCompress = $true
    } else {
      Set-Content -Path $bundleZip -Value ("Diagnostics bundle placeholder " + $stamp) -Encoding ASCII
    }

    return [pscustomobject]@{
      BundleDir = $bundleDir
      BundleZip = $bundleZip
      HashPath = $hashFile
      UsedCompress = $usedCompress
    }
  } -Arguments @($exportDir) -OnOk {
    param($result, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $bundleDir = if ($result -and $result.BundleDir) { [string]$result.BundleDir } else { $null }
    $bundleZip = if ($result -and $result.BundleZip) { [string]$result.BundleZip } else { $null }
    $hashPath = if ($result -and $result.HashPath) { [string]$result.HashPath } else { $null }
    $rowStatus = if ($ToolMissing) { 'WARN' } else { 'PASS' }
    $evidenceParts = @()
    if ($bundleZip) { $evidenceParts += $bundleZip }
    if ($bundleDir) { $evidenceParts += $bundleDir }
    if ($hashPath) { $evidenceParts += $hashPath }
    if ($evidenceParts.Count -gt 0) { $state.Evidence = ($evidenceParts -join '; ') }
    if ($bundleZip) {
      $state.LogDetails = if ($state.LogDetails) { $state.LogDetails + ' Output=' + $bundleZip } else { 'Output=' + $bundleZip }
    }
    $evidencePath = if ($ToolMissing) { Merge-ToolMissingEvidence -PrimaryPath $bundleZip -ExpectedTools $ExpectedTools } else { $bundleZip }
    if ($bundleZip) {
      Write-ActionOutputLine -Text ($ActionLabel + ": Bundle " + $bundleZip) -Level 'PASS'
    }
    $finalLevel = if ($rowStatus -eq 'WARN') { 'WARN' } else { 'PASS' }
    Write-ActionOutputLine -Text ($ActionLabel + ": COMPLETE") -Level $finalLevel
    if ($StatusText) {
      $detail = if ($bundleZip) { " | Output: " + $bundleZip } else { '' }
      $label = if ($ToolMissing) { 'WARN' } else { 'OK' }
      $StatusText.Text = ("Last run: " + $label + " | " + $timestamp + $detail)
    }
    if ($RowCheck) {
      $prefix = if ($ToolMissing) { 'Tool missing; fallback used. ' } else { '' }
      $detailText = if ($bundleZip) { $prefix + "Output: " + $bundleZip } else { $prefix + "Completed: " + $timestamp }
      Set-ChecklistRowStatus -Check $RowCheck -Status $rowStatus -Details $detailText -EvidencePath $evidencePath
    }
    if ($rowStatus -eq 'WARN' -and $state -and $state.Finalize) {
      if ($ToolMissing) {
        if ($state.LogDetails) { $state.LogDetails = ($state.LogDetails + " ToolMissing") } else { $state.LogDetails = "ToolMissing" }
      }
      $state.Finalize.Invoke('Warn', $null)
    }
  } -OnFail {
    param($err, $state)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-ActionOutputLine -Text ($ActionLabel + ": FAIL (" + $err + ")") -Level 'FAIL'
    if ($StatusText) { $StatusText.Text = ("Last run: FAIL | " + $timestamp + " | See AdminPanel-Actions.log") }
    if ($RowCheck) {
      Set-ChecklistRowStatus -Check $RowCheck -Status 'FAIL' -Details ("Failed: " + $err) -EvidencePath '(failed) see logs'
    }
  }
}

function Normalize-PowerShellArguments {
  param([AllowNull()][string]$Arguments)
  $argsText = if ($Arguments) { $Arguments.Trim() } else { '' }

  $argsText = [regex]::Replace($argsText, '(?i)(^|\\s)-NoLogo(:\\S+)?(?=\\s|$)', ' ')
  $argsText = [regex]::Replace($argsText, '(?i)(^|\\s)-NoProfile(:\\S+)?(?=\\s|$)', ' ')
  $argsText = [regex]::Replace($argsText, '(?i)(^|\\s)-NonInteractive(:\\S+)?(?=\\s|$)', ' ')
  $argsText = [regex]::Replace($argsText, '(?i)(^|\\s)-ExecutionPolicy(:\\S+|\\s+\\S+)', ' ')
  $argsText = [regex]::Replace($argsText, '(?i)(^|\\s)-ExecutionPolicy(?=\\s|$)', ' ')
  $argsText = [regex]::Replace($argsText, '(?i)(^|\\s)-WindowStyle(:\\S+|\\s+\\S+)', ' ')
  $argsText = [regex]::Replace($argsText, '(?i)(^|\\s)-WindowStyle(?=\\s|$)', ' ')
  $argsText = ($argsText -replace '\\s+', ' ').Trim()

  $prefix = @(
    '-NoLogo',
    '-NoProfile',
    '-NonInteractive',
    '-ExecutionPolicy Bypass',
    '-WindowStyle Hidden'
  )

  $combined = if ($argsText) { ($prefix + $argsText) -join ' ' } else { $prefix -join ' ' }
  return $combined.Trim()
}

function Repair-ScheduledTaskActions {
  param([Parameter(Mandatory)][string[]]$TaskNames)
  $updated = @()
  $missing = @()
  $failed = @()
  $unchanged = @()
  $psExe = Get-AdminPanelPowerShellExe

  foreach ($name in $TaskNames) {
    $task = $null
    try { $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue } catch { $task = $null }
    if (-not $task) {
      $missing += $name
      continue
    }

    $actions = @($task.Actions)
    $changed = $false
    foreach ($action in $actions) {
      $execute = [string]$action.Execute
      if (-not $execute -or $execute -match '(?i)pwsh\\.exe$' -or $execute -notmatch '(?i)powershell\\.exe$') {
        $action.Execute = $psExe
        $changed = $true
      }
      $newArgs = Normalize-PowerShellArguments -Arguments ([string]$action.Arguments)
      if ($newArgs -and $newArgs -ne $action.Arguments) {
        $action.Arguments = $newArgs
        $changed = $true
      }
    }

    if ($changed) {
      try {
        Set-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Action $actions -ErrorAction Stop | Out-Null
        $updated += $name
      } catch {
        $failed += ($name + ': ' + $_.Exception.Message)
      }
    } else {
      $unchanged += $name
    }
  }

  return [pscustomobject]@{
    Updated = $updated
    Missing = $missing
    Failed = $failed
    Unchanged = $unchanged
  }
}

function Invoke-RepairScheduledTasksAction {
  param(
    [object]$StatusText,
    [string]$RowCheck = 'Scheduled Tasks'
  )
  if (-not (Test-IsAdmin)) {
    $detail = 'Admin elevation required.'
    Write-AdminPanelActionLog -Action 'Repair Task Action' -Script $null -Status 'Fail' -Details $detail
    Write-ActionOutputLine -Text ('Repair Task Action: FAIL (admin required)') -Level 'FAIL'
    if ($StatusText) { $StatusText.Text = "Admin required: re-run as Administrator." }
    return $false
  }

  $taskNames = @(
    'Firewall Core Monitor',
    'Firewall WFP Monitor',
    'Firewall-Defender-Integration',
    'FirewallCore Toast Listener',
    'FirewallCore Toast Watchdog',
    'FirewallCore User Notifier',
    'Firewall Tamper Guard'
  )

  return Invoke-UiAsyncAction -Action 'Repair Task Action' -ScriptLabel 'RepairScheduledTasks' -LogDetails 'Category=Action' -BusyKey 'AdminAction' -ProgressMode 'Indeterminate' -UiRefreshReason 'Scheduled Tasks' -ScriptBlock {
    param($names)
    Repair-ScheduledTaskActions -TaskNames $names
  } -Arguments @($taskNames) -OnOk {
    param($result, $state)
    $updated = @($result.Updated)
    $missing = @($result.Missing)
    $failed = @($result.Failed)
    $detailParts = @()
    if ($updated.Count -gt 0) { $detailParts += ("Updated=" + ($updated -join ', ')) }
    if ($missing.Count -gt 0) { $detailParts += ("Missing=" + ($missing -join ', ')) }
    if ($failed.Count -gt 0) { $detailParts += ("Failed=" + ($failed -join ' | ')) }
    $detailText = if ($detailParts.Count -gt 0) { $detailParts -join ' || ' } else { 'No changes required.' }
    $state.Evidence = 'taskschd.msc'
    $state.LogDetails = if ($state.LogDetails) { $state.LogDetails + ' ' + $detailText } else { $detailText }
    Write-ActionOutputLine -Text ('Repair Task Action: ' + $detailText) -Level 'PASS'
    if ($StatusText) { $StatusText.Text = ("Repair Task Action: " + $detailText) }
    if ($RowCheck) {
      $rowStatus = if ($failed.Count -gt 0 -or $missing.Count -gt 0) { 'FAIL' } else { 'PASS' }
      Set-ChecklistRowStatus -Check $RowCheck -Status $rowStatus -Details $detailText -EvidencePath 'taskschd.msc'
    }
  } -OnFail {
    param($err, $state)
    Write-ActionOutputLine -Text ('Repair Task Action: FAIL (' + $err + ')') -Level 'FAIL'
    if ($StatusText) { $StatusText.Text = "Repair Task Action failed. See AdminPanel-Actions.log." }
    if ($RowCheck) {
      Set-ChecklistRowStatus -Check $RowCheck -Status 'FAIL' -Details ("Failed: " + $err) -EvidencePath 'taskschd.msc'
    }
  }
}

function Invoke-ArchiveNotifyQueueAction {
  param(
    [object]$StatusText,
    [string]$RowCheck = 'Notify Queue Health'
  )
  return Invoke-UiAsyncAction -Action 'Archive Notify Queue' -ScriptLabel 'ArchiveNotifyQueue' -LogDetails 'Category=Action' -BusyKey 'AdminAction' -ProgressMode 'Indeterminate' -UiRefreshReason 'Notify Queue' -ScriptBlock {
    Archive-NotifyQueue
  } -OnOk {
    param($result, $state)
    $archived = if ($result -and $result.Archived -ne $null) { [int]$result.Archived } else { 0 }
    $archivePath = if ($result -and $result.ArchivePath) { [string]$result.ArchivePath } else { $null }
    $state.Evidence = $archivePath
    $detail = "Archived=" + $archived
    if ($archivePath) { $detail += " | Path=" + $archivePath }
    Write-ActionOutputLine -Text ("Archive Notify Queue: " + $detail) -Level 'PASS'
    if ($StatusText) { $StatusText.Text = $detail }
    if ($RowCheck) {
      Set-ChecklistRowStatus -Check $RowCheck -Status 'PASS' -Details $detail -EvidencePath $archivePath
    }
  } -OnFail {
    param($err, $state)
    Write-ActionOutputLine -Text ("Archive Notify Queue: FAIL (" + $err + ")") -Level 'FAIL'
    if ($StatusText) { $StatusText.Text = "Archive queue failed. See AdminPanel-Actions.log." }
    if ($RowCheck) {
      Set-ChecklistRowStatus -Check $RowCheck -Status 'FAIL' -Details ("Failed: " + $err) -EvidencePath '(failed) see logs'
    }
  }
}

function Invoke-ExportBaselineAction {
  param(
    [object]$StatusText,
    [string]$RowCheck = 'Last Test Summary'
  )
  $reportsDir = 'C:\ProgramData\FirewallCore\Reports'
  return Invoke-UiAsyncAction -Action 'Export Baseline + SHA256' -ScriptLabel 'ExportBaseline' -LogDetails 'Category=Action' -BusyKey 'AdminAction' -ProgressMode 'Indeterminate' -UiRefreshReason 'Export Baseline' -ScriptBlock {
    param($reportsDir)
    try { New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null } catch { }
    $baselinePath = 'C:\Firewall\State\baseline.json'
    if (-not (Test-Path -LiteralPath $baselinePath)) {
      throw "Baseline not found: $baselinePath"
    }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $exportPath = Join-Path $reportsDir ("BaselineExport_{0}.json" -f $stamp)
    Copy-Item -LiteralPath $baselinePath -Destination $exportPath -Force
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $exportPath).Hash
    $hashPath = Join-Path $reportsDir ("BaselineExport_{0}.sha256.txt" -f $stamp)
    Set-Content -LiteralPath $hashPath -Value $hash -Encoding ASCII
    return [pscustomobject]@{
      BaselinePath = $exportPath
      HashPath = $hashPath
      Hash = $hash
    }
  } -Arguments @($reportsDir) -OnOk {
    param($result, $state)
    $baselinePath = if ($result -and $result.BaselinePath) { [string]$result.BaselinePath } else { $null }
    $hashPath = if ($result -and $result.HashPath) { [string]$result.HashPath } else { $null }
    $evidenceParts = @()
    if ($baselinePath) { $evidenceParts += $baselinePath }
    if ($hashPath) { $evidenceParts += $hashPath }
    if ($evidenceParts.Count -gt 0) { $state.Evidence = ($evidenceParts -join '; ') }
    $detail = "Baseline=" + $baselinePath
    if ($hashPath) { $detail += " | SHA256=" + $hashPath }
    Write-ActionOutputLine -Text ("Export Baseline + SHA256: " + $detail) -Level 'PASS'
    if ($StatusText) { $StatusText.Text = ("Last run: OK | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | " + $detail) }
    if ($RowCheck) {
      Set-ChecklistRowStatus -Check $RowCheck -Status 'PASS' -Details $detail -EvidencePath $baselinePath
    }
  } -OnFail {
    param($err, $state)
    Write-ActionOutputLine -Text ("Export Baseline + SHA256: FAIL (" + $err + ")") -Level 'FAIL'
    if ($StatusText) { $StatusText.Text = "Export baseline failed. See AdminPanel-Actions.log." }
  }
}

function Open-FirewallEventViewer {
  param([AllowNull()][AllowEmptyString()][string]$ViewPath)
  $viewer = 'eventvwr.msc'
  try {
    if ($ViewPath -and (Test-Path -LiteralPath $ViewPath)) {
      $arg = '/c:"{0}"' -f $ViewPath
      Start-Process -FilePath $viewer -ArgumentList $arg | Out-Null
    } else {
      Start-Process -FilePath $viewer | Out-Null
    }
  } catch {
    Start-Process -FilePath $viewer | Out-Null
  }
}

function Invoke-RowHelpAction {
  param(
    [object]$Row,
    [AllowNull()][AllowEmptyString()][string]$ActionOverride
  )
  if (-not $Row) { return }
  $action = if ($ActionOverride) { $ActionOverride } elseif ($Row.HelpAction) { $Row.HelpAction } else { $Row.EvidenceAction }
  if (-not $action) { return }

  $actionLabel = if ($Row.Component) { $Row.Component } elseif ($Row.Check) { $Row.Check } elseif ($Row.HelpLabel) { $Row.HelpLabel } else { 'Evidence Action' }

  if ($action -eq 'RunRulesReport') {
    $reportsFolder = if ($Row.HelpTarget) { $Row.HelpTarget } else { 'C:\ProgramData\FirewallCore\Reports' }
    $scripts = if ($Row.HelpScripts) { $Row.HelpScripts } else { @() }
    Invoke-RulesReportAction -ActionLabel $actionLabel -ScriptCandidates $scripts -ReportsFolder $reportsFolder -RowCheck $Row.Check -StatusText $null
    return
  }

  if ($action -eq 'RunRepair') {
    $options = Get-SelectedRepairOptions
    $args = @()
    if ($options -and $options.Count -gt 0) {
      $args = $options | ForEach-Object { $_.Arg }
    }
    Invoke-AdminPanelProcessAction -Action 'Repair' -ScriptCandidates $ActionScripts.Repair -Arguments $args -LogDetails 'Category=Action' -BusyKey 'AdminAction' -TimeoutSec 180 -StatusText $txtRepairStatus -RecordSnapshots -RequireAdmin
    return
  }

  if ($action -eq 'RepairScheduledTasks') {
    Invoke-RepairScheduledTasksAction -StatusText $txtActionStatus -RowCheck $Row.Check | Out-Null
    return
  }

  if ($action -eq 'ArchiveNotifyQueue') {
    Invoke-ArchiveNotifyQueueAction -StatusText $txtActionStatus -RowCheck $Row.Check | Out-Null
    return
  }

  if ($action -eq 'ExportDiagnosticsBundle') {
    Invoke-FallbackExportDiagnosticsBundle -ActionLabel 'Export Diagnostics Bundle' -StatusText $txtActionStatus -RowCheck 'Last Diagnostics Bundle' | Out-Null
    return
  }

  if ($action -eq 'ExportBaseline') {
    Invoke-ExportBaselineAction -StatusText $txtActionStatus | Out-Null
    return
  }

  if ($action -eq 'OpenWindowsFirewallLogs') {
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

  if ($action -eq 'RunScript') {
    Invoke-AdminPanelScript -Action $actionLabel -ScriptCandidates $Row.HelpScripts -LogDetails $Row.Check | Out-Null
    return
  }

  $target = if ($Row.EvidenceTarget) { $Row.EvidenceTarget } else { $Row.HelpTarget }
  if ($action -eq 'OpenTaskScheduler' -and -not $target) { $target = 'taskschd.msc' }
  if ($action -eq 'OpenEventViewer' -and -not $target) { $target = 'eventvwr.msc' }
  if ($action -eq 'OpenFirewallRulesView' -and -not $target) { $target = 'wf.msc' }

  Write-AdminPanelActionLog -Action $actionLabel -Script $target -Status 'Start' -Details $Row.Check
  try {
    switch ($action) {
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
      'OpenEventViewer' {
        $viewPath = if ($Row -and $Row.EvidencePath -and ($Row.EvidencePath -like '*.xml')) { $Row.EvidencePath } else { Get-FirewallEventViewerViewPath }
        Open-FirewallEventViewer -ViewPath $viewPath
      }
      'OpenFirewallRulesView' { Start-Process -FilePath $target | Out-Null }
      default { throw "Unsupported help action: $action" }
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

  $useCmd = $false
  try {
    $ext = [System.IO.Path]::GetExtension($scriptPath)
    if ($ext) {
      $ext = $ext.ToLowerInvariant()
      if ($ext -eq '.cmd' -or $ext -eq '.bat') { $useCmd = $true }
    }
  } catch { }

  if ($useCmd) {
    $exe = if ($env:ComSpec) { $env:ComSpec } else { 'cmd.exe' }
    $args = @('/c', $scriptPath)
    if ($Arguments) { $args += $Arguments }
  } else {
    $exe = Resolve-PreferredShellExe -AllowPwsh:$AllowPwsh
    $args = @(
      '-NoLogo','-NoProfile','-NonInteractive','-WindowStyle','Hidden',
      '-ExecutionPolicy','Bypass',
      '-File',$scriptPath
    )
    if ($Arguments) { $args += $Arguments }
  }

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
    if (-not (Assert-NotBusy -Context $meta.Action -StatusText $null)) { return }
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
  $DevPanel.Visibility = 'Visible'
  if ($DevHeader) { $DevHeader.Visibility = 'Visible' }
  if ($DevNote) { $DevNote.Visibility = 'Visible' }
  if ($DevPanel) { $DevPanel.IsEnabled = $Visible }
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
  $devUnlockStatus = $WindowOrRoot.FindName('TxtDevUnlockStatus')
  if (-not ($testSelect -and $btnRunTest -and $devToggle -and $devSelect -and $btnRunDev -and $devPanel)) { return }

  $script:TestActionSelect = $testSelect
  $script:BtnRunTest = $btnRunTest
  $script:DevActionSelect = $devSelect
  $script:BtnRunDevTest = $btnRunDev

  $root = if ($script:FirewallRoot) { $script:FirewallRoot } else { Get-AdminPanelScriptRoot }
  $toolsRoot = if ($root) { Join-Path $root 'Tools' } else { $null }
  $devRoot = if ($root) { Join-Path $root 'DEV-Only' } else { $null }

  $testSelect.Items.Clear()
  $devSelect.Items.Clear()
  $placeholder = New-Object System.Windows.Controls.ComboBoxItem
  $placeholder.Content = 'Select a test...'
  $placeholder.Tag = $null
  $testSelect.Items.Add($placeholder) | Out-Null

  $tests = @(
    @{ Title = 'Quick Health Check'; Subtitle = 'Validate services, tasks, logs, and baseline.'; Script = @((Join-Path $toolsRoot 'Run-QuickHealthCheck.ps1'),'C:\Firewall\Tools\Run-QuickHealthCheck.ps1'); OutputHint = 'C:\ProgramData\FirewallCore\Reports\QuickHealth_*'; HandlerId = 'QuickHealth'; RowCheck = 'Last Test Summary' },
    @{ Title = 'Notification Demo'; Subtitle = 'Show Info, Warning, and Critical alerts.'; Script = @((Join-Path $toolsRoot 'Run-NotificationDemo.ps1'),'C:\Firewall\Tools\Run-NotificationDemo.ps1'); HandlerId = 'NotificationDemo'; RowCheck = 'Last Test Summary' },
    @{ Title = 'Baseline Drift Check'; Subtitle = 'Read-only drift status and last baseline time.'; Script = @((Join-Path $toolsRoot 'Run-DriftCheck.ps1'),'C:\Firewall\Tools\Run-DriftCheck.ps1'); OutputHint = 'C:\ProgramData\FirewallCore\Reports\BaselineDrift_*'; HandlerId = 'BaselineDrift'; RowCheck = 'Last Test Summary' },
    @{ Title = 'Inbound Allow Risk Report'; Subtitle = 'Audit inbound exposure (no changes).'; Script = @((Join-Path $toolsRoot 'Run-InboundRiskReport.ps1'),'C:\Firewall\Tools\Run-InboundRiskReport.ps1'); OutputHint = 'C:\ProgramData\FirewallCore\Reports\InboundAllowRisk_*.csv'; HandlerId = 'InboundRisk'; RowCheck = 'Last Test Summary' },
    @{ Title = 'Export Diagnostics Bundle'; Subtitle = 'Package logs and snapshots for support.'; Script = @((Join-Path $toolsRoot 'Export-DiagnosticsBundle.ps1'),'C:\Firewall\Tools\Export-DiagnosticsBundle.ps1'); OutputHint = @('C:\ProgramData\FirewallCore\Diagnostics\BUNDLE_*.zip','C:\ProgramData\FirewallCore\Diagnostics\BUNDLE_*'); HandlerId = 'ExportBundle'; RowCheck = 'Last Diagnostics Bundle' }
  )

  foreach ($test in $tests) {
    if ($null -eq $test) { continue }
    $title = Get-OptionalValue -Obj $test -Key 'Title'
    if (-not $title) { continue }
    $scriptCandidates = Get-OptionalValue -Obj $test -Key 'Script' -Default @()
    if ($null -eq $scriptCandidates) { $scriptCandidates = @() }
    $outputHint = Get-OptionalValue -Obj $test -Key 'OutputHint'
    if ($null -ne $outputHint -and -not ($outputHint -is [string]) -and -not ($outputHint -is [System.Array])) {
      $outputHint = [string]$outputHint
    }

    $item = New-Object System.Windows.Controls.ComboBoxItem
    $item.Content = [string]$title
    $item.Tag = [pscustomobject]@{
      Action = [string]$title
      ScriptCandidates = @($scriptCandidates)
      OutputHint = $outputHint
      RequiresConfirm = $false
      HandlerId = (Get-OptionalValue -Obj $test -Key 'HandlerId')
      RowCheck = (Get-OptionalValue -Obj $test -Key 'RowCheck')
    }
    $testSelect.Items.Add($item) | Out-Null
  }
  if ($testSelect.Items.Count -gt 0) { $testSelect.SelectedIndex = 0 }

  $devPlaceholder = New-Object System.Windows.Controls.ComboBoxItem
  $devPlaceholder.Content = 'Select a Dev/Lab action...'
  $devPlaceholder.Tag = $null
  $devSelect.Items.Add($devPlaceholder) | Out-Null

  $devTests = @(
    @{ Title = 'DEV Test Suite'; Subtitle = 'Developer validation (requires Dev Mode).'; Script = @((Join-Path $devRoot 'Run-FirewallTests.ps1'),'C:\Firewall\Tools\Run-DevSuite.ps1'); RowCheck = 'Last Test Summary' },
    @{ Title = 'Forced Test Suite'; Subtitle = 'Aggressive validation (requires Dev Mode).'; Script = @((Join-Path $devRoot 'Run-Forced-Dev-Tests.ps1'),'C:\Firewall\Tools\Run-ForcedSuite.ps1'); RowCheck = 'Last Test Summary' },
    @{ Title = 'Attack Simulation (Local) / Defensive Validation (benign)'; Subtitle = 'Lab-only simulation (no exploitation/persistence). Validates detections, alerts, and logging.'; Script = @((Join-Path $toolsRoot 'Run-AttackSimSafe.ps1'),'C:\Firewall\Tools\Run-AttackSimSafe.ps1'); RowCheck = 'Last Test Summary' }
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
      HandlerId = (Get-OptionalValue -Obj $dev -Key 'HandlerId')
      RowCheck = (Get-OptionalValue -Obj $dev -Key 'RowCheck')
    }
    $devSelect.Items.Add($item) | Out-Null
  }
  if ($devSelect.Items.Count -gt 0) { $devSelect.SelectedIndex = 0 }

  $devFlagPath = Get-DevUnlockFlagPath
  $devUnlockHashPath = Get-DevUnlockHashPath
  $devUnlockExpiresAt = Read-DevUnlockExpiry -Path $devFlagPath
  $devModeEnabled = $false
  if ($devUnlockExpiresAt -and $devUnlockExpiresAt -gt (Get-Date)) {
    $devModeEnabled = $true
  } else {
    if (Test-Path -LiteralPath $devFlagPath) {
      try { Remove-Item -Path $devFlagPath -Force -ErrorAction SilentlyContinue } catch { }
    }
    $devUnlockExpiresAt = $null
  }
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
    DevUnlockStatus = $devUnlockStatus
    DevUnlockExpiresAt = $devUnlockExpiresAt
    DevUnlockMinutes = 10
    DevToggle = $devToggle
    Busy = $false
  }

  $devToggle.IsChecked = $devModeEnabled
  if ($devUnlockExpiresAt) { $devToggle.ToolTip = ("Dev Mode unlocked until " + $devUnlockExpiresAt.ToString('HH:mm:ss')) }
  Set-DevPanelVisibility -DevPanel $devPanel -DevHeader $devHeader -DevNote $devNote -DevSelect $devSelect -DevRunButton $btnRunDev -Visible:$devModeEnabled
  Set-DevUnlockStatusText -StatusControl $devUnlockStatus -ExpiresAt $devUnlockExpiresAt
  $script:DevUnlockState = $devToggle.Tag

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
    try {
      if (-not (Assert-NotBusy -Context 'Test Run' -StatusText $txtTestStatus)) { return }
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
      if ($meta.Action -eq 'Rules Report') {
        Invoke-RulesReportAction -ActionLabel $actionLabel -ScriptCandidates $meta.ScriptCandidates -ReportsFolder 'C:\ProgramData\FirewallCore\Reports' -RowCheck 'Firewall rules inventory' -StatusText $state.StatusText
        return
      }
      $handlerId = Get-OptionalValue -Obj $meta -Key 'HandlerId'
      $resolvedScript = Resolve-AdminPanelScriptPath -Candidates $meta.ScriptCandidates
      if (-not $resolvedScript) {
        $expectedScripts = @($meta.ScriptCandidates | Where-Object { $_ })
        switch ($handlerId) {
          'NotificationDemo' { Invoke-DemoAllSeveritiesAction -ActionLabel $actionLabel -StatusText $state.StatusText -RowCheck $meta.RowCheck -ToolMissing -ExpectedTools $expectedScripts | Out-Null; return }
          'QuickHealth' { Invoke-FallbackQuickHealthCheck -ActionLabel $actionLabel -StatusText $state.StatusText -RowCheck $meta.RowCheck -ToolMissing -ExpectedTools $expectedScripts | Out-Null; return }
          'BaselineDrift' { Invoke-FallbackBaselineDriftCheck -ActionLabel $actionLabel -StatusText $state.StatusText -RowCheck $meta.RowCheck -ToolMissing -ExpectedTools $expectedScripts | Out-Null; return }
          'InboundRisk' { Invoke-FallbackInboundRiskReport -ActionLabel $actionLabel -StatusText $state.StatusText -RowCheck $meta.RowCheck -ToolMissing -ExpectedTools $expectedScripts | Out-Null; return }
          'ExportBundle' { Invoke-FallbackExportDiagnosticsBundle -ActionLabel $actionLabel -StatusText $state.StatusText -RowCheck $meta.RowCheck -ToolMissing -ExpectedTools $expectedScripts | Out-Null; return }
        }
      }
      $hintText = Format-OutputHints -Hints $meta.OutputHint
      $logDetails = if ($hintText) { $meta.Action + " | OutputHint=" + $hintText } else { $meta.Action }
      $null = Invoke-AdminPanelProcessAction `
        -Action $actionLabel `
        -ScriptCandidates $meta.ScriptCandidates `
        -LogDetails $logDetails `
        -BusyKey 'AdminAction' `
        -StatusText $state.StatusText `
        -OutputHint $meta.OutputHint `
        -RowCheck $meta.RowCheck
    } catch {
      $err = $_.Exception.Message
      Write-ActionOutputLine -Text ("Test Run: FAIL (" + $err + ")") -Level 'FAIL'
      Write-AdminPanelActionLog -Action 'Test Run' -Script $null -Status 'Fail' -Details $err
      if ($meta -and $meta.RowCheck) {
        Set-ChecklistRowStatus -Check $meta.RowCheck -Status 'FAIL' -Details ("Failed: " + $err) -EvidencePath '(failed) see logs'
      }
      Set-TestStatusText ("Last run: FAIL | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | See AdminPanel-Actions.log")
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
        $expiresAt = (Get-Date).AddMinutes($state.DevUnlockMinutes)
        Write-DevUnlockExpiry -Path $state.DevFlagPath -ExpiresAt $expiresAt
        $state.DevUnlockExpiresAt = $expiresAt
        Write-AdminPanelActionLog -Action 'Dev Mode: Enable' -Script $state.DevFlagPath -Status 'Ok' -Details ("ExpiresAt=" + $expiresAt.ToString('HH:mm:ss'))
        Set-DevPanelVisibility -DevPanel $state.DevPanel -DevHeader $state.DevHeader -DevNote $state.DevNote -DevSelect $state.DevSelect -DevRunButton $state.DevRunButton -Visible:$true
        Set-DevUnlockStatusText -StatusControl $state.DevUnlockStatus -ExpiresAt $expiresAt
        if ($state.DevToggle) { $state.DevToggle.ToolTip = ("Dev Mode unlocked until " + $expiresAt.ToString('HH:mm:ss')) }
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
        $state.DevUnlockExpiresAt = $null
        Write-AdminPanelActionLog -Action 'Dev Mode: Disable' -Script $state.DevFlagPath -Status 'Ok'
        Set-DevPanelVisibility -DevPanel $state.DevPanel -DevHeader $state.DevHeader -DevNote $state.DevNote -DevSelect $state.DevSelect -DevRunButton $state.DevRunButton -Visible:$false
        Set-DevUnlockStatusText -StatusControl $state.DevUnlockStatus -ExpiresAt $null
        if ($state.DevToggle) { $state.DevToggle.ToolTip = $null }
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
    try {
      if (-not (Assert-NotBusy -Context 'Dev/Lab Run' -StatusText $txtDevStatus)) { return }
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
      $handlerId = Get-OptionalValue -Obj $meta -Key 'HandlerId'
      if ($handlerId -eq 'DemoAllSeverities') {
        Invoke-DemoAllSeveritiesAction -ActionLabel $actionLabel -StatusText $state.StatusText -RowCheck $meta.RowCheck -ExpectedTools $meta.ScriptCandidates | Out-Null
        return
      }
      $null = Invoke-AdminPanelProcessAction `
        -Action $actionLabel `
        -ScriptCandidates $meta.ScriptCandidates `
        -LogDetails $meta.Action `
        -BusyKey 'AdminAction' `
        -StatusText $state.StatusText `
        -RowCheck $meta.RowCheck
    } catch {
      $err = $_.Exception.Message
      Write-ActionOutputLine -Text ("Dev/Lab Run: FAIL (" + $err + ")") -Level 'FAIL'
      Write-AdminPanelActionLog -Action 'Dev/Lab Run' -Script $null -Status 'Fail' -Details $err
      if ($meta -and $meta.RowCheck) {
        Set-ChecklistRowStatus -Check $meta.RowCheck -Status 'FAIL' -Details ("Failed: " + $err) -EvidencePath '(failed) see logs'
      }
      Set-DevStatusText ("Last run: FAIL | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | See AdminPanel-Actions.log")
    }
  })
}

# Initial render
Write-AdminPanelStartupLog
if ($grid) { Initialize-InventoryGrid -Grid $grid }
Apply-Checklist -Reason 'Startup'
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

<#
Changes Made / Implementations Done
- Files changed: Firewall\User\FirewallAdminPanel.ps1
- Crash fixes: removed stray script-level param, runspace-safe output streaming, action/test handlers hardened with try/catch
- Action/test runner: centralized process execution, tool-missing WARN handling, system action status row updates
- Refresh cascade: non-blocking row-by-row render with deterministic completion status
- Evidence/path persistence: report rows for health/drift/risk/diagnostics, evidence overrides retained across refresh
- Dev mode gating + expiry: time-limited unlock persisted with auto-relock; demo action updates user alert evidence
#>











