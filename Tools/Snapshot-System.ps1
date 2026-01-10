[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

"=== SNAPSHOT START === $(Get-Date -Format o)" | Out-File $OutFile

"`n--- FIREWALL RULES ---" | Out-File $OutFile -Append
Get-NetFirewallRule |
Sort DisplayName |
Select DisplayName, Direction, Action, Enabled, Profile, Program |
Format-Table -Auto | Out-String | Out-File $OutFile -Append

"`n--- SCHEDULED TASKS (Firewall) ---" | Out-File $OutFile -Append
schtasks /Query /FO LIST | Select-String "Firewall" | Out-File $OutFile -Append

"`n--- EXECUTION POLICY ---" | Out-File $OutFile -Append
Get-ExecutionPolicy -List | Format-Table | Out-String | Out-File $OutFile -Append

"`n--- EVENT LOGS ---" | Out-File $OutFile -Append
Get-WinEvent -ListLog Firewall | Format-List | Out-String | Out-File $OutFile -Append

"`n--- CERTIFICATES (Firewall related) ---" | Out-File $OutFile -Append
Get-ChildItem Cert:\LocalMachine\Root |
Where Subject -like "*Firewall*" |
Format-List | Out-String | Out-File $OutFile -Append

"`n--- GOLDEN MANIFEST ---" | Out-File $OutFile -Append
if (Test-Path "C:\Firewall\Golden\payload.manifest.sha256.json") {
    Get-Item "C:\Firewall\Golden\payload.manifest.sha256.json" |
    Format-List | Out-String | Out-File $OutFile -Append
} else {
    "Missing payload.manifest.sha256.json" | Out-File $OutFile -Append
}

"=== SNAPSHOT END ===" | Out-File $OutFile -Append
