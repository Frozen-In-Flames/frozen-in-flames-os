{ pkgs, ... }:
let
  # Apache serves legacy applications on loopback port 8081. nginx forwards /legacy/ to it.
  # This does not use services.httpd, because that module listens on port 80, which nginx owns.
  httpdConf = pkgs.writeText "frozen-legacy-httpd.conf" ''
    ServerRoot "${pkgs.apacheHttpd}"
    Listen 127.0.0.1:8081
    ServerName frozen-legacy
    PidFile /run/frozen-legacy/httpd.pid
    ErrorLog /var/lib/frozen-legacy/error.log
    CustomLog /var/lib/frozen-legacy/access.log common
    LogLevel warn

    LoadModule unixd_module modules/mod_unixd.so
    LoadModule mpm_event_module modules/mod_mpm_event.so
    LoadModule authz_core_module modules/mod_authz_core.so
    LoadModule dir_module modules/mod_dir.so
    LoadModule log_config_module modules/mod_log_config.so

    DocumentRoot "/var/lib/frozen-legacy"
    DirectoryIndex index.html
    <Directory "/var/lib/frozen-legacy">
      Require all granted
    </Directory>
  '';
in
{
  systemd.services.frozen-legacy = {
    description = "Apache HTTP Server for legacy applications (loopback only)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.apacheHttpd}/bin/httpd -f ${httpdConf} -DFOREGROUND";
      DynamicUser = true;
      StateDirectory = "frozen-legacy";
      RuntimeDirectory = "frozen-legacy";
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" ];
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      CapabilityBoundingSet = "";
    };
  };
}
