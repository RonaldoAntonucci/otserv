# Docker-built Windows OTClient and First VPS Connection Context

**Spec**: `.specs/features/dockerized-otclient-vps-connection/spec.md`
**Status**: Paused — specification revision required before Design
**Originally confirmed on**: 2026-07-21
**Build strategy changed on**: 2026-07-21

---

## User-confirmed decisions

| Area | Locked decision | Consequence for design |
| --- | --- | --- |
| Delivery target | Build a Windows x64 OTClient; no native macOS build is required. | The only runtime payload is `PE32+` x86-64. macOS-native application packaging is out of scope. |
| Runtime | Run the Windows client through CrossOver's Windows 10 compatibility environment. | Runtime validation targets CrossOver 26.2, not Wine installed separately and not a containerized GUI. |
| Existing bottle | Reuse the already-created CrossOver bottle `Steam`. | The workflow must preflight and preserve this shared bottle; it must not create, rename, delete, or upgrade a bottle. |
| Persistence | Leave OTClient installed in CrossOver after validation so the user can open it later. | Installation, profile, verified assets, Windows shortcut, and exported CrossOver launcher survive the smoke test. |
| Host isolation | No project dependency may be installed directly on macOS. | The toolchain is installed only on the Windows build machine; macOS receives the finished Windows artifact for CrossOver UAT. |
| Build approach | Compile natively on Windows with the fork's supported MSVC/vcpkg flow and `windows-release` CMake preset. | Docker/MinGW on macOS is no longer the selected implementation path. Exact Windows prerequisites and packaging choices must be confirmed during the revised Specify phase. |
| Installation level | Use a project-owned NSIS installer with user-level scope. | The only installation root is `%LOCALAPPDATA%\OTServ\OTClient`; no elevation or redistributable installer is allowed. |
| Launcher | Keep one persistent CrossOver launcher named `OTServ OTClient`, derived from the verified Start Menu shortcut. | Shortcut/launcher creation happens only after installed-payload and activation verification. |
| Orchestration | This chat is the orchestrator and may assign agents/subagents using the models appropriate to bounded tasks. | Planning may expose independent phases, but worker dispatch remains controlled by the orchestrator and the TLC execution/verification contract. |

## Post-approval change

After the original specification was approved, the user selected a native Windows build instead of the Docker/MinGW cross-build on macOS. The original `spec.md` is retained as research history, but its `OTC-BLD-*` requirements and any dependent installer assumptions are not authorized for implementation. The feature must return to Specify on the Windows machine, replace those requirements with the native MSVC/vcpkg workflow, and receive explicit approval before Design.

The following confirmed outcomes remain intended unless the revised specification changes them: Windows x64 delivery, persistent installation in the existing CrossOver `Steam` bottle, the isolated runtime profile, test identity provisioning, and first world-entry validation against the VPS.

## Defaults approved with the specification

Approval of `spec.md` also confirmed its proposed defaults:

- immutable client baseline `99d43bd6559841ee684e35082da3ea9a360d0e16`, followed by a minimal fork commit and a root gitlink update;
- OpenGL/WGL client with `TOGGLE_DIRECTX=OFF` and no DirectX/VC++ runtime installation;
- endpoint `srv1826871.hstgr.cloud:7171`, raw login, protocol/client `1310`;
- isolated PHYSFS identity `otserv/otclient-vps-smoke`;
- strict asset verification, OTC-standard protocol-1310 runtime paths, and reuse only after re-verification;
- immutable host artifact layout `artifacts/otclient-windows-x64/<client-sha>/<manifest-sha256>/`;
- user-level release/staging/rollback/current installation model and stable launcher identity;
- account `otserv-smoke`, character `Docker Scout`, and a generated 32-character URL-safe password held only in ignored `env/client-test.env` with mode `0600`;
- strict-host-key-checked SSH and VPS-native MariaDB Unix-socket provisioning as root;
- town 1 / zero-position fixture only after an exact deployed-map temple/placeability probe;
- success only after character-list, rendered-world, joined `players_online`, and bounded `lastlogin` evidence all agree.

## Agent's discretion

The following implementation details are delegated to Design, provided every spec requirement remains satisfied:

- exact Dockerfile stage names, scripts, and manifest JSON field names;
- minimal MinGW portability patches in the OTClient fork;
- the project-owned Windows helper used by NSIS for hashing, PE closure inspection, locking, and activation;
- exact sanitized evidence file schema and test fixture layout;
- whether test orchestration uses Make targets or direct scripts, as long as all project tooling remains Docker-only on macOS;
- the map-probe implementation, provided it parses the exact active release/map and proves the same town/tile semantics used by the pinned TFS source.

## Non-negotiable safety boundaries

- Never persist or print the plaintext password or its SHA-1 digest outside the approved secret file/database boundary.
- Never mutate the shared bottle until exact CrossOver/bottle preflight passes.
- Never provision the VPS identity until the exact deployed map/town contract passes.
- Never publish a partial package, activate a partial release, or leave a launcher targeting an unverified release.
- Never substitute a weaker builder, asset hash policy, SSH policy, database access path, or success signal.
