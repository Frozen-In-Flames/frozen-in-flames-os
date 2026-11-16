# FROZEN IN FLAMES

A libre NixOS-based computing environment: 39 platform targets, nine loopback-only service processes, a PostgreSQL schema, Valkey as the cache and event service, a web workspace, and QCOW2 and ISO build targets.

## Release invariants

- `nixpkgs.config.allowUnfree = false`.
- No default user, password, automatic login, or password-authenticated SSH.
- The first account is created by GNOME Initial Setup at first boot.
- SSH password authentication and root SSH login are disabled.
- Redis is not included. Valkey is the cache and event service.
- Software freedom (F) and hardware freedom (H) are assessed separately.
- Artifact identity is SHA-256. Provenance runs Project → Source Version → Package Instance → Artifact.

## Build

On an internet-connected x86_64 Linux host with Nix and flakes enabled:

```sh
./scripts/build.sh check
./scripts/build.sh qcow2       # release image
./scripts/build.sh iso         # installer
./scripts/build.sh qcow2-test  # development image for tests/health_check.py; never released
```

Outputs and SHA-256 manifests go to `artifacts/`. Machines without Nix can run `./scripts/build-in-container.sh [target]`.

## Test

```sh
python3 scripts/validate_catalog.py registry/platforms.json
python3 -m unittest discover -s tests -v
```

`tests/health_check.py` runs against a booted `qcow2-test` image. It checks 39 platforms and 9 services.

## Services

Each service is a separate systemd unit that listens only on loopback.

1. Catalog: 8101
2. Provenance: 8102
3. Dependency intelligence: 8103
4. Evidence: 8104
5. Policy: 8105
6. Profiles: 8106
7. Build/release: 8107
8. AI model registry: 8108
9. Workspace: 8109

The services accept and validate input, but nothing is persisted yet.

## Infrastructure and routes

- nginx on port 80: the workspace at `/`, the services at `/api/<service>/`, and Apache at `/legacy/`.
- WordPress on port 8080, running under PHP-FPM.
- Home Assistant on port 8123.
- Apache on loopback port 8081, as its own unit.
- k3s, with Traefik and ServiceLB disabled so nginx keeps ports 80 and 443.
- Docker, PostgreSQL, Valkey, and FreeBSD as a QEMU guest.

The release firewall opens no ports. `docs/RECONCILIATION.md` lists the checks against sources and the remaining blockers.

## Status

Catalog validation and 19 unit tests pass, and all nine services answer on loopback. Nothing in the Nix layer has been evaluated or built yet. The FreeBSD image hash and the WordPress plugin commit are still open, as listed in `docs/RECONCILIATION.md`.
