{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.monitor;
in
with lib;
{
  options.homelab.monitor = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable monitor configuration.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.bottom # cross-platform graphical process/system monitor with a customizable interface (btm)
      pkgs.gdu # disk usage analyzer with console interface
      pkgs.iperf # tool to measure ip bandwidth using udp or tcp
    ];

    services.iperf3 = {
      enable = true;
      openFirewall = true;
    };
  };
}
