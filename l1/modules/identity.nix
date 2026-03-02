{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.identity;
in
with lib;
{
  options.homelab.identity = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable identity.";
    };
    domain = mkOption {
      type = types.str;
      example = "identity.lab";
      description = "The identity domain.";
    };
    certificate = mkOption {
      type = types.str;
      example = "identity";
      description = "The identity domain certificate.";
    };
    adminPasswordFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to the admin password file.";
    };
    idmAdminPasswordFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to the idm admin password file.";
    };
    kubernetes = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable kubernetes oauth2.";
      };
      secretFile = mkOption {
        type = types.str;
        description = "Path to kubernetes shared secret.";
      };
    };
  };

  config = mkIf cfg.enable {
    users.users.kanidm.extraGroups = [ "certs" ];

    services.kanidm = {
      package = pkgs.kanidmWithSecretProvisioning_1_8;
      enableServer = true;
      serverSettings = {
        domain = cfg.domain;
        origin = "https://${cfg.domain}";
        bindaddress = "127.0.0.1:8443";
        tls_chain = "/var/lib/certs/${cfg.certificate}.pem";
        tls_key = "/var/lib/certs/${cfg.certificate}-key.pem";
      };

      provision = {
        enable = true;
        adminPasswordFile = cfg.adminPasswordFile;
        idmAdminPasswordFile = cfg.idmAdminPasswordFile;

        systems.oauth2 = mkIf cfg.kubernetes.enable {
          "kubernetes" = {
            present = true;
            displayName = "OIDC for Kubernetes";
            originUrl = "https://${cfg.domain}";
            originLanding = "http://localhost:8000";
            basicSecretFile = cfg.kubernetes.secretFile;
          };
        };
      };
    };
  };
}
