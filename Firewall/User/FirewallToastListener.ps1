# FirewallToastListener.ps1 - drain Pending and route UX (Toast/Dialog/Both)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try { Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop | Out-Null } catch {}

$CoreRoot  = Join-Path $env:ProgramData "FirewallCore"
$QueueRoot = Join-Path $CoreRoot "NotifyQueue"
$StateDir  = Join-Path $CoreRoot "State"
$LogDir    = Join-Path $CoreRoot "Logs"

$Pending    = Join-Path $QueueRoot "Pending"
$Processing = Join-Path $QueueRoot "Processing"
$Processed  = Join-Path $QueueRoot "Processed"
$Failed     = Join-Path $QueueRoot "Failed"
$Reviewed   = Join-Path $QueueRoot "Reviewed"
$Working    = Join-Path $QueueRoot "Working"

$Heartbeat  = Join-Path $StateDir "toastlistener.heartbeat"
$ListenerLog= Join-Path $LogDir "ToastListener.log"

$null = New-Item -ItemType Directory -Path $StateDir,$LogDir,$Pending,$Processing,$Processed,$Failed,$Reviewed,$Working -Force

function Log([string]$msg) {
  $ts = (Get-Date).ToUniversalTime().ToString("o")
  "$ts $msg" | Add-Content -LiteralPath $ListenerLog -Encoding UTF8
}
function TouchHB {
  try { Set-Content -LiteralPath $Heartbeat -Value ((Get-Date).ToUniversalTime().ToString("o")) -Encoding ASCII -Force } catch {}
}

function Get-Sound([string]$sev) {
  $live = "C:\Firewall\Monitor\Sounds"
  switch ($sev) {
    "Info"     { Join-Path $live "ding.wav" }
    "Warning"  { Join-Path $live "chimes.wav" }
    "Critical" { Join-Path $live "chord.wav" }
    default    { $null }
  }
}
function PlaySound([string]$path) {
  if (!$path -or !(Test-Path $path)) { return }
  try {
    $sp = New-Object System.Media.SoundPlayer $path
    $sp.Play()
  } catch {}
}

function ShowToastBestEffort($P, [string]$QueueFolder, [string]$QueueFile) {
  try {
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType=WindowsRuntime]::new()
    $Mgr  = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime]

    $t = [Security.SecurityElement]::Escape([string]$P.Title)
    $m = [Security.SecurityElement]::Escape([string]$P.Message)
    $s = [Security.SecurityElement]::Escape(("EventId={0} TestId={1} Mode={2}" -f $P.EventId, $P.TestId, $P.Mode))

    $sinceUtc = ([datetime]::Parse([string]$P.CreatedUtc).ToUniversalTime().AddMinutes(-10)).ToString("o")

    $argLog    = "firewallcore-review://open?action=log&EventId=$($P.EventId)&TestId=$([uri]::EscapeDataString([string]$P.TestId))&SinceUtc=$([uri]::EscapeDataString($sinceUtc))"
    $argDialog = "firewallcore-review://open?action=dialog&Folder=$([uri]::EscapeDataString($QueueFolder))&File=$([uri]::EscapeDataString($QueueFile))"

    $launch = $argDialog

$xml = @"
<toast activationType='protocol' launch='$launch'>
  <visual>
    <binding template='ToastGeneric'>
      <text>$t</text>
      <text>$m</text>
      <text>$s</text>
    </binding>
  </visual>
  <actions>
    <action content='Review Log' activationType='protocol' arguments='$argLog' />
    <action content='Details'   activationType='protocol' arguments='$argDialog' />
  </actions>
  <audio silent='true'/>
</toast>
"@

    $doc = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType=WindowsRuntime]::new()
    $doc.LoadXml($xml)
    $toast = [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType=WindowsRuntime]::new($doc)

    
    # ForcePopupOnWarningCritical
    if ($P.Severity -ne 'Info') { $toast.SuppressPopup = $false }
# Info: no popup, expires in 15s
    if ($P.Severity -eq "Info") {
      $toast.SuppressPopup = $true
      $toast.ExpirationTime = [DateTimeOffset]::Now.AddSeconds(15)
    }

    $notifier = $Mgr::CreateToastNotifier("WindowsPowerShell")
    $notifier.Show($toast)
  } catch {
    Log "Toast error: $(# FirewallToastListener.ps1 - drain Pending and route UX (Toast/Dialog/Both)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try { Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop | Out-Null } catch {}

$CoreRoot  = Join-Path $env:ProgramData "FirewallCore"
$QueueRoot = Join-Path $CoreRoot "NotifyQueue"
$StateDir  = Join-Path $CoreRoot "State"
$LogDir    = Join-Path $CoreRoot "Logs"

$Pending    = Join-Path $QueueRoot "Pending"
$Processing = Join-Path $QueueRoot "Processing"
$Processed  = Join-Path $QueueRoot "Processed"
$Failed     = Join-Path $QueueRoot "Failed"
$Reviewed   = Join-Path $QueueRoot "Reviewed"
$Working    = Join-Path $QueueRoot "Working"

$Heartbeat  = Join-Path $StateDir "toastlistener.heartbeat"
$ListenerLog= Join-Path $LogDir "ToastListener.log"

$null = New-Item -ItemType Directory -Path $StateDir,$LogDir,$Pending,$Processing,$Processed,$Failed,$Reviewed,$Working -Force

function Log([string]$msg) {
  $ts = (Get-Date).ToUniversalTime().ToString("o")
  "$ts $msg" | Add-Content -LiteralPath $ListenerLog -Encoding UTF8
}
function TouchHB {
  try { Set-Content -LiteralPath $Heartbeat -Value ((Get-Date).ToUniversalTime().ToString("o")) -Encoding ASCII -Force } catch {}
}

function Get-Sound([string]$sev) {
  $live = "C:\Firewall\Monitor\Sounds"
  switch ($sev) {
    "Info"     { Join-Path $live "ding.wav" }
    "Warning"  { Join-Path $live "chimes.wav" }
    "Critical" { Join-Path $live "chord.wav" }
    default    { $null }
  }
}
function PlaySound([string]$path) {
  if (!$path -or !(Test-Path $path)) { return }
  try {
    $sp = New-Object System.Media.SoundPlayer $path
    $sp.Play()
  } catch {}
}

function ShowToastBestEffort($P) {
  if ($P.Severity -eq "Info") { return } # contract: no popup toast
  try {
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType=WindowsRuntime]::new()
    $Mgr  = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime]

    $t = [Security.SecurityElement]::Escape([string]$P.Title)
    $m = [Security.SecurityElement]::Escape([string]$P.Message)
    $s = [Security.SecurityElement]::Escape(("EventId={0} TestId={1} Mode={2}" -f $P.EventId, $P.TestId, $P.Mode))

$xml = @"
<toast>
  <visual>
    <binding template='ToastGeneric'>
      <text>$t</text>
      <text>$m</text>
      <text>$s</text>
    </binding>
  </visual>
</toast>
"@

    $doc = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType=WindowsRuntime]::new()
    $doc.LoadXml($xml)
    $toast = [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType=WindowsRuntime]::new($doc)

    
    # ForcePopupOnWarningCritical
    if ($P.Severity -ne 'Info') { $toast.SuppressPopup = $false }
$notifier = $Mgr::CreateToastNotifier("WindowsPowerShell")
    $notifier.Show($toast)
  } catch {
    Log "Toast error: $($_.Exception.Message)"
  }
}

function LaunchDialog([string]$pathToJson) {
  try {
    Start-Process powershell.exe -ArgumentList @(
      "-NoLogo","-NoProfile","-STA","-ExecutionPolicy","Bypass",
      "-File","C:\Firewall\User\FirewallReviewDialog.ps1",
      "-PayloadPath", "`"$pathToJson`""
    )
  } catch {
    Log "Dialog launch error: $($_.Exception.Message)"
  }
}

function DrainOnce {
  $files = Get-ChildItem -LiteralPath $Pending -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime
  foreach ($f in $files) {
    $QueueFolder = $null
    $QueueFile   = $null
    $proc = Join-Path $Processing $f.Name
    try {
      Move-Item -LiteralPath $f.FullName -Destination $proc -Force
      $raw = Get-Content -LiteralPath $proc -Raw -Encoding UTF8
      $P = $raw | ConvertFrom-Json

      $sev = [string]$P.Severity

      # Determine UX
      $ux = "Toast"
      if ($P.PSObject.Properties.Name -contains "Ux" -and -not [string]::IsNullOrWhiteSpace([string]$P.Ux)) {
        $ux = [string]$P.Ux
      } elseif ($sev -eq "Critical") {
        $ux = "Both"
      }

      # Sound always per contract
      PlaySound (Get-Sound $sev)

      # Toast
      if ($ux -eq "Toast" -or $ux -eq "Both") {
        $QueueFile = $f.Name
        if (-not $QueueFolder) { $QueueFolder = 'Processed' }
        ShowToastBestEffort $P $QueueFolder $QueueFile
      }

      # Dialog routing
      if (($ux -eq "Dialog" -or $ux -eq "Both") -and ($sev -eq "Warning" -or $sev -eq "Critical")) {
        # For Critical: keep item in Working until ACK (dialog moves to Acknowledged)
        if ($sev -eq "Critical") {
          $workPath = Join-Path $Working $f.Name
          Move-Item -LiteralPath $proc -Destination $workPath -Force
          LaunchDialog $workPath
      $QueueFile = $f.Name
      $QueueFolder = 'Working'
      Log "Working(Critical): $($f.Name) EventId=$($P.EventId) TestId=$($P.TestId)"
          continue
        }

        # For Warning dialog: move to Reviewed (dialog is informational + review button)
        $revPath = Join-Path $Reviewed $f.Name
        Move-Item -LiteralPath $proc -Destination $revPath -Force
        LaunchDialog $revPath
      $QueueFile = $f.Name
      $QueueFolder = 'Reviewed'
      Log "Reviewed(Warning): $($f.Name) EventId=$($P.EventId) TestId=$($P.TestId)"
        continue
      }

      # Default: processed
      Move-Item -LiteralPath $proc -Destination (Join-Path $Processed $f.Name) -Force
      Log "Processed: $($f.Name) Severity=$sev EventId=$($P.EventId) TestId=$($P.TestId)"
    }
    catch {
      $err = $_.Exception.Message
      Log "FAILED: $($f.Name) $err"
      try {
        if (Test-Path $proc) {
          $fail = Join-Path $Failed $f.Name
          Move-Item -LiteralPath $proc -Destination $fail -Force
          @{ File=$f.Name; Error=$err; WhenUtc=(Get-Date).ToUniversalTime().ToString("o") } |
            ConvertTo-Json -Compress |
            Set-Content -LiteralPath ($fail + ".error.json") -Encoding UTF8 -Force
        }
      } catch {}
    }
  }
}

Log "Listener start. QueueRoot=$QueueRoot User=$env:USERNAME"
while ($true) {
  TouchHB
  DrainOnce
  Start-Sleep -Milliseconds 300
}
.Exception.Message)"
  }
}

function LaunchDialog([string]$pathToJson) {
  try {
    Start-Process powershell.exe -ArgumentList @(
      "-NoLogo","-NoProfile","-STA","-ExecutionPolicy","Bypass",
      "-File","C:\Firewall\User\FirewallReviewDialog.ps1",
      "-PayloadPath", "`"$pathToJson`""
    )
  } catch {
    Log "Dialog launch error: $($_.Exception.Message)"
  }
}

function DrainOnce {
  $files = Get-ChildItem -LiteralPath $Pending -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime
  foreach ($f in $files) {
    $proc = Join-Path $Processing $f.Name
    try {
      Move-Item -LiteralPath $f.FullName -Destination $proc -Force
      $raw = Get-Content -LiteralPath $proc -Raw -Encoding UTF8
      $P = $raw | ConvertFrom-Json

      $sev = [string]$P.Severity

      # Determine UX
      $ux = "Toast"
      if ($P.PSObject.Properties.Name -contains "Ux" -and -not [string]::IsNullOrWhiteSpace([string]$P.Ux)) {
        $ux = [string]$P.Ux
      } elseif ($sev -eq "Critical") {
        $ux = "Both"
      }

      # Sound always per contract
      PlaySound (Get-Sound $sev)

      # Toast
      if ($ux -eq "Toast" -or $ux -eq "Both") {
        $QueueFile = $f.Name
        if (-not $QueueFolder) { $QueueFolder = 'Processed' }
        ShowToastBestEffort $P $QueueFolder $QueueFile
      }

      # Dialog routing
      if (($ux -eq "Dialog" -or $ux -eq "Both") -and ($sev -eq "Warning" -or $sev -eq "Critical")) {
        # For Critical: keep item in Working until ACK (dialog moves to Acknowledged)
        if ($sev -eq "Critical") {
          $workPath = Join-Path $Working $f.Name
          Move-Item -LiteralPath $proc -Destination $workPath -Force
          LaunchDialog $workPath
      $QueueFile = $f.Name
      $QueueFolder = 'Working'
      Log "Working(Critical): $($f.Name) EventId=$($P.EventId) TestId=$($P.TestId)"
          continue
        }

        # For Warning dialog: move to Reviewed (dialog is informational + review button)
        $revPath = Join-Path $Reviewed $f.Name
        Move-Item -LiteralPath $proc -Destination $revPath -Force
        LaunchDialog $revPath
      $QueueFile = $f.Name
      $QueueFolder = 'Reviewed'
      Log "Reviewed(Warning): $($f.Name) EventId=$($P.EventId) TestId=$($P.TestId)"
        continue
      }

      # Default: processed
      Move-Item -LiteralPath $proc -Destination (Join-Path $Processed $f.Name) -Force
      Log "Processed: $($f.Name) Severity=$sev EventId=$($P.EventId) TestId=$($P.TestId)"
    }
    catch {
      $err = $_.Exception.Message
      Log "FAILED: $($f.Name) $err"
      try {
        if (Test-Path $proc) {
          $fail = Join-Path $Failed $f.Name
          Move-Item -LiteralPath $proc -Destination $fail -Force
          @{ File=$f.Name; Error=$err; WhenUtc=(Get-Date).ToUniversalTime().ToString("o") } |
            ConvertTo-Json -Compress |
            Set-Content -LiteralPath ($fail + ".error.json") -Encoding UTF8 -Force
        }
      } catch {}
    }
  }
}

Log "Listener start. QueueRoot=$QueueRoot User=$env:USERNAME"
while ($true) {
  TouchHB
  DrainOnce
  Start-Sleep -Milliseconds 300
}






