{ config, lib, ... }:
let
  cfg = config.homelab.iscsi.initiator;
in
with lib;
{
  options = {
    homelab.iscsi.initiator = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable iscsi initiator configuration.";
      };
      iqn = mkOption {
        type = types.str;
        example = "iqn.2006-01.org.linux-iscsi.hostname";
        description = "Initiator IQN.";
      };
    };
  };
  config = mkIf cfg.enable {
    networking = {
      firewall = {
        allowedTCPPorts = [
          3260 # iscsi
        ];
      };
    };
    services.openiscsi = {
      enable = true;
      name = cfg.iqn;
    };
  };
}
