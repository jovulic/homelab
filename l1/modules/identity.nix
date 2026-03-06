{
  config,
  lib,
  pkgs,
  hlib,
  ...
}:
let
  cfg = config.homelab.identity;
in
with lib;
with hlib;
{
  options.homelab.identity = {
    enable = mkEnableOption "identity";
    domain = mkOption {
      type = types.str;
      example = "identity.lab";
      description = "The identity domain.";
    };
    address = mkOption {
      type = types.str;
      description = "The identity bind address.";
      default = "0.0.0.0";
    };
    port = mkOption {
      type = types.port;
      default = 8443;
      description = "The port identity will listen on.";
    };
    certificate = mkOption {
      type = types.str;
      example = "identity";
      description = "The identity domain certificate.";
    };
    adminPassword = mkOption {
      type = types.nullOr htypes.sopsSecret;
      default = null;
      description = "The admin password.";
    };
    idmAdminPassword = mkOption {
      type = types.nullOr htypes.sopsSecret;
      default = null;
      description = "The idm admin password.";
    };
    kubernetes = mkOption {
      default = { };
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable kubernetes oauth2.";
          };
          secret = mkOption {
            type = htypes.sopsSecret;
            description = "The kubernetes shared secret.";
          };
        };
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
        bindaddress = "${cfg.address}:${toString cfg.port}";
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
          adminPasswordFile = if cfg.adminPassword != null then cfg.adminPassword.secret.path else null;
          idmAdminPasswordFile =
            if cfg.idmAdminPassword != null then cfg.idmAdminPassword.secret.path else null;

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
              basicSecretFile = cfg.kubernetes.secret.secret.path;
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
