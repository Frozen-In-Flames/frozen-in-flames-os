# Reconciliation report

## Checked against sources

| Item | Finding | Result |
| --- | --- | --- |
| FreeBSD image | FreeBSD's release path has 15.0-RELEASE amd64 UFS images, named `FreeBSD-15.0-RELEASE-amd64-ufs.qcow2.xz` | URL corrected from 14.3 |
| k3s options | `extraFlags` accepts a string or a list. `role` defaults to `server` | Confirmed. Configuration unchanged |
| GNOME Initial Setup | `services.gnome.gnome-initial-setup.enable` exists, defaults to false, and runs when no user accounts exist | Confirmed. Configuration unchanged |
| Redis module options | At the locked nixpkgs revision (flake.lock, rev b349185bb79c7cf7ad8ea8c097931730bf473c71), the redis module defines first-class `bind` and `port` options on each server (nixos/modules/services/databases/redis.nix, options at lines 193 and 218) and merges them into the generated `settings` (line 483 carries `bind` into settings when set) | Confirmed against the locked source on 2026-11-21. The configuration in system/services.nix, which sets `bind` and `port` as server options on the redis module with `package = pkgs.valkey`, is the module intended form. Resolved |
| Blender license | Its copyright file says version 2 of the GPL or any later version | Registry corrected from GPL-3.0-or-later |
| QEMU license | Its maintainer states the binary is GPLv2-only. The Alpine package record lists GPL-2.0-only AND LGPL-2.1-only | Registry corrected from GPL-2.0-or-later |
| LibreOffice license | The official license page says MPL v2.0 | Registry corrected from the dual entry |
| PG4WP plugin source | The maintained fork is on GitHub and publishes no releases. The original download URL was wrong | Switched to `fetchFromGitHub` |
| Apache module paths | At the same locked nixpkgs revision, the NixOS httpd module loads the core modules from `${pkg}/modules/mod_<name>.so` (nixos/modules/services/web-servers/apache-httpd/default.nix, line 375), which is the apacheHttpd package layout | The `modules/mod_*.so` paths in system/legacy.nix, relative to ServerRoot `${pkgs.apacheHttpd}`, match the package layout. Confirmed 2026-11-21. Resolved |
| Toolchain versions | react and react-dom 19.3.1, @angular/cli 22.3.0 (npm registry), rails 8.1.4.1 (RubyGems), read 2026-11-21 | Pinned exactly in the frozen-toolchains unit in system/services.nix. Resolved |
| Neovim license | Neovim LICENSE.txt: Apache 2.0 except parts contributed under the Vim license | Registry entry (Apache-2.0) correct as the primary license; row closed in docs/license-review.md on 2026-11-21. Resolved |
| Service persistence | The nine frozen services were read-only or accepted records without storing them | The three record-accepting endpoints now persist to the state directory and read back; the rest are stateless by design (account below). Resolved 2026-11-21 |
| FreeBSD image hash | SHA-256 pinned in system/services.nix, verified 2026-11-16 against the FreeBSD project published checksum for FreeBSD-15.0-RELEASE-amd64-ufs.qcow2.xz | Resolved |
| PG4WP commit | Pinned commit and archive hash in system/services.nix; plugin layout reviewed against the fork install instructions | Resolved |
| Nix evaluation | Flake evaluation runs in continuous integration (nix flake check, no builds, plus deep configuration evaluation); successful runs recorded from November 16, 2026; flake.lock committed | Resolved for evaluation. Image build and boot remain open |

## Changes made

- **Apache** runs as its own unit (`system/legacy.nix`) and listens only on 127.0.0.1:8081. The `services.httpd` module, which listened on port 80, is removed.
- **WordPress** moved from loopback port 8000 to port 8080. The health check, `run.sh` (host port 8081), and the development firewall are updated to match.
- **Home Assistant** no longer has a `/ha/` route. It runs on port 8123, because it needs a base URL to work under a path.
- **Valkey** runs through the redis module with `package = pkgs.valkey`; `bind` and `port` are set as server options, which the module merges into the generated settings (confirmed against the locked nixpkgs source, 2026-11-21).
- **FreeBSD** image: 15.0-RELEASE URL.
- **PG4WP**: GitHub source.
- **License registry**: three entries corrected (QEMU, Blender, LibreOffice).
- **Development profile**: opens ports 22, 80, 8080, and 8123. Its comments now name the correct configuration and output.

## Ports and routes

| Address | Serves | Reachable |
| --- | --- | --- |
| nginx port 80, `/` | Workspace UI | Release: local only. Development: forwarded to host 8080 |
| nginx port 80, `/api/<service>/` | Nine services on 127.0.0.1:8101 to 8109, prefix stripped | Same as above |
| nginx port 80, `/legacy/` | Apache on 127.0.0.1:8081 | Same as above |
| nginx port 8080 | WordPress | Development: forwarded to host 8081 |
| Home Assistant on 8123 | Home Assistant | Development: forwarded to host 8123 |
| SSH on 22 | Administration | Development only. Release has password login disabled |

The release firewall opens no ports. Local access works without opening anything.

## Remaining blockers

One blocker remains, and it is not a repository defect:

1. **Image build and boot**: QCOW2 generation, ISO generation, and a VM
   boot have not been performed. They require a compute host with Nix
   and nested virtualization. The host route is an AWS Free Plan
   signup that waits at the password step for the account owner to
   enter his password himself; Azure is the researched fallback.
   Everything short of the boot is in place: flake evaluation is green
   in continuous integration, flake.lock is committed, and the build
   targets are declared in flake.nix.

## Resolved blockers (2026-11-21 pass)

Each item below was a remaining blocker before this pass. Each was
closed against a source or by a change in this repository, not by
assertion.

1. **Valkey options**: confirmed against the redis module source at
   the locked nixpkgs revision (see the checked-against-sources
   table). The configuration already used the correct form.
2. **Apache module paths**: confirmed against the NixOS httpd module
   at the same revision; `modules/mod_*.so` under the apacheHttpd
   package root is the package layout.
3. **Toolchain pinning**: react, react-dom, @angular/cli, and rails
   are pinned to exact registry-verified versions in the
   frozen-toolchains unit (system/services.nix).
4. **Neovim license row**: closed against Neovim's LICENSE.txt.
5. **Services and persistence**: the account is per service.
   PostgreSQL is the relational store: the `frozen` database carries
   the migration-managed schema (migrations/001_initial.sql, applied
   by the frozen-migrate unit), and WordPress uses PostgreSQL through
   PG4WP. The nine loopback services divide as follows.
   - catalog and workspace: read-only projections of the platform
     registry file. Stateless by design; the registry is the record.
   - dependency: a pure parser. Its output is a function of its
     input, so there is nothing to store.
   - policy and provenance: read-only statements of fixed model data.
     Stateless by design.
   - build: a validation receipt. Build execution belongs to the
     host Nix builder, as its response states; it stores nothing
     because it builds nothing.
   - evidence, ai, profiles: the record-accepting services. Since
     this pass they persist: each accepted POST is appended as one
     JSON line to /var/lib/frozen-in-flames/<service>.jsonl (the
     systemd StateDirectory the units already declared), the response
     reports status "persisted" with the stored count only after the
     append succeeds, a failed append returns 503 and claims nothing,
     and the matching GET endpoint reads the records back. Verified
     locally on 2026-11-21 by running the evidence service and
     completing a POST, GET, and on-disk read of the record.
