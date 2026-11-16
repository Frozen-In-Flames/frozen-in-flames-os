{ lib, ... }:
{
  system.nixos.distroName = "Frozen in Flames";
  system.stateVersion = "25.05";

  environment.etc."issue".text = ''
    Frozen in Flames
    \n \l

  '';

  networking.hostName = "frozen";
  networking.hosts."127.0.0.1" = [ "frozen" ];
  networking.networkmanager.enable = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Libre policy: proprietary firmware is not loaded. See PROVENANCE-EXCEPTIONS.md.
  hardware.enableRedistributableFirmware = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # First boot: GNOME Initial Setup creates the first account. No default credentials.
  services.gnome.gnome-initial-setup.enable = lib.mkDefault true;
  users.mutableUsers = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = lib.mkDefault false;
  };
}
