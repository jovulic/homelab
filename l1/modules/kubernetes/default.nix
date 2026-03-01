{ lib, ... }:
with lib;
{
  imports = [
    ./master
    ./node.nix
  ];
  options = {
    homelab.kubernetes = {
      masterAddress = mkOption {
        type = types.str;
        description = "The master address.";
      };
    };
  };
}
