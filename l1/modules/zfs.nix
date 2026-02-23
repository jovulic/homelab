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
  options = {
    homelab.zfs = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable zfs configuration.";
      };
      hostId = mkOption {
        type = types.str;
        example = "028406e6"; # head -c 8 /etc/machine-id
        description = options.boot.networking.hostId.description;
      };
      poolName = mkOption {
        type = types.str;
        default = "tank";
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
      cacheDevice = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/dev/disk/by-id/disk3";
        description = "Optional device path to use as an L2ARC cache.";
      };
      setup = mkOption {
        type = types.bool;
        default = false;
        description = "Run the setup scripts.";
      };
    };
  };
  config = mkIf cfg.enable {
    boot = {
      supportedFilesystems = [ "zfs" ];
      zfs = {
        extraPools = mkIf cfg.setup [ cfg.poolName ];
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

    systemd.services."setup-${cfg.poolName}" = mkIf cfg.setup {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      after = [ "getty@tty1.service" ];
      serviceConfig = {
        Type = "exec";
        ExecStart = pkgs.writeShellScript "setup-${cfg.poolName}.sh" ''
          source ${config.system.build.setEnvironment}

          set -veuo pipefail

          if ! zpool list tank -Ho name > /dev/null 2>&1; then
            zpool create \
              -f \
              -o ashift=12 \
              -m none \
              ${cfg.poolName} \
              ${escapeShellArgs cfg.vdev} \
              ${optionalString (cfg.cacheDevice != null) "cache ${escapeShellArg cfg.cacheDevice}"}
          fi

          if ! zfs list tank/default -Ho name > /dev/null 2>&1; then
            mkdir -p /var/lib/zfs/
            dd if=/dev/urandom of=/var/lib/zfs/default.key bs=32 count=1
            zfs create \
              -o mountpoint=none \
              -o recordsize=128KB \
              -o compression=lz4 \
              -o encryption=on -o keyformat=raw -o keylocation=file:///var/lib/zfs/default.key \
              -o relatime=on \
              -o dnodesize=auto \
              -o xattr=sa \
              ${cfg.poolName}/default
          fi

          if ! zfs list tank/block -Ho name > /dev/null 2>&1; then
            mkdir -p /var/lib/zfs/
            dd if=/dev/urandom of=/var/lib/zfs/block.key bs=32 count=1
            zfs create \
              -o mountpoint=none \
              -o encryption=on -o keyformat=raw -o keylocation=file:///var/lib/zfs/block.key \
              ${cfg.poolName}/block
          fi

          if ! zfs list tank/postgres -Ho name > /dev/null 2>&1; then
            mkdir -p /var/lib/zfs/
            dd if=/dev/urandom of=/var/lib/zfs/postgres.key bs=32 count=1
            zfs create \
              -o mountpoint=none \
              -o recordsize=8k \
              -o encryption=on -o keyformat=raw -o keylocation=file:///var/lib/zfs/postgres.key \
              -o atime=off \
              -o dnodesize=auto \
              -o xattr=sa \
              -o primarycache=metadata \
              -o logbias=throughput \
              ${cfg.poolName}/postgres
          fi
        '';
        StandardInput = "null";
        StandardOutput = "journal";
        StandardError = "inherit";
      };
    };
  };
}
