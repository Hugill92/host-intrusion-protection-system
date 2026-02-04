#requires -Version 5.1
[CmdletBinding()]
param(
  [Parameter()] [string] $RepoRoot = "C:\FirewallInstaller",
  [Parameter()] [string] $WorkspaceName = "FirewallCore-DevLive.code-workspace"
)

$wsPath = Join-Path $RepoRoot $WorkspaceName
$vsDir = Join-Path $RepoRoot ".vscode"
if (-not (Test-Path -LiteralPath $vsDir)) { New-Item -ItemType Directory -Path $vsDir -Force | Out-Null }

$settingsPath = Join-Path $vsDir "settings.json"
@"
{
  ""chat.editing.confirmBeforeApply"": false,
  ""chat.tools.edits.autoApprove"": {
    ""**/*"": true
  }
}
"@ | Set-Content -LiteralPath $settingsPath -Encoding UTF8

@"
{
  ""folders"": [
    { ""name"": ""Repo"", ""path"": ""C:\\FirewallInstaller"" },
    { ""name"": ""Live-Firewall (READ-ONLY)"", ""path"": ""C:\\Firewall"" },
    { ""name"": ""Live-ProgramData (READ-ONLY)"", ""path"": ""C:\\ProgramData\\FirewallCore"" }
  ],
  ""settings"": {
    ""chat.editing.confirmBeforeApply"": false,
    ""chat.tools.edits.autoApprove"": {
      ""**/*"": true
    }
  }
}
"@ | Set-Content -LiteralPath $wsPath -Encoding UTF8

Write-Host "[OK] Workspace:" $wsPath
Write-Host "[OK] Settings :" $settingsPath
