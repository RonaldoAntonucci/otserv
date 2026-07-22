# LESSONS — auto-maintained by scripts/lessons.py

> Machine-owned. Do NOT hand-edit. Changes are overwritten on the next `lessons.py` write.
> Canonical state lives in `.specs/lessons.json`. Edit lessons only via the script.
> promote_threshold=2 distinct features · window_days=45 · quarantine_threshold=2

## Confirmed (load these at Specify/Design)

Corroborated across multiple features. Safe to apply as guidance.

_none_

## Candidates (under observation — do NOT load as guidance yet)

Seen once or not yet corroborated. Tracked, not trusted.

### L-001 — Native installers must reuse the complete configuration contract before their first mutating operation
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `deploy/vps` · harmful: 0
- features: bootstrap-open-tibia-server
- evidence: .specs/features/bootstrap-open-tibia-server/validation.md:76 (deploy/vps)
- last seen: 2026-07-21T20:35:44Z

### L-002 — Installers must not declare readiness until the managed service is active and the documented immediate smoke prerequisites are satisfied
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `deploy/vps` · harmful: 0
- features: bootstrap-open-tibia-server
- evidence: .specs/features/bootstrap-open-tibia-server/validation.md:84 (deploy/vps)
- last seen: 2026-07-21T20:35:49Z

### L-003 — Assert exact conflict predicates for idempotent no-op paths, not merely the presence of a preflight guard.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `provisioning` · harmful: 0
- features: dockerized-otclient-vps-connection
- evidence: M5 (provisioning)
- last seen: 2026-07-22T02:36:55Z

### L-004 — Assert remote artifact identity gates at the boundary immediately before persistent mutation.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `provisioning` · harmful: 0
- features: dockerized-otclient-vps-connection
- evidence: M7 (provisioning)
- last seen: 2026-07-22T02:36:56Z

### L-005 — Assert every persisted fixture value required by the spec, not just the insert statement and columns.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `provisioning` · harmful: 0
- features: dockerized-otclient-vps-connection
- evidence: M4 (provisioning)
- last seen: 2026-07-22T02:36:56Z

### L-006 — Exercise ownership validation with an explicit owner-mismatch fixture, not only mode and symlink cases.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `secrets` · harmful: 0
- features: dockerized-otclient-vps-connection
- evidence: M6 (secrets)
- last seen: 2026-07-22T02:36:56Z

### L-007 — Assert credential-bearing database operations refuse execution while query logging is enabled.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `provisioning` · harmful: 0
- features: dockerized-otclient-vps-connection
- evidence: M8 (provisioning)
- last seen: 2026-07-22T02:36:56Z

## Quarantined (failed when applied — ignore)

A confirmed lesson that recurred alongside failure. Kept for the maintainer to review.

_none_
