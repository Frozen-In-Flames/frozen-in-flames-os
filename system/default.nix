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

  # Libre policy: proprietary firmware is not loaded. Some Wi-Fi and GPU hardware
  # may not work until a documented exception is approved.
  hardware.enableRedistributableFirmware = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Desktop. No automatic login.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # No default credentials. Account setup at first boot is not built yet.
  users.mutableUsers = true;
  users.users.frozen = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "kvm" ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = lib.mkDefault false;
  };
}
