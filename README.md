# FROZEN IN FLAMES

A libre NixOS-based computing environment with 39 platform targets, nine independently supervised service endpoints, a PostgreSQL provenance schema, a Valkey cache/event service, a searchable workspace, and QCOW2/ISO build targets.

## Non-negotiable release invariants

- `nixpkgs.config.allowUnfree = false`.
- No default user, password, automatic login, or password-authenticated SSH.
- First account is created by the GNOME Initial Setup first-boot flow; no technical configuration is required.
- SSH password authentication is disabled; root SSH login is disabled.
- Redis is not included; Valkey is the cache/event service.
- Software freedom (F) and hardware freedom (H) are separate assessment dimensions.
- Artifact identity is SHA-256 and provenance is Project → Source Version → Package Instance → Artifact.

## Build

On an internet-connected x86_64 Linux Nix host with flakes enabled:

```sh
./scripts/build.sh check
./scripts/build.sh qcow2
./scripts/build.sh iso
```

`qcow2-dev` is retained as a compatibility alias for the QCOW2 target. Build outputs and hashes are written to `artifacts/`.

## Nine services

1. Catalog — 8101
2. Provenance — 8102
3. Dependency intelligence — 8103
4. Evidence — 8104
5. Policy — 8105
6. Profiles — 8106
7. Build/release — 8107
8. AI model registry — 8108
9. Workspace — 8109

The NixOS image also enables PostgreSQL, Valkey, nginx, Apache HTTP Server, Docker, k3s, and Home Assistant as infrastructure platforms/services.

## Important implementation boundary

This is an assembled source build, not a claim that a disk image has already been produced or boot-tested. The current environment used to prepare this source bundle does not contain Nix or an x86_64 Linux Nix builder. The package registry, API service shells, schema, desktop configuration, UI, catalog validator, and tests are included. Advanced production work still requiring implementation includes a full Debian-compatible resolver (including dpkg version ordering, full architecture/profile semantics and snapshot solving), authenticated IAM, persistent API writes, complete SBOM/provenance attestation, policy evaluation, real model execution, and end-to-end VM/installer tests. These are not represented as complete merely because their service endpoints exist.
