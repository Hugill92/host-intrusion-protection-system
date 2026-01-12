# FirewallCore Event Viewer Views

## Canonical view files
These views are shipped/staged to allow deterministic “Review Log” drill-down by severity and/or bands.

### Single EventId views
- FirewallCore-EventId-3001.xml
- FirewallCore-EventId-4001.xml
- FirewallCore-EventId-9001.xml

### Range views
- FirewallCore-Range-3000-3999.xml (Info band)
- FirewallCore-Range-4000-4999.xml (Warning band)
- FirewallCore-Range-8000-8999.xml (Test/Pentest band)
- FirewallCore-Range-9000-9999.xml (Critical band)

## Install-time staging targets
- %ProgramData%\Microsoft\Event Viewer\Views
- %ProgramData%\FirewallCore\User\Views

## Permissions (important)
Standard users must be able to **read** the XML in ProgramData view folders.
Use Tools\Ensure-EventViewerViewAcl.ps1 after staging/copy.
