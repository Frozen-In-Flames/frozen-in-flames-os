# Frozen in Flames

One operating system that combines 39 open source platforms into one service.
Users work through tasks. The platforms run underneath and stay hidden.

## Layout

- `flake.nix`: builds two configurations and two outputs
- `system/default.nix`: release base system (desktop, first-boot account setup, networking, firmware policy, SSH)
- `system/packages.nix`: installable platforms, system-wide
- `system/services.nix`: services (PostgreSQL, Valkey, nginx, WordPress, Apache, Docker, Kubernetes, Home Assistant, FreeBSD guest, first-boot toolchains)
- `profiles/development.nix`: test-only settings (test user, passwordless sudo, password SSH, open ports)
- `tests/health_check.py`: 39 checks, one per platform, each testing real function
- `scripts/build.sh`: builds an output inside a Nix container
- `scripts/run.sh`: boots a test image in a KVM virtual machine
- `docs/license-review.md`: license status for all 39 platforms, with items to verify
- `PROVENANCE-EXCEPTIONS.md`: every departure from the libre policy, with its planned fix

## Two configurations

- **frozen-in-flames** (release): no default credentials. GNOME Initial Setup creates the first account at first boot. Password SSH is off. Proprietary firmware is not loaded. Output: `iso`.
- **frozen-in-flames-dev** (test): adds `profiles/development.nix`, which creates user `frozen` with password `frozen`, passwordless sudo, password SSH, and ports 22/80/8123. Output: `qcow2-dev`. Only this image can be checked by `tests/health_check.py`.

## Decisions applied

- **Redis is replaced by Valkey**, the BSD-licensed fork. Redis 7.4 and later are not open source, and Redis 8 offers AGPLv3 only as an option.
- **Firmware policy is strict**: proprietary firmware is not loaded. PyTorch and TensorFlow run on CPU only.
- **FreeBSD** runs as a prebuilt image, recorded as a provenance exception.
- **VS Code** is VSCodium, the open source build.
- **WordPress** runs on PostgreSQL through PG4WP.

## Build and run

1. Install Docker, or Podman with `ENGINE=podman`. Keep about 100 GB free.
2. `scripts/build.sh qcow2-dev`. The output goes to `build/`.
3. The first build stops at two `lib.fakeHash` lines in `system/services.nix` (WordPress plugin and FreeBSD image). The error prints the real hash. Paste it over `lib.fakeHash` and build again.
4. Commit `flake.lock` after the first successful evaluation so nixpkgs stays pinned.
5. `scripts/run.sh`. The FreeBSD guest runs inside this VM, so nested virtualization must be enabled on the host.
6. Install `sshpass` on the host, then run `python3 tests/health_check.py`.
7. `scripts/build.sh iso` produces the installer for physical hardware.

## Not yet verified by a build

These are written from memory of nixpkgs and need a real build to confirm:

- `services.valkey` and `services.gnome.gnome-initial-setup` option names
- Apache's `Listen` override, which may conflict with nginx on port 80
- WordPress's file layout under `pkgs.wordpress`
- Single-node Kubernetes setup
- TensorFlow's availability in nixpkgs
- The FreeBSD download URL
- Two placeholder hashes, which can only be filled from a real download

## Known gaps

- The first user created at install time is not in the `docker` or `kvm` groups.
- React, Angular, and Rails are installed at first boot without pinned versions (see `PROVENANCE-EXCEPTIONS.md`).
- Not started: the provenance database, Debian dependency resolver, libre knowledge base, policy and profile layers, compliance mapping, AI model management, and the graphical workspace.

## Status

Not built or booted. The Nix files have not been evaluated, so expect the first build to
show errors in the places listed above.
