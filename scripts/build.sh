#!/usr/bin/env bash
# Builds a Frozen in Flames output inside a Nix container.
# Usage: scripts/build.sh [iso|qcow2-dev]   (default: qcow2-dev)
# Needs Docker (or ENGINE=podman), network access, and about 100 GB of free disk.
set -euo pipefail
cd "$(dirname "$0")/.."
ENGINE="${ENGINE:-docker}"
TARGET="${1:-qcow2-dev}"
mkdir -p build

"$ENGINE" run --rm --privileged \
  -v "$PWD":/src -w /src \
  nixos/nix:latest \
  sh -c "printf 'experimental-features = nix-command flakes\nsandbox = false\n' >> /etc/nix/nix.conf && out=\$(nix build .#$TARGET --no-link --print-out-paths) && cp -rL \"\$out\"/. /src/build/"

echo "Built $TARGET into build/"
