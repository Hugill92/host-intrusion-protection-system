function Get-WfpBlocked {
    param([int]$Count = 10)

    Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        Id      = 5157
    } -MaxEvents $Count |
    ForEach-Object {
        [PSCustomObject]@{
            TimeCreated = $_.TimeCreated
            Application = $_.Properties[5].Value
            Direction   = $_.Properties[7].Value
            RemoteAddr  = $_.Properties[18].Value
            RemotePort  = $_.Properties[19].Value
            Protocol    = $_.Properties[20].Value
        }
    }
}
