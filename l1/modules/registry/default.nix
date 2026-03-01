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
    address = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "The address the registry will listen on.";
    };
    port = mkOption {
      type = types.port;
      default = 5000;
      description = "The port the registry will listen on.";
    };
  };
  config =
    let
      setup_registry_storage = pkgs.writeShellApplication {
        name = "setup_registry_storage";
        runtimeInputs = [
          pkgs.zfs
          pkgs.coreutils
        ];
        text = builtins.readFile (
          pkgs.replaceVars ./setup_storage.sh {
            dataset = cfg.dataset;
          }
        );
      };
      setup_registry_cleaner = pkgs.writeShellApplication {
        name = "setup_registry_cleaner";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
          pkgs.coreutils
          pkgs.gnused
          pkgs.gawk
        ];
        text = builtins.readFile (
          pkgs.replaceVars ./setup_cleaner.sh {
            registry_url = "http://127.0.0.1:${toString cfg.port}";
          }
        );
      };
    in
    mkIf cfg.enable {
      systemd.services.registry-storage = {
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
        wants = [ "registry-storage.service" ];
        after = [ "registry-storage.service" ];
        environment = {
          OTEL_TRACES_EXPORTER = "none"; # disable open telemetry
        };
      };

      services.dockerRegistry = {
        enable = true;
        listenAddress = cfg.address;
        port = cfg.port;
        storagePath = "/var/lib/registry";
        enableDelete = true;
        enableGarbageCollect = true;
      };

      systemd.services.registry-cleaner = {
        description = "Clean up old container registry images";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${setup_registry_cleaner}/bin/setup_registry_cleaner";
        };
        startAt = "daily";
      };
    };
}
