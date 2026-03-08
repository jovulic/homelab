{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.zfs.extra;
in
with lib;
{
  options.homelab.zfs.extra = {
    enable = mkEnableOption "extra";
    datasets = mkOption {
      type = types.listOf (types.submodule {
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
      });
      default = [];
      description = "List of extra ZFS datasets to create.";
    };
  };
  config =
    let
      datasetConfigs = builtins.toJSON cfg.datasets;
      setup_extra = pkgs.writeShellApplication {
        name = "setup_extra";
        runtimeInputs = [ pkgs.zfs pkgs.coreutils pkgs.jq ];
        text = builtins.readFile ./setup_extra.sh;
      };
    in
    mkIf cfg.enable {
      systemd.services.setup-zfs-extra = {
        enable = true;
        description = "Create Extra ZFS Datasets";
        wantedBy = [ "multi-user.target" ];
        after = [ "zfs.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${setup_extra}/bin/setup_extra '${datasetConfigs}'";
        };
      };
    };
}