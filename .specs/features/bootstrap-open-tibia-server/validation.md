# Bootstrap Open Tibia Server Validation — Iteration 2

**Date**: 2026-07-21
**Spec**: `.specs/features/bootstrap-open-tibia-server/spec.md`
**Tasks**: `.specs/features/bootstrap-open-tibia-server/tasks.md`
**Previous report**: iteration 1 FAIL, replaced by this report
**Diff range**: `d50d181..da5e389`
**Fix commits re-verified**: `c47f150`, `da5e389`
**Verifier**: fresh independent sub-agent (author != verifier)
**Verdict**: PASS

---

## Executive Summary

The full bootstrap now satisfies the specification. The two iteration-1 gaps are closed:

1. `deploy/vps/install.sh:378-386` executes the canonical VPS configuration contract before acquiring the installer lock or making any package, identity, database, filesystem, or service mutation. `tests/installer-contract.sh:233-266` verifies valid input, eight invalid semantic cases, and the validation-before-lock ordering.
2. `deploy/vps/install.sh:366-410` enables and starts `tfs.service`, verifies it is active, and only then prints readiness. `tests/installer-contract.sh:330-355` asserts the exact `enable --now` then `is-active --quiet` call sequence and rejects an inactive-service result before readiness.

The mandatory local gate completed with 94/94 assertions passing and no failures or skips. Three scratch mutations targeted the repaired contracts; all three were killed. The sanitized VPS evidence records reapplication of the corrected installer at `2026-07-21T20:43:24Z`, preservation of the existing release/database, active-service confirmation before readiness, and an immediately following 14/14 smoke pass. This verifier did not access or mutate the VPS.

---

## Task Completion

| Task | Status | Evidence / notes |
| --- | --- | --- |
| T1 | PASS | Public `RonaldoAntonucci/otserv`, default branch `main`, local `origin`, and clean pre-report worktree confirmed. GitHub API readback returned `private=false`, `fork=false`. Commit `e31cc66`. |
| T2 | PASS | `tests/harness-contract.sh:19-54` verifies pinned/read-only Docker execution, deliberate failure detection, explicit counts, and non-success placeholders; 4/4 passed. Commit `2d0bd36`. |
| T3 | PASS | GitHub API returned `RonaldoAntonucci/forgottenserver` as a public fork of `otland/forgottenserver`; exact fork/upstream URLs and gitlink `098641981400f8ff89959f427f0e8718d9dd22e2` passed at `tests/repository-structure-contract.sh:22-59`. Commit `b831bd7`. |
| T4 | PASS | GitHub API returned `RonaldoAntonucci/otclient` as a public fork of `opentibiabr/otclient`; exact URLs, gitlink `99d43bd6559841ee684e35082da3ea9a360d0e16`, and the TFS 1.6/13.10 compatibility row passed at `tests/repository-structure-contract.sh:61-88`. Commit `351e40e`. |
| T5 | PASS | The shared configuration suite covers examples, secret ignore rules, exact hosts/ports/database/map/protocol, valid environments, and invalid inputs; 14/14 passed at `tests/config-contract.sh:48-116`. Commit `63e1127`. |
| T6 | PASS | Clean `linux/amd64` image build, exact revision label, executable, runtime payload, non-root user, resolved libraries, and invalid-context failure all passed at `tests/docker-build.sh:21-89`; 6/6. Commit `3de35bb`. |
| T7 | PASS | Compose topology, pinned MariaDB, health ordering, isolated persistence, schema-once, active TFS, ports, datapack, logs, restart persistence, and three negative paths passed at `tests/docker-bootstrap.sh:98-288`; 18/18. Commit `742d630`. |
| T8 | PASS | Unit syntax, identity, paths, permissions, MariaDB dependency, hardening, and preflight positive/negative paths passed at `tests/native-install-static.sh:95-190`; 10/10. Commit `ea2b346`. |
| T9 | PASS | Installer platform/build/release/failure/idempotency/secret/schema contracts plus the canonical input integration passed at `tests/installer-contract.sh:39-328`; 18/18 with T13/T14 additions. Commit `b834d25`, corrected by `c47f150`. |
| T10 | PASS | Native smoke validates all 14 runtime outcomes at `scripts/smoke-vps.sh:163-179`; its positive and negative fixture contracts passed 12/12 at `tests/vps-smoke-contract.sh:114-222`. Commit `d9389cd`. |
| T11 | PASS | Sanitized real-VPS evidence records install, rerun persistence, service/network state, prior smoke runs, and the corrected reapplication plus immediate 14/14 smoke at `docs/vps-validation.md:18-63`. Commits `922b195`, `3ae90d0`, `9dcf391`; no VPS access by this verifier. |
| T12 | PASS | Clone, Docker-only development, native VPS install/smoke, logs, update, rollback, recovery, and exact 94/14 gate counts are documented at `README.md:15-43`, `docs/development.md:17-74`, and `docs/vps.md:9-106`. Commit `2a24cf7`, aligned by `da5e389`. |
| T13 | PASS | Canonical VPS semantics are invoked at `deploy/vps/install.sh:382` before the lock at `:385`; eight invalid semantic mutations and the ordering assertion pass at `tests/installer-contract.sh:233-266`. Sensor M1 independently killed a validation-after-lock regression. Commit `c47f150`. |
| T14 | PASS | `deploy/vps/install.sh:366-410` requires `enable --now`, successful `is-active --quiet`, and readiness afterward. `tests/installer-contract.sh:330-355` passed; sensor M2/M3 independently killed both weakened forms. Updated VPS evidence is at `docs/vps-validation.md:49`. Commit `da5e389`. |

**Task status**: 14/14 complete; 0 partial; 0 blocked.

---

## Spec-Anchored Acceptance Criteria

| Criterion | Spec-defined outcome | `file:line` + assertion expression / runtime evidence | Result |
| --- | --- | --- | --- |
| Repository AC1: creating the GitHub structure yields authentic forks of both official upstreams under `RonaldoAntonucci` | Public true forks whose exact parents are `otland/forgottenserver` and `opentibiabr/otclient` | `tests/repository-structure-contract.sh:22` — `assert_equal "accepted" "$validator_result"`; `:31`, `:34`, `:62` assert exact origin/upstream URLs. Fresh public GitHub API readback confirmed `fork=true` and the two exact parents. | PASS |
| Repository AC2: `otserv` contains orchestration/configuration/docs and fixed references, without secrets | Public orchestration repository; only examples/non-secret paths files tracked; runtime credentials ignored | `tests/config-contract.sh:54` — `assert_equal` requires both named placeholders plus the `ignored` state; diff review found no usable credential and no tracked runtime `.env`. | PASS |
| Repository AC3: each fork identifies its official upstream and the baseline is traceable | Exact fork/upstream URLs and exact server/client gitlink SHAs | `tests/repository-structure-contract.sh:25`, `:28`, `:31`, `:34`, `:62`, `:65` — exact-value `assert_equal` calls for every URL and SHA. | PASS |
| Build AC1: a clean Docker build produces executable TFS v1.6 without host libraries | `linux/amd64` image labeled with exact TFS SHA; executable with all libraries resolved inside the image | `tests/docker-build.sh:38` — `assert_equal ready "$build_contract"`; `:44` executable; `:77` expected libraries. All build commands execute through Docker. | PASS |
| Build AC2: Ubuntu 24.04 native build uses the same commit | Native installer verifies `098641981400f8ff89959f427f0e8718d9dd22e2`, produces an executable immutable release, and the real VPS reports that release | `tests/installer-contract.sh:116` — pinned revision; `:157` — complete immutable release; `scripts/smoke-vps.sh:165-166`; `docs/vps-validation.md:10-22`, `:45`. | PASS |
| Build AC3: dependency/build failure exits non-zero and does not publish a ready artifact | Invalid Docker source/build and native build failure cannot replace the current ready artifact | `tests/docker-build.sh:89` — `assert_equal ready "$invalid_contract"`; `tests/installer-contract.sh:176` — failed build preserves active release/marker and does not publish the candidate. | PASS |
| Build AC4: upstream changes do not move the baseline implicitly | Both gitlinks and Docker/native runtime pins remain exact until explicit change | `tests/repository-structure-contract.sh:28`, `:65`; `tests/docker-build.sh:38`; `tests/installer-contract.sh:116` — all assert exact approved SHAs. | PASS |
| Database AC1: an empty development volume imports the schema exactly once | Official schema tables exist; init script appears once; restart preserves a marker without reimport | `tests/docker-bootstrap.sh:156` — schema present; `:159` — `assert_equal 1 "$initial_imports"`; `:206` — persisted marker and unchanged import count. | PASS |
| Database AC2: native installer imports only when absent and preserves data on rerun | Existing sentinel prevents import; installed secrets/config/data/release remain unchanged | `tests/installer-contract.sh:295` — rerun preserves secret/config; `:305` — repeatable DB/user without password reset; `:328` — sentinel prevents reimport. Real rerun evidence: `docs/vps-validation.md:24-35`, `:49`. | PASS |
| Database AC3: unhealthy MariaDB prevents TFS readiness in both environments | Compose does not start TFS; native preflight/service and smoke reject unavailable MariaDB | `tests/docker-bootstrap.sh:247` — `assert_equal ready "$unhealthy_contract"`; `tests/native-install-static.sh:190` — unavailable DB rejected; `deploy/vps/tfs.service:3-5` requires MariaDB. | PASS |
| Database AC4: credentials are untracked and MariaDB is private/loopback-only | Runtime secrets ignored/root-only; no development DB host port; VPS listener only loopback | `tests/config-contract.sh:54`; `tests/installer-contract.sh:277`; `tests/docker-bootstrap.sh:136` — `assert_equal 0 "$db_ports"`; `tests/vps-smoke-contract.sh:174`; real listener evidence `docs/vps-validation.md:53-61`. | PASS |
| Datapack AC1: official map, items, monsters, NPCs, and scripts load without fatal startup error | All mandatory loader stages complete before online/readiness and the log contains no startup error | `tests/docker-bootstrap.sh:186` — map before `Server Online!`; `:194` — script systems/Lua loaded with no `> ERROR:`. Fixed upstream control flow aborts on items, scripts, monsters, NPCs, or map failure before readiness at `server/src/otserv.cpp:146-188`, `:214-218`, `:257-268`. | PASS |
| Datapack AC2: after startup the container/service remains active and configured ports listen | Development TFS and native `tfs.service` active; ports 7171/7172 listening | `tests/docker-bootstrap.sh:166`, `:172`, `:178`; `tests/vps-smoke-contract.sh:146`, `:202`; installer lifecycle assertion `tests/installer-contract.sh:355`; real evidence `docs/vps-validation.md:49`, `:53-63`. | PASS |
| Datapack AC3: missing/incompatible mandatory file fails without false readiness and identifies the cause | Missing map/datapack fails the process or preflight; log identifies map failure; fatal journal rejected | `tests/docker-bootstrap.sh:288` — missing map requires non-running TFS and `Failed to load map`; `tests/native-install-static.sh:182`; `tests/vps-smoke-contract.sh:214`, `:222`. | PASS |
| Datapack AC4: documented log commands return Compose and journal logs | Development uses Compose logs; VPS uses `journalctl`; both mechanisms are exercised by gates | Commands at `docs/development.md:34-49` and `docs/vps.md:45-52`; `tests/docker-bootstrap.sh:180-194` derives assertions from Compose logs; `scripts/smoke-vps.sh:150-160` and `tests/vps-smoke-contract.sh:222` derive assertions from the boot journal. | PASS |
| Client AC1: pinned OTClient declares TFS 1.6 / protocol 13.10 compatibility | Exact client SHA and explicit compatible matrix row | `tests/repository-structure-contract.sh:65` — exact SHA; `:72` — `assert_equal "compatible" "$compatibility_result"`; GitHub API confirmed official parent. | PASS |
| Client AC2: next client feature can consume address/protocol from configuration without secrets in code | Address/protocol are environment values; only placeholders are tracked | `tests/config-contract.sh:54`, `:64`, `:70`, `:83`, `:86`; exact examples at `env/development.env.example:9-14` and `deploy/vps/otserv.env.example:9-14`. | PASS |

**Acceptance-criteria status**: 17/17 matched the spec-defined outcomes; 0 uncovered ACs; 0 spec-precision gaps.

---

## Edge Cases and Implicit Requirements

| Dimension | Evidence | Result |
| --- | --- | --- |
| Input validation and bounds | Shared exact-value validator at `scripts/validate-config.sh:33-66`; installer calls it before lock/mutation at `deploy/vps/install.sh:378-386`; `tests/installer-contract.sh:233-266` rejects wrong DB identity, every port, map, and protocol. Sensor M1 killed validation moved after the lock. | PASS |
| Failure / partial-failure states | Invalid Docker context, unhealthy DB, missing map, failed native build, inactive TFS, and fatal journal all fail without ready publication (`tests/docker-build.sh:79-89`; `tests/docker-bootstrap.sh:219-288`; `tests/installer-contract.sh:159-176`, `:330-355`; `tests/vps-smoke-contract.sh:192-222`). | PASS |
| Idempotency / retry / duplicate handling | Compose marker/import-count persists (`tests/docker-bootstrap.sh:196-206`); native secrets/config/release/schema persist (`tests/installer-contract.sh:178-200`, `:279-328`); real rerun preserved marker/release/map (`docs/vps-validation.md:24-35`, `:49`). | PASS |
| Auth boundaries / rate limits | Secrets ignored/root-only, image/service non-root, MariaDB private/loopback-only (`tests/config-contract.sh:48-54`; `tests/docker-build.sh:53-62`; `tests/native-install-static.sh:101-119`; `tests/docker-bootstrap.sh:132-136`; `tests/vps-smoke-contract.sh:164-174`). HTTP rate limiting is explicitly N/A. | PASS |
| Concurrency / ordering | Compose requires `service_healthy` (`tests/docker-bootstrap.sh:109-113`); systemd requires MariaDB (`tests/native-install-static.sh:121-129`); installer locks at `deploy/vps/install.sh:385-386`; schema sentinel prevents duplicate import. | PASS |
| Data lifecycle / expiry | Named Docker volume and native data/marker survive restart/reapplication (`tests/docker-bootstrap.sh:123-130`, `:196-206`; `docs/vps-validation.md:24-35`). Backup/expiry remains explicitly out of scope before real player data. | PASS |
| Observability | Compose logs and systemd status/journal commands are documented (`docs/development.md:34-49`; `docs/vps.md:45-61`) and used by automated log/journal assertions (`tests/docker-bootstrap.sh:180-194`; `scripts/smoke-vps.sh:150-160`). | PASS |
| External-dependency failure | Invalid/missing Docker source and native build failure are rejected; sources/images/revisions are pinned (`tests/docker-build.sh:79-89`; `tests/installer-contract.sh:159-176`; `.gitmodules:1-6`; `compose.yaml:1-3`). | PASS |
| State-transition integrity | Installer validates before mutation, then starts and verifies TFS before readiness (`deploy/vps/install.sh:378-410`). `tests/installer-contract.sh:233-266`, `:330-355` enforce both transitions; all three targeted mutants were killed. The corrected real reapplication and immediate 14/14 smoke are retained at `docs/vps-validation.md:49`. | PASS |

**Edge-case status**: 9/9 passed.

---

## Regression Fix Re-verification

### `c47f150` — Canonical validation before mutation

- `validate_environment_source` still rejects non-files, examples, malformed lines, placeholders, missing/duplicate/blank required keys, and non-loopback native DB host at `deploy/vps/install.sh:98-140`.
- `validate_vps_configuration` invokes the shared validator in VPS mode at `deploy/vps/install.sh:142-152`.
- `main` invokes both validators and the exact revision check before the lock at `deploy/vps/install.sh:378-386`; the first provisioning call is later at `:388`.
- `tests/installer-contract.sh:233-266` checks valid input, eight invalid semantic values, and exact source-order before the lock.
- Result: PASS; sensor M1 proves that moving the call after the lock is detected.

### `da5e389` — Active service before readiness

- `start_tfs_service` requires successful `systemctl enable --now tfs.service` and `systemctl is-active --quiet tfs.service` at `deploy/vps/install.sh:366-369`.
- `main` calls it after daemon reload and before the readiness message at `deploy/vps/install.sh:408-410`.
- `tests/installer-contract.sh:330-355` asserts exact call order, injects an inactive result, and confirms start precedes readiness.
- The runbook explicitly requires no extra manual start and describes failure-before-readiness at `docs/vps.md:22-33`.
- Result: PASS; sensors M2 and M3 prove that dropping `--now` or dropping `is-active` is detected.

---

## Gate Check

- **Gate command**: `make verify`
- **Result**: exit 0; 94 passed, 0 failed, 0 skipped
- **Static gate**: 70 passed (14 config + 4 harness + 18 installer + 10 native service + 12 repository + 12 VPS smoke contracts)
- **Development gate**: 24 passed (6 Docker image + 18 Compose/MariaDB/TFS)
- **Baseline before feature (`d50d181`)**: 0 test files, 0 assertions
- **Delta**: +94 local assertions
- **Skipped tests**: none; no skip/disable/pending mechanism exists in the scoped test runners
- **Remote retained gate**: corrected installer reapplication followed immediately by 14/14 (`docs/vps-validation.md:49`); earlier 14/14 runs remain recorded at `:39-47`
- **Environment note**: the sandboxed first invocation lacked Docker-socket permission; the authorized Docker invocation completed the full gate. This is an execution permission boundary, not a project failure.

All local build/runtime activity was Docker-backed. No project build or runtime dependency was installed on macOS.

---

## Discrimination Sensor

All mutations ran in a detached temporary worktree under `/private/tmp`, with the real worktree mounted read-only for the targeted Docker test. Each mutation was restored before the next, and the temporary worktree/submodules were removed afterward. The real implementation was never mutated.

| Mutation | Scratch target | Behavior-level fault | Targeted result | Killed? |
| --- | --- | --- | --- | --- |
| M1 | `deploy/vps/install.sh:382-386` | Moved canonical `validate_vps_configuration` from before the installer lock to after lock acquisition, bypassing the pre-mutation ordering contract | `tests/installer-contract.sh`: 17 passed, 1 failed; only `installer enforces canonical VPS semantics before mutation` failed | YES |
| M2 | `deploy/vps/install.sh:367` | Weakened `systemctl enable --now tfs.service` to `systemctl enable tfs.service`, so installation no longer starts TFS | `tests/installer-contract.sh`: 17 passed, 1 failed; only `installer requires active TFS before declaring readiness` failed | YES |
| M3 | `deploy/vps/install.sh:368` | Removed `systemctl is-active --quiet tfs.service`, allowing readiness without confirmed active state | `tests/installer-contract.sh`: 17 passed, 1 failed; only `installer requires active TFS before declaring readiness` failed | YES |

**Sensor depth**: lightweight, 3 targeted behavior-level mutations
**Result**: 3 injected, 3 killed, 0 survived — PASS

---

## Docker-Only macOS Confirmation

**Result**: PASS.

- `README.md:3-5` and `docs/development.md:3-15` make Docker Desktop the only local project runtime/build dependency and explicitly reject Homebrew/MacPorts installation.
- `Makefile:5-16` delegates static checks to a pinned Docker image and development integration to Docker-backed scripts.
- `docker/tfs.Dockerfile:1-33` installs the compiler, CMake, Ninja, and TFS libraries only inside the Docker build stage.
- `docs/vps.md:3-7` confines native packages, MariaDB, and systemd operations to Ubuntu 24.04 on the VPS.
- `scripts/smoke-vps.sh:74-84` rejects non-root, non-Ubuntu-24.04, non-amd64, or non-systemd hosts.
- This verification used Docker for `make verify` and for all mutation tests; no native project dependency was installed on macOS.

---

## Code Quality

| Principle | Status | Notes |
| --- | --- | --- |
| No features beyond the requested bootstrap | PASS | All 44 diff paths map to orchestration, pinned sources, Docker/native bootstrap, tests, runbooks, or the approved spec process. |
| No unnecessary abstraction/flexibility | PASS | The fixes reuse the existing canonical validator and add one focused service-start helper. |
| Surgical changes / no unrelated cleanup | PASS | `c47f150` and `da5e389` are narrowly scoped to the two verifier gaps plus their contracts/docs/status updates. `sources/` remains untouched. |
| Matches project style/patterns | PASS | POSIX shell, exact-value contracts, scratch fixtures, pinned Docker images, and explicit exit behavior match the project. |
| Test integrity | PASS | Baseline had zero tests; no test deletion, assertion weakening, skip, or pending mechanism was found. |
| Tests map to AC, edge case, or Done-when | PASS | Harness-only assertions map to T2 Done-when; all other 90 local assertions map to BOOT requirements, listed edge cases, or task Done-when clauses. |
| Payload/conjunction rule | PASS | Multi-part outcomes assert exact values and all required conjuncts: URLs/SHAs, ports, state, call order, persistence, and absence of fatal logs. |
| Spec-anchored asserted values | PASS | 17/17 story ACs target the precise spec outcome; 0 spec-precision gaps. |
| Per-layer coverage expectation | PASS | Repository/config/native shell have positive and negative contracts; Docker/Compose cover build plus happy/edge/error paths; native runtime has 14 e2e checks and 12 negative fixture contracts. |
| Senior-engineer approval | PASS | Both release-blocking iteration-1 defects now fail closed and are empirically protected by killed mutants. |
| Documented guidelines | PASS | Workspace `AGENTS.md` honored (`sources/` read-only); task matrix gates and TLC Verifier rules followed. |

---

## Remote Evidence Review

Only `docs/vps-validation.md` was inspected; no remote command, SSH session, Hostinger action, service operation, or VPS mutation was performed by this verifier.

The sanitized evidence records:

- Ubuntu 24.04 amd64, MariaDB 10.11.14, and exact TFS SHA (`docs/vps-validation.md:7-16`);
- successful recovery from the earlier release-permission defect (`:18-22`);
- preserved secret, database marker, active release, map, schema, and data across rerun (`:24-35`);
- prior 14/14 smoke runs and their verified runtime outcomes (`:37-47`);
- corrected installer reapplication at `2026-07-21T20:43:24Z`, canonical validation before mutation, reused release/database, active TFS before readiness, and immediate 14/14 smoke (`:49`);
- active/enabled services, loopback-only MariaDB, listening TFS ports, two datapack completion entries, and zero fatal startup entries (`:51-63`).

This evidence closes T11/T14 without violating the instruction not to touch the VPS.

---

## Requirement Traceability Recommendation

The source spec was intentionally not edited by this independent verifier.

| Requirement | Current spec status | Verified recommendation |
| --- | --- | --- |
| BOOT-01 | Complete | Verified |
| BOOT-02 | Complete | Verified |
| BOOT-03 | Complete | Verified |
| BOOT-04 | Fixed — Pending Verify | Verified — close |
| BOOT-05 | Complete | Verified |
| BOOT-06 | Fixed — Pending Verify | Verified — close |
| BOOT-07 | Complete | Verified |
| BOOT-08 | Fixed — Pending Verify | Verified — close |

---

## Interactive UAT

Not applicable. This is backend/infrastructure bootstrap; the automated Docker gate, mutation sensor, public repository readback, and retained sanitized native evidence provide the appropriate verification.

---

## Lessons Self-Check

This iteration is a clean PASS: no surviving mutant, uncovered/failed AC, spec-precision gap, or `SPEC_DEVIATION` was found. Per the TLC rule, no new lesson was recorded. This report is the only real file modified by the verifier.

---

## Summary

**Overall**: READY

- Story ACs: 17/17 passed; 0 spec-precision gaps
- Edge cases: 9/9 passed
- Tasks: 14/14 complete
- Local gate: 94 passed, 0 failed, 0 skipped
- Corrected retained VPS smoke: 14/14 at `2026-07-21T20:43:24Z`
- Sensor: 3/3 mutations killed
- Ranked gaps: none
