{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.zfs;
in
with lib;
{
  imports = [ ./extra ];
  options.homelab.zfs = {
    enable = mkEnableOption "zfs";
    hostId = mkOption {
      type = types.str;
      example = "028406e6"; # head -c 8 /etc/machine-id
      description = options.boot.networking.hostId.description;
    };
    poolName = mkOption {
      type = types.str;
      default = "pool";
      description = "The name of the ZFS pool to create and manage.";
    };
    vdev = mkOption {
      type = types.listOf types.str;
      example = [
        "mirror"
        "/dev/disk/by-id/disk1"
        "/dev/disk/by-id/disk2"
      ];
      description = "The vdev configuration arguments for the zpool.";
    };
    ssd = mkOption {
      default = { };
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable partitioning an SSD for SLOG, L2ARC, and a fastpool.";
          };
          device = mkOption {
            type = types.str;
            default = "";
            example = "/dev/disk/by-id/nvme-1234567890";
            description = "The block device path of the SSD.";
          };
          slogSize = mkOption {
            type = types.str;
            default = "16G";
            description = "Size of the SLOG partition.";
          };
          cacheSize = mkOption {
            type = types.str;
            default = "64G";
            description = "Size of the L2ARC cache partition.";
          };
          fastpoolName = mkOption {
            type = types.str;
            default = "fastpool";
            description = "The name of the fastpool created from the remaining SSD space.";
          };
        };
      };
    };
    setup = mkOption {
      type = types.bool;
      default = false;
      description = "Run the setup scripts.";
    };
  };
  config =
    let
      setup_zfs = pkgs.writeShellApplication {
        name = "setup_zfs";
        runtimeInputs = [
          pkgs.zfs
          pkgs.gptfdisk
          pkgs.parted
          pkgs.systemd
          pkgs.coreutils
        ];
        text = builtins.readFile (
          pkgs.replaceVars ./setup_zfs.sh {
            ssd_enable = if cfg.ssd.enable then "1" else "0";
            ssd_fastpool_name = cfg.ssd.fastpoolName;
            ssd_device = cfg.ssd.device;
            ssd_slog_size = cfg.ssd.slogSize;
            ssd_cache_size = cfg.ssd.cacheSize;
            pool_name = cfg.poolName;
            vdev = escapeShellArgs cfg.vdev;
          }
        );
      };
    in
    mkIf cfg.enable {
      boot = {
        supportedFilesystems = [ "zfs" ];
        zfs = {
          extraPools = mkIf cfg.setup ([ cfg.poolName ] ++ (optional cfg.ssd.enable cfg.ssd.fastpoolName));
        };
      };

      # "The primary use case is to ensure when using ZFS that a pool isn't
      # imported accidentally on a wrong machine."
      networking = {
        hostId = cfg.hostId;
      };

      services.zfs = {
        # This operation informs the underlying storage devices of all blocks in
        # the pool which are no longer allocated and allows thinly provisioned
        # devices to reclaim the space
        trim = {
          enable = true;
        };

        # Disk scrub will read all the VDEVs in the pool, fixing any and all bit
        # rot errors.
        autoScrub = {
          enable = true;
        };
      };

      systemd.services.setup-zf = mkIf cfg.setup {
        enable = true;
        wantedBy = [ "multi-user.target" ];
        after = [ "getty@tty1.service" ];
        serviceConfig = {
          Type = "exec";
          ExecStart = "${setup_zfs}/bin/setup_zfs";
          StandardInput = "null";
          StandardOutput = "journal";
          StandardError = "inherit";
        };
      };
    };
}
