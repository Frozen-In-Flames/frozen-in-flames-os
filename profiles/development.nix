{ ... }:
{
  # DEVELOPMENT ONLY. Used by frozen-in-flames-dev and qcow2-dev, never by the release.
  users.users.frozen = {
    isNormalUser = true;
    initialPassword = "frozen";
    extraGroups = [ "wheel" "docker" "kvm" ];
  };
  services.gnome.gnome-initial-setup.enable = false;
  security.sudo.wheelNeedsPassword = false;
  services.openssh.settings.PasswordAuthentication = true;
  networking.firewall.allowedTCPPorts = [ 22 80 8123 ];
}
