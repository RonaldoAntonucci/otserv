# Bootstrap Open Tibia Server Validation

**Date**: 2026-07-21  
**Spec**: `.specs/features/bootstrap-open-tibia-server/spec.md`  
**Tasks**: `.specs/features/bootstrap-open-tibia-server/tasks.md`  
**Diff range**: `d50d181..2a24cf7`  
**Verifier**: independent sub-agent (author != verifier)  
**Verdict**: FAIL

---

## Executive Summary

The implemented Docker development stack and the already-running native VPS satisfy the observable runtime outcomes. The local build gate passed all 92 assertions, the retained VPS evidence records three successful 14/14 read-only smoke runs, the public GitHub repository/fork topology was independently read back, and all three scratch mutations were killed.

The feature is not ready to close because two fresh-install guarantees are not met:

1. `deploy/vps/install.sh` accepts semantically invalid VPS ports and map names before the installer begins mutating the host. An isolated negative test supplied `TFS_LOGIN_PORT=not-a-port` and `TFS_MAP_NAME=missing-map`; `validate_environment_source` returned success.
2. The installer runs `systemctl enable tfs.service` and then prints `Installation ready`, but it does not start the service or verify it is active. The documented first-install sequence proceeds directly to `make test-vps`, so it fails on a clean VPS unless the operator follows the installer stdout instruction that is absent from the runbook.

These are spec-level gaps in input validation and state-transition integrity even though the current VPS was manually brought to a passing state.

---

## Task Completion

| Task | Status | Evidence / notes |
| --- | --- | --- |
| T1 | PASS | Public `RonaldoAntonucci/otserv`, default branch `main`, and local `origin` were independently read back. Commit `e31cc66`. |
| T2 | PASS | Containerized static harness passes and detects deliberate assertion failure. Commit `2d0bd36`. |
| T3 | PASS | TFS fork relationship, official upstream, and gitlink `098641981400f8ff89959f427f0e8718d9dd22e2` confirmed. Commit `b831bd7`. |
| T4 | PASS | OTClient fork relationship, compatibility declaration, and gitlink `99d43bd6559841ee684e35082da3ea9a360d0e16` confirmed. Commit `351e40e`. |
| T5 | PASS | Shared validator itself rejects the specified invalid values and secret-tracking cases. Commit `63e1127`. Integration into the native installer is the T9 gap below. |
| T6 | PASS | Reproducible `linux/amd64` image, executable, libraries, runtime files, and non-root identity all passed. Commit `3de35bb`. |
| T7 | PASS | Compose/database/TFS integration passed all 18 assertions. Commit `742d630`. |
| T8 | PASS | Native service/preflight contracts passed all 10 assertions. Commit `ea2b346`. |
| T9 | PARTIAL | Build, release activation, schema idempotency, and secret preservation pass, but the installer does not enforce the full VPS configuration contract before mutation. Commit `b834d25`. |
| T10 | PASS | Native smoke behavior and all negative fixture branches passed 12/12. Commit `d9389cd`. |
| T11 | PASS | Sanitized evidence records the fixed release-permission defect, second installer run, restart, loopback-only database, active services, listening ports, and three 14/14 smoke confirmations. Commits `922b195`, `3ae90d0`, `9dcf391`. No VPS mutation was performed by this verifier. |
| T12 | PARTIAL | Docker-only macOS rule and operational commands are documented, but the clean native install sequence omits `systemctl start tfs.service` while the installer does not start it. Commit `2a24cf7`. |

**Task status**: 10 complete, 2 partial (`T9`, `T12`).

---

## Spec-Anchored Acceptance Criteria

| Criterion | Spec-defined outcome | `file:line` + asserted evidence | Result |
| --- | --- | --- | --- |
| Repository AC1: creating the GitHub structure yields authenticated forks of both official upstreams under `RonaldoAntonucci` | Both repositories are public forks with the exact official parent | `tests/repository-structure-contract.sh:22` - `assert_equal "accepted" "$validator_result"`; `:31`, `:34`, `:62` assert exact fork/upstream URLs. Live GitHub API readback on 2026-07-21 confirmed `fork=true` and parents `otland/forgottenserver` and `opentibiabr/otclient`. | PASS |
| Repository AC2: `otserv` contains orchestration/configuration/docs and fixed references, without secrets | Public orchestration repo; no runtime credential tracked | `tests/config-contract.sh:54` - `assert_equal "CHANGE_ME_LOCAL_PASSWORD\|CHANGE_ME_VPS_PASSWORD\|ignored" ...`; current `git ls-tree` contains only examples plus non-secret `paths.env`; secret-pattern scan found no credential value. | PASS |
| Repository AC3: each fork identifies its official upstream and the baseline is traceable | Exact origin/upstream URLs and exact gitlink SHAs | `tests/repository-structure-contract.sh:25`, `:28`, `:31`, `:34`, `:62`, `:65` assert the exact values. | PASS |
| Build AC1: a clean Docker build produces executable TFS v1.6 without host libraries | `linux/amd64` image, pinned revision, executable binary, resolved container libraries | `tests/docker-build.sh:38` - `assert_equal ready "$build_contract"`; `:44` executable; `:77` required libraries. Build commands are Docker-only. | PASS |
| Build AC2: Ubuntu 24.04 native build uses the same commit | Native build verifies SHA `098641...` and emits an executable immutable release | `tests/installer-contract.sh:116`, `:126`, `:157`; `scripts/smoke-vps.sh:165-166`; retained evidence `docs/vps-validation.md:10-22`, `:39-45`. | PASS |
| Build AC3: dependency/build failure exits non-zero and does not publish a ready artifact | Failed source/build cannot become the active ready artifact | `tests/docker-build.sh:89` - invalid context must fail; `tests/installer-contract.sh:176` - failed native build preserves the previous active release and removes the candidate. | PASS |
| Build AC4: upstream changes do not move the baseline implicitly | Server/client gitlinks and runtime/native revision checks remain exact | `tests/repository-structure-contract.sh:28`, `:65`; `tests/docker-build.sh:38`; `tests/installer-contract.sh:116`. | PASS |
| Database AC1: empty development volume creates/imports the schema once | At least the official schema tables exist; init log occurs exactly once; restart does not reimport | `tests/docker-bootstrap.sh:156`, `:159`, `:206` assert all three outcomes. | PASS |
| Database AC2: native installer imports only when absent and preserves data on rerun | Sentinel prevents reimport; secrets/config/marker survive rerun | `tests/installer-contract.sh:260`, `:270`, `:293`; retained real outcome `docs/vps-validation.md:24-35`. | PASS |
| Database AC3: unhealthy MariaDB prevents TFS readiness in both environments | Compose blocks TFS; native preflight fails | `tests/docker-bootstrap.sh:113`, `:247`; `tests/native-install-static.sh:129`, `:190`. | PASS |
| Database AC4: credentials are untracked and MariaDB is private/loopback-only | Ignored secrets; no development host port; VPS listener only on loopback | `tests/config-contract.sh:54`; `tests/docker-bootstrap.sh:136`; `tests/vps-smoke-contract.sh:174`; retained real listener `docs/vps-validation.md:53-63`. | PASS |
| Datapack AC1: official map, items, monsters, NPCs, and scripts load without fatal startup error | Loader completes all mandatory stages before `Server Online!` and no fatal log exists | `tests/docker-bootstrap.sh:166`, `:186`, `:194`; fixed upstream control flow `server/src/otserv.cpp:147-188`, `:214-218`, `:257-268`; native assertions `scripts/smoke-vps.sh:175-176`. | PASS |
| Datapack AC2: after startup the container/service remains active and configured ports listen | Development and current VPS runtime are active on 7171/7172 | `tests/docker-bootstrap.sh:166`, `:172`, `:178`; `scripts/smoke-vps.sh:172-174`; retained real outcome `docs/vps-validation.md:39-61`. | PASS for current runtime; fresh-install transition fails separately below |
| Datapack AC3: a missing/incompatible mandatory file fails without false readiness and identifies the cause | Process/preflight rejects missing map/datapack and log names the map failure | `tests/docker-bootstrap.sh:272-288`; `tests/native-install-static.sh:182`; `tests/vps-smoke-contract.sh:214`, `:222`. | PASS |
| Datapack AC4: documented log commands return Compose and journal logs | Exact commands are documented and the same mechanisms are exercised | `docs/development.md:37-49`; `docs/vps.md:43-50`; exercised by `tests/docker-bootstrap.sh:180` and `scripts/smoke-vps.sh:150-160`. | PASS |
| Client AC1: pinned OTClient declares TFS 1.6 / protocol 13.10 compatibility | Exact client SHA and compatibility row | `tests/repository-structure-contract.sh:65`, `:72`; live GitHub fork readback confirmed parent `opentibiabr/otclient`. | PASS |
| Client AC2: the next client feature can consume address/protocol from configuration without secrets in code | Address and protocol are environment/example values; only placeholders are tracked | `tests/config-contract.sh:54`, `:69-70`, `:85-86`; `env/development.env.example:9-14`; `deploy/vps/otserv.env.example:9-14`. | PASS |

**Acceptance-criteria status**: 17/17 story ACs have outcome evidence for the implemented/current environments; 0 spec-precision gaps. Closure still fails because two mandatory edge/success-path guarantees below are violated.

---

## Edge Cases and Implicit Requirements

| Dimension | Evidence | Result |
| --- | --- | --- |
| Input validation and bounds | The standalone validator rejects bad ports/map (`tests/config-contract.sh:88-116`), but the native installer calls only its weaker `validate_environment_source` (`deploy/vps/install.sh:98-140`, `:361-365`). Isolated Docker diagnostic: invalid `TFS_LOGIN_PORT=not-a-port` plus `TFS_MAP_NAME=missing-map` returned `INVALID_CONFIG_ACCEPTED`. | FAIL |
| Failure / partial-failure states | Invalid Docker context, unhealthy DB, missing map, and failed native build all return non-zero/preserve prior state (`tests/docker-build.sh:79-89`; `tests/docker-bootstrap.sh:219-288`; `tests/installer-contract.sh:159-176`). | PASS |
| Idempotency / retry / duplicate handling | Development marker survives restart without reimport; existing release, secrets/config, native schema, and real VPS marker survive rerun (`tests/docker-bootstrap.sh:196-206`; `tests/installer-contract.sh:178-200`, `:244-293`; `docs/vps-validation.md:24-35`). | PASS |
| Auth boundaries / rate limits | Runtime secrets ignored/root-only; database private; HTTP rate limiting explicitly N/A (`tests/config-contract.sh:48-54`; `tests/native-install-static.sh:111-119`; `tests/docker-bootstrap.sh:132-136`; `scripts/smoke-vps.sh:103-109`). | PASS |
| Concurrency / ordering | Compose uses `service_healthy`; systemd requires MariaDB; native installer uses a non-blocking lock (`compose.yaml:43-45`; `deploy/vps/tfs.service:3-5`; `deploy/vps/install.sh:367-368`). | PASS |
| Data lifecycle / expiry | Isolated named volume and native persistence marker survive restart/rerun (`tests/docker-bootstrap.sh:123-130`, `:196-206`; `docs/vps-validation.md:24-35`). Backup/expiry remains explicitly N/A for bootstrap. | PASS |
| Observability | Compose logs, journal, status, and listener checks are documented and exercised (`docs/development.md:34-49`; `docs/vps.md:43-59`; `scripts/smoke-vps.sh:150-160`). | PASS |
| External-dependency failure | Docker invalid source context and native build failure are rejected; exact revisions/images are pinned (`tests/docker-build.sh:79-89`; `tests/installer-contract.sh:159-176`; `.gitmodules:1-6`; `compose.yaml:3`). | PASS |
| State-transition integrity | `deploy/vps/install.sh:391-392` enables but does not start `tfs.service`, then prints `Installation ready`. `docs/vps.md:24-29` proceeds directly to `make test-vps`; `scripts/smoke-vps.sh:141-142`, `:172-176` requires the service active, ports listening, and datapack completion. A clean install therefore declares readiness before those conditions. | FAIL |

---

## Docker-Only macOS Rule

**Result**: PASS.

- `README.md:5` and `docs/development.md:3-15` explicitly prohibit installing project build/runtime dependencies on macOS and make Docker Desktop the only local runtime dependency.
- `Makefile:5-16` delegates the static gate to a pinned Docker image and development build/runtime to scripts that invoke only Docker/Docker Compose.
- `docker/tfs.Dockerfile:5-33` installs and runs the compiler, CMake, Ninja, and build libraries inside the Docker build stage.
- Repository-wide inspection found native `apt-get`, CMake, MariaDB, and systemd operations only inside Dockerfiles or the explicitly VPS-only bundle; no Homebrew/MacPorts/native macOS installation path exists.
- `make test-vps` is guarded by `scripts/smoke-vps.sh:74-84` and rejects non-Ubuntu/non-amd64/non-systemd hosts.

No project runtime or build dependency was installed directly on macOS during validation.

---

## Gate Check

- **Command**: `make verify`
- **Result**: exit 0; 92 passed, 0 failed, 0 skipped
- **Static**: 68 passed (14 config + 4 harness + 16 installer + 10 native service + 12 repository + 12 VPS smoke contracts)
- **Development build/runtime**: 24 passed (6 Docker image + 18 Compose/MariaDB/TFS)
- **Test files exercised**: all top-level `tests/*.sh` either directly or through `tests/run-static.sh` / `scripts/smoke-development.sh`; `tests/lib/assert.sh` is the shared assertion library
- **Baseline before feature (`d50d181`)**: 0 test files, 0 assertions
- **Delta**: +92 local assertions
- **Retained remote gate**: three recorded runs of 14 passed, 0 failed (`docs/vps-validation.md:37-47`); not re-run because this verifier was instructed not to mutate/access the VPS runtime
- **Skipped tests**: none
- **Failures**: none in the build gate
- **Environment note**: the first sandboxed invocation could not access the Docker socket; the required authorized Docker invocation then ran to completion. This was an execution-environment permission, not a project failure.

`git diff --check d50d181..2a24cf7` passed. The real working tree and both submodules were clean before this report was created.

---

## Discrimination Sensor

All mutations were made only in `/private/tmp` copies and discarded. The real worktree was never mutated.

| Mutation | Scratch target | Behavior-level fault | Targeted result | Killed? |
| --- | --- | --- | --- | --- |
| M1 | `deploy/vps/preflight.sh:32` | Secret-file permission requirement changed from `0600` to `0644` | `tests/native-install-static.sh` failed the weakened-permission and valid-preflight assertions: 8 passed, 2 failed | YES |
| M2 | `scripts/smoke-vps.sh:5` | Expected TFS revision changed from the approved SHA to all zeroes | `tests/vps-smoke-contract.sh` failed the healthy-fixture and wrong-revision assertions: 10 passed, 2 failed | YES |
| M3 | `docker/tfs.Dockerfile:65` | Runtime identity changed from `otserv` to `root` | `tests/docker-build.sh` failed the non-root runtime assertion: 5 passed, 1 failed | YES |

**Sensor depth**: lightweight, 3 targeted mutations  
**Result**: 3 injected, 3 killed, 0 survived - PASS

---

## Code Quality

| Principle | Status | Notes |
| --- | --- | --- |
| No features beyond the requested bootstrap | PASS | Diff is confined to repositories, Docker/native bootstrap, tests, evidence, and runbooks. |
| No unnecessary abstraction/flexibility | PASS | Shell components are direct and environment-specific. |
| Surgical changes / no unrelated cleanup | PASS | All 41 changed paths trace to the feature or its approved spec process. `sources/` is untouched. |
| Matches project style/patterns | PASS | POSIX shell, explicit fixtures, exact pins, and containerized local gates are consistent. |
| Test integrity | PASS | Baseline had zero tests; no deletion, weakening, skip, or pending mechanism exists. |
| Tests map to AC, edge case, or Done-when | PASS | Harness-only assertions map to T2 Done-when; all other suites map to BOOT requirements. |
| Spec-anchored asserted values | PARTIAL | Runtime values are precise, but the native install path does not apply the already-tested exact configuration contract. |
| Per-layer coverage expectation | FAIL | No installer-path test rejects invalid ports/map; no clean-install lifecycle test proves `tfs.service` is started before readiness/smoke. |
| Senior-engineer approval | FAIL | Printing readiness before the managed service is active and accepting invalid configuration before host mutation are release-blocking bootstrap defects. |
| Documented guidelines | PASS | Project `AGENTS.md` honored (`sources/` read-only); task matrix gates used; strong defaults applied where no other quality guide exists. |

---

## Remote Evidence Review (T11)

`docs/vps-validation.md` is internally consistent with the implementation revisions and records:

- Ubuntu 24.04 amd64, MariaDB 10.11.14, exact TFS SHA, and release/environment ownership modes;
- a real initial `CHDIR` permission failure plus its two corrective commits;
- preservation of secret, marker, active release, map, schema, and data across rerun;
- two required 14/14 smoke runs plus a third post-firewall 14/14 confirmation;
- active/enabled services, MariaDB on `127.0.0.1:3306`, TFS on 7171/7172, external reachability only for TFS, two datapack completion entries, and zero fatal entries.

This proves the current manually-remediated VPS state, not the missing clean-install service-start step. No remote command or mutation was performed during this verification.

---

## Fix Plans

### Fix 1 - Enforce the full VPS configuration contract before mutation

- **Root cause**: `deploy/vps/install.sh:98-140` validates regular-file shape, placeholders, required/nonblank keys, and loopback host, but not the exact/ranged ports, map, protocol, database name/user, or the complete semantics already implemented in `scripts/validate-config.sh:33-66`. `main` calls the weaker function at `deploy/vps/install.sh:361-365` before the first mutation.
- **Fix task**: Make the installer invoke/reuse one canonical VPS validator before acquiring/installing anything; add installer-path tests for each invalid port, wrong map, wrong protocol, wrong database identity, duplicate key, and placeholder. Assert zero mutating mock calls on every rejection.
- **Verify**: `make test-static`; repeat the isolated invalid port/map diagnostic and require rejection.
- **Done when**: every spec-defined invalid VPS input exits non-zero with a clear message before packages, identities, database, files, or services are changed.
- **Priority**: Major

### Fix 2 - Start and verify TFS before declaring installation ready

- **Root cause**: `deploy/vps/install.sh:391-392` enables the unit and prints readiness without starting it. The runbook at `docs/vps.md:24-29` omits the separate start command printed to stdout, then invokes a smoke that requires an active service.
- **Fix task**: Prefer `systemctl enable --now tfs.service`, fail if `systemctl is-active --quiet tfs.service` is false, and print readiness only after the service start succeeds. Add mocked installer lifecycle assertions for call order and start failure. Update the runbook to match the chosen behavior.
- **Verify**: `make test-static`, then a clean native installation followed directly by `make test-vps`; retain sanitized 14/14 evidence.
- **Done when**: the documented clean-install sequence needs no undocumented command and cannot print readiness before TFS is active.
- **Priority**: Major

---

## Requirement Traceability Recommendation

The source spec was intentionally not edited during independent validation.

| Requirement | Current spec status | Verified recommendation |
| --- | --- | --- |
| BOOT-01 | Complete | Verified |
| BOOT-02 | Complete | Verified |
| BOOT-03 | Complete | Verified for current environments |
| BOOT-04 | Complete | Needs Fix - clean native startup/readiness |
| BOOT-05 | Complete | Verified |
| BOOT-06 | Complete | Needs Fix - installer input validation |
| BOOT-07 | Complete | Verified |
| BOOT-08 | Complete | Needs Fix - no false readiness / runbook lifecycle |

---

## Interactive UAT

Not applicable. This is backend/infrastructure bootstrap; automated local gates plus retained native VPS evidence are the appropriate validation mechanism.

---

## Lessons Self-Check

Validation contains grounded `ac_gap` signals. The reusable lessons would be:

1. Native installers must reuse the complete configuration contract before their first mutating operation.
2. Installers must not declare readiness until the managed service is active and the documented immediate smoke prerequisites are satisfied.

No lesson state was written because the verifier was explicitly restricted to a single real write: this `validation.md`. Recording via the TLC-owned script would also modify `.specs/lessons.json` and `.specs/LESSONS.md`, which was outside the granted write scope.

---

## Summary

**Overall**: NOT READY

- Story AC evidence: 17/17 current-environment outcomes, 0 spec-precision gaps
- Mandatory edge cases: 7/9 passed, 2 failed
- Tasks: 10 complete, 2 partial
- Local gate: 92 passed, 0 failed, 0 skipped
- Remote evidence: 3 recorded runs of 14 passed, 0 failed
- Sensor: 3/3 mutations killed
- Ranked gaps: (1) native installer accepts invalid semantic configuration before mutation; (2) installer/runbook declares readiness and invokes smoke without starting TFS
