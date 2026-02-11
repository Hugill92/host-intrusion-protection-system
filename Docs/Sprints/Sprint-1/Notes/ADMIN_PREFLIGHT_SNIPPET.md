# Admin Preflight Snippet (Reusable)

Purpose:
- Consistent admin verification
- Log OS/build details
- Enforce minimum PowerShell version

Notes:
- Reference snippet only. Assumes exitInstall/auditLog/Get-WindowsFriendlyName exist (or equivalents).

Reference snippet:

    try {
        # Check if running as Administrator
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            exitInstall "You are not running this script as an Administrator. Please launch the PowerShell prompt to Run as Administrator."
        } else {
            # Log that the script is running as Administrator
            $windowsVersion = [System.Environment]::OSVersion.Version

            if ($windowsVersion.Major -eq 10) {
                $osInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\"
                $releaseId = $osInfo.ReleaseId
                $buildNumber = $osInfo.CurrentBuild
                $ubr = $osInfo.UBR
                $windowsBuild = "Windows Release ID: $releaseId (Build $buildNumber.$ubr)"
            }

            auditLog -Level $infoLevel -Message "$scriptTitle is Running as Administrator"
            auditLog -Level $infoLevel -Message (Get-WindowsFriendlyName -version $windowsVersion)
            auditLog -Level $infoLevel -Message "$windowsBuild"
        }

        $currentVersion = $PSVersionTable.PSVersion
        if ($currentVersion -lt $minVersion) {
            exitInstall "This script requires PowerShell version 5.0 or higher. Current version is $currentVersion."
        } else {
            auditLog -Level $infoLevel -Message "PowerShell version is acceptable: $currentVersion"
        }
    } catch {
        exitInstall "An error occurred: $_"
    }

---

## UX that feels good
- If not admin: show a friendly message and offer a single-click relaunch as Administrator.
- Keep destructive actions disabled until elevation is confirmed.
- Log environment details once at startup (OS build + PowerShell version).
- Fail loud with a clear reason, and write the reason to logs.

## Preflight guidance
- Admin check should be centralized (single helper function) and reused across install/uninstall/maintenance UI.
- OS/build logging is useful for troubleshooting VM differences.
- PowerShell version gate should be explicit and logged.
