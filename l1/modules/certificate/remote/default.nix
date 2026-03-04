{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.certificate.remote;
in
with lib;
{
  options.homelab.certificate.remote = {
    enable = mkEnableOption "remote certificate";

    server = mkOption {
      type = types.str;
      description = "URL of the cfssl server.";
    };

    authKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to the file containing the shared HMAC key for cfssl authentication.";
    };

    certificates = mkOption {
      description = "Certificates to generate.";
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            commonName = mkOption {
              type = types.str;
              description = "Common Name for the certificate.";
            };
            hosts = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Hosts for the certificate (SANs).";
            };
            organization = mkOption {
              type = types.str;
              default = "Homelab";
              description = "Organization for the certificate.";
            };
            organizationalUnit = mkOption {
              type = types.str;
              default = "Hosts";
              description = "Organizational Unit for the certificate.";
            };
            profile = mkOption {
              type = types.enum [
                "server"
                "client"
                "peer"
                "intermediate"
              ];
              default = "server";
              description = "cfssl profile to use.";
            };
          };
        }
      );
    };
  };

  config =
    let
      setup_certs = pkgs.writeShellApplication {
        name = "setup_certs";
        runtimeInputs = [
          pkgs.cfssl
          pkgs.coreutils
        ];
        text = builtins.readFile (
          pkgs.replaceVars ./setup_certs.sh {
            generate_remote_certificates = concatStringsSep "\n" (
              mapAttrsToList (name: certCfg: ''
                if [[ ! -e ${name}.pem ]]; then
                  cfssl gencert \
                    -remote ${cfg.server} \
                    ${optionalString (cfg.authKeyFile != null) "-authkey ${cfg.authKeyFile}"} \
                    -profile=${certCfg.profile} \
                    /etc/certs/${name}.json | \
                  cfssljson -bare ${name}
                fi
              '') cfg.certificates
            );
          }
        );
      };
    in
    mkIf cfg.enable {
      users.groups.certs = { };

      environment.systemPackages = [ pkgs.cfssl ];

      environment.etc = (
        mapAttrs' (
          name: certCfg:
          nameValuePair "certs/${name}.json" {
            text = builtins.toJSON {
              CN = certCfg.commonName;
              hosts = certCfg.hosts;
              key = {
                algo = "ecdsa";
                size = 256;
              };
              names = [
                {
                  O = certCfg.organization;
                  OU = certCfg.organizationalUnit;
                }
              ];
            };
          }
        ) cfg.certificates
      );

      systemd.services.setup-certs = {
        description = "Generate remote certificates";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${setup_certs}/bin/setup_certs";
        };
      };
    };
}
