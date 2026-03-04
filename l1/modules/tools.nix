{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.tools;
in
with lib;
{
  options.homelab.tools = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable tools configuration.";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.zfs # zfs filesystem linux userspace tools
      pkgs.gptfdisk # set of text-mode partitioning tools for globally unique identifier (guid) partition table (gpt) disks
      pkgs.parted # create, destroy, resize, check, and copy partitions
      pkgs.systemd # system and service manager for linux
      pkgs.coreutils # gnu core utilities
      pkgs.neovim # vim text editor fork focused on extensibility and agility
      pkgs.kubectl # kubernetes cli
    ];
  };
}
