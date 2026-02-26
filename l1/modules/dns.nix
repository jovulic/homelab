{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.dns;
in
with lib;
{
  options.homelab.dns = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable dns.";
    };
    records = mkOption {
      type = types.lines;
      default = "";
      description = "DNS records to add to the lab zone, one per line.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    environment.etc."coredns/lab.db".text = ''
      $ORIGIN lab.
      $TTL 3600
      @ IN SOA ns admin 1 86400 7200 4000000 11200

      @ IN NS ns
      ns IN A 192.168.1.5

      ${cfg.records}
    '';

    services.coredns = {
      enable = true;
      config = ''
        .:53 {
          errors
          file /etc/coredns/lab.db lab
          forward . /etc/resolv.conf
          cache 30
          loop
          loadbalance
        }
      '';
    };
  };
}
