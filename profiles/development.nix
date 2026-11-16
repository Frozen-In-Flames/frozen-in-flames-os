{ ... }:
{
  # DEVELOPMENT ONLY. Used by frozen-in-flames-test and qcow2-test, never by the release.
  users.users.frozen = {
    isNormalUser = true;
    initialPassword = "frozen";
    extraGroups = [ "wheel" "docker" "kvm" ];
  };
  services.gnome.gnome-initial-setup.enable = false;
  security.sudo.wheelNeedsPassword = false;
  services.openssh.settings.PasswordAuthentication = true;
  networking.firewall.allowedTCPPorts = [ 22 80 8080 8123 ];
}
