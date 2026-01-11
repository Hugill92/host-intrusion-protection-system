param([switch]$Once)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==========================
# FirewallCore Invoke Notifier
# Queue consumer (Pending -> Processed / Failed)
# UI:
#   Info    = bottom-right, non-blocking, auto-close 15s, ding.wav
#   Warning = center,      non-blocking, auto-close 30s, chimes.wav
#   Critical= center,      BLOCKING, no X/Close, repeats chord.wav every 10s until acknowledged
# All dialogs: click "Review logs" opens Event Viewer FILTERED view and closes (except Critical needs Acknowledge).
# NO tray balloons / NotifyIcon.
# ==========================

# region Paths
$script:CoreRoot   = Join-Path $env:ProgramData "FirewallCore"
$script:QueueRoot  = Join-Path $script:CoreRoot "NotifyQueue"
$script:PendingDir = Join-Path $script:QueueRoot "Pending"
$script:ProcDir    = Join-Path $script:QueueRoot "Processed"
$script:FailDir    = Join-Path $script:QueueRoot "Failed"
$script:ViewsRoot  = Join-Path $script:CoreRoot "EventViews"

# Prefer live config (self-contained install), then repo fallback
$script:MapCandidates = @(
  "C:\Firewall\Config\EventViewMap.json",
  "C:\FirewallInstaller\Firewall\Config\EventViewMap.json",
  (Join-Path $script:ViewsRoot "EventViewMap.json")
)

$script:SoundsDirCandidates = @(
  "C:\Firewall\Monitor\Sounds",
  "C:\Firewall\Monitor",
  "C:\Windows\Media"
)
# endregion

function Ensure-Dirs {
  foreach ($p in @($script:CoreRoot,$script:QueueRoot,$script:PendingDir,$script:ProcDir,$script:FailDir,$script:ViewsRoot)) {
    if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
  }
}

function Get-FirstExistingPath {
  param([Parameter(Mandatory)][string[]]$Paths)
  foreach ($p in $Paths) { if ($p -and (Test-Path -LiteralPath $p)) { return $p } }
  return $null
}

function Get-SoundPath {
  param([Parameter(Mandatory)][string]$FileName)
  foreach ($dir in $script:SoundsDirCandidates) {
    $p = Join-Path $dir $FileName
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return $null
}

function Start-SoundForSeconds {
  param(
    [Parameter(Mandatory)][string]$FileName,
    [Parameter(Mandatory)][int]$Seconds
  )

  if ($Seconds -le 0) { return }

  $p = Get-SoundPath -FileName $FileName
  if (-not $p) { return }

  try {
    $player = New-Object System.Media.SoundPlayer $p
    $player.PlayLooping()

    $stopTimer = New-Object System.Windows.Forms.Timer
    $stopTimer.Interval = [Math]::Max(250, $Seconds * 1000)
    $stopTimer.Add_Tick({
      try {
        $stopTimer.Stop(); $stopTimer.Dispose()
        $player.Stop()
      } catch {}
    })
    $stopTimer.Start()
  } catch {}
}

function Play-Sound {
  param([Parameter(Mandatory)][string]$FileName)
  # Back-compat: one-shot play
  $p = Get-SoundPath -FileName $FileName
  if (-not $p) { return }
  try { (New-Object System.Media.SoundPlayer $p).Play() } catch {}
}

function Load-EventViewMap {
  $mapPath = Get-FirstExistingPath -Paths $script:MapCandidates
  if (-not $mapPath) { return @{} }

  try {
    $raw = Get-Content -LiteralPath $mapPath -Raw -ErrorAction Stop
    if (-not $raw) { return @{} }
    $obj = $raw | ConvertFrom-Json -ErrorAction Stop

    $ht = @{}
    foreach ($p in $obj.PSObject.Properties) {
      $ht[$p.Name] = $p.Value
    }
    return $ht
  } catch {
    return @{}
  }
}

function New-ViewFile {
  param(
    [Parameter(Mandatory)][int]$EventId,
    [Parameter(Mandatory)][string]$ViewName
  )
  Ensure-Dirs
  $safe = ($ViewName -replace '[^a-zA-Z0-9_\-\.]', '_')
  $viewPath = Join-Path $script:ViewsRoot ("{0}.xml" -f $safe)

@"
<QueryList>
  <Query Id="0" Path="FirewallCore">
    <Select Path="FirewallCore">*[System[EventID=$EventId]]</Select>
  </Query>
</QueryList>
"@ | Set-Content -LiteralPath $viewPath -Encoding UTF8 -Force

  return $viewPath
}

function Open-EventViewerFiltered {
  param([Parameter(Mandatory)][int]$EventId)

  $map = Load-EventViewMap
  $key = [string]$EventId

  $viewName = $null
  if ($map.ContainsKey($key) -and $map[$key] -and $map[$key].View) {
    $viewName = [string]$map[$key].View
  } else {
    $viewName = "FirewallCore-$EventId"
  }

  $viewPath = New-ViewFile -EventId $EventId -ViewName $viewName

  try {
    Start-Process "eventvwr.msc" -ArgumentList "/v:`"$viewPath`"" | Out-Null
  } catch {
    Start-Process "eventvwr.msc" | Out-Null
  }
}

function New-DialogForm {
  param(
    [Parameter(Mandatory)][ValidateSet('Info','Warning','Critical')][string]$Severity,
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Message,
    [Parameter(Mandatory)][int]$EventId
  )

  $form = New-Object System.Windows.Forms.Form
  $form.StartPosition   = 'Manual'
  $form.TopMost         = $true
  $form.ShowInTaskbar   = $false
  $form.BackColor       = [System.Drawing.Color]::FromArgb(32,32,32)
  $form.ForeColor       = [System.Drawing.Color]::White
  $form.Font            = New-Object System.Drawing.Font("Segoe UI", 9)
  $form.FormBorderStyle = 'FixedSingle'
  $form.MinimizeBox     = $false
  $form.MaximizeBox     = $false

  if ($Severity -eq 'Critical') {
    $form.ControlBox = $false   # no X
  } else {
    $form.ControlBox = $true
  }

  # Layout: Title label, message textbox, button row (buttons always visible)
  $layout = New-Object System.Windows.Forms.TableLayoutPanel
  $layout.Dock = 'Fill'
  $layout.BackColor = $form.BackColor
  $layout.Padding = New-Object System.Windows.Forms.Padding(14,12,14,12)
  $layout.RowCount = 3
  $layout.ColumnCount = 1
  $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
  $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
  $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
  $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))

  $lblTitle = New-Object System.Windows.Forms.Label
  $lblTitle.AutoSize = $true
  $lblTitle.Text = $Title
  $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
  $lblTitle.ForeColor = [System.Drawing.Color]::White
  $lblTitle.Margin = New-Object System.Windows.Forms.Padding(0,0,0,8)

  $txt = New-Object System.Windows.Forms.TextBox
  $txt.Multiline   = $true
  $txt.ReadOnly    = $true
  $txt.BorderStyle = 'None'
  $txt.BackColor   = $form.BackColor
  $txt.ForeColor   = [System.Drawing.Color]::Gainsboro
  $txt.ScrollBars  = 'Vertical'
  $txt.Text        = $Message
  $txt.Dock        = 'Fill'

  $btnRow = New-Object System.Windows.Forms.FlowLayoutPanel
  $btnRow.Dock = 'Fill'
  $btnRow.FlowDirection = 'RightToLeft'
  $btnRow.WrapContents  = $false
  $btnRow.AutoSize      = $true
  $btnRow.Margin        = New-Object System.Windows.Forms.Padding(0,10,0,0)
  $btnRow.Padding       = New-Object System.Windows.Forms.Padding(0)

  $btnReview = New-Object System.Windows.Forms.Button
  $btnReview.Text = "Review logs"
  $btnReview.AutoSize = $true
  $btnReview.Margin = New-Object System.Windows.Forms.Padding(8,0,0,0)

  $btnClose = $null
  $btnAck   = $null

  if ($Severity -eq 'Critical') {
    $btnAck = New-Object System.Windows.Forms.Button
    $btnAck.Text = "I acknowledge"
    $btnAck.AutoSize = $true
    $btnAck.Margin = New-Object System.Windows.Forms.Padding(8,0,0,0)
    $btnRow.Controls.Add($btnAck)
    $btnRow.Controls.Add($btnReview)
  } else {
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Close"
    $btnClose.AutoSize = $true
    $btnClose.Margin = New-Object System.Windows.Forms.Padding(8,0,0,0)
    $btnRow.Controls.Add($btnClose)
    $btnRow.Controls.Add($btnReview)
  }

  $layout.Controls.Add($lblTitle, 0, 0)
  $layout.Controls.Add($txt, 0, 1)
  $layout.Controls.Add($btnRow, 0, 2)
  $form.Controls.Add($layout)

  # Size + position
  $work = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
  $width  = 560
  $height = switch ($Severity) {
    'Info'     { 220 }
    'Warning'  { 260 }
    'Critical' { 300 }
  }
  $form.Size = New-Object System.Drawing.Size($width, $height)

  if ($Severity -eq 'Info') {
    $form.Location = New-Object System.Drawing.Point($work.Right - $form.Width - 12, $work.Bottom - $form.Height - 12)
  } else {
    $form.Location = New-Object System.Drawing.Point([int]($work.Left + (($work.Width - $form.Width) / 2)), [int]($work.Top + (($work.Height - $form.Height) / 2)))
  }

  return [pscustomobject]@{
    Form      = $form
    Title     = $lblTitle
    TextBox   = $txt
    BtnReview = $btnReview
    BtnClose  = $btnClose
    BtnAck    = $btnAck
    EventId   = $EventId
    Severity  = $Severity
  }
}

function Show-NotificationDialog {
  param(
    [Parameter(Mandatory)][ValidateSet('Info','Warning','Critical')][string]$Severity,
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Message,
    [Parameter(Mandatory)][int]$EventId
  )

  $ctx  = New-DialogForm -Severity $Severity -Title $Title -Message $Message -EventId $EventId
  $form = $ctx.Form

  $autoCloseSeconds = $null
  switch ($Severity) {
    'Info'    { Start-SoundForSeconds -FileName 'ding.wav'   -Seconds 15 ; $autoCloseSeconds = 15 }
    'Warning' { Start-SoundForSeconds -FileName 'chimes.wav' -Seconds 30 ; $autoCloseSeconds = 30 }
    'Critical'{ Start-SoundForSeconds -FileName 'chord.wav'  -Seconds 10 ; $autoCloseSeconds = $null }
  }

  $deadline = $null
  if ($autoCloseSeconds) { $deadline = (Get-Date).AddSeconds($autoCloseSeconds) }

  $timer = $null
  if ($deadline) {
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 250
    $timer.Add_Tick({
      try {
        if ($form.IsDisposed) { $timer.Stop(); $timer.Dispose(); return }
        if ((Get-Date) -ge $deadline) {
          $timer.Stop()
          $form.Close()
          $timer.Dispose()
        }
      } catch { }
    })
  }

  $rem = $null
  if ($Severity -eq 'Critical') {
    $rem = New-Object System.Windows.Forms.Timer
    $rem.Interval = 10000
    $rem.Add_Tick({ try { Start-SoundForSeconds -FileName 'chord.wav' -Seconds 10 } catch {} })
    $rem.Start()
  }

  $openEvAndClose = {
    try { Open-EventViewerFiltered -EventId $EventId } catch {}
    if ($Severity -ne 'Critical') {
      try { $form.Close() } catch {}
    }
  }

  $ctx.Title.Add_Click($openEvAndClose)
  $ctx.TextBox.Add_Click($openEvAndClose)
  $ctx.BtnReview.Add_Click($openEvAndClose)

  if ($ctx.BtnClose) { $ctx.BtnClose.Add_Click({ try { $form.Close() } catch {} }) }

  if ($ctx.BtnAck) {
    $ctx.BtnAck.Add_Click({
      try { Open-EventViewerFiltered -EventId $EventId } catch {}
      try { if ($rem) { $rem.Stop(); $rem.Dispose() } } catch {}
      try { $form.Close() } catch {}
    })
  }

  $form.Add_FormClosed({
    try { if ($timer) { $timer.Stop(); $timer.Dispose() } } catch {}
    try { if ($rem)   { $rem.Stop();   $rem.Dispose()   } } catch {}
  })

  if ($timer) { $timer.Start() }

  if ($Severity -eq 'Critical') { [void]$form.ShowDialog() } else { [void]$form.Show() }
}

function Process-QueueOnce {
  Ensure-Dirs

  $files = Get-ChildItem -LiteralPath $script:PendingDir -Filter *.json -ErrorAction SilentlyContinue
  foreach ($f in $files) {
    $procPath = Join-Path $script:ProcDir $f.Name
    $failPath = Join-Path $script:FailDir $f.Name

    try {
      $n = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json

      if (-not $n.Severity -or -not $n.Title -or -not $n.Message -or -not $n.EventId) {
        throw "Invalid payload shape"
      }

      Move-Item -LiteralPath $f.FullName -Destination $procPath -Force

      $sev = [string]$n.Severity
      if ($sev -notin @('Info','Warning','Critical')) { $sev = 'Info' }

      Show-NotificationDialog -Severity $sev -Title ([string]$n.Title) -Message ([string]$n.Message) -EventId ([int]$n.EventId)
    } catch {
      try { Move-Item -LiteralPath $f.FullName -Destination $failPath -Force } catch {}
    }
  }
}
Process-QueueOnce
if ($Once) { return }

while ($true) {
  Start-Sleep -Milliseconds 300
  Process-QueueOnce
}


# SIG # Begin signature block
# MIIFtgYJKoZIhvcNAQcCoIIFpzCCBaMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCoADJfjWu3sclt
# zzBOwPgEYgbh24AHPK7i8S/9r3pveaCCAyAwggMcMIICBKADAgECAhAWqBrNbp/s
# q0LWLpUoGJqsMA0GCSqGSIb3DQEBCwUAMCYxJDAiBgNVBAMMG0ZpcmV3YWxsQ29y
# ZSBTY3JpcHQgU2lnbmluZzAeFw0yNjAxMTExMDMzMDBaFw0zNjAxMTExMDQzMDBa
# MCYxJDAiBgNVBAMMG0ZpcmV3YWxsQ29yZSBTY3JpcHQgU2lnbmluZzCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBALanpHAxqchTmDsDelBMMGqhuD/qBCS6
# WBhFkFyipQH1RYozRTLMorh/XyL90qtuHSWc53r1JEwy07Fyeq4VVvpSQpf/kDDx
# fuSpEDKkux9Oqbm0E0fUbCg33kXEPliunM8qnrtz0QKsudVLCSdRc1lzgBNI7vYS
# LoybGQYGSlRKiITXafzKHM3TGp7kxhuc+Fcz1IxTnAd3NRKrUHGfm0p3rflpPL4c
# 8STqXkZCATWtgfkaoCJ6VKbfTn6Plsv54t0rqBmRFfKd5DkmsNrVCdCQk408iBF5
# B9gMtNU+U7Kp9e527JxWcMT5vZaKZ0GhNhYopLJLS+E5CDAtjWH+EgECAwEAAaNG
# MEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQW
# BBRo4Db7+Vk/nbKtkGTT9k1im36MhjANBgkqhkiG9w0BAQsFAAOCAQEADoGX2VSj
# mrwdYR7ShaEsj/rtxOBqFDGK1uKMxJAcnjqsD45jhE+fEqMNlvx+Nw7pjxxvLyQd
# zL9JY/hrLgQxdeGCCJyuXxoaOqdDv5UNs9J1UiHd9YitD6Y++GiMCIPNu3JJoUL4
# OmXTs8stDk9jM2m2nbN3vyGOI7SifX+O9cBe6uK/UgiNRQ+D4mSi1A6PsGdPlDcU
# 2QYjt+xT6q6hqgVqgvqWmwrzqkEw1TlQ4d9rVQxmxRH8a2SofdULbbdw6CJJXn4F
# 0Z6fE8KPe1nELXplmRsulgrx1xJJ/mjs7EsVq6tEClQ5Mt0n5RoqxRhfJYGrpo0a
# cEKp1Uw2HG8aQTGCAewwggHoAgEBMDowJjEkMCIGA1UEAwwbRmlyZXdhbGxDb3Jl
# IFNjcmlwdCBTaWduaW5nAhAWqBrNbp/sq0LWLpUoGJqsMA0GCWCGSAFlAwQCAQUA
# oIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcN
# AQkEMSIEIPfFF0fPeFLoAmdlBTUEBDu2GXBpnnr4Sl2O5kZ0R0FcMA0GCSqGSIb3
# DQEBAQUABIIBAC0NiIth1fLqGq7qCQ1Bb5q0FeCD8KCejOeY2Z1ajp5knlpxLTWS
# C1S3hkZ5vY4vZloI+Q3FVgODEAvU4+77cS+coFWKgIHVHr3SSrGUmrIS4a3DoM2+
# +TC8ij+c6PcDPZHu5ieK6RCUh2rltPF1GwdRQIVCnImdy5z46/JIBnwaYC8w/Ocz
# VQ5JZ7wR9Dpm2HRXd0RO0775yywhB3U982mUR6DF5+cSuyoFbpYHFNDm/BpSR3lC
# i6JTlt0wX9uTUwYBLjZzJikntO7H6sgzl3ol4qYgbdM0rnK0bYVBh4dCynynCdZm
# Mb4fZTyhm2ZCIbJcE9gh3I4TXIM05Xs7NTE=
# SIG # End signature block
