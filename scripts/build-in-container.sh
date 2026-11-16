#!/usr/bin/env bash
# Runs scripts/build.sh inside a Nix container, for machines without Nix installed.
# Usage: scripts/build-in-container.sh [qcow2|qcow2-test|iso|check]
# Needs Docker (or ENGINE=podman), network access, and about 100 GB of free disk.
set -euo pipefail
cd "$(dirname "$0")/.."
ENGINE="${ENGINE:-docker}"
TARGET="${1:-qcow2}"

"$ENGINE" run --rm --privileged \
  -v "$PWD":/src -w /src \
  nixos/nix:latest \
  sh -c "printf 'experimental-features = nix-command flakes\nsandbox = false\n' >> /etc/nix/nix.conf && nix shell nixpkgs#python3 --command ./scripts/build.sh '$TARGET'"
