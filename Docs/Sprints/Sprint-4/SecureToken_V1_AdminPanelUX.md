# Secure Token v1 Admin Panel UX

## Maintenance Mode control
- Button: "Unlock Maintenance"
  - Requires OS admin
  - Issues Secure Token (default TTL 15 minutes)
  - Shows: scopes granted + expiry time
- Button: "Lock Maintenance"
  - Revokes token immediately

## Privileged actions gating
- Actions requiring Maintenance:
  - Static IP write
  - Policy apply/import (as configured)
  - Baseline export (admin+maintenance)
  - Uninstall override/destructive actions

## Dialog-driven actions
### Static IP…
- Requires Maintenance token scope: StaticIpWrite
- Opens dialog collecting:
  - InterfaceAlias (dropdown)
  - IPAddress
  - PrefixLength
  - DefaultGateway (optional)
  - DnsServers (optional)
  - Rollback checkbox (recommended default ON)
- On Apply:
  - Validate token scope
  - Execute backend script
  - Write receipt + EVTX
  - Render outcome in UI with evidence pointer

### New IP (DHCP)
- Default one-click action
- Recommended scope: DhcpRenew (admin required)
- Confirmation dialog warns transient disconnect
- Writes receipt + EVTX and shows before/after IP summary
