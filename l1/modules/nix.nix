{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.nix;
in
with lib;
{
  options.homelab.nix = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable nix configuration.";
    };
  };
  config = mkIf cfg.enable {
    nix = {
      extraOptions = ''
        experimental-features = nix-command flakes
      '';
      gc = {
        automatic = true;
      };
    };
  };
}
