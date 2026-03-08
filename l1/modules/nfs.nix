{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.nfs;
in
with lib;
{
  options.homelab.nfs = {
    enable = mkEnableOption "nfs";
    domain = mkOption {
      type = types.str;
      default = "homelab";
      description = "The domain for idmapd authentication.";
    };
    exports = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of NFS exports.";
    };
  };
  config = mkIf cfg.enable {
    services.nfs.server = {
      enable = true;
      exports = concatStringsSep "\n" cfg.exports;
    };

    # Ensure NFS server starts after create ZFS datasets are created.
    systemd.services.nfs-server.after = [ "setup-zfs-create.service" ];

    # Allow for idmapd authentication.
    services.nfs.idmapd.settings.General.Domain = cfg.domain;

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [
        111 # rpcbind (required for showmount)
        2049 # 2049: nfs (the actual file transfer protocol)
        4000 # statd and lockd (file locking mechanisms)
        4001 # statd and lockd (file locking mechanisms)
        20048 # mountd (required for nfsv3 mounting)
        20049 # statd and lockd (file locking mechanisms)
      ];
      allowedUDPPorts = [
        111
        2049
        4000
        4001
        20048
        20049
      ];
    };
  };
}

# Commands:
#
# See what volumes are being shared...
# $ sudo exportfs -v
#
# See what the network sees in terms of volumes...
# $ showmount -e localhost
