#!/usr/bin/env bash
# Boots a test image in a KVM virtual machine. Needs /dev/kvm on this machine.
# Usage: scripts/run.sh [image.qcow2]   (default: first qcow2 in build/)
# Ports: 2222 -> SSH, 8080 -> web, 8123 -> Home Assistant.
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE="${1:-$(ls build/*.qcow2 2>/dev/null | head -n 1)}"
CPUS="${CPUS:-4}"
MEMORY="${MEMORY:-12G}"

if [ -z "$IMAGE" ]; then
  echo "No qcow2 image found. Run scripts/build.sh first." >&2
  exit 1
fi
if [ ! -e /dev/kvm ]; then
  echo "No /dev/kvm. Enable virtualization in the BIOS, or run on a KVM host." >&2
  exit 1
fi

exec qemu-system-x86_64 \
  -accel kvm -cpu host -smp "$CPUS" -m "$MEMORY" \
  -drive file="$IMAGE",if=virtio,format=qcow2 \
  -nic user,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80,hostfwd=tcp::8123-:8123 \
  -vga virtio -display gtk \
  -device virtio-tablet-pci -device virtio-keyboard-pci
