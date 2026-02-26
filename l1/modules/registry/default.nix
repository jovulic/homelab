{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.registry;
in
with lib;
{
  options.homelab.registry = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable container registry.";
    };
    dataset = mkOption {
      type = types.str;
      default = "pool/default";
      description = "The name of the ZFS dataset to use for storage.";
    };
    registryAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "The address the registry will listen on.";
    };
    registryPort = mkOption {
      type = types.port;
      default = 5000;
      description = "The port the registry will listen on.";
    };
  };
  config =
    let
      setup_registry_storage = pkgs.writeShellApplication {
        name = "setup_registry_storage";
        runtimeInputs = with pkgs; [
          zfs
          coreutils
        ];
        text = builtins.readFile (
          pkgs.replaceVars ./setup_storage.sh {
            dataset = cfg.dataset;
          }
        );
      };
      setup_registry_cleaner = pkgs.writeShellApplication {
        name = "setup_registry_cleaner";
        runtimeInputs = with pkgs; [
          curl
          jq
          coreutils
          gnused
          gawk
        ];
        text = builtins.readFile (
          pkgs.replaceVars ./setup_cleaner.sh {
            registry_url = "http://127.0.0.1:${toString cfg.registryPort}";
          }
        );
      };
    in
    mkIf cfg.enable {
      systemd.services."registry_storage" = {
        description = "Setup ZFS storage for container registry";
        wantedBy = [ "multi-user.target" ];
        after = [
          "zfs-mount.service"
          "zfs-import.target"
        ];
        before = [ "docker-registry.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${setup_registry_storage}/bin/setup_registry_storage";
          RemainAfterExit = true;
        };
      };

      systemd.services.docker-registry = {
        wants = [ "registry_storage.service" ];
        after = [ "registry_storage.service" ];
        environment = {
          OTEL_TRACES_EXPORTER = "none"; # disable open telemetry
        };
      };

      services.dockerRegistry = {
        enable = true;
        listenAddress = cfg.registryAddress;
        port = cfg.registryPort;
        storagePath = "/var/lib/registry";
        enableDelete = true;
        enableGarbageCollect = true;
      };

      systemd.services."registry_cleaner" = {
        description = "Clean up old container registry images";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${setup_registry_cleaner}/bin/setup_registry_cleaner";
        };
        startAt = "daily";
      };
    };
}
