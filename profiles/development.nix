{ ... }:
{
  # DEVELOPMENT ONLY. Imported by frozen-in-flames-dev and qcow2-dev, never by the release.
  users.users.frozen.initialPassword = "frozen";
  security.sudo.wheelNeedsPassword = false;
  services.openssh.settings.PasswordAuthentication = true;
  networking.firewall.allowedTCPPorts = [ 22 80 8123 ];
}
