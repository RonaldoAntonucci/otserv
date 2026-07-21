# Bootstrap Open Tibia Server Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user — do not proceed without it.**

---

**Design**: `.specs/features/bootstrap-open-tibia-server/design.md`
**Status**: Approved — Execute in progress

---

## Test Coverage Matrix

> Generated from the approved user strategy, `AGENTS.md`, the upstream TFS build/test configuration and the spec. No project test suite exists yet, so strong defaults apply: every acceptance criterion and listed edge case must have observable evidence.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Repository topology and revision locks | contract/integration | Owner, fork relation, Git URLs and exact pinned SHAs for all three repositories | `tests/repository-structure.sh` | `make test-static` |
| Shell validation and installers | contract | Every validation branch; required inputs; repeat execution; failure exits; no secret leakage | `tests/*-contract.sh` | `make test-static` |
| Dockerfile and development configuration | integration | Clean build success; missing/invalid inputs fail; produced binary is executable and reports pinned revision | `tests/docker-build.sh` | `make test-dev` |
| Compose, MariaDB and TFS development stack | integration | Happy path plus every spec edge/failure path: readiness order, schema initialization, persistence, ports, datapack and logs | `scripts/smoke-development.sh` | `make test-dev` |
| Native VPS templates and `systemd` unit | contract | Syntax, paths, permissions, dependency ordering, restart policy and secret boundaries | `tests/native-install-static.sh` | `make test-static` |
| Native VPS runtime | e2e | Build from pinned SHA, idempotent install, MariaDB persistence, active TFS service, listening ports, datapack load and journal evidence | `scripts/smoke-vps.sh` | `make test-vps` |
| Documentation/config examples | none | Build gate only: commands, names and paths must match implemented artifacts | `README.md`, `docs/**`, `env/**` | `make verify` |

## Parallelism Assessment

> Generated from the approved test strategy and design. Execution remains sequential because tasks share the same Git worktree and each must produce its own atomic commit.

| Test Type | Parallel-Safe? | Isolation Model | Evidence |
| --- | --- | --- | --- |
| Contract/static | Yes | Temporary directories per test; no persistent service state | Planned `tests/lib/assert.sh` and per-test temp roots |
| Docker integration | No | Shared Compose project, build cache, ports and named database volume | Planned `compose.yaml` and `scripts/smoke-development.sh` |
| Native VPS e2e | No | One VPS, one native MariaDB instance and one `tfs.service` | VPS `1826871` and `scripts/smoke-vps.sh` |

## Gate Check Commands

> Commands were explicitly approved by the user. All local project checks run through Docker; `make` only orchestrates Docker commands.

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | Repository, shell, config and static native-service tasks | `make test-static` |
| Full | Docker build, Compose, MariaDB and local TFS tasks | `make test-dev` |
| Build | Phase completion and final local verification | `make verify` |
| Remote | Native VPS installation and runtime validation | `make test-vps` |

---

## Execution Plan

### Phase 1: Repository Foundation (Sequential)

```text
T1 → T2 → T3 → T4
```

### Phase 2: Docker Development Environment (Sequential)

```text
T4 → T5 → T6 → T7
```

### Phase 3: Native VPS and Handoff (Sequential)

```text
T7 → T8 → T9 → T10 → T11 → T12
```

There are exactly three phases, so execution stays inline. No phase workers are offered. A fresh independent Verifier is still mandatory after T12.

---

## Task Breakdown

### T1: Initialize the `otserv` Project Repository

**Status**: Complete

**What**: Create public `RonaldoAntonucci/otserv`, initialize the local Git superproject on `main`, and commit the approved `.specs` artifacts plus a minimal project README.

**Where**: GitHub `RonaldoAntonucci/otserv`; repository root

**Depends on**: None

**Reuses**: Current `.specs/` artifacts and project `AGENTS.md` constraints

**Requirement**: BOOT-01

**Tools**:

- MCP: GitHub (`get_me`, `create_repository`, repository readback)
- Local: filesystem, Git
- Skill: `tlc-spec-driven`

**Done when**:

- [x] The public repository exists under `RonaldoAntonucci` with default branch `main`.
- [x] The workspace is a Git repository pointing to that remote.
- [x] `sources/` remains untouched and untracked as project code.
- [x] The approved spec, context, design and task plan are present.
- [x] Gate passes: GitHub repository readback plus clean `git status` after commit.
- [x] Verification count: 5 repository assertions pass.

**Tests**: none — repository entity/config; readback is the build gate

**Gate**: build/readback

**Commit**: `chore: initialize otserv project`

---

### T2: Add the Containerized Test Gate Harness

**Status**: Complete

**What**: Add the Docker-backed assertion runner and `Makefile` target that execute static contract tests without installing test tools on macOS.

**Where**: `Makefile`, `docker/test.Dockerfile`, `tests/run-static.sh`, `tests/harness-contract.sh`, `tests/lib/assert.sh`

**Depends on**: T1

**Reuses**: Approved commands `make test-static`, `make test-dev`, `make test-vps`, `make verify`

**Requirement**: BOOT-06, BOOT-08

**Tools**:

- MCP: none
- Local: filesystem, Docker, Git
- Skill: `tlc-spec-driven`

**Done when**:

- [x] `make test-static` runs entirely inside a pinned Ubuntu-based test image.
- [x] Assertion output reports explicit pass/fail counts and exits non-zero on failure.
- [x] A deliberate scratch assertion failure is detected by the harness.
- [x] Placeholder commands never report success for unimplemented suites.
- [x] Gate passes: `make test-static`.
- [x] Test count: exactly 4 harness contract tests pass.

**Tests**: contract

**Gate**: quick — `make test-static`

**Commit**: `test: add containerized infrastructure gate harness`

---

### T3: Fork and Pin The Forgotten Server

**Status**: Complete

**What**: Create the true TFS fork and register it as the `server/` submodule pinned to TFS `v1.6` commit `098641981400f8ff89959f427f0e8718d9dd22e2`, with repository contract assertions.

**Where**: GitHub `RonaldoAntonucci/forgottenserver`, `.gitmodules`, `server/`, `scripts/validate-repositories.sh`, `tests/repository-structure-contract.sh`

**Depends on**: T2

**Reuses**: `otland/forgottenserver` fork relation and tag `v1.6`

**Requirement**: BOOT-01, BOOT-02

**Tools**:

- MCP: GitHub (`fork_repository`, tag/repository readback)
- Local: filesystem, Git
- Skill: `tlc-spec-driven`

**Done when**:

- [x] GitHub reports `RonaldoAntonucci/forgottenserver` as a fork of `otland/forgottenserver`.
- [x] `server/` points to the user's fork and exact SHA `098641981400f8ff89959f427f0e8718d9dd22e2`.
- [x] The local submodule has an `upstream` remote for `otland/forgottenserver`.
- [x] Contract tests reject a scratch wrong owner, URL or SHA.
- [x] Gate passes: `make test-static`.
- [x] Test count: exactly 8 repository contract tests pass.

**Tests**: contract/integration

**Gate**: quick — `make test-static`

**Commit**: `chore: pin forgottenserver v1.6 fork`

---

### T4: Fork and Pin OTClient

**Status**: Complete

**What**: Create the true OTClient fork and register it as the `client/` submodule pinned to tag `4.1` commit `99d43bd6559841ee684e35082da3ea9a360d0e16`, extending repository contract assertions.

**Where**: GitHub `RonaldoAntonucci/otclient`, `.gitmodules`, `client/`, `scripts/validate-repositories.sh`, `tests/repository-structure-contract.sh`

**Depends on**: T3

**Reuses**: `opentibiabr/otclient` fork relation and documented TFS 1.6 compatibility

**Requirement**: BOOT-01, BOOT-05

**Tools**:

- MCP: GitHub (`fork_repository`, tag/repository readback)
- Local: filesystem, Git
- Skill: `tlc-spec-driven`

**Done when**:

- [x] GitHub reports `RonaldoAntonucci/otclient` as a fork of `opentibiabr/otclient`.
- [x] `client/` points to the user's fork and exact SHA `99d43bd6559841ee684e35082da3ea9a360d0e16`.
- [x] The local submodule has an `upstream` remote for `opentibiabr/otclient`.
- [x] The pinned README still declares TFS 1.6/protocol 13.10 compatibility.
- [x] Contract tests reject a scratch wrong client owner, URL, SHA or missing compatibility statement.
- [x] Gate passes: `make test-static`.
- [x] Test count: exactly 12 repository contract tests pass.

**Tests**: contract/integration

**Gate**: quick — `make test-static`

**Commit**: `chore: pin otclient 4.1 fork`

---

### T5: Define and Validate the Shared Configuration Contract

**Status**: Complete

**What**: Add ignored secret rules, safe environment examples, the shared TFS `config.lua` and a validator covering development and VPS inputs.

**Where**: `.gitignore`, `env/development.env.example`, `deploy/vps/otserv.env.example`, `docker/config.lua`, `deploy/vps/config.lua`, `scripts/validate-config.sh`, `tests/config-contract.sh`

**Depends on**: T4

**Reuses**: `server/.env.example`, `server/config.lua.dist`, TFS environment-variable support

**Requirement**: BOOT-03, BOOT-06, BOOT-07

**Tools**:

- MCP: none
- Local: filesystem, Docker, Git
- Skill: `tlc-spec-driven`

**Done when**:

- [x] Examples contain names/placeholders only and no usable credentials.
- [x] Development uses `MYSQL_HOST=db`; VPS uses loopback/local MariaDB.
- [x] Ports, map name and protocol values match the spec.
- [x] Validator rejects missing variables, blank secrets, invalid ports, wrong map and tracked secret files.
- [x] Validator accepts valid development and VPS scratch configurations.
- [x] Gate passes: `make test-static`.
- [x] Test count: exactly 14 configuration contract tests pass.

**Tests**: contract

**Gate**: quick — `make test-static`

**Commit**: `feat(config): define shared tfs environment contract`

---

### T6: Add the Development TFS Docker Build

**Status**: Complete

**What**: Add an Ubuntu 24.04 multi-stage Dockerfile that builds the pinned TFS in `RelWithDebInfo` and a co-located integration test for the produced runtime image.

**Where**: `docker/tfs.Dockerfile`, `.dockerignore`, `tests/docker-build.sh`, `Makefile`

**Depends on**: T5

**Reuses**: `server/Dockerfile`, `server/CMakeLists.txt`, `server/CMakePresets.json`

**Requirement**: BOOT-02, BOOT-06

**Tools**:

- MCP: none
- Local: filesystem, Docker BuildKit, Git
- Skill: `tlc-spec-driven`

**Done when**:

- [x] Build uses only the repository context and pinned `server/` submodule.
- [x] Runtime image contains executable TFS, config, schema and official datapack.
- [x] Image runs as a non-root user and does not declare a broad `/srv` volume.
- [x] Clean `linux/amd64` build produces an executable linked against expected runtime libraries.
- [x] A scratch invalid source/build stage is killed by the test.
- [x] Gate passes: `make test-dev` build portion.
- [x] Test count: exactly 6 Docker build integration tests pass.

**Tests**: integration

**Gate**: full — `make test-dev`

**Commit**: `feat(dev): add reproducible tfs docker build`

---

### T7: Add and Verify the Development Compose Stack

**Status**: Complete

**What**: Add the development-only TFS/MariaDB Compose stack and its complete smoke test covering initialization, readiness, persistence, datapack and failure behavior.

**Where**: `compose.yaml`, `scripts/smoke-development.sh`, `tests/docker-bootstrap.sh`, `Makefile`

**Depends on**: T6

**Reuses**: Development TFS image, MariaDB 10.11 image, `server/schema.sql`, official datapack

**Requirement**: BOOT-03, BOOT-04, BOOT-06, BOOT-07, BOOT-08

**Tools**:

- MCP: none
- Local: filesystem, Docker Compose, Git
- Skill: `tlc-spec-driven`

**Done when**:

- [x] MariaDB uses a named volume and has no published host port.
- [x] TFS waits on MariaDB `service_healthy` and publishes only `7171`/`7172`.
- [x] Empty-volume startup imports the official schema exactly once.
- [x] Restart preserves a unique test marker and does not destructively reimport schema.
- [x] TFS remains active, ports listen, official map/scripts load and logs show no fatal startup error.
- [x] Scratch missing secret, unhealthy DB and missing map mutations are all detected.
- [x] Test cleanup preserves normal developer data unless an explicit isolated test project/volume is used.
- [x] Gate passes: `make test-dev`.
- [x] Test count: exactly 18 development integration tests pass.

**Tests**: integration

**Gate**: full — `make test-dev`

**Commit**: `feat(dev): add verified tfs compose stack`

---

### T8: Add the Native VPS Service Bundle

**Status**: Complete

**What**: Add the native Ubuntu filesystem contract and hardened `systemd` unit, together with static unit/config tests executed in the test container.

**Where**: `deploy/vps/tfs.service`, `deploy/vps/paths.env`, `tests/native-install-static.sh`, `Makefile`

**Depends on**: T7

**Reuses**: Approved release paths, shared environment contract and `mariadb.service`

**Requirement**: BOOT-03, BOOT-04, BOOT-07, BOOT-08

**Tools**:

- MCP: Hostinger read-only VPS details
- Local: filesystem, Docker-based `systemd-analyze`, Git
- Skill: `tlc-spec-driven`

**Done when**:

- [x] Unit syntax passes `systemd-analyze verify` in an Ubuntu 24.04 test container.
- [x] Unit uses dedicated `otserv` user, approved paths and root-owned environment file.
- [x] Unit orders after MariaDB/network readiness and uses `Restart=on-failure`.
- [x] Preflight refuses missing executable, config, environment, datapack or database readiness.
- [x] Contract tests reject weakened permissions and removed service dependencies.
- [x] Gate passes: `make test-static`.
- [x] Test count: exactly 10 native service contract tests pass.

**Tests**: contract

**Gate**: quick — `make test-static`

**Commit**: `feat(vps): add native tfs systemd service`

---

### T9: Add the Idempotent Native VPS Installer

**Status**: Complete

**What**: Add the Ubuntu 24.04 installer that provisions dependencies, MariaDB, the dedicated user, pinned TFS release and service without destroying an existing installation.

**Where**: `deploy/vps/install.sh`, `tests/installer-contract.sh`, `Makefile`

**Depends on**: T8

**Reuses**: TFS CMake build, Ubuntu packages, native service bundle and shared schema/config

**Requirement**: BOOT-02, BOOT-03, BOOT-06, BOOT-07

**Tools**:

- MCP: Hostinger read-only machine details
- Local: filesystem, Docker-based Ubuntu contract environment, Git
- Skill: `tlc-spec-driven`

**Done when**:

- [x] Installer refuses non-Ubuntu-24.04 or unsupported architecture before mutation.
- [x] Package list matches pinned TFS CMake requirements and MariaDB 10.11 availability.
- [x] Build runs with one parallel job and activates only a successful immutable release.
- [x] Database/user/schema initialization is idempotent and never overwrites existing secrets or data.
- [x] Re-running against a fixture preserves an existing DB marker and active release on simulated build failure.
- [x] Shell/static checks find no unquoted secrets or unsafe broad destructive targets.
- [x] Gate passes: `make test-static`.
- [x] Test count: exactly 16 installer contract tests pass.

**Tests**: contract

**Gate**: quick — `make test-static`

**Commit**: `feat(vps): add idempotent native installer`

---

### T10: Add the Native VPS Smoke Test

**Status**: Complete

**What**: Add the VPS runtime smoke command and its contract tests so it can prove every native acceptance criterion after installation.

**Where**: `scripts/smoke-vps.sh`, `tests/vps-smoke-contract.sh`, `Makefile`

**Depends on**: T9

**Reuses**: `systemctl`, `journalctl`, MariaDB client, socket inspection and pinned revision files

**Requirement**: BOOT-02, BOOT-03, BOOT-04, BOOT-06, BOOT-08

**Tools**:

- MCP: Hostinger read-only machine/status details
- Local: filesystem, Docker contract fixtures, Git
- Skill: `tlc-spec-driven`

**Done when**:

- [x] `make test-vps` delegates to the native smoke script and refuses non-VPS/non-systemd environments.
- [x] Smoke checks exact source SHA, executable, MariaDB schema, persistent marker, active service and listening ports.
- [x] Smoke checks official datapack load and absence of fatal journal entries from the current boot.
- [x] Fixture tests prove each missing/broken condition causes a non-zero exit.
- [x] Output reports explicit pass/fail counts without printing secrets.
- [x] Gate passes: `make test-static` before remote execution.
- [x] Test count: exactly 12 VPS smoke contract tests pass.

**Tests**: contract

**Gate**: quick — `make test-static`

**Commit**: `test(vps): add native runtime smoke gate`

---

### T11: Install and Validate the Native Stack on the VPS

**Status**: Complete

**What**: Execute the approved installer on VPS `1826871`, run the native e2e gate twice and record sanitized evidence.

**Where**: VPS `1826871`; `docs/vps-validation.md`

**Depends on**: T10

**Reuses**: `deploy/vps/install.sh`, `scripts/smoke-vps.sh`, Hostinger machine details

**Requirement**: BOOT-02, BOOT-03, BOOT-04, BOOT-07, BOOT-08

**Tools**:

- MCP: Hostinger for machine/firewall readback
- External authority required: SSH terminal or user-executed installer
- Local: filesystem, Git
- Skill: `tlc-spec-driven`

**Done when**:

- [x] SSH/terminal execution authority is available; otherwise this task stops without VPS mutation.
- [x] Installer succeeds on Ubuntu 24.04 and activates the pinned TFS release.
- [x] `make test-vps` passes before and after a service restart.
- [x] A second installer run preserves DB marker, secrets and active data.
- [x] MariaDB listens only locally and TFS listens on configured ports.
- [x] Sanitized evidence records revisions, service states, test counts and timestamps without credentials/IP secrets beyond already public VPS metadata.
- [x] Gate passes: `make test-vps` twice.
- [x] Test count: exactly 14 native e2e assertions pass on each run.

**Tests**: e2e

**Gate**: remote — `make test-vps`

**Commit**: `docs: record native vps bootstrap validation`

---

### T12: Publish the Reproducible Bootstrap Runbook

**What**: Complete the README/runbook for cloning with submodules, Docker development, native VPS installation, logs, recovery and all approved gates.

**Where**: `README.md`, `docs/development.md`, `docs/vps.md`, `Makefile`

**Depends on**: T11

**Reuses**: Commands and evidence from T1–T11

**Requirement**: BOOT-01, BOOT-02, BOOT-03, BOOT-04, BOOT-05, BOOT-06, BOOT-07, BOOT-08

**Tools**:

- MCP: GitHub repository readback
- Local: filesystem, Docker, Git
- Skill: `tlc-spec-driven`

**Done when**:

- [ ] A clean clone command initializes both pinned submodules.
- [ ] Development instructions use Docker only and document `make test-static`, `make test-dev` and `make verify`.
- [ ] VPS instructions use native packages/services only and document `make test-vps` plus the SSH limitation.
- [ ] Log, restart, update, rollback and safe data-preservation commands match implemented artifacts.
- [ ] No command references missing files, wrong repository names or unimplemented behavior.
- [ ] Full local gate passes: `make verify`.
- [ ] Remote evidence from T11 remains passing and linked.
- [ ] Expected aggregate count: 64 local assertions plus 14 native e2e assertions, with no silent deletion.

**Tests**: none — documentation/config; full build gate

**Gate**: build — `make verify`, plus retained `make test-vps` evidence

**Commit**: `docs: publish otserv bootstrap runbook`

---

## Parallel Execution Map

```text
Phase 1 — Repository Foundation
  T1 → T2 → T3 → T4

Phase 2 — Docker Development
  T4 → T5 → T6 → T7

Phase 3 — Native VPS and Handoff
  T7 → T8 → T9 → T10 → T11 → T12
```

No task is marked `[P]`: although static tests can be isolated, every task changes the shared worktree and must be gated and committed atomically before the next begins.

---

## Task Granularity Check

| Task | Single Deliverable | Status |
| --- | --- | --- |
| T1 | Initialized project repository | ✅ Granular |
| T2 | Containerized test gate harness | ✅ Granular |
| T3 | Pinned TFS fork/submodule | ✅ Granular |
| T4 | Pinned OTClient fork/submodule | ✅ Granular |
| T5 | Shared configuration contract | ✅ Cohesive contract bundle |
| T6 | Development TFS image | ✅ Component + co-located tests |
| T7 | Development Compose stack | ✅ Component + co-located smoke tests |
| T8 | Native service bundle | ✅ Cohesive service bundle + tests |
| T9 | Native installer | ✅ Component + co-located tests |
| T10 | Native smoke gate | ✅ Component + co-located tests |
| T11 | Validated VPS installation | ✅ One external deployment outcome |
| T12 | Bootstrap runbook | ✅ Documentation handoff |

**Result**: all tasks pass the granularity gate.

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | Start → T1 | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | T2 | T2 → T3 | ✅ Match |
| T4 | T3 | T3 → T4 | ✅ Match |
| T5 | T4 | T4 → T5 | ✅ Match |
| T6 | T5 | T5 → T6 | ✅ Match |
| T7 | T6 | T6 → T7 | ✅ Match |
| T8 | T7 | T7 → T8 | ✅ Match |
| T9 | T8 | T8 → T9 | ✅ Match |
| T10 | T9 | T9 → T10 | ✅ Match |
| T11 | T10 | T10 → T11 | ✅ Match |
| T12 | T11 | T11 → T12 | ✅ Match |

**Result**: diagram and task definitions are consistent.

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1 | Repository entity/config | none + readback | none/readback | ✅ OK |
| T2 | Test harness | contract | contract | ✅ OK |
| T3 | Repository topology | contract/integration | contract/integration | ✅ OK |
| T4 | Repository topology | contract/integration | contract/integration | ✅ OK |
| T5 | Shell/config contract | contract | contract | ✅ OK |
| T6 | Dockerfile/runtime image | integration | integration | ✅ OK |
| T7 | Compose/database/runtime | integration | integration | ✅ OK |
| T8 | Native service/config | contract | contract | ✅ OK |
| T9 | Native installer | contract | contract | ✅ OK |
| T10 | Native smoke logic | contract | contract | ✅ OK |
| T11 | Native VPS runtime | e2e | e2e | ✅ OK |
| T12 | Documentation/config | none + build gate | none/build | ✅ OK |

**Result**: all implementation tasks include their required tests in the same task; no test deferral exists.

---

## Requirement Coverage

| Requirement | Tasks | Coverage |
| --- | --- | --- |
| BOOT-01 | T1, T3, T4, T12 | ✅ |
| BOOT-02 | T3, T6, T9, T10, T11, T12 | ✅ |
| BOOT-03 | T5, T7, T8, T9, T10, T11, T12 | ✅ |
| BOOT-04 | T7, T8, T10, T11, T12 | ✅ |
| BOOT-05 | T4, T12 | ✅ |
| BOOT-06 | T2, T5, T6, T7, T9, T10, T12 | ✅ |
| BOOT-07 | T5, T7, T8, T9, T11, T12 | ✅ |
| BOOT-08 | T2, T7, T8, T10, T11, T12 | ✅ |

**Coverage**: 8 total, 8 mapped, 0 unmapped.

---

## Proposed Tool Assignment for Approval

| Task Range | MCPs / Tools | Skills |
| --- | --- | --- |
| T1, T3, T4, T12 | GitHub MCP, filesystem, Git | `tlc-spec-driven` |
| T2, T5–T10 | Filesystem, Git, Docker/Compose; Hostinger read-only where noted | `tlc-spec-driven` |
| T11 | Hostinger MCP plus a separate SSH terminal or user execution | `tlc-spec-driven` |

No coding-navigation skill is proposed because this is greenfield orchestration rather than an unfamiliar existing codebase change.
