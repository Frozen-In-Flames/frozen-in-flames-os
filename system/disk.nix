# Reference disk layout for the standalone NixOS configurations.
#
# The image packages (qcow2, iso) get their filesystem and bootloader layout
# from their nixos-generators format modules, so this module is deliberately
# NOT part of releaseModules. It exists so the bare nixosConfigurations are
# complete, bootable-in-principle systems: the first full flake evaluation
# (GitHub Actions, 2026-11-16) reached the system assertions and failed on
# exactly these two points, no root filesystem and no bootloader device.
#
# The layout matches how the images are actually run: a single virtio disk
# (scripts/run.sh boots the qcow2 in QEMU), root on the partition labeled
# "nixos", GRUB on /dev/vda. A real install on different hardware overrides
# this module with its own hardware configuration.
{ ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/vda" ];
  };
}
