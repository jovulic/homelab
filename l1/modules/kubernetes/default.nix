{ lib, ... }:
with lib;
{
  imports = [
    ./master
    ./node
  ];
  options.homelab.kubernetes = {
    masterAddress = mkOption {
      type = types.str;
      description = "The master address.";
    };
  };
}
