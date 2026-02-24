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
      ssd = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable partitioning an SSD for SLOG, L2ARC, and a fastpool.";
        };
        device = mkOption {
          type = types.str;
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

    systemd.services."setup_zfs" = mkIf cfg.setup {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      after = [ "getty@tty1.service" ];
      serviceConfig = {
        Type = "exec";
        Environment = "PATH=${
          lib.makeBinPath [
            pkgs.zfs
            pkgs.gptfdisk
            pkgs.parted
            pkgs.systemd
            pkgs.coreutils
          ]
        }";
        ExecStart = pkgs.writeShellScript "setup_zfs.sh" ''
          set -veuo pipefail

          ${optionalString cfg.ssd.enable ''
            if ! zpool list ${cfg.ssd.fastpoolName} -Ho name > /dev/null 2>&1; then
              echo "Partitioning SSD ${cfg.ssd.device}..."

              # Wipe existing partitions.
              sgdisk -Z ${cfg.ssd.device}

              # SLOG (BF01 is ZFS partition type).
              sgdisk -n 1:0:+${cfg.ssd.slogSize} -t 1:BF01 -c 1:zfs_slog ${cfg.ssd.device}

              # L2ARC.
              sgdisk -n 2:0:+${cfg.ssd.cacheSize} -t 2:BF01 -c 2:zfs_cache ${cfg.ssd.device}

              # Fastpool.
              sgdisk -n 3:0:0 -t 3:BF01 -c 3:zfs_${cfg.ssd.fastpoolName} ${cfg.ssd.device}

              # Inform OS of partition changes and wait for them to populate.
              partprobe ${cfg.ssd.device}
              udevadm settle

              # Create fastpool.
              zpool create \
                -f \
                -o ashift=12 \
                -m none \
                ${cfg.ssd.fastpoolName} \
                /dev/disk/by-partlabel/zfs_${cfg.ssd.fastpoolName}
            fi
          ''}


          if ! zpool list ${cfg.poolName} -Ho name > /dev/null 2>&1; then
            zpool create \
              -f \
              -o ashift=12 \
              -m none \
              ${cfg.poolName} \
              ${escapeShellArgs cfg.vdev} \
              ${optionalString cfg.ssd.enable "log /dev/disk/by-partlabel/zfs_slog cache /dev/disk/by-partlabel/zfs_cache"}
          fi

          if ! zfs list ${cfg.poolName}/default -Ho name > /dev/null 2>&1; then
            mkdir -p /var/lib/zfs/
            dd if=/dev/urandom of=/var/lib/zfs/default.key bs=32 count=1
            zfs create \
              -o mountpoint=none \
              -o recordsize=128KB \
              -o compression=lz4 \
              -o encryption=on -o keyformat=raw -o keylocation=file:///var/lib/zfs/default.key \
              -o atime=off \
              -o dnodesize=auto \
              -o xattr=sa \
              ${cfg.poolName}/default
          fi

          if ! zfs list ${cfg.poolName}/block -Ho name > /dev/null 2>&1; then
            mkdir -p /var/lib/zfs/
            dd if=/dev/urandom of=/var/lib/zfs/block.key bs=32 count=1
            zfs create \
              -o mountpoint=none \
              -o compression=lz4 \
              -o encryption=on -o keyformat=raw -o keylocation=file:///var/lib/zfs/block.key \
              ${cfg.poolName}/block
          fi

          if ! zfs list ${cfg.poolName}/postgres -Ho name > /dev/null 2>&1; then
            mkdir -p /var/lib/zfs/
            dd if=/dev/urandom of=/var/lib/zfs/postgres.key bs=32 count=1
            zfs create \
              -o mountpoint=none \
              -o recordsize=8k \
              -o compression=lz4 \
              -o encryption=on -o keyformat=raw -o keylocation=file:///var/lib/zfs/postgres.key \
              -o atime=off \
              -o dnodesize=auto \
              -o xattr=sa \
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
