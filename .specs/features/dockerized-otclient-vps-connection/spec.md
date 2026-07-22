# OTClient Test Identity Provisioning Specification

> **Status: DELIVERED.** Scope closed by user decision on 2026-07-22. The historical directory name is retained to preserve commit and validation references. OTClient compilation, packaging, CrossOver installation, and first-connection automation are deferred to future features; a precompiled OTClient is sufficient for current access.

## Problem Statement

The already deployed TFS instance needed one safe, repeatable test identity for client login without manual SQL or a public account website. Provisioning had to prove the deployed map fixture before mutation, protect the credential, converge safely on retries, and expose only sanitized evidence.

## Goals

- [x] Provision exactly one persistent account `otserv-smoke` and one non-deleted character `Docker Scout` on the validated VPS.
- [x] Keep the generated credential outside Git and logs while proving exact creation, linkage, fixture state, and idempotent rerun behavior.

## Out of Scope

| Feature | Reason |
| --- | --- |
| Compiling, modifying, packaging, signing, or distributing OTClient | Deferred to a separately specified future feature; a precompiled client is acceptable now. |
| CrossOver installation, profile management, launcher creation, or client runtime UAT | Not required to deliver the test identity. |
| Automated client login, character-list, world-entry, `players_online`, or `lastlogin` evidence | Connection validation belongs to a future feature. |
| Website, account manager, email flow, or self-service registration | Provisioning is an operator-only bootstrap action. |
| Password recovery/rotation or automated identity deletion | Lifecycle changes require a later explicit operator workflow. |
| Definitive datapack or production player onboarding | The official TFS datapack remains a technical validation baseline. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Test identity | Account `otserv-smoke`, character `Docker Scout`, one generated 32-character password from `[A-Za-z0-9_-]` | Fixed technical names and a high-entropy URL-safe secret make the state precise and repeatable. | Yes |
| Secret handoff | Exactly three keys in ignored `env/client-test.env`, regular/non-symlink, current-user-owned, mode `0600` | The operator needs the credential while Git, arguments, logs, and reports must not receive it. | Yes |
| VPS access | Strict-host-key-checked SSH and VPS-native MariaDB Unix socket as root | Reuses the validated native VPS trust boundary without exposing MariaDB. | Yes |
| Initial player fixture | `town_id=1`, `posx=0`, `posy=0`, `posz=0`, only after proving the deployed town-1 temple tile | TFS resolves the zero position to the town temple; invalid map state must fail before mutation. | Yes |
| Client availability | A precompiled OTClient is sufficient for current manual access | Native compilation is not needed to deliver this identity and can be prioritized independently later. | Yes |

**Open questions:** none.

---

## User Stories

### P1: Transactional test identity provisioning ⭐ MVP

**User Story**: As the operator, I want a safe repeatable way to create the test account and character so that client login can be attempted without manual SQL or a public account website.

**Why P1**: A precisely linked, loadable identity is the only deliverable required from this feature.

**Acceptance Criteria**:

1. **OTC-PROV-01** — WHEN `env/client-test.env` is accepted THEN it SHALL be an ignored regular file, not a symlink, owned by the current user, mode exactly `0600`, and contain exactly `CLIENT_TEST_ACCOUNT=otserv-smoke`, `CLIENT_TEST_CHARACTER=Docker Scout`, and `CLIENT_TEST_PASSWORD=<32 characters matching [A-Za-z0-9_-]{32}>`, with no duplicate keys, extra keys, blank values, surrounding whitespace, newline inside a value, or placeholder token.
2. **OTC-PROV-02** — WHEN the secret is handled THEN plaintext SHALL exist only in the approved `0600` file, non-exported process memory, SSH standard input when strictly required, and the visible GUI password field; plaintext or digest SHALL NOT appear in command arguments, Docker build arguments/layers, exported child-process environments, shell tracing/history, persistent temporary files, stdout/stderr, client logs, committed/generated artifacts, or evidence reports.
3. **OTC-PROV-03** — WHEN provisioning connects to the VPS THEN it SHALL use authenticated SSH with host-key verification enabled and the expected host identity, and MariaDB SHALL be accessed only through the VPS-native Unix socket as root; no database port or public provisioning endpoint SHALL be opened.
4. **OTC-PROV-04** — WHEN provisioning preflight runs THEN it SHALL inspect the exact map file resolved from the currently deployed VPS release and prove that `town_id=1` exists, has a non-zero temple position, and that the temple position resolves to a placeable map tile; failure SHALL abort before starting the account/player transaction.
5. **OTC-PROV-05** — WHEN no matching identity exists and preflight passes THEN one transaction SHALL create account `otserv-smoke` with the TFS-compatible SHA-1 digest and exactly one non-deleted player `Docker Scout` linked to it with `town_id=1`, `posx=0`, `posy=0`, and `posz=0`; the transaction SHALL commit only after the exact account/player cardinality and linkage are verified.
6. **OTC-PROV-06** — WHEN account `otserv-smoke` and character `Docker Scout` already exist THEN provisioning SHALL be a no-op only if the stored digest equals SHA-1 of the supplied password, exactly one non-deleted player belongs to the account, and `Docker Scout` is that player's exact name and linkage; the no-op SHALL leave password and player state unchanged.
7. **OTC-PROV-07** — WHEN digest, account/player linkage, active-player cardinality, name identity, or any requested identity conflicts THEN provisioning SHALL fail before mutation and report only sanitized booleans/counts, never the password or digest.
8. **OTC-PROV-08** — WHEN provisioning is interrupted or two attempts overlap THEN transaction/locking and database uniqueness constraints SHALL prevent partial, duplicate, or cross-linked identities; every retry SHALL converge either to the exact no-op state in `OTC-PROV-06` or the fail-closed conflict in `OTC-PROV-07`.
9. **OTC-PROV-09** — WHEN TFS or MariaDB is inactive, the deployed release/map cannot be identified, SSH trust fails, or the map probe cannot prove the temple contract THEN provisioning SHALL fail without service reconfiguration, partial identity creation, or mutation of unrelated VPS data.

**Independent Test**: Reject malformed/unsafe secret fixtures locally, prove the deployed town-1 temple contract, provision once, query sanitized digest-match/count/linkage/fixture-state booleans, rerun for an exact no-op, and inject mismatch, interruption, and concurrency faults to prove fail-closed transaction behavior.

---

## Edge Cases

- **OTC-EDGE-08** — WHEN the map probe finds town 1 absent, its temple zero/invalid, the tile non-placeable, or the inspected map does not belong to the current deployed release THEN no identity transaction SHALL begin.
- **OTC-EDGE-09** — WHEN an existing account has a different digest, zero/multiple active players, an extra active character, or `Docker Scout` linked elsewhere THEN provisioning SHALL fail before mutation.

---

## Implicit-Requirement Dimensions

| Dimension | Resolution and requirement references |
| --- | --- |
| Input validation & bounds | Exact secret schema, owner/mode, identity names, map fixture, and zero-position bounds are defined by `OTC-PROV-01`, `OTC-PROV-04`, and `OTC-PROV-05`. |
| Failure / partial-failure states | Preflight-before-mutation, serialized transaction, verified commit, and fail-closed conflicts are required by `OTC-PROV-04`–`OTC-PROV-09` and both edge cases. |
| Idempotency / retry / duplicate handling | Exact no-op, conflict behavior, locking, uniqueness, and retry convergence are required by `OTC-PROV-06`–`OTC-PROV-08`. |
| Auth boundaries & rate limits | Secret containment, strict SSH trust, and Unix-socket-only database access are required by `OTC-PROV-02` and `OTC-PROV-03`; rate limiting is N/A because no public endpoint exists. |
| Concurrency / ordering | Map/service preflight precedes database input; named locking, transactions, and uniqueness guard overlapping attempts under `OTC-PROV-04`, `OTC-PROV-08`, and `OTC-PROV-09`. |
| Data lifecycle / expiry | The identity and secret are persistent; automated rotation/deletion is explicitly out of scope. |
| Observability | Output is limited to sanitized result, count, and boolean evidence under `OTC-PROV-02`, `OTC-PROV-05`–`OTC-PROV-07`. |
| External-dependency failure | SSH, services, deployed release/map, and MariaDB failures halt before unrelated mutation under `OTC-PROV-03`, `OTC-PROV-04`, and `OTC-PROV-09`. |
| State-transition integrity | The only valid outcomes are exact creation, exact no-op, or fail-closed conflict as defined by `OTC-PROV-05`–`OTC-PROV-08`. |

---

## Requirement Traceability

| Requirement range | Story / concern | Status |
| --- | --- | --- |
| `OTC-PROV-01`–`OTC-PROV-09` | Transactional test identity provisioning | ✅ Verified |
| `OTC-EDGE-08`–`OTC-EDGE-09` | Map and existing-identity conflicts | ✅ Verified |

**Coverage:** 11/11 delivered requirements have independent evidence in `validation.md`; gate 84/84 passed, focused identity contract 14/14 passed, and the P0 discrimination sensor killed 8/8 mutations.

---

## Success Criteria

- [x] The deployed map probe proves the town-1 temple contract before the VPS transaction.
- [x] Initial provisioning reports `created` and proves exactly one digest-matching `otserv-smoke` account linked to exactly one active `Docker Scout` character with the specified town/position fixture.
- [x] Repeated provisioning reports `noop` without changing the password or player state.
- [x] All 11 scoped criteria pass independent verification without exposing the plaintext password or digest.
