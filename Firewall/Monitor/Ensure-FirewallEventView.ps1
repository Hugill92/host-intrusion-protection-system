param(
    [Parameter(Mandatory)]
    [int]$EventId,

    [Parameter(Mandatory)]
    [string]$LogName
)

$ViewsRoot = "C:\FirewallInstaller\Firewall\Monitor\EventViews"
if (-not (Test-Path $ViewsRoot)) {
    New-Item -ItemType Directory -Path $ViewsRoot -Force | Out-Null
}

$ViewPath = Join-Path $ViewsRoot ("{0}-{1}.xml" -f $LogName, $EventId)

@"
<QueryList>
  <Query Id="0" Path="$LogName">
    <Select Path="$LogName">
      *[System[EventID=$EventId]]
    </Select>
  </Query>
</QueryList>
"@ | Set-Content -Path $ViewPath -Encoding UTF8

Write-Output $ViewPath
