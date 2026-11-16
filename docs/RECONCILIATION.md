# Reconciliation report

This report compares the repository with the release checklist, the README claims, and the
results of running the code locally.

## 1. Uploads

- The uploads folder was empty at review time. `flake.nix`, `configuration.nix`, and any `.pyc` files did not arrive. The review used the copies already in the repository.
- Please upload `configuration.nix` again as `configuration.nix.txt`, or paste it. Uploads of `.pyc` files should be avoided. Bytecode is not needed, and the service units set `PYTHONDONTWRITEBYTECODE`. No bytecode is in the tree.
- The flake assembles the `system/*.nix` modules. A separate `configuration.nix` would duplicate them unless it contains host-specific overrides.

## 2. Verified by running the code

These checks ran on source code only. They do not cover Nix evaluation or a booted image.

- Catalog validation passes: 39 unique platform targets, unfree disabled, Valkey present.
- 19 unit tests pass: 3 in `test_core.py`, 16 in `test_services.py`.
- All nine service processes start on loopback and answer `/health`.

Bugs found by running the services, now fixed:

| Bug | Effect | Fix |
| --- | --- | --- |
| JSON array body on `POST /records` | Handler raised `AttributeError` and dropped the connection | Body must be a JSON object; otherwise 400 |
| Query string on a POST path | `POST /records?x=1` returned 404 | Routing ignores the query string |
| Invalid dependency relation | Returned 200 | Returns 422 with `valid: false` |
| Evidence response said `queued-for-persistence` | Nothing is queued or stored | Status is `accepted-not-persisted` |
| Non-numeric `Content-Length` | Server error | Returns 400 |
| Registry missing | Server error | Returns 503 |
| Test import order | Two tests failed depending on which test imported the module first | Tests set the registry path explicitly |
| Dead SQLite code path | Misleading; the service never used it | Removed |

## 3. Not verified

- Nix evaluation of the flake and modules
- Image builds (QCOW2, ISO, test image)
- VM boot, GNOME Initial Setup, and the health check against a running system
- systemd units, nginx configuration, and PostgreSQL migration
- k3s, Valkey, Docker, Apache, and Home Assistant running under NixOS

## 4. Decisions applied

- **NixOS release**: 26.05 is the current stable release. It shipped on May 30, 2026 and receives security updates until December 31, 2026. The flake already uses `nixos-26.05`. Plan the move to 26.11 when it is released.
- **Kubernetes distribution**: k3s. It is a single binary under Apache-2.0 with a NixOS module. The older `services.kubernetes` module runs several components separately. k3s bundles Traefik and ServiceLB, which bind ports 80 and 443, so both are disabled to leave those ports to nginx.
- **Valkey**: bound to 127.0.0.1 explicitly.
- **Service units**: DynamicUser, read-only system view, no capabilities, restricted address families, no namespaces, and no SUID or SGID. The checklist's dedicated unprivileged account is met by DynamicUser.

## 5. nginx routing plan

| Public path | Target | Status |
| --- | --- | --- |
| `/` | Workspace UI, `web/index.html` | Configured |
| `/api/<service>/` | `127.0.0.1:810x`, prefix stripped | Configured. Tested on loopback, not yet through nginx |
| `/ha/` | Home Assistant on 127.0.0.1:8123 | Configured. Home Assistant needs a base URL for a subpath, which is not set |
| `/legacy/` | Apache on 127.0.0.1:8081 | Blocked. Apache's default port 80 conflicts with nginx |
| `/blog/` | WordPress | Planned. WordPress currently listens on 127.0.0.1:8000. Moving it to `/blog/` requires `WP_HOME` and `WP_SITEURL` set to `/blog` |

The firewall opens no ports in the release. The workspace is reachable on the local machine only until a port is opened on purpose.

## 6. Release checklist status

| Item | Status |
| --- | --- |
| `nix flake check` passes | Not verified. Needs a Nix build |
| QCOW2 builds and boots | Not verified |
| Installer ISO installs to a blank disk | Not verified |
| GNOME Initial Setup creates the first account; no baked credentials | Source complete. Test profile only sets the test user. Verify in a VM |
| SSH password auth and root login disabled | Source complete (`PasswordAuthentication` default false, `PermitRootLogin` no). Verify |
| Firewall exposes only intended ports | Release opens none. Verify |
| PostgreSQL migration succeeds | Migration unit present. Not run |
| Services use least-privilege database access | Not implemented. The services do not connect to PostgreSQL yet |
| Valkey health check passes and is loopback-only | Health check present. Bind option name not verified |
| All nine services pass health checks | Passes on loopback. `health_check.py` now checks them |
| All 39 platforms resolve to pinned artifacts | Not done |
| License review verified upstream | Not done. Three open conflicts (see `docs/license-review.md`) |
| Debian resolver test coverage | Partial. Only relation atom parsing is implemented. Version ordering, alternatives, Multi-Arch, Provides, Conflicts, Breaks, profiles, snapshots, and cycles are not |
| SPDX or CycloneDX SBOM | Not done |
| SHA-256 manifest and signed provenance | SHA-256 manifest written by `build.sh`. Signing not done |
| Offline installation and rollback | NixOS generations provide rollback. Not tested. Offline install not done |
| Accessibility, update, recovery, backup, security tests | Not done |

## 7. Blockers and open items

- **Apache port**: `services.httpd` keeps its default listener on port 80, which nginx uses. The fix is a dedicated Apache configuration that listens only on 8081.
- **Unverified option names**: `services.valkey`, `services.gnome.gnome-initial-setup`, `services.k3s` (including `extraFlags`), and the Valkey `bind` option.
- **Placeholder hashes**: the WordPress plugin and the FreeBSD image. The first build prints both.
- **FreeBSD download URL**: check it against download.freebsd.org.
- **Toolchains**: React, Angular, and Rails install on first boot without pinned versions.
- **WordPress subpath**: needs `WP_HOME` and `WP_SITEURL`, which are not yet configured.
- **Services do not persist**: the POST endpoints accept and validate input, but nothing is stored. This is documented in the code and tests.
- **Registry and license review conflicts**: QEMU, Blender, and LibreOffice (see `docs/license-review.md`).
