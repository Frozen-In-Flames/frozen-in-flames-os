{ config, pkgs, lib, ... }:
let
  wordpressRoot = "/var/lib/wordpress";
  phpSocket = config.services.phpfpm.pools.wordpress.socket;

  # PG4WP, the PostgreSQL driver for WordPress, from its maintained GitHub fork.
  # The fork publishes no releases, so rev is a pinned commit: the fork's HEAD
  # as of 2026-11-16, reviewed for layout against the fork's own install
  # instructions (the pg4wp directory goes in wp-content, and db.php is copied
  # from inside it to wp-content/db.php). The hash is the archive tree hash
  # computed with nix hash path; the first full build re-verifies it.
  pg4wp = pkgs.fetchFromGitHub {
    owner = "PostgreSQL-For-Wordpress";
    repo = "postgresql-for-wordpress";
    rev = "ea843d1560a40cce42b9297323636bde59a9bc70";
    hash = "sha256-fiT5IMFlTvrNFO9ak1yQHyxa/dYZu7/HRxVO7e3d0kc=";
  };
  # FreeBSD 15.0-RELEASE amd64 UFS image from FreeBSD's official release path.
  # The first build stops on the hash and prints it.
  freebsdArchive = pkgs.fetchurl {
    url = "https://download.freebsd.org/releases/VM-IMAGES/15.0-RELEASE/amd64/Latest/FreeBSD-15.0-RELEASE-amd64-ufs.qcow2.xz";
    hash = lib.fakeHash;
  };
  freebsdImage = pkgs.runCommand "freebsd.qcow2" { nativeBuildInputs = [ pkgs.xz ]; } ''
    xz -dc ${freebsdArchive} > $out
  '';
in
{
  # Data: PostgreSQL also holds WordPress's database.
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "wordpress" ];
    ensureUsers = [{ name = "wordpress"; ensureDBOwnership = true; }];
  };

  # Redis is replaced by Valkey, its BSD-licensed fork. See docs/license-review.md.
  # Verify the services.valkey option name on the first build.
  services.valkey.servers."" = {
    enable = true;
    settings = {
      port = 6379;
      bind = "127.0.0.1";
    };
  };

  # Web: WordPress runs under PHP-FPM on port 8080. The workspace owns port 80.
  services.nginx.virtualHosts.wordpress = {
    listen = [ { addr = "0.0.0.0"; port = 8080; } ];
    root = wordpressRoot;
    locations."/" = {
      tryFiles = "$uri $uri/ /index.php?$args";
    };
    locations."~ \\.php$" = {
      extraConfig = ''
        include ${config.services.nginx.package}/conf/fastcgi_params;
        fastcgi_pass unix:${phpSocket};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
      '';
    };
  };

  users.groups.wordpress = { };
  users.users.wordpress = {
    isSystemUser = true;
    group = "wordpress";
  };

  services.phpfpm.pools.wordpress = {
    user = "wordpress";
    group = "wordpress";
    settings = {
      "listen.owner" = config.services.nginx.user;
      "listen.group" = config.services.nginx.group;
      "pm" = "dynamic";
      "pm.max_children" = 8;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 3;
    };
  };

  # Copies WordPress and the PG4WP plugin into a writable location on first boot.
  systemd.services.frozen-wordpress = {
    description = "Prepare WordPress with PostgreSQL support";
    wantedBy = [ "multi-user.target" ];
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -d ${wordpressRoot} ]; then
        cp -r ${pkgs.wordpress}/share/wordpress ${wordpressRoot}
        chmod -R u+w ${wordpressRoot}
        cp -r ${pg4wp}/pg4wp ${wordpressRoot}/wp-content/pg4wp
        cp ${pg4wp}/pg4wp/db.php ${wordpressRoot}/wp-content/db.php
        chown -R wordpress:wordpress ${wordpressRoot}
      fi
    '';
  };

  # Apache runs as its own unit, defined in system/legacy.nix.

  # Delivery: Docker runs the containerized modules.
  virtualisation.docker.enable = true;

  # Delivery: k3s is a single-node Kubernetes distribution. Verify the option names on the first build.
  services.k3s = {
    enable = true;
    role = "server";
    # Traefik and ServiceLB bind host ports 80 and 443, which nginx uses. Disable both.
    extraFlags = [ "--write-kubeconfig-mode=0644" "--disable=traefik" "--disable=servicelb" ];
  };

  # Smart home: Home Assistant listens on 8123. nginx does not proxy it, because it needs a
  # base URL to work under a path.
  services.home-assistant = {
    enable = true;
    config = {
      default_config = { };
      http = {
        server_port = 8123;
        use_x_forwarded_for = true;
        trusted_proxies = [ "127.0.0.1" ];
      };
    };
  };

  # Foundation: FreeBSD runs as a QEMU guest. The disk is read-only (-snapshot),
  # so the image never changes.
  systemd.services.frozen-freebsd = {
    description = "FreeBSD guest for FreeBSD-only workloads";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Restart = "on-failure";
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.qemu}/bin/qemu-system-x86_64"
        "-accel kvm -cpu host -smp 2 -m 2G"
        "-snapshot"
        "-drive file=${freebsdImage},if=virtio,format=qcow2"
        "-nic user,hostfwd=tcp:127.0.0.1:2223-:22"
        "-display none -serial null -monitor none"
      ];
    };
  };

  # Web: React, Angular and Ruby on Rails are installed on first boot, not from nixpkgs.
  systemd.services.frozen-toolchains = {
    description = "Install React, Angular and Ruby on Rails";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.nodejs pkgs.ruby pkgs.gcc pkgs.gnumake pkgs.git ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "30min";
    };
    script = ''
      if [ -f /opt/frozen/.toolchains-done ]; then exit 0; fi
      mkdir -p /opt/frozen/shell /opt/frozen/npm /opt/frozen/gems
      npm install --prefix /opt/frozen/shell react react-dom
      npm install -g --prefix /opt/frozen/npm @angular/cli
      GEM_HOME=/opt/frozen/gems gem install rails --no-document
      touch /opt/frozen/.toolchains-done
    '';
  };
}
