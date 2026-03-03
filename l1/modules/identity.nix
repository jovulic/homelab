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
        trust_x_forward_for = true;
      };

      provision =
        let
          k8sAdminGroup = "k8s_admin";
        in
        {
          enable = true;
          adminPasswordFile = cfg.adminPasswordFile;
          idmAdminPasswordFile = cfg.idmAdminPasswordFile;

          groups = {
            ${k8sAdminGroup} = { };
          };

          persons = {
            "me" = {
              displayName = "Me";
              mailAddresses = [ "me@${cfg.domain}" ];
              groups = [ k8sAdminGroup ];
            };
          };

          systems.oauth2 = mkIf cfg.kubernetes.enable {
            "kubernetes" = {
              present = true;
              displayName = "OIDC for Kubernetes";
              originUrl = [ "http://localhost:8000" ];
              originLanding = "https://kubernetes.lab"; # NOTE: once the dashboard is up this can point there.
              basicSecretFile = cfg.kubernetes.secretFile;
              scopeMaps = {
                ${k8sAdminGroup} = [
                  "openid"
                  "profile"
                  "email"
                  "groups"
                ];
              };
              claimMaps = {
                "groups" = {
                  joinType = "array";
                  valuesByGroup = {
                    ${k8sAdminGroup} = [ "${k8sAdminGroup}" ];
                  };
                };
              };
            };
          };
        };
    };
  };
}
