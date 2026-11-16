{ config, pkgs, lib, ... }:
let
  # Ports match SERVICE_PORTS in app/frozen_service/__main__.py.
  servicePorts = {
    catalog = 8101;
    provenance = 8102;
    dependency = 8103;
    evidence = 8104;
    policy = 8105;
    profiles = 8106;
    build = 8107;
    ai = 8108;
    workspace = 8109;
  };

  # The application, registry, schema, and UI as one store path, without bytecode caches.
  frozenApp = pkgs.runCommand "frozen-in-flames-app" { } ''
    mkdir -p $out
    cp -r ${../app} $out/app
    cp -r ${../registry} $out/registry
    cp -r ${../migrations} $out/migrations
    cp -r ${../web} $out/web
    find $out -name __pycache__ -prune -exec rm -rf {} +
  '';

  # One systemd unit per service: loopback-only, unprivileged, and sandboxed.
  mkService = name: port: {
    description = "FROZEN IN FLAMES ${name} service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = {
      FIF_ROOT = "${frozenApp}";
      FIF_REGISTRY = "${frozenApp}/registry/platforms.json";
      FIF_STATE = "/var/lib/frozen-in-flames";
      PYTHONPATH = "${frozenApp}/app";
      PYTHONDONTWRITEBYTECODE = "1";
    };
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 -m frozen_service --service ${name} --port ${toString port}";
      DynamicUser = true;
      StateDirectory = "frozen-in-flames";
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      CapabilityBoundingSet = "";
    };
  };
in
{
  # Delivery: nginx is the public entry point. Routes are listed in docs/RECONCILIATION.md.
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    virtualHosts.frozen = {
      default = true;
      root = "${frozenApp}/web";
      locations = {
        "/ha/" = {
          proxyPass = "http://127.0.0.1:8123/";
          proxyWebsockets = true;
        };
        "/legacy/" = {
          proxyPass = "http://127.0.0.1:8081/";
        };
      } // lib.mapAttrs' (name: port:
        lib.nameValuePair "/api/${name}/" {
          proxyPass = "http://127.0.0.1:${toString port}/";
        }
      ) servicePorts;
    };
  };

  systemd.services = (lib.mapAttrs' (name: port:
    lib.nameValuePair "frozen-${name}" (mkService name port)
  ) servicePorts) // {
    frozen-migrate = {
      description = "Apply FROZEN IN FLAMES database migrations";
      wantedBy = [ "multi-user.target" ];
      after = [ "postgresql.service" "postgresql-setup.service" ];
      requires = [ "postgresql.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
      };
      script = ''
        ${config.services.postgresql.package}/bin/psql -d frozen -v ON_ERROR_STOP=1 -f ${frozenApp}/migrations/001_initial.sql
      '';
    };
  };

  # Data: the frozen database exists before the migration runs.
  services.postgresql.ensureDatabases = [ "frozen" ];
}
