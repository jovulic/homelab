{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.certificate.authority;
in
with lib;
{
  options.homelab.certificate.authority = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable certificate generation";
    };

    rootCertificateAuthority = {
      commonName = mkOption {
        type = types.str;
        default = "Homelab Root CA";
        description = "Common Name for the Root CA";
      };
      organization = mkOption {
        type = types.str;
        default = "Homelab";
        description = "Organization for the Root CA";
      };
      organizationalUnit = mkOption {
        type = types.str;
        default = "Root CA";
        description = "Organizational Unit for the Root CA";
      };
      expiry = mkOption {
        type = types.str;
        default = "87600h"; # 10 years
        description = "Expiry for the Root CA";
      };
    };

    certificates = mkOption {
      description = "Certificates to generate";
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            commonName = mkOption {
              type = types.str;
              description = "Common Name for the certificate";
            };
            hosts = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Hosts for the certificate (SANs)";
            };
            organization = mkOption {
              type = types.str;
              default = "Homelab";
              description = "Organization for the certificate";
            };
            organizationalUnit = mkOption {
              type = types.str;
              default = "Hosts";
              description = "Organizational Unit for the certificate";
            };
            profile = mkOption {
              type = types.enum [
                "server"
                "client"
                "peer"
                "intermediate"
              ];
              default = "server";
              description = "cfssl profile to use";
            };
          };
        }
      );
    };

    server = {
      enable = mkEnableOption "Enable cfssl server";
      address = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Address for the cfssl server";
      };
      port = mkOption {
        type = types.port;
        default = 23775;
        description = "Port for the cfssl server";
      };
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
            generate_certificates = concatStringsSep "\n" (
              mapAttrsToList (name: certCfg: ''
                if [[ ! -e ${name}.pem ]]; then
                  cfssl gencert \
                    -ca ca.pem \
                    -ca-key ca-key.pem \
                    -config /etc/certs/cfssl.json \
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
      # NOTE: The group is used as a way for other users to have access to
      # certificates.
      users.groups.certs = { };

      environment.systemPackages = [
        pkgs.cfssl
      ];

      environment.etc = {
        "certs/ca.json".text = builtins.toJSON {
          CN = cfg.rootCertificateAuthority.commonName;
          key = {
            algo = "ecdsa";
            size = 256;
          };
          names = [
            {
              O = cfg.rootCertificateAuthority.organization;
              OU = cfg.rootCertificateAuthority.organizationalUnit;
            }
          ];
        };
        "certs/cfssl.json".text = builtins.toJSON {
          signing = {
            default = {
              expiry = "8760h";
            };
            profiles = {
              peer = {
                usages = [
                  "signing"
                  "digital signature"
                  "key encipherment"
                  "client auth"
                  "server auth"
                ];
                expiry = "8760h";
              };
              server = {
                usages = [
                  "signing"
                  "digital signature"
                  "key encipherment"
                  "server auth"
                ];
                expiry = "8760h";
              };
              client = {
                usages = [
                  "signing"
                  "digital signature"
                  "key encipherment"
                  "client auth"
                ];
                expiry = "8760h";
              };
              intermediate = {
                usages = [
                  "signing"
                  "digital signature"
                  "key encipherment"
                  "cert sign"
                  "crl sign"
                ];
                expiry = "43800h";
                ca_constraint = {
                  is_ca = true;
                  max_path_len = 1;
                };
              };
            };
          };
        };
      }
      // (mapAttrs' (
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
      ) cfg.certificates);

      systemd.services.setup-certs = {
        description = "Generate certificates";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${setup_certs}/bin/setup_certs";
        };
      };

      systemd.services.cfssl-serve = mkIf cfg.server.enable {
        description = "cfssl server";
        after = [ "certificates.service" ];
        requires = [ "certificates.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.cfssl}/bin/cfssl serve -address ${cfg.server.address} -port ${toString cfg.server.port} -ca /var/lib/certs/ca.pem -ca-key /var/lib/certs/ca-key.pem -config /etc/certs/cfssl.json";
          WorkingDirectory = "/var/lib/certs";
          User = "root";
        };
      };
    };
}
