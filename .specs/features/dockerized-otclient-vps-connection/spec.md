# Docker-built Windows OTClient and First VPS Connection Specification

> **Status: PAUSED — REQUIRES RE-SPECIFICATION BEFORE DESIGN.** On 2026-07-21, after this specification was approved, the user replaced the Docker/MinGW build strategy with a native Windows MSVC/vcpkg build. The `OTC-BLD-*` requirements and all dependent Docker/MinGW or NSIS assumptions below are preserved only as historical research and MUST NOT be implemented. Runtime, persistent CrossOver installation, test-account, and VPS-connection outcomes remain candidates for the revised specification.

## Problem Statement

The OTClient fork is pinned to a known baseline but has not yet been configured, packaged into a project-owned NSIS installer, and persistently installed as a Windows client from the Docker-only Apple Silicon macOS environment or proven against the native TFS instance on the VPS. The project needs a repeatable Windows x64 payload and user-level installer built without host project toolchains, an atomic self-contained installation and isolated profile in the existing CrossOver bottle, persistent Windows/CrossOver launchers, a safe test identity, and end-to-end evidence that the character enters the VPS world.

## Goals

- [ ] Advance the pinned OTClient baseline through a traceable fork commit and build that exact root-pinned revision as a self-contained Windows x64 payload plus project-owned NSIS installer entirely inside Docker Desktop on Apple Silicon macOS.
- [ ] Configure the package for TFS protocol 13.10, install/update it atomically in a dedicated directory of the existing CrossOver 26.2 `Steam` Windows 10 bottle, and leave one persistent launcher using an isolated OTClient profile.
- [ ] Provision exactly one persistent test account and character on the VPS without committing, logging, or persistently copying their password or digest outside the approved secret/database locations.
- [ ] Validate the ordered path from source identity and Docker cross-build through CrossOver login, asset installation, character list, and world entry with sanitized, repeatable evidence.

## Out of Scope

| Feature | Reason |
| --- | --- |
| Native macOS `.app`, Linux GUI runtime container, noVNC, or WebAssembly client | The delivery target is a Windows x64 client executed through CrossOver. |
| Installing, licensing, upgrading, deleting, renaming, or creating a CrossOver bottle | CrossOver 26.2 and the existing `Steam` Windows 10 bottle are operator-provided prerequisites. |
| Installing compilers, CMake, vcpkg, MinGW, Visual Studio, Wine, libraries, or other project build/runtime dependencies directly on macOS | All project build dependencies must remain inside Docker. |
| Falling back to Windows containers, a remote Windows builder, GitHub Actions artifacts, or a host toolchain | This feature specifically proves the local Docker-on-macOS cross-build. |
| General-purpose MinGW support, broad CI matrix expansion, or unrelated client modernization | Only minimal fork changes required for this Windows x64 Docker cross-build are in scope. |
| Public client download/update service, release signing, or final branding | The project-owned local NSIS installer is in scope solely for this validated installation; public distribution remains a later feature. |
| Running third-party installers or installing additional Windows components, package managers, redistributables, or unrelated launchers/shortcuts into `Steam` | Only the project-owned NSIS installer, its verified OTServ Start Menu shortcut, and the derived CrossOver launcher are permitted; VC++ redistributables and unrelated bottle software remain untouched. |
| Website, account manager, email flow, or self-service registration | Test identity provisioning is an operator-only bootstrap action. |
| Definitive datapack or production player onboarding | The official TFS datapack remains the technical validation baseline. |
| Password recovery/rotation or automated deletion of the test identity | A lost or mismatched test secret fails closed; lifecycle changes require a later explicit operator workflow. |

---

## Assumptions & Open Questions

Every ambiguity is resolved or recorded here. Approval of this specification confirms all proposed defaults.

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Client target | Self-contained Windows x64 payload (`PE32+`, x86-64) plus a project-owned NSIS 3.09 installer, using OpenGL with `TOGGLE_DIRECTX=OFF` | Matches CrossOver while avoiding DirectX or redistributable installation in the shared bottle. | Windows x64 confirmed by user; OpenGL proposed |
| Client source identity | `99d43bd6559841ee684e35082da3ea9a360d0e16` is the immutable starting baseline. VPS endpoint, isolated-profile identity, and minimal cross-build portability changes are committed to `RonaldoAntonucci/otclient`; the root repository then pins `client` to that resulting full commit SHA. | Preserves AD-007 provenance while allowing this feature to configure the fork. | Proposed |
| Build environment | Cross-compile inside Linux Docker stages pinned by digest with a pinned MinGW-w64 x86-64 toolchain and the fork's pinned vcpkg baseline; generate the installer with NSIS 3.09 running natively in a `linux/arm64` packaging stage; no fallback builder is permitted. | Docker Desktop on Apple Silicon can run the proven NSIS packaging tool natively while the emitted client payload remains Windows x64. | Docker-only confirmed by user; NSIS 3.09 arm64 proven by research |
| Build repeatability | Require identical logical package contents across repeated builds and report all byte-level differences; byte-identical reproducible builds are not claimed. | The client embeds build metadata, so repeatability must not be misrepresented as deterministic bytes. | Proposed |
| CrossOver runtime | Reuse the existing CrossOver 26.2 bottle named `Steam`, observed as Windows 10 / Ready. | Uses the existing user-provided bottle without creating or installing another runtime. | Existing bottle confirmed by user; exact name observed locally |
| CrossOver profile isolation | Use organization `otserv` and compact name `otclient-vps-smoke`; keep Remember password, Stay logged in, and autologin disabled. | PHYSFS derives a distinct preference namespace from organization/application identity, avoiding the default `otcr/otclient` profile. | Proposed |
| Artifact and bottle installation layout | Publish immutable host artifacts under `artifacts/otclient-windows-x64/<client-sha>/<manifest-sha256>/`; the NSIS installer uses `RequestExecutionLevel user` and installs only under `%LOCALAPPDATA%\OTServ\OTClient` inside `Steam`, using `releases`, `.staging`, `rollback`, and a CrossOver-resolvable atomically replaceable `current` activation indirection. | Keeps installation user-scoped, self-contained, and bounded while preventing partial activation. | User-level NSIS path confirmed by user |
| Persistent launchers | After installed payload verification, create `$SMPROGRAMS\OTServ\OTServ OTClient.lnk` targeting `%LOCALAPPDATA%\OTServ\OTClient\current\otclient.exe`, then derive exactly one CrossOver launcher named `OTServ OTClient` from that verified shortcut. | Leaves the client accessible in both the bottle and CrossOver while keeping metadata stable across updates. | Confirmed by user |
| VPS endpoint embedded in the fork | `srv1826871.hstgr.cloud`, login port `7171`, protocol/client `1310` | Uses the already validated public hostname and TFS 1.6 protocol baseline. | Proposed |
| Client assets | Keep the strict auto-installer in the installed `current` tree; during update, reuse only previously verified protocol-1310 assets copied into staging and reverify them before activation. | Preserves downloaded assets across updates without committing them or weakening the mandatory runtime contract. | Proposed |
| Test identity | Account `otserv-smoke`, character `Docker Scout`, and one randomly generated 32-character password from `[A-Za-z0-9_-]` | Fixed technical names and a high-entropy URL-safe secret make validation precise without a shared default password. | Proposed |
| Secret handoff | Store exactly three keys in ignored `env/client-test.env`, owned by the current user, regular/non-symlink, mode `0600`; the operator types the password into the GUI with persistence controls disabled. | The provisioning workflow and GUI need the credential while Git, process arguments, and reports must not receive it. | Proposed |
| VPS provisioning | Use an idempotent transaction over strict-host-key-checked authenticated SSH and the VPS-native MariaDB Unix socket as root. | Reuses the established native VPS trust boundary without exposing MariaDB. | Proposed |
| Initial player fixture | Create `Docker Scout` with `town_id=1` and `posx=0`, `posy=0`, `posz=0` only after proving the exact deployed map has a valid, non-zero, placeable temple for town 1. | TFS resolves an all-zero login position to the town temple, but an absent town or invalid temple would prevent world entry. | Proposed |
| Successful first connection | The only active character for the test account is returned, enters the official bootstrap map, appears in `players_online` while connected, and advances `players.lastlogin` after a clean disconnect/save. | Uses observable database and visual outcomes instead of merely proving an open socket. | Proposed |

**Open questions:** none — all current ambiguities are confirmed or logged as proposed defaults above.

---

## User Stories

### P1: Traceable Docker-only Windows client build ⭐ MVP

**User Story**: As the macOS developer, I want the configured fork built as a traceable Windows x64 package using Docker so that no project build dependency is installed directly on macOS.

**Why P1**: CrossOver cannot validate the fork until a compatible artifact exists, and both source provenance and host isolation are project constraints.

**Acceptance Criteria**:

1. **OTC-BLD-01** — WHEN any client build starts THEN the gate SHALL verify that `client/` is clean, its `HEAD` equals the root repository's recorded submodule gitlink, and that commit descends from baseline `99d43bd6559841ee684e35082da3ea9a360d0e16`; the package manifest SHALL record the root commit, final client commit, and baseline commit.
2. **OTC-BLD-02** — WHEN the feasibility gate runs on Apple Silicon Docker Desktop THEN the pinned Linux builder SHALL configure, compile, and link the final client commit as a self-contained `PE32+` x86-64 payload using a pinned MinGW-w64 toolchain, `x64-mingw-static`, the pinned vcpkg baseline, and OpenGL with `TOGGLE_DIRECTX=OFF`, then generate the project installer with NSIS `3.09` running natively in a pinned `linux/arm64` stage; any required port/source/installer incompatibility SHALL fail without fallback to Windows containers, a remote builder, another installer, or a host toolchain.
3. **OTC-BLD-03** — WHEN a clean build succeeds THEN publication SHALL stage a complete package on the same filesystem and atomically rename it to `artifacts/otclient-windows-x64/<40-char-client-sha>/<64-char-manifest-sha256>/`; an identical existing package is a no-op, while a conflicting existing directory SHALL remain untouched and fail the gate.
4. **OTC-BLD-04** — WHEN the artifact is published THEN it SHALL contain the self-contained payload (`otclient.exe`, `data/`, `modules/`, `mods/`, `init.lua`, `otclientrc.lua`, `cacert.pem`, and required runtime DLLs) embedded in the project NSIS installer, its source script declaring `RequestExecutionLevel user`, and a canonical `artifact-manifest.json` containing SHA-256 and size for every other file plus builder image digests, MinGW and NSIS versions, vcpkg baseline, build options, and source identities; installation SHALL require no network download or third-party installer.
5. **OTC-BLD-05** — WHEN artifact imports are inspected inside Docker THEN every installed payload executable/DLL SHALL be `PE32+` x86-64, no Mach-O or ELF runtime binary SHALL be installed, and each recursively imported non-system payload DLL SHALL be embedded in the installer; system DLL classification SHALL use a committed reviewable allowlist with one exact case-insensitive basename per line and no patterns/globs. The only payload-architecture exception SHALL be the verified stock NSIS 3.09 installer stub, which is packaging machinery and SHALL NOT be copied into the installed runtime closure.
6. **OTC-BLD-06** — WHEN the same root/client commits, pinned builder, toolchain, dependency baseline, and build options are built twice THEN the two canonical manifests SHALL contain the same logical file paths; the gate SHALL emit a sanitized added/removed/changed summary for byte differences and SHALL never claim byte reproducibility when hashes differ.
7. **OTC-BLD-07** — WHEN host prerequisites are documented or checked THEN they SHALL be limited to Docker Desktop, Git/SSH, CrossOver 26.2, and tools already shipped with macOS; documentation and scripts SHALL NOT prescribe a host package manager or install a compiler, CMake, vcpkg, MinGW, Wine, library, or project runtime on macOS.

**Independent Test**: From a clean Docker cache boundary, verify the root/client SHA relationship, build the x64 static payload, generate the user-level installer with native-arm64 NSIS 3.09, publish and inspect its complete payload/import closure in Docker, repeat the build, and confirm that macOS received only ignored generated artifacts rather than installed project dependencies.

### P1: Persistent isolated VPS-ready CrossOver installation ⭐ MVP

**User Story**: As the operator, I want the Windows client preconfigured, persistently installed, safely updateable, and isolated inside the existing bottle so that it remains accessible after validation without disturbing Steam or unrelated bottle state.

**Why P1**: Endpoint, installation, launcher, profile, asset, or CrossOver drift would make a successful compile unusable, ephemeral, or unsafe in the shared bottle.

**Acceptance Criteria**:

1. **OTC-RUN-01** — WHEN CrossOver preflight runs THEN it SHALL prove CrossOver version `26.2`, bottle name `Steam`, Windows 10 bottle type, and Ready status before any launch or remote mutation; a mismatch SHALL fail without changing the bottle.
2. **OTC-RUN-02** — WHEN a fresh OTClient profile is required THEN the runtime SHALL use only the PHYSFS preference namespace derived from organization `otserv` and compact name `otclient-vps-smoke`; resetting that profile SHALL first prove canonical containment inside `Steam`, move only that exact namespace to `$LOCALAPPDATA\OTServ\OTClient\rollback\profiles\<UTC-timestamp>`, and SHALL NOT delete or recreate the bottle.
3. **OTC-RUN-03** — WHEN the published project installer is selected in `Steam` THEN it SHALL prove that its script declares `RequestExecutionLevel user`, run without elevation, resolve `$LOCALAPPDATA\OTServ\OTClient` as the only installation root, prove canonical containment there, and extract the complete manifest-bound payload into `$LOCALAPPDATA\OTServ\OTClient\.staging\<manifest-sha256>` without writing into Steam's application directories or any unrelated bottle path.
4. **OTC-RUN-04** — WHEN staging is complete THEN the project installer SHALL verify the staged manifest and full PE import closure, preserve previously installed protocol-1310 assets only by copying them into the OTC-standard staged paths and reverifying their strict hashes, record package and asset identities in a separate installation-state manifest, close any running isolated OTClient process, publish staging as `$LOCALAPPDATA\OTServ\OTClient\releases\<manifest-sha256>`, and atomically replace the CrossOver-resolvable `current` activation indirection so it resolves wholly to that release; it SHALL retain the immediately previous working release and activation identity under `rollback` and SHALL never expose a partially copied `current`.
5. **OTC-RUN-05** — WHEN installation/update is repeated with the same package and installation-state manifests already active THEN it SHALL be a no-op; WHEN activation or the post-install launch health gate fails THEN it SHALL atomically repoint `current` to the previous working release, preserve the failed staged/release evidence, and leave unrelated Steam software and the isolated profile unchanged.
6. **OTC-RUN-06** — WHEN installed payload verification and activation succeed THEN the project installer SHALL create exactly one Windows shortcut at `$SMPROGRAMS\OTServ\OTServ OTClient.lnk` targeting `$LOCALAPPDATA\OTServ\OTClient\current\otclient.exe` with that `current` directory as working directory; only after the shortcut is verified SHALL the workflow derive exactly one persistent CrossOver launcher named `OTServ OTClient` for `Steam`, and both launchers SHALL remain valid across atomic update/rollback.
7. **OTC-RUN-07** — WHEN the derived persistent CrossOver launcher starts the installed client THEN `otclient.exe` SHALL resolve from `$LOCALAPPDATA\OTServ\OTClient\current`, use that directory as its work directory, display a responsive login window within 120 seconds, and remain free of missing-DLL, unsupported-architecture, OpenGL-context, or fatal rendering errors.
8. **OTC-RUN-08** — WHEN a fresh isolated profile opens the login screen THEN it SHALL select `srv1826871.hstgr.cloud`, port `7171`, client version `1310`, and raw/non-HTTP login by default.
9. **OTC-RUN-09** — WHEN installed client configuration is validated THEN it SHALL contain no placeholder public server such as `ip.net`, SHALL keep `strictManifestSha256 = true` and `allowRawFallbackHashMismatch = false`, and SHALL use organization `otserv` and compact name `otclient-vps-smoke`.
10. **OTC-RUN-10** — WHEN protocol 13.10 assets are installed THEN final runtime files SHALL exist only under `$LOCALAPPDATA\OTServ\OTClient\current\data\things\1310`, `$LOCALAPPDATA\OTServ\OTClient\current\data\sounds\1310`, and explicitly documented runtime-extra paths beneath `current`; the immutable host artifact SHALL remain unchanged and no alternate permanent asset root SHALL become the runtime source of truth.
11. **OTC-RUN-11** — WHEN credentials are entered and the client later exits THEN Remember password, Stay logged in, and autologin SHALL remain false, and neither the isolated profile, dedicated installation tree, launcher metadata, client/CrossOver logs, nor collected evidence SHALL contain the plaintext password or its SHA-1 digest.
12. **OTC-RUN-12** — WHEN the feature operates in the shared bottle THEN it SHALL invoke only the project-owned, manifest-verified NSIS installer; it SHALL NOT run a third-party installer, install VC++/DirectX redistributables or other Windows components, create any shortcut/launcher beyond `$SMPROGRAMS\OTServ\OTServ OTClient.lnk` and the derived `OTServ OTClient` CrossOver launcher, create/delete/rename a bottle, or intentionally write/delete outside `$LOCALAPPDATA\OTServ\OTClient`, the isolated preference namespace, those two launchers' minimum metadata, and incidental CrossOver-managed runtime metadata.

**Independent Test**: Verify the exact bottle/version/type/status and `RequestExecutionLevel user`, run the project installer without elevation, verify staging/activation before shortcut creation, derive the CrossOver launcher from the validated Start Menu shortcut, use a fresh isolated profile to inspect defaults/assets, repeat the same install for a no-op, inject a bad replacement for rollback, and prove that all project-controlled writes and credential checks remain inside the dedicated installation/profile/launcher scopes.

### P1: Transactional test identity provisioning ⭐ MVP

**User Story**: As the operator, I want a safe repeatable way to create the test account and character so that end-to-end login can be validated without manual SQL or a public account website.

**Why P1**: A precisely linked account and loadable player are required for a real protocol login and world-entry proof.

**Acceptance Criteria**:

1. **OTC-PROV-01** — WHEN `env/client-test.env` is accepted THEN it SHALL be an ignored regular file, not a symlink, owned by the current macOS user, mode exactly `0600`, and contain exactly `CLIENT_TEST_ACCOUNT=otserv-smoke`, `CLIENT_TEST_CHARACTER=Docker Scout`, and `CLIENT_TEST_PASSWORD=<32 characters matching [A-Za-z0-9_-]{32}>`, with no duplicate keys, extra keys, blank values, surrounding whitespace, newline inside a value, or placeholder token.
2. **OTC-PROV-02** — WHEN the secret is handled THEN plaintext SHALL exist only in the approved `0600` file, non-exported process memory, SSH standard input when strictly required, and the visible GUI password field; plaintext or digest SHALL NOT appear in command arguments, Docker build arguments/layers, exported child-process environments, shell tracing/history, persistent temporary files, stdout/stderr, client/CrossOver logs, committed/generated artifacts, or evidence reports.
3. **OTC-PROV-03** — WHEN provisioning connects to the VPS THEN it SHALL use authenticated SSH with host-key verification enabled and the expected host identity, and MariaDB SHALL be accessed only through the VPS-native Unix socket as root; no database port or public provisioning endpoint SHALL be opened.
4. **OTC-PROV-04** — WHEN provisioning preflight runs THEN it SHALL inspect the exact map file resolved from the currently deployed VPS release and prove that `town_id=1` exists, has a non-zero temple position, and that the temple position resolves to a placeable map tile; failure SHALL abort before starting the account/player transaction.
5. **OTC-PROV-05** — WHEN no matching identity exists and preflight passes THEN one transaction SHALL create account `otserv-smoke` with the TFS-compatible SHA-1 digest and exactly one non-deleted player `Docker Scout` linked to it with `town_id=1`, `posx=0`, `posy=0`, and `posz=0`; the transaction SHALL commit only after the exact account/player cardinality and linkage are verified.
6. **OTC-PROV-06** — WHEN account `otserv-smoke` and character `Docker Scout` already exist THEN provisioning SHALL be a no-op only if the stored digest equals SHA-1 of the supplied password, exactly one non-deleted player belongs to the account, and `Docker Scout` is that player's exact name and linkage; the no-op SHALL leave password and player state unchanged.
7. **OTC-PROV-07** — WHEN digest, account/player linkage, active-player cardinality, name identity, or any requested identity conflicts THEN provisioning SHALL fail before mutation and report only sanitized booleans/counts, never the password or digest.
8. **OTC-PROV-08** — WHEN provisioning is interrupted or two attempts overlap THEN transaction/locking and database uniqueness constraints SHALL prevent partial, duplicate, or cross-linked identities; every retry SHALL converge either to the exact no-op state in `OTC-PROV-06` or the fail-closed conflict in `OTC-PROV-07`.
9. **OTC-PROV-09** — WHEN TFS or MariaDB is inactive, the deployed release/map cannot be identified, SSH trust fails, or the map probe cannot prove the temple contract THEN provisioning SHALL fail without service reconfiguration, partial identity creation, or mutation of unrelated VPS data.

**Independent Test**: Reject malformed/unsafe secret fixtures locally, prove the deployed town-1 temple contract, provision once, query sanitized digest-match/count/linkage/fixture-state booleans, rerun for an exact no-op, and inject mismatch, interruption, and concurrency faults to prove fail-closed transaction behavior.

### P1: First character connection and correlated evidence ⭐ MVP

**User Story**: As the developer, I want to log the test character into the VPS from the Docker-built Windows client in CrossOver so that source identity, packaging, assets, authentication, protocol, network, map, and server runtime are proven together.

**Why P1**: This vertical slice demonstrates that the built client and deployed server actually interoperate.

**Acceptance Criteria**:

1. **OTC-CONN-01** — WHEN valid test credentials are submitted from the manifest-bound installed `current` release through the persistent CrossOver launcher THEN the VPS SHALL return a character list containing exactly one active identity, `Docker Scout`, for account `otserv-smoke`.
2. **OTC-CONN-02** — WHEN `Docker Scout` is selected THEN the client SHALL enter the official bootstrap map, render the character and surrounding world, and show no missing-DLL, protocol-version, asset-loading, temple-position, or fatal rendering error.
3. **OTC-CONN-03** — WHEN connection evidence is collected THEN it SHALL record root/baseline/final-client commits, artifact and active installation-state manifest identities, active `current` release resolution, builder/toolchain identity, verified Start Menu shortcut and derived CrossOver launcher identities, CrossOver version and bottle type/name, isolated profile identity, configured endpoint/protocol, sanitized database linkage, TFS/MariaDB service state, exactly one joined `players_online` row while connected, UTC attempt bounds, and a `players.lastlogin` value after clean disconnect/save that is greater than its pre-attempt value and falls within those bounds; no credential or digest SHALL be recorded.
4. **OTC-CONN-04** — WHEN build, package, CrossOver preflight/profile/install/launcher/launch, town probe, provisioning, asset download, TCP `7171`, authentication, TCP `7172`, world entry, online evidence, or logout evidence fails THEN the workflow SHALL exit non-zero with exactly one matching stage label from `SOURCE`, `BUILD`, `PACKAGE`, `CROSSOVER_PREFLIGHT`, `PROFILE`, `INSTALL`, `LAUNCHER`, `PROVISION`, `ASSETS`, `LOGIN_7171`, `AUTH`, `GAME_7172`, `WORLD`, `ONLINE_EVIDENCE`, or `LOGOUT_EVIDENCE`, preserve prior package/VPS/working installation/unrelated-bottle state, and remain safe to retry.
5. **OTC-CONN-05** — WHEN the end-to-end workflow runs THEN it SHALL enforce this order: root/client SHA gate → Docker feasibility/build → atomic host package/PE verification → CrossOver bottle/profile preflight → atomic bottle installation/launcher health → deployed-map/town probe → identity transaction/no-op → persistent-launcher start → verified asset installation → TCP `7171` character list → TCP `7172` world entry → online evidence → clean disconnect/save → lastlogin evidence; no later stage SHALL be reported successful if a predecessor failed.

**Independent Test**: Use the persistent launcher with a fresh isolated profile, complete the ordered workflow from the installed release, capture the exact one-character list and visual world entry, prove the joined online row while connected, disconnect cleanly, and correlate the bounded `lastlogin` advance with sanitized source/package/installation/service evidence.

---

## Edge Cases

- **OTC-EDGE-01** — WHEN Docker Desktop is unavailable or the pinned cross-toolchain cannot execute on the current Apple Silicon host THEN the workflow SHALL fail at `BUILD` before package publication, bottle mutation, provisioning, or other remote mutation.
- **OTC-EDGE-02** — WHEN a pinned vcpkg port or OTClient source is incompatible with MinGW-w64 THEN the feasibility gate SHALL report the exact port/source blocker and SHALL NOT weaken pins, switch toolchains/builders, disable a required runtime capability, or install anything on macOS.
- **OTC-EDGE-03** — WHEN a PE import is missing, a binary has the wrong architecture, the system-DLL allowlist contains a pattern, or a Mach-O/ELF runtime enters staging THEN atomic publication SHALL not occur and any previously published package SHALL remain unchanged.
- **OTC-EDGE-04** — WHEN the `Steam` bottle is absent, not Ready, not Windows 10, already has the isolated OTClient process/profile or installation tree actively in use, or is opened by a conflicting feature operation THEN the workflow SHALL fail before profile reset, install/update, launcher mutation, launch, or remote mutation.
- **OTC-EDGE-05** — WHEN an isolated profile already exists and a fresh profile is requested THEN only a successful contained timestamped backup SHALL permit recreation; backup or containment failure SHALL preserve the existing profile and stop at `PROFILE`.
- **OTC-EDGE-06** — WHEN TCP `7171` or `7172` is unreachable from the actual CrossOver-run client path THEN the workflow SHALL identify the corresponding `LOGIN_7171` or `GAME_7172` stage without printing credentials and SHALL not report authentication/world success.
- **OTC-EDGE-07** — WHEN the client-assets source is unavailable, a manifest/hash check fails, or installation resolves outside the allowed runtime roots THEN login SHALL not continue with incomplete, unverified, or misplaced assets.
- **OTC-EDGE-08** — WHEN the map probe finds town 1 absent, its temple zero/invalid, the tile non-placeable, or the inspected map does not belong to the current deployed release THEN no identity transaction SHALL begin.
- **OTC-EDGE-09** — WHEN an existing account has a different digest, zero/multiple active players, an extra active character, or `Docker Scout` linked elsewhere THEN provisioning SHALL fail before mutation and the connection workflow SHALL not attempt login.
- **OTC-EDGE-10** — WHEN install/update is interrupted, staging is incomplete, shortcut/launcher creation fails, or the new `current` release fails its health gate THEN an existing previous working `current` and launcher target SHALL be restored atomically when activation had begun; on a first install with no previous release, `current`, the Start Menu shortcut, and the CrossOver launcher SHALL remain absent/inactive. In both cases, failed staging/release evidence and profile backups SHALL not be overwritten, and no unrelated `Steam` bottle software or VPS row SHALL be deleted or reset.

---

## Implicit-Requirement Dimensions

| Dimension | Resolution and requirement references |
| --- | --- |
| Input validation & bounds | Exact source SHA form, PE architecture/import closure, bottle/install containment, secret schema/mode/owner/pattern, endpoint/protocol, and map fixture are defined by `OTC-BLD-01`, `OTC-BLD-05`, `OTC-RUN-01`, `OTC-RUN-03`, `OTC-PROV-01`, and `OTC-PROV-04`. |
| Failure / partial-failure states | Atomic package publication, contained profile backup, atomic install activation/rollback, transactional provisioning, stage-labelled failure, and preservation are required by `OTC-BLD-03`, `OTC-RUN-02`, `OTC-RUN-04`, `OTC-RUN-05`, `OTC-PROV-08`, `OTC-CONN-04`, `OTC-EDGE-03`, `OTC-EDGE-05`, and `OTC-EDGE-10`. |
| Idempotency / retry / duplicate handling | Package no-op/conflict behavior, manifest comparison, installation no-op/rollback, exact provisioning no-op/conflict, and rerun preservation are defined by `OTC-BLD-03`, `OTC-BLD-06`, `OTC-RUN-03`–`OTC-RUN-06`, `OTC-PROV-06`–`OTC-PROV-08`, and `OTC-EDGE-10`. |
| Auth boundaries & rate limits | Secret containment, strict SSH host verification, MariaDB Unix-socket-only access, disabled credential persistence, and sanitized evidence are required by `OTC-PROV-02`, `OTC-PROV-03`, `OTC-RUN-11`, and `OTC-CONN-03`. Public provisioning rate limiting is N/A because no public provisioning endpoint exists; changing TFS public-login throttling is outside this single test-attempt feature. |
| Concurrency / ordering | Database transactions/uniqueness, active shared-profile/installation exclusion, local atomic publication/activation, and full gate order are required by `OTC-PROV-08`, `OTC-EDGE-04`, `OTC-BLD-03`, `OTC-RUN-04`, and `OTC-CONN-05`. |
| Data lifecycle / expiry | Immutable host packages, retained bottle releases/current/rollback, persistent verified assets, recoverable isolated-profile backups, persistent launcher, and persistent test identity are defined by `OTC-RUN-02`–`OTC-RUN-06`, `OTC-RUN-10`, `OTC-EDGE-10`, and Out of Scope. Automated identity expiry/deletion and password rotation are explicitly out of scope. |
| Observability | Canonical source/package manifests, repeat-build diffs, installation/launcher/launch outcome, stage labels, joined online row, bounded lastlogin advance, and sanitized service/runtime identity are required by `OTC-BLD-04`, `OTC-BLD-06`, `OTC-RUN-04`–`OTC-RUN-07`, `OTC-CONN-03`, and `OTC-CONN-04`. |
| External-dependency failure | Docker/toolchain/vcpkg, CrossOver/bottle, asset host, SSH/VPS services, network ports, and deployed-map failures halt without fallback or unrelated mutation under `OTC-BLD-02`, `OTC-RUN-01`, `OTC-PROV-09`, and `OTC-EDGE-01`–`OTC-EDGE-08`. |
| State-transition integrity | The single valid transition chain and predecessor guards are explicit in `OTC-CONN-05`; outcome guards for character list/world/evidence are `OTC-CONN-01`–`OTC-CONN-04`. |

---

## Requirement Traceability

| Requirement range | Story / concern | Phase | Status |
| --- | --- | --- | --- |
| `OTC-BLD-01`–`OTC-BLD-07` | Traceable Docker-only Windows client build | Design | Pending |
| `OTC-RUN-01`–`OTC-RUN-12` | Persistent isolated VPS-ready CrossOver installation | Design | Pending |
| `OTC-PROV-01`–`OTC-PROV-09` | Transactional test identity provisioning | Design | Pending |
| `OTC-CONN-01`–`OTC-CONN-05` | First character connection and evidence | Design | Pending |
| `OTC-EDGE-01`–`OTC-EDGE-10` | Cross-component edge cases | Design | Pending |

**Coverage:** 43 normative requirements total; all 43 have inline unique IDs, all 43 are pending design, and all 9 implicit-requirement dimensions map to named requirement IDs or an explicit scoped N/A.

---

## Success Criteria

- [ ] A clean Docker-only feasibility/build gate produces an atomically published, fully inspected Windows x64 OpenGL static payload and project-owned NSIS 3.09 user-level installer from the final root-pinned OTClient commit descended from baseline `99d43bd6559841ee684e35082da3ea9a360d0e16`.
- [ ] CrossOver 26.2 keeps the client installed under `%LOCALAPPDATA%\OTServ\OTClient` in the existing `Steam` Windows 10 bottle, exposes it through `$SMPROGRAMS\OTServ\OTServ OTClient.lnk` and the derived persistent `OTServ OTClient` CrossOver launcher, passes idempotent update/rollback gates, and uses only the isolated `otserv/otclient-vps-smoke` profile without credential persistence or intentional unrelated bottle modification.
- [ ] The deployed map probe proves the town-1 temple contract before the VPS transaction, and initial plus repeated provisioning produces exactly one digest-matching `otserv-smoke` / `Docker Scout` linkage with the specified initial town/position fixture.
- [ ] `Docker Scout` is the only character returned, enters the official bootstrap world, appears in `players_online`, and advances `lastlogin` after clean disconnect within the captured UTC attempt bounds.
- [ ] All feature gates and the independent Verifier pass without installing a project dependency directly on macOS, weakening source/dependency/security pins, exposing credentials/digests, or falling back to a different builder/runtime path.
