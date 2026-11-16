# Provenance exceptions

Each item departs from the strict libre policy, or cannot be verified until a build runs.

| Item | Why it is an exception | Planned fix |
| --- | --- | --- |
| FreeBSD 15.0 guest image | Prebuilt binary from download.freebsd.org, not built from source | Build from FreeBSD source. The download hash is filled and verified (2026-11-16): the complete download passed an xz integrity test and its SHA-256 matches the FreeBSD project's published CHECKSUM.SHA256 exactly |
| Nix binary cache | Builds use prebuilt packages from cache.nixos.org | Add a source-only build option |
| React, Angular, Ruby on Rails | Installed on first boot from npm and RubyGems, without pinned versions | Pin versions in lockfiles and review each license |
| PG4WP WordPress plugin | GitHub fork with no releases. Commit pinned 2026-11-16 (ea843d1, the fork's HEAD, layout reviewed against its install instructions); hash computed with nix hash path | Review the plugin source in depth; the first full build re-verifies the hash |
| Proprietary firmware | Disabled by policy, so some Wi-Fi and GPU hardware may not work | Document a hardware exception list |
| CUDA | Not used, so PyTorch and TensorFlow run on CPU only | Revisit only if an exception is approved |
| First user's groups | GNOME Initial Setup creates the first account, so docker and kvm membership is not set | Add a first-boot step |
