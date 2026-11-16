# Build status and provenance

## Inputs recovered from the available project materials

- Existing flake.nix and default.nix were present in the Library.
- Existing UI reference PDF states 39 platforms, 9 layers, 1 service, and explicitly notes that routing in that UI is simulated.
- The recovered default.nix contained a fixed `frozen` account, password, auto-login, password SSH, and passwordless sudo. Those development-only settings have been removed from this assembled release configuration.
- The original flake referenced missing `system/default.nix`, `system/packages.nix`, and `system/services.nix` files. The full `frozen-in-flames.tar.gz` archive was not present in the available Library listing.

## Current assembly

- 39 platform registry records; Valkey replaces Redis.
- 9 systemd-supervised API processes.
- PostgreSQL schema for projects, source versions, package instances, artifacts, evidence, derivations, policies, profiles, and audit events.
- NixOS 26.05 flake with QCOW2 and installer ISO outputs.
- Libre-only package policy; `allowUnfree = false`; VSCodium is used instead of proprietary Microsoft VS Code.
- First-user creation is delegated to GNOME Initial Setup; no default account or password is defined.
- SSH password auth and root login disabled.
- Unit tests and catalog validation included.

## Not claimed

No Nix evaluation, package build, QCOW2 generation, ISO generation, VM boot, hardware test, or security certification has been performed in this environment. A successful source-level test is not a successful OS build.
