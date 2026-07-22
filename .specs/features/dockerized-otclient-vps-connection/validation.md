# OTClient Test Identity Provisioning Validation

**Date**: 2026-07-21
**Spec**: `.specs/features/dockerized-otclient-vps-connection/spec.md`
**Diff range**: `477a235..1895531` (`995e689`, `38ba490`, `1895531`)
**Verifier**: independent sub-agent (author != verifier)
**Scope**: only `OTC-PROV-01`–`OTC-PROV-09`, `OTC-EDGE-08`, and `OTC-EDGE-09`; build, CrossOver, and connection remain paused.

---

## Verdict

**Overall**: ✅ PASS — implementation and observed VPS outcomes match the active provisioning slice. After test-strengthening commit `1895531`, the focused contract gate passes 14/14 and kills all 8 P0 behavior-level mutations, including the five mutants that survived the initial verifier pass.

## Task Completion

| Task | Status | Notes |
| --- | --- | --- |
| Activate the independent provisioning slice | ✅ Done | `995e689` limits the active scope without resuming build/runtime/connection. |
| Implement map probe, secret contract, and transactional provisioner | ✅ Done | `38ba490`; no client/CrossOver code was changed. |
| Strengthen assertions exposed by the initial sensor | ✅ Done | `1895531` adds five spec-exact contract assertions without changing implementation. |
| Provision and re-read the VPS identity | ✅ Done | Sanitized first-run, rerun, and final-state evidence was supplied by the orchestrator. |
| Independent discrimination sensor | ✅ Done | Reverification injected the same 8 scratch-only mutations; all 8 were killed. |

## Spec-Anchored Acceptance Criteria

| Criterion | Spec-defined outcome | `file:line` + assertion/evidence | Result |
| --- | --- | --- | --- |
| `OTC-PROV-01` | Exactly three fixed keys; URL-safe 32-character password; ignored regular owner-only mode-0600 file | `tests/client-identity-contract.sh:24-28` — exact current-owner guard; `:48-80` validates initialization, mode, overwrite refusal, and symlink rejection; `.gitignore:5-12` ignores runtime env files. External metadata confirms ignored, regular, current-owner, mode `0600`; secret content was not read by the verifier. | ✅ PASS |
| `OTC-PROV-02` | Plaintext/digest stay inside approved boundaries and never enter output, arguments, logs, or artifacts | `tests/client-identity-contract.sh:14-22` — composite assertion requires no tracing or password echo; `:134-141` requires MariaDB general logging disabled; `scripts/provision-client-test-identity.sh:225-234` derives in process, unsets plaintext, and sends only SQL over SSH stdin. Supplied evidence contains only counts/booleans. | ✅ PASS |
| `OTC-PROV-03` | Strict authenticated SSH and MariaDB Unix socket only | `tests/client-identity-contract.sh:14-22` — assertion requires `StrictHostKeyChecking=yes` and `--protocol=socket`; `scripts/provision-client-test-identity.sh:229-233` supplies the exact transport. | ✅ PASS |
| `OTC-PROV-04` | Current release/map, town 1, non-zero temple `(95,117,7)`, and one placeable tile proven before transaction | `tests/client-identity-contract.sh:30-41` — remote map digest must precede MariaDB; `:82-99` asserts exact local map SHA/tile/ground/blocker/no-logout output and rejects absent coordinates. Supplied VPS preflight identifies release `098641981400f8ff89959f427f0e8718d9dd22e2`, map SHA `92ffae05e4da12b3d6603283e7a4356f39c4735dd9b996306c62de5c72549327`, and town 1 temple `(95,117,7)`. | ✅ PASS |
| `OTC-PROV-05` | One serialized transaction creates exactly one SHA-1-matching account and one linked active player at town 1 / zero position, then verifies before commit | `tests/client-identity-contract.sh:101-125` — generated SQL must include lock, transaction, inserts, verification, commit, and the exact player fixture values. Supplied first-run evidence: `result=created`, all four identity checks `1`, initial fixture `1`, town match `1`. | ✅ PASS |
| `OTC-PROV-06` | Exact existing identity is a no-op and preserves password/player state | `tests/client-identity-contract.sh:101-132` — fail-closed SQL plus exact `@digest_match = 1` no-op predicate; `scripts/provision-client-test-identity.sh:151-159,167-188` gates no-op on exact digest/cardinality/linkage and executes inserts only in create mode. Supplied rerun: `result=noop`, identity checks `1`, fixture `preserved`. | ✅ PASS |
| `OTC-PROV-07` | Any digest/cardinality/name/linkage conflict fails before mutation with sanitized output | `tests/client-identity-contract.sh:101-147` — preflight guard, exact digest predicate, no conflict-masking writes, and malformed-digest rejection. SQL output is limited to result/count/boolean fields at `scripts/provision-client-test-identity.sh:197-205`. | ✅ PASS |
| `OTC-PROV-08` | Locking, transaction, and uniqueness prevent partial/duplicate/cross-linked identities; retry converges to no-op or conflict | `tests/client-identity-contract.sh:101-116` — named lock, transaction, guarded verification, commit, and release; `server/schema.sql:10-11,77-79` provides unique account/player names and the player-account foreign key. The observed retry converged to exact no-op. | ✅ PASS |
| `OTC-PROV-09` | Service, trust, release/map, or probe failure aborts without unrelated mutation | `tests/client-identity-contract.sh:30-41,93-99,134-141` — remote map identity, invalid local map, and query-logging guards are exact; `scripts/provision-client-test-identity.sh:210-233` orders map and service checks before MariaDB input. | ✅ PASS |
| `OTC-EDGE-08` | Absent/invalid/non-placeable/wrong-release temple prevents identity transaction | `tests/client-identity-contract.sh:30-41,82-99` — exact valid tile, absent coordinate, and remote digest-before-MariaDB assertions. | ✅ PASS |
| `OTC-EDGE-09` | Existing digest/cardinality/linkage conflict fails before mutation and prevents later login | `tests/client-identity-contract.sh:101-132` — generated SQL contains the fail-closed preflight and exact digest-match no-op predicate. The connection slice is paused, so no login was attempted. | ✅ PASS |

**Spec-anchored status**: 11/11 scoped criteria have file/line evidence matching precise spec outcomes; 0 spec-precision gaps.

## Sanitized VPS Outcome Evidence

- Preflight: active release `098641981400f8ff89959f427f0e8718d9dd22e2`; map SHA `92ffae05e4da12b3d6603283e7a4356f39c4735dd9b996306c62de5c72549327`; town 1 temple `(95,117,7)`; identity initially absent.
- First execution: `result=created|account_count=1|digest_match=1|active_player_count=1|link_match=1|initial_fixture_match=1|town_match=1`.
- Second execution: `result=noop|account_count=1|digest_match=1|active_player_count=1|link_match=1|initial_fixture_match=preserved|town_match=1`.
- Final read: TFS active; exactly one normal account with two-factor disabled; exactly one active linked character with group `1`, vocation `0`, town `1`, and zero initial position.
- No plaintext password or digest is present in this report.

## Gate Check

- **Defined gate**: `make test-static` (Docker).
- **Complete orchestrator execution after `1895531`**: exit `0`; 7 contract files; 84 passed, 0 failed, 0 skipped; identity contract 14/14.
- **Fresh verifier focused execution after `1895531`**: `sh tests/client-identity-contract.sh`; 14 passed, 0 failed.
- **Test count before feature**: 70.
- **Test count after feature**: 84.
- **Delta**: +14, with no deletion or weakening of pre-existing tests observed.

## Discrimination Sensor

| Mutation | Scratch target | Behavior-level fault | Focused gate result |
| --- | --- | --- | --- |
| M1 | `scripts/provision-client-test-identity.sh:231` | Disabled strict SSH host-key checking | ✅ Killed — trust-boundary assertion failed |
| M2 | `scripts/provision-client-test-identity.sh:127` | Replaced named database lock acquisition with constant success | ✅ Killed — transactional/idempotency assertion failed |
| M3 | `scripts/probe-otbm-tile.py:157` | Forced the temple tile to have no ground | ✅ Killed — exact map/tile assertion failed |
| M4 | `scripts/provision-client-test-identity.sh:171` | Created the player with `town_id=2` instead of `1` | ✅ Killed — exact initial-fixture assertion failed |
| M5 | `scripts/provision-client-test-identity.sh:153` | Accepted digest mismatch as the exact no-op condition | ✅ Killed — exact digest predicate assertion failed |
| M6 | `scripts/provision-client-test-identity.sh:53` | Removed secret-file owner validation | ✅ Killed — owner-guard assertion failed |
| M7 | `scripts/provision-client-test-identity.sh:233` | Removed the deployed VPS map SHA guard before MariaDB | ✅ Killed — remote map digest ordering assertion failed |
| M8 | `scripts/provision-client-test-identity.sh:149` | Bypassed the MariaDB `general_log=0` confidentiality guard | ✅ Killed — general-log preflight assertion failed |

**Sensor depth**: P0/full manual sensor, 8 behavior-level mutations across credential containment, SSH trust, map integrity, transaction/locking, exact fixture creation, and no-op conflict branches.
**Result**: 8 injected, 8 killed, 0 survived — ✅ PASS.
**Real-tree integrity**: every mutation existed only under `/private/tmp`; no implementation/test file in the repository was mutated, and the ignored secret was neither opened nor printed.

## Code Quality

| Principle | Status |
| --- | --- |
| Minimum code / no unrelated feature | ✅ |
| Surgical changes within the active slice | ✅ |
| No build/CrossOver/connection scope creep | ✅ |
| Matches existing shell contract-test patterns | ✅ |
| Spec-anchored asserted values match outcomes | ✅ |
| Scoped requirements have traceable evidence | ✅ |
| Tests are non-shallow under P0 discrimination | ✅ 8/8 mutants killed |
| No unclaimed scoped test | ✅ |
| Project guideline | ✅ `AGENTS.md` is intentionally ignored/not present in the tracked root; TLC strong defaults applied. |

## Edge Cases

- [x] `OTC-EDGE-08`: exact valid deployed fixture proved; absent coordinate fails closed; remote release/map identity is checked before database input.
- [x] `OTC-EDGE-09`: SQL preflight rejects non-exact identity state before conditional inserts; downstream login remains paused.

## Closed Gaps

Commit `1895531` closes every gap from the initial sensor with spec-exact assertions for the creation fixture, no-op digest predicate, secret owner, deployed-map digest ordering, and MariaDB general-log guard. Reverification killed M1–M8; no fix task remains.

## Distilled Lessons

The five mutants that survived the initial pass remain recorded through the TLC lessons ledger as grounded historical candidates `L-003`–`L-007` (`surviving_mutant`). Reverification adds no new lesson because the final pass is clean; `.specs/lessons.json` remains canonical and `.specs/LESSONS.md` was rendered by the ledger tool.

## Requirement Traceability

| Requirement | Previous status | Validation status |
| --- | --- | --- |
| `OTC-PROV-01`–`OTC-PROV-09` | Active / implemented | ✅ Verified |
| `OTC-EDGE-08`–`OTC-EDGE-09` | Active / implemented | ✅ Verified |
| `OTC-BLD-*`, `OTC-RUN-*`, `OTC-CONN-*` | Paused | Paused; not evaluated |
