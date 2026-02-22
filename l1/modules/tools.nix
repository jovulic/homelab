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
  options = {
    homelab.tools = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable tools configuration.";
      };
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.coreutils # gnu core utilities
      pkgs.neovim # vim text editor fork focused on extensibility and agility
    ];
  };
}
