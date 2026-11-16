# Reconciliation report

## Checked against sources

| Item | Finding | Result |
| --- | --- | --- |
| FreeBSD image | FreeBSD's release path has 15.0-RELEASE amd64 UFS images, named `FreeBSD-15.0-RELEASE-amd64-ufs.qcow2.xz` | URL corrected from 14.3. The SHA-256 is not available here |
| k3s options | `extraFlags` accepts a string or a list. `role` defaults to `server` | Confirmed. Configuration unchanged |
| GNOME Initial Setup | `services.gnome.gnome-initial-setup.enable` exists, defaults to false, and runs when no user accounts exist | Confirmed. Configuration unchanged |
| Redis module options | The newer module takes bind and port under `settings` | Valkey follows the same pattern. Not confirmed for Valkey itself |
| Blender license | Its copyright file says version 2 of the GPL or any later version | Registry corrected from GPL-3.0-or-later |
| QEMU license | Its maintainer states the binary is GPLv2-only. The Alpine package record lists GPL-2.0-only AND LGPL-2.1-only | Registry corrected from GPL-2.0-or-later |
| LibreOffice license | The official license page says MPL v2.0 | Registry corrected from the dual entry |
| PG4WP plugin source | The maintained fork is on GitHub and publishes no releases. The original download URL was wrong | Switched to `fetchFromGitHub`. A reviewed commit SHA is still needed |

## Changes made

- **Apache** runs as its own unit (`system/legacy.nix`) and listens only on 127.0.0.1:8081. The `services.httpd` module, which listened on port 80, is removed.
- **WordPress** moved from loopback port 8000 to port 8080. The health check, `run.sh` (host port 8081), and the development firewall are updated to match.
- **Home Assistant** no longer has a `/ha/` route. It runs on port 8123, because it needs a base URL to work under a path.
- **Valkey** puts `bind` and `port` under `settings`.
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

These can't be resolved from this environment, because each needs a download or a decision:

1. **FreeBSD hash**: the SHA-256 of the 15.0 image. The first build prints it.
2. **PG4WP commit**: a reviewed commit SHA, then its hash. The plugin's file layout (`db.php` and the plugin directory at the repository root) is unverified.
3. **Valkey options**: `settings.bind` and `settings.port` follow the Redis module pattern. Not confirmed for Valkey.
4. **Apache module paths**: the `modules/mod_*.so` paths in `system/legacy.nix` are unverified against the nixpkgs package layout.
5. **Nix evaluation**: nothing in the Nix layer has been evaluated yet.
6. **Toolchains**: React, Angular, and Rails install on first boot without pinned versions.
7. **Neovim**: its license row is still open.
8. **Services**: they don't use PostgreSQL, and nothing persists.
