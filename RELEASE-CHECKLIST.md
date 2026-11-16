# Release checklist

- [ ] `nix flake check` passes on x86_64-linux.
- [ ] QCOW2 image builds and boots in QEMU.
- [ ] Installer ISO builds and installs to a blank virtual disk.
- [ ] GNOME Initial Setup creates the first account; no baked credentials exist.
- [ ] SSH password auth is disabled; root login is disabled.
- [ ] Firewall exposes only intended ports.
- [ ] PostgreSQL migration succeeds and service DB access is least-privilege.
- [ ] Valkey health check succeeds and is loopback-only.
- [ ] All nine services pass health checks.
- [ ] All 39 platform records resolve to pinned package/source artifacts or explicitly documented external-image targets.
- [ ] License review verified against upstream sources at pinned versions.
- [ ] Debian resolver tests cover version ordering, alternatives, qualifiers, Multi-Arch, Provides, Conflicts, Breaks, profiles, snapshots, and cycles.
- [ ] SPDX/CycloneDX SBOM generated from actual closure.
- [ ] SHA-256 manifest and signed provenance generated.
- [ ] Offline installation and rollback tested.
- [ ] Accessibility, update, recovery, backup, and security tests pass.
