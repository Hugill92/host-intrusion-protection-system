param([Parameter(Mandatory)][string]$Uri)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Parse URI like: firewallcore-review://open?action=log&EventId=2001&TestId=W-DLG&SinceUtc=...
$u = [uri]$Uri
$q = [System.Web.HttpUtility]::ParseQueryString($u.Query)

$action = ($q["action"] ?? "dialog")
$eventId = [int]($q["EventId"] ?? "0")
$testId  = ($q["TestId"] ?? "")
$sinceUtc = $q["SinceUtc"]

$folder = ($q["Folder"] ?? "")
$file   = ($q["File"] ?? "")

if ($action -eq "log") {
  if ($eventId -le 0) { return }
  $since = if ($sinceUtc) { [datetime]::Parse($sinceUtc).ToUniversalTime() } else { (Get-Date).ToUniversalTime().AddMinutes(-10) }

  Start-Process powershell.exe -ArgumentList @(
    "-NoLogo","-NoProfile","-ExecutionPolicy","Bypass",
    "-File","C:\Firewall\User\FirewallEventReview.ps1",
    "-EventId",$eventId,
    "-TestId",$testId,
    "-SinceUtc",$since.ToString("o")
  )
  return
}

# action = dialog
if (-not [string]::IsNullOrWhiteSpace($folder) -and -not [string]::IsNullOrWhiteSpace($file)) {
  $base = Join-Path $env:ProgramData "FirewallCore\NotifyQueue"
  $path = Join-Path (Join-Path $base $folder) $file
  if (Test-Path -LiteralPath $path) {
    Start-Process powershell.exe -ArgumentList @(
      "-NoLogo","-NoProfile","-STA","-ExecutionPolicy","Bypass",
      "-File","C:\Firewall\User\FirewallReviewDialog.ps1",
      "-PayloadPath", "`"$path`""
    )
  }
}
