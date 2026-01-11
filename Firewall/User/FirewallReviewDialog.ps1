param(
  [Parameter(Mandatory)][string]$PayloadPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try { Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase -ErrorAction Stop | Out-Null } catch {}

$payloadRaw = Get-Content -LiteralPath $PayloadPath -Raw -Encoding UTF8
$P = $payloadRaw | ConvertFrom-Json

# Helpers
function Get-SoundPath([string]$severity) {
  $live = "C:\Firewall\Monitor\Sounds"
  switch ($severity) {
    "Info"     { Join-Path $live "ding.wav" }
    "Warning"  { Join-Path $live "chimes.wav" }
    "Critical" { Join-Path $live "chord.wav" }
    default    { $null }
  }
}
function Play-Sound([string]$path) {
  if (!$path -or !(Test-Path $path)) { return }
  try {
    $sp = New-Object System.Media.SoundPlayer $path
    $sp.Play()
  } catch {}
}

$sev = [string]$P.Severity
$title = [string]$P.Title
$msg   = [string]$P.Message

$meta = @(
  "Severity: $($P.Severity)"
  "EventId:  $($P.EventId)"
  "TestId:   $($P.TestId)"
  "Mode:     $($P.Mode)"
  "Provider: $($P.Provider)"
  "Host:     $($P.Host)"
  "User:     $($P.User)"
  "Created:  $($P.CreatedUtc)"
) -join "`r`n"

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="FirewallCore Review" Height="320" Width="560"
        WindowStartupLocation="CenterScreen"
        Topmost="True">
  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <TextBlock Grid.Row="0" FontSize="18" FontWeight="Bold" TextWrapping="Wrap" Name="Hdr"/>
    <TextBlock Grid.Row="1" Margin="0,8,0,0" FontSize="13" TextWrapping="Wrap" Name="Body"/>
    <TextBox Grid.Row="2" Margin="0,10,0,0" IsReadOnly="True" TextWrapping="Wrap"
             VerticalScrollBarVisibility="Auto" Name="Meta"/>

    <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
      <Button Name="BtnReview" Margin="0,0,8,0" Padding="12,6">Review Log</Button>
      <Button Name="BtnEV" Margin="0,0,8,0" Padding="12,6">Open Event Viewer</Button>
      <Button Name="BtnAck" Padding="12,6">Acknowledge</Button>
    </StackPanel>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$win = [Windows.Markup.XamlReader]::Load($reader)

$win.FindName("Hdr").Text  = $title
$win.FindName("Body").Text = $msg
$win.FindName("Meta").Text = $meta

$btnReview = $win.FindName("BtnReview")
$btnEV     = $win.FindName("BtnEV")
$btnAck    = $win.FindName("BtnAck")

# Warning vs Critical rules
if ($sev -eq "Warning") {
  $btnAck.Content = "Close"
  # Auto-close 30s
  $t = New-Object Windows.Threading.DispatcherTimer
  $t.Interval = [TimeSpan]::FromSeconds(20)
  $t.Add_Tick({
    $t.Stop()
    $win.Close()
  })
  $t.Start()
}
elseif ($sev -eq "Critical") {
  # Disable close/X and force manual ACK
  $win.WindowStyle = "None"
  $win.ResizeMode  = "NoResize"
  $win.Add_Closing({
    if (-not $script:acked) { $_.Cancel = $true }
  })

  $btnAck.Content = "Acknowledge (Manual Review)"
  $script:acked = $false

  # Remind every 10s until ack
  $rem = New-Object Windows.Threading.DispatcherTimer
  $rem.Interval = [TimeSpan]::FromSeconds(10)
  $rem.Add_Tick({
    if (-not $script:acked) {
      Play-Sound (Get-SoundPath "Critical")
      $win.Topmost = $true
      $win.Activate() | Out-Null
    } else {
      $rem.Stop()
    }
  })
  $rem.Start()
} else {
  # Info shouldn't be here normally
  $btnAck.Content = "Close"
}

$btnReview.Add_Click({
  $since = [datetime]::Parse([string]$P.CreatedUtc).ToUniversalTime().AddMinutes(-10)
  $args = @(
    "-NoLogo","-NoProfile","-ExecutionPolicy","Bypass",
    "-File","C:\Firewall\User\FirewallEventReview.ps1",
    "-EventId",$P.EventId,
    "-TestId",$P.TestId,
    "-SinceUtc",$since.ToString("o")
  )
  Start-Process powershell.exe -ArgumentList $args
})

$btnEV.Add_Click({
  Start-Process "eventvwr.msc"
})

$btnAck.Add_Click({
  if ($sev -eq "Critical") {
    $script:acked = $true

    # Move file to Acknowledged (best effort)
    try {
      $base = Join-Path $env:ProgramData "FirewallCore\NotifyQueue"
      $ack  = Join-Path $base "Acknowledged"
      New-Item -ItemType Directory -Path $ack -Force | Out-Null
      Move-Item -LiteralPath $PayloadPath -Destination (Join-Path $ack ([IO.Path]::GetFileName($PayloadPath))) -Force
    } catch {}

    $win.Close()
  } else {
    $win.Close()
  }
})

# Initial sound was already played by listener; keep dialog silent on open
$win.ShowDialog() | Out-Null

