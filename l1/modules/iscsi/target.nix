{ config, lib, ... }:
let
  cfg = config.homelab.iscsi.target;
in
with lib;
{
  options.homelab.iscsi.target = {
    enable = mkEnableOption "iscsi target (server)";
  };
  config = mkIf cfg.enable {
    networking = {
      firewall = {
        allowedTCPPorts = [
          3260 # iscsi
        ];
      };
    };
    services.target = {
      enable = true;
    };
  };
}
