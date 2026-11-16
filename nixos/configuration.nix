{ config, lib, pkgs, ... }:
let
  root = ../.;
  serviceNames = [ "catalog" "provenance" "dependency" "evidence" "policy" "profiles" "build" "ai" "workspace" ];
  mkService = name: port: {
    description = "FROZEN IN FLAMES ${name} service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "postgresql.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      User = "frozen-service";
      Group = "frozen-service";
      WorkingDirectory = "/opt/frozen-in-flames";
      ExecStart = "${pkgs.python3}/bin/python -m frozen_service --service ${name} --port ${toString port}";
      Restart = "on-failure";
      RestartSec = 3;
      StateDirectory = "frozen-in-flames";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/frozen-in-flames" ];
      Environment = [ "FIF_DATABASE_URL=postgresql://fif@/frozen_in_flames?host=/run/postgresql" "FIF_REGISTRY=/opt/frozen-in-flames/registry/platforms.json" "PYTHONPATH=/opt/frozen-in-flames/app" ];
    };
  };
  servicePorts = [ 8101 8102 8103 8104 8105 8106 8107 8108 8109 ];
  serviceAttrs = builtins.listToAttrs (lib.imap0 (i: name: { name = "fif-${name}"; value = mkService name (builtins.elemAt servicePorts i); }) serviceNames);
in {
  imports = [ ];
  system.stateVersion = "26.05";
  networking.hostName = "frozen-in-flames";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 8123 ];
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = false;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.gnome.gnome-initial-setup.enable = true;
  services.xserver.enable = true;

  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "frozen_in_flames" ];
    ensureUsers = [{ name = "fif"; ensureDBOwnership = true; }];
  };

  # Valkey is run as an explicit systemd unit to avoid relying on an
  # unverified NixOS module option name.
  systemd.services.valkey = {
    description = "Valkey cache and event transport";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.valkey}/bin/valkey-server --bind 127.0.0.1 --port 6379 --protected-mode yes";
      Restart = "on-failure";
      User = "valkey";
      Group = "valkey";
      StateDirectory = "valkey";
    };
  };
  users.groups.valkey = { };
  users.users.valkey = { isSystemUser = true; group = "valkey"; };

  services.nginx.enable = true;
  services.nginx.virtualHosts."_" = {
    default = true;
    locations."/".root = "/opt/frozen-in-flames/ui";
    locations."/api/catalog/".proxyPass = "http://127.0.0.1:8101/";
    locations."/api/provenance/".proxyPass = "http://127.0.0.1:8102/";
    locations."/api/dependency/".proxyPass = "http://127.0.0.1:8103/";
    locations."/api/evidence/".proxyPass = "http://127.0.0.1:8104/";
    locations."/api/policy/".proxyPass = "http://127.0.0.1:8105/";
    locations."/api/profiles/".proxyPass = "http://127.0.0.1:8106/";
    locations."/api/build/".proxyPass = "http://127.0.0.1:8107/";
    locations."/api/ai/".proxyPass = "http://127.0.0.1:8108/";
    locations."/api/workspace/".proxyPass = "http://127.0.0.1:8109/";
  };
  services.httpd.enable = true;
  services.httpd.adminAddr = "admin@localhost";
  services.httpd.port = 8080;
  virtualisation.docker.enable = true;
  virtualisation.podman.enable = false;
  services.k3s = { enable = true; role = "server"; clusterInit = true; };
  services.home-assistant.enable = true;
  services.home-assistant.openFirewall = false;

  users.groups.frozen-service = { };
  users.users.frozen-service = { isSystemUser = true; group = "frozen-service"; home = "/var/empty"; };
  systemd.services = serviceAttrs;

  environment.systemPackages = with pkgs; [
    git curl openssl gcc llvm python3 nodejs_22 ruby php go rustc cargo dotnet-sdk_8
    postgresql_16 valkey nginx apacheHttpd docker-compose kubectl k3s chromium firefox
    ffmpeg vlc blender libreoffice vim neovim vscodium qemu_full freetype
    python3Packages.pip python3Packages.numpy python3Packages.psycopg
  ];

  system.activationScripts.fif-source.text = ''
    mkdir -p /opt/frozen-in-flames
    cp -r ${../app} /opt/frozen-in-flames/app
    cp -r ${../registry} /opt/frozen-in-flames/registry
    cp -r ${../ui} /opt/frozen-in-flames/ui
    cp -r ${../db} /opt/frozen-in-flames/db
  '';
  systemd.services.fif-db-migrate = {
    description = "FROZEN IN FLAMES database migrations";
    wantedBy = [ "multi-user.target" ];
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      Group = "postgres";
      ExecStart = "${pkgs.postgresql_16}/bin/psql -h /run/postgresql -U postgres -d frozen_in_flames -f /opt/frozen-in-flames/db/migrations/001_initial.sql";
      RemainAfterExit = true;
    };
  };
}
