# Frozen in Flames

One operating system that combines 39 open source platforms into one service.
Users work through tasks. The platforms run underneath and stay hidden.

## Layout

- `flake.nix`: builds two configurations and two outputs
- `system/default.nix`: release base system (desktop, networking, firmware policy, SSH)
- `system/packages.nix`: installable platforms, system-wide
- `system/services.nix`: services, WordPress, Apache, Kubernetes, Home Assistant, FreeBSD guest, first-boot toolchains
- `profiles/development.nix`: test-only settings (password, passwordless sudo, open ports)
- `tests/health_check.py`: 39 checks, one per platform, each testing real function
- `scripts/build.sh`: builds an output inside a Nix container
- `scripts/run.sh`: boots a test image in a KVM virtual machine

## Two configurations

- **frozen-in-flames** (release): no default password, no passwordless sudo, password SSH off, firewall at defaults, proprietary firmware not loaded. Output: `iso`.
- **frozen-in-flames-dev** (test): adds `profiles/development.nix`, which sets the password `frozen`, passwordless sudo, password SSH, and ports 22/80/8123. Output: `qcow2-dev`. Only this image can be checked by `tests/health_check.py`.

## Build and run

1. Install Docker, or Podman with `ENGINE=podman`. Keep about 100 GB free.
2. `scripts/build.sh qcow2-dev`. The output goes to `build/`.
3. The first build stops at two `lib.fakeHash` lines in `system/services.nix` (WordPress plugin and FreeBSD image). The error prints the real hash. Paste it over `lib.fakeHash` and build again.
4. Commit `flake.lock` after the first successful evaluation so nixpkgs stays pinned.
5. `scripts/run.sh`. The FreeBSD guest runs inside this VM, so nested virtualization must be enabled on the host.
6. Install `sshpass` on the host, then run `python3 tests/health_check.py`.
7. `scripts/build.sh iso` produces the installer for physical hardware.

## Changes made in response to review

- Removed `nixpkgs.config.allowUnfree`.
- Removed automatic login.
- Moved all default credentials, passwordless sudo, password SSH, and open ports into `profiles/development.nix`.
- Added an installer ISO output.
- Pinned nixpkgs to `nixos-25.05` and set up `flake.lock` for an exact revision.
- Set `hardware.enableRedistributableFirmware = false` for the libre policy.

## Known gaps

- **Account setup**: the release has no password yet, so a first-boot setup step is needed before anyone can log in.
- **Redis license**: Redis 7.4 and later are not open source unless you use the AGPLv3 option. Valkey is a BSD-licensed fork and a drop-in replacement. The choice is undecided.
- **FreeBSD image**: the guest is a prebuilt binary downloaded from FreeBSD. Under the libre policy it needs a provenance decision or a source build.
- **Substitutes**: builds use the Nix binary cache. A source-only build needs a separate decision.
- **Hardware**: with firmware disabled, some Wi-Fi and GPU hardware may not work.
- **Not started**: the provenance database, Debian dependency resolver, libre knowledge base, policy and profile layers, compliance mapping, AI model management, and the graphical workspace.

## Status

Not built or booted. Nix is not available in the authoring sandbox, so the Nix files
have not been evaluated. Expect the first build to show errors in the places listed above.
