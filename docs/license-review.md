# License review

Status of each platform against the libre policy. These entries are from memory and have
not been checked against upstream sources. Every row marked "Verify" needs checking, and
the FSF evaluation in the specification requires that check for every row.

| Platform | License | Status |
| --- | --- | --- |
| Linux | GPL-2.0 | Free. Firmware excluded by policy |
| FreeBSD | BSD-2-Clause | Free source. Prebuilt image is a provenance exception |
| systemd | LGPL-2.1-or-later | Free |
| QEMU | GPL-2.0-only AND LGPL-2.1-only | Free. Verify bundled firmware blobs |
| OpenSSL | Apache-2.0 | Free |
| curl | curl license (MIT-style) | Free |
| GCC | GPL-3.0-or-later with runtime exceptions | Free |
| LLVM | Apache-2.0 with LLVM exceptions | Free |
| Python | PSF-2.0 | Free |
| Node.js | MIT | Verify bundled dependencies |
| Ruby | Ruby License / BSD-2-Clause | Verify |
| PHP | PHP-3.01 | Verify against the FSF list |
| Go | BSD-3-Clause | Free |
| Rust | MIT or Apache-2.0 | Free |
| .NET | MIT | Free |
| TypeScript | Apache-2.0 | Free |
| PostgreSQL | PostgreSQL License | Free |
| Redis | RSALv2 / SSPLv1 from 7.4; AGPLv3 is an option in 8.0 | Not libre. Replaced by Valkey (BSD-3-Clause) |
| nginx | BSD-2-Clause | Free |
| Apache HTTP Server | Apache-2.0 | Free |
| Docker | Apache-2.0 | Free |
| Kubernetes | Apache-2.0 | Free |
| Git | GPL-2.0 | Free |
| React | MIT | Free |
| Angular | MIT | Free |
| Ruby on Rails | MIT | Free |
| WordPress | GPL-2.0-or-later | Free. PG4WP plugin needs review |
| Chromium | BSD-3-Clause | Verify build options (codecs, DRM) |
| Firefox | MPL-2.0 | Verify build options (DRM) |
| PyTorch | BSD-3-Clause | Free on CPU. CUDA is nonfree and not used |
| TensorFlow | Apache-2.0 | Free on CPU. CUDA is nonfree and not used |
| FFmpeg | LGPL-2.1-or-later (GPL parts in some builds) | Verify build options |
| VLC | GPL-2.0-or-later | Verify plugins |
| Blender | GPL-2.0-or-later | Free |
| LibreOffice | MPL-2.0 | Free |
| VS Code (VSCodium) | MIT | Free. Microsoft's VS Code is not open source |
| Vim | Vim license | Verify against the FSF list |
| Neovim | Apache-2.0 (some Vim-licensed code) | Free |
| Home Assistant | Apache-2.0 | Free |


## Resolved against sources

| Platform | Decision | Source |
| --- | --- | --- |
| QEMU | GPL-2.0-only AND LGPL-2.1-only | QEMU's maintainer stated in 2013 that the combined binary is GPLv2-only. The Alpine package record lists GPL-2.0-only AND LGPL-2.1-only. The registry's GPL-2.0-or-later was wrong |
| Blender | GPL-2.0-or-later | Blender's copyright file says version 2 of the GPL or any later version. The registry's GPL-3.0-or-later was wrong |
| LibreOffice | MPL-2.0 | The official license page says MPL v2.0. The dual MPL and LGPLv3+ licensing applies to contributions. The registry's dual entry was corrected to MPL-2.0 |

Resolved 2026-11-21: the Neovim row. Neovim's own LICENSE.txt states
that Neovim is licensed under the Apache 2.0 license except for parts
contributed under the Vim license; the registry entry (Apache-2.0)
states the primary license correctly and the row is closed. Still
open: firmware blobs bundled with QEMU.
