# OTClient Test Identity Provisioning Context

**Spec**: `.specs/features/dockerized-otclient-vps-connection/spec.md`
**Status**: Delivered
**Originally confirmed on**: 2026-07-21
**Scope closed on**: 2026-07-22

---

## Final User Decision

The feature is delivered solely by creating and verifying the persistent OTClient test identity. Compiling, packaging, installing, or automatically validating an OTClient connection is not required now because the user can access the server with an already compiled client.

The historical feature directory name is retained so the implementation commits and independent validation report keep stable paths. Deferred client work will receive a new specification when reprioritized.

## Delivered Scope

- account `otserv-smoke`;
- exactly one active linked character `Docker Scout`;
- generated 32-character URL-safe password held only in ignored mode-`0600` `env/client-test.env`;
- exact active-release map and town-1 temple/placeability probe before database mutation;
- serialized transaction with strict create/no-op/conflict outcomes;
- strict SSH host verification and VPS-native MariaDB Unix-socket access;
- sanitized evidence for the initial `created` execution and repeated `noop` execution;
- independent PASS for `OTC-PROV-01`–`OTC-PROV-09`, `OTC-EDGE-08`, and `OTC-EDGE-09`.

## Delivered Evidence

- identity implementation commits: `995e689`, `38ba490`, and test-strengthening commit `1895531`;
- complete gate: 84 passed, 0 failed, 0 skipped;
- focused identity contract: 14 passed, 0 failed;
- independent spec-anchored verification: 11/11 criteria;
- P0 discrimination sensor: 8/8 behavior-level mutations killed;
- VPS final state: exactly one digest-matching account linked to exactly one active character with `town_id=1` and zero initial position.

## Deferred to Future Features

- native Windows OTClient compilation through MSVC/vcpkg;
- client source customization and root gitlink updates;
- Windows packaging, signing, and distribution;
- CrossOver installation, isolated profile, shortcut, and launcher management;
- automated login, character-list, world-entry, `players_online`, and `lastlogin` evidence.

AD-013 remains the selected native Windows build strategy if compilation is later prioritized. The current operational path may use a precompiled OTClient.

## Non-negotiable Safety Boundaries

- Never persist or print the plaintext password or its SHA-1 digest outside the approved secret file/database boundary.
- Never provision or accept the identity unless the exact deployed release/map/town contract passes.
- Never treat a digest, cardinality, name, or linkage conflict as a no-op.
- Never claim compilation, packaging, CrossOver installation, or end-to-end connection as delivered by this feature.
