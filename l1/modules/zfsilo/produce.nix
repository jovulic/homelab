{
  config,
  lib,
  hlib,
  ...
}:
let
  cfg = config.homelab.zfsilo.produce;
in
with lib;
with hlib;
{
  options.homelab.zfsilo.produce = {
    enable = mkEnableOption "zfsilo producer";
    image = mkOption {
      type = types.str;
      default = "ghcr.io/jovulic/zfsilo:0.3.1";
      description = "The zfsilo image to use.";
    };
    address = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "The address that zfsilo will listen on.";
    };
    port = mkOption {
      type = types.port;
      default = 8080;
      description = "The port zfsilo will listen on.";
    };
    service = mkOption {
      default = { };
      type = types.submodule {
        options = {
          externalServerUri = mkOption {
            type = types.str;
            default = "dns:///:${toString cfg.port}";
            description = "The external URI for the zfsilo service.";
          };
          authorizedKeys = mkOption {
            type = types.listOf (
              types.submodule {
                options = {
                  identity = mkOption {
                    type = types.str;
                    description = "The identity name for the API key.";
                  };
                  token = mkOption {
                    type = htypes.sopsSecret;
                    description = "The API token.";
                  };
                };
              }
            );
            default = [ ];
            description = "List of authorized API keys.";
          };
        };
      };
    };
    database = mkOption {
      default = { };
      type = types.submodule {
        options = {
          path = mkOption {
            type = types.str;
            default = "/var/lib/zfsilo/zfsilo.db";
            description = "Path to the zfsilo database file.";
          };
        };
      };
    };
    command = mkOption {
      default = { };
      type = types.submodule {
        options = {
          produceTarget = mkOption {
            default = { };
            type = types.submodule {
              options = {
                password = mkOption {
                  type = htypes.sopsSecret;
                  description = "The iSCSI password.";
                };
              };
            };
          };
          consumeTargets = mkOption {
            type = types.listOf (
              types.submodule {
                options = {
                  connect = mkOption {
                    default = { };
                    type = types.submodule {
                      options = {
                        address = mkOption {
                          type = types.str;
                          description = "Remote address.";
                        };
                        port = mkOption {
                          type = types.port;
                          default = 22;
                          description = "Remote SSH port.";
                        };
                        username = mkOption {
                          type = types.str;
                          default = "zfsilo";
                          description = "Remote SSH username.";
                        };
                        password = mkOption {
                          type = types.nullOr htypes.sopsSecret;
                          default = null;
                          description = "The SSH password.";
                        };
                      };
                    };
                  };
                  password = mkOption {
                    type = htypes.sopsSecret;
                    description = "The iSCSI password.";
                  };
                  iqn = mkOption {
                    type = types.str;
                    description = "Remote initiator IQN.";
                  };
                };
              }
            );
            default = [ ];
            description = "List of consume targets.";
          };
        };
      };
    };
    user = mkOption {
      default = { };
      type = types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            default = "zfsilo";
            description = "The zfsilo user name";
          };
          hashedPassword = mkOption {
            type = types.nullOr htypes.sopsSecret;
            default = null;
            description = "The hashed password.";
          };
        };
      };
    };
  };

  config =
    let
      backend = config.virtualisation.oci-containers.backend;
      containerServiceName = "${backend}-zfsilo";
    in
    mkIf cfg.enable {
      users.groups.${cfg.user.name} = { };
      users.users.${cfg.user.name} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        hashedPasswordFile =
          if cfg.user.hashedPassword != null then cfg.user.hashedPassword.secret.path else null;
      };
      security.sudo.extraRules = [
        {
          users = [ cfg.user.name ];
          commands = [
            {
              command = "ALL";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

      systemd.tmpfiles.rules = [
        # Create the database directory.
        "d ${dirOf cfg.database.path} 0750 root root -"
      ];

      sops.templates."zfsilo-config.json" = {
        content = builtins.toJSON {
          log = {
            level = "INFO";
            format = "JSON";
          };
          service = {
            bindAddress = "${toString cfg.address}:${toString cfg.port}";
            externalServerURI = cfg.service.externalServerUri;
            keys = map (key: {
              identity = key.identity;
              token = key.token.placeholder;
            }) cfg.service.authorizedKeys;
          };
          database = {
            dsn = "file:${cfg.database.path}?cache=shared";
          };
          command = {
            produceTarget = {
              type = "LOCAL";
              runAsRoot = true;
              host = {
                hostname = config.networking.hostName;
              };
              password = cfg.command.produceTarget.password.placeholder;
            };
            consumeTargets = map (target: {
              type = "REMOTE";
              remote = {
                address = target.connect.address;
                port = target.connect.port;
                username = target.connect.username;
                password = if target.connect.password != null then target.connect.password.placeholder else "";
              };
              iqn = target.iqn;
              password = target.password.placeholder;
            }) cfg.command.consumeTargets;
          };
        };
      };

      systemd.services.${containerServiceName} = {
        after = [
          "zfs.target"
          "target.service"
        ];
      };

      virtualisation.oci-containers.containers.zfsilo = {
        image = cfg.image;
        volumes = [
          "${config.sops.templates."zfsilo-config.json".path}:/config.json:ro"
          "${dirOf cfg.database.path}:${dirOf cfg.database.path}:rw"
          "/dev:/dev:rw"
          "/sys:/sys:rw"
          "/run/udev:/run/udev:ro"
        ];
        privileged = true;
        extraOptions = [ "--net=host" ];
        cmd = [
          "/bin/zfsilo"
          "start"
          "--config=/config.json"
        ];
      };
    };
}
