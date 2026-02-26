{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.proxy;
in
with lib;
{
  options.homelab.proxy = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable proxy.";
    };

    hosts = mkOption {
      description = "Virtual hosts for the proxy";
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            certificate = mkOption {
              type = types.str;
              description = "Name of the certificate to use (from /var/lib/certs/)";
            };
            locations = mkOption {
              type = types.attrsOf (
                types.submodule {
                  options = {
                    proxyPass = mkOption {
                      type = types.str;
                      description = "Target URL for the proxy.";
                    };
                    extraConfig = mkOption {
                      type = types.lines;
                      default = "";
                      description = "Extra configuration for the location block.";
                    };
                  };
                }
              );
              default = { };
            };
            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = "Extra configuration for the virtual host block.";
            };
          };
        }
      );
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [
      80 # http
      443 # https
    ];

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = mapAttrs (host: vhostCfg: {
        sslCertificate = "/var/lib/certs/${vhostCfg.certificate}.pem";
        sslCertificateKey = "/var/lib/certs/${vhostCfg.certificate}-key.pem";
        sslTrustedCertificate = "/var/lib/certs/ca.pem";
        forceSSL = true;
        locations = mapAttrs (path: locCfg: {
          proxyPass = locCfg.proxyPass;
          extraConfig = locCfg.extraConfig;
        }) vhostCfg.locations;
        extraConfig = vhostCfg.extraConfig;
      }) cfg.hosts;
    };

    systemd.services.nginx = {
      after = [ "certificates.service" ];
      wants = [ "certificates.service" ];
    };
  };
}
