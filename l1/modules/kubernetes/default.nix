{ lib, ... }:
with lib;
{
  imports = [
    ./master
    ./node.nix
  ];
  options = {
    host.kubernetes = {
      masterAddress = mkOption {
        type = types.str;
        description = "The master address.";
      };
    };
  };
}
