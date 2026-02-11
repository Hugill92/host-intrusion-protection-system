# Secure Token v1 Scopes

Secure Token scopes are stable identifiers that gate privileged actions.

## v1 scope set (default)
- MaintenanceMode
- DhcpRenew
- StaticIpWrite
- BaselineExport
- DiagnosticsExport
- PolicyApply
- UninstallOverride

## Notes
- A privileged action must require the narrowest scope possible.
- Admin Panel should display required scope(s) in the confirmation UI.
- Token issuance can include multiple scopes for a single maintenance session (time-bounded).
