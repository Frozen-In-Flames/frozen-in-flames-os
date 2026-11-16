# Provenance exceptions

Each item below departs from the strict libre policy, or cannot be verified until the
first build. Each has a planned fix.

| Item | Why it is an exception | Planned fix |
| --- | --- | --- |
| FreeBSD guest image | A prebuilt binary downloaded from download.freebsd.org, not built from source | Build the image from FreeBSD source, which takes hours |
| Nix binary cache | Builds use prebuilt packages from cache.nixos.org | Add a source-only build option |
| React, Angular, Ruby on Rails | Installed at first boot from npm and RubyGems, with no pinned lockfile | Pin versions in lockfiles and review each license |
| WordPress plugin PG4WP | Downloaded from wordpress.org, hash still a placeholder | Fill the hash from the first build and review the plugin source |
| FreeBSD image hash | Placeholder until the first build | Fill from the first build |
| Proprietary firmware | Disabled by policy, so some Wi-Fi and GPU hardware may not work | Document a hardware exception list |
| CUDA | Not used, so PyTorch and TensorFlow run on CPU only | Revisit only if an exception is approved |
| First user's groups | GNOME Initial Setup creates the first account, so docker and kvm membership is not set | Solve in a first-boot step |
