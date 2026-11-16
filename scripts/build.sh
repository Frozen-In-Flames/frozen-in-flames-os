#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
target="${1:-qcow2}"
case "$target" in
  qcow2|qcow2-test|iso) attr=".#packages.x86_64-linux.$target" ;;
  check) nix flake check --show-trace; exit 0 ;;
  *) echo "usage: $0 {qcow2|qcow2-test|iso|check}" >&2; exit 2 ;;
esac
python3 scripts/validate_catalog.py registry/platforms.json
python3 -m unittest discover -s tests -v
nix build "$attr" --show-trace
mkdir -p artifacts
rm -rf "artifacts/$target"
cp -rL result "artifacts/$target"
find "artifacts/$target" -type f -exec sha256sum {} + | tee "artifacts/$target.sha256"
