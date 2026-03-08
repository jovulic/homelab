{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.zfs.create;
in
with lib;
{
  options.homelab.zfs.create = {
    enable = mkEnableOption "zfs create";
    datasets = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            dataset = mkOption {
              type = types.str;
              description = "The name of the dataset to create.";
            };
            mount = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to mount the dataset.";
            };
          };
        }
      );
      default = [ ];
      description = "List of create ZFS datasets to create.";
    };
  };
  config =
    let
      datasetConfigs = builtins.toJSON cfg.datasets;
      setup_create = pkgs.writeShellApplication {
        name = "setup_create";
        runtimeInputs = [
          pkgs.zfs
          pkgs.coreutils
          pkgs.jq
        ];
        text = builtins.readFile ./setup_create.sh;
      };
    in
    mkIf cfg.enable {
      systemd.services.setup-zfs-create = {
        enable = true;
        description = "Create create ZFS Datasets";
        wantedBy = [ "multi-user.target" ];
        after = [ "zfs.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${setup_create}/bin/setup_create '${datasetConfigs}'";
        };
      };
    };
}
