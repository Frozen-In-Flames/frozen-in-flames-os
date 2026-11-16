{ config, pkgs, lib, ... }:
let
  wordpressRoot = "/var/lib/wordpress";
  phpSocket = config.services.phpfpm.pools.wordpress.socket;

  # Placeholder hashes. The first build stops on these lines and prints the real
  # hash. Paste it over lib.fakeHash and build again.
  pg4wp = pkgs.fetchzip {
    url = "https://downloads.wordpress.org/plugin/pg4wp.zip";
    hash = lib.fakeHash;
  };
  freebsdArchive = pkgs.fetchurl {
    # Verify this URL against download.freebsd.org before the first build.
    url = "https://download.freebsd.org/releases/VM-IMAGES/14.3-RELEASE/amd64/Latest/FreeBSD-14.3-RELEASE-amd64.qcow2.xz";
    hash = lib.fakeHash;
  };
  freebsdImage = pkgs.runCommand "freebsd.qcow2" { nativeBuildInputs = [ pkgs.xz ]; } ''
    xz -dc ${freebsdArchive} > $out
  '';
in
{
  # Data: PostgreSQL is the main database. WordPress uses it through PG4WP.
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "wordpress" ];
    ensureUsers = [{ name = "wordpress"; ensureDBOwnership = true; }];
  };

  services.redis.servers."" = {
    enable = true;
    port = 6379;
  };

  # Delivery: nginx is the front door. It serves WordPress and proxies the rest.
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    virtualHosts.frozen = {
      default = true;
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
      locations."/ha/" = {
        proxyPass = "http://127.0.0.1:8123/";
        proxyWebsockets = true;
      };
      locations."/legacy/" = {
        proxyPass = "http://127.0.0.1:8081/";
      };
    };
  };

  # Web: WordPress runs under PHP-FPM.
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
        mkdir -p ${wordpressRoot}/wp-content/plugins
        cp -r ${pg4wp} ${wordpressRoot}/wp-content/plugins/pg4wp
        cp ${pg4wp}/db.php ${wordpressRoot}/wp-content/db.php
        chown -R wordpress:wordpress ${wordpressRoot}
      fi
    '';
  };

  # Delivery: Apache serves legacy applications behind nginx.
  # Apache's default port is 80, which nginx uses. Confirm the Listen override on first build.
  services.httpd = {
    enable = true;
    adminAddr = "admin@frozen";
    extraConfig = ''
      Listen 127.0.0.1:8081
    '';
  };

  # Delivery: Docker runs every containerized module.
  virtualisation.docker.enable = true;

  # Delivery: single-node Kubernetes for workloads that need scheduling.
  services.kubernetes = {
    roles = [ "master" "node" ];
    masterAddress = "frozen";
    easyCerts = true;
  };

  # Smart home: Home Assistant listens on 8123 and is reachable at /ha/.
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
