# Provenance exceptions

| Item | Exception | Closure requirement |
|---|---|---|
| Original archive | `frozen-in-flames.tar.gz` was not present in the available Library listing | Reconcile this assembly against the full source archive when available |
| Package versions | Some on-demand platform targets are catalogued but not pinned as separate upstream releases | Lock each upstream source/version and verify license at that revision |
| FreeBSD VM image | Not downloaded or embedded | Fetch from official FreeBSD release mirror, verify signed checksum, record SHA-256 |
| WordPress plugin | No plugin artifact included | Select plugin, inspect GPL compatibility, fetch and record SHA-256 |
| SBOM | Schema and architecture are present; release SBOM not generated | Generate SPDX or CycloneDX from the actual Nix closure and container images |
| Build provenance | Schema exists; attestation not generated | Produce signed provenance from a successful reproducible build |
| Compliance mapping | Not asserted | Map controls to actual implementation and evidence; do not claim blanket CMMC/NIST compliance |
