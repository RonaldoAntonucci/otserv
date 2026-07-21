# Native VPS Bootstrap Validation

## Scope

This report records the sanitized validation of the native OTServ stack on Hostinger VPS `1826871` (`srv1826871.hstgr.cloud`). No database password, secret value, secret hash or private key is included.

| Item | Validated value |
| --- | --- |
| Validation window | 2026-07-21 20:02–20:10 UTC |
| Operating system | Ubuntu 24.04 LTS, amd64 |
| Orchestrator revision | `3ae90d0` |
| TFS revision | `098641981400f8ff89959f427f0e8718d9dd22e2` |
| MariaDB | 10.11.14-MariaDB |
| Native release | `/opt/otserv/releases/098641981400f8ff89959f427f0e8718d9dd22e2` |
| Release ownership/mode | `root:otserv`, `0750` |
| Installed environment ownership/mode | `root:root`, `0600` |

## Installation and recovery evidence

The installer completed on the supported VPS, built the pinned TFS revision with one compilation job, initialized MariaDB, published an immutable release and activated the `tfs` systemd service.

The first service start exposed a real release-permission defect (`status=200/CHDIR`). The correction was implemented and tested in commits `922b195` and `3ae90d0`: releases are now published as `root:otserv`, and the installer repairs permissions when safely reusing an existing release. Reapplying the installer activated the same pinned release successfully.

## Idempotency and persistence

The installer was executed a second time against the active installation. The comparison before and after the rerun produced the following sanitized outcomes:

| Property | Outcome |
| --- | --- |
| Installed secret | Preserved |
| Database marker | Preserved exactly once |
| Active release | Preserved |
| Official map | Preserved |

The persistence marker remained `bootstrap_persistence_marker=vps-bootstrap-v1`, with exactly one matching database row. The installer did not reimport or destroy the existing schema and data.

## Native runtime gates

Two required read-only gate executions were performed around service restart and installer reapplication. Each execution reported exactly the same result:

```text
14 passed, 0 failed
```

Each run verified Ubuntu 24.04/amd64, operational systemd, the exact pinned release, executable and official map, active loopback-only MariaDB, schema and persistence marker, active TFS, login/game listeners, completed datapack loading and absence of fatal startup journal entries.

A third confirmation at `2026-07-21T20:10:13Z`, after the UFW rules were applied, also passed `14/14` without modifying runtime state.

## Service and network state

| Check | Evidence |
| --- | --- |
| `mariadb.service` | Active and enabled |
| `tfs.service` | Active and enabled |
| MariaDB listener | `127.0.0.1:3306` only |
| TFS login listener | TCP `7171` |
| TFS game listener | TCP `7172` |
| UFW | Active; TCP `7171` and `7172` allowed for IPv4 and IPv6 |
| External TCP check | `7171` reachable; `7172` reachable; `3306` unreachable |
| Current-boot datapack completion entries | 2 |
| Current-boot fatal startup entries | 0 |

Hostinger had no separate firewall group assigned to this VPS at validation time. The persistent host-level UFW policy retains SSH/HTTP/HTTPS rules, explicitly exposes only the two OTServ protocol ports, and does not expose MariaDB.

## Reproduction commands

These commands contain no credentials. They assume the operator has already installed a root-owned `0600` environment file as described by the deployment runbook.

```sh
sudo deploy/vps/install.sh /path/to/root-owned-otserv.env
make test-vps
sudo systemctl restart mariadb tfs
make test-vps
```

The installer output and smoke output must be retained for each deployment. Secret-bearing environment files must never be copied into Git or attached to validation evidence.
