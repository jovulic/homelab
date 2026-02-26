{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.dns;
  hostAddress = config.homelab.network.hostAddress;
in
with lib;
{
  options.homelab.dns = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable dns.";
    };
    zones = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            records = mkOption {
              type = types.lines;
              default = "";
              description = "DNS records for this zone.";
            };
          };
        }
      );
      default = { };
      description = "DNS zones to handle.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    environment.etc = mapAttrs' (
      name: zone:
      nameValuePair "coredns/${name}.db" {
        text = ''
          $ORIGIN ${name}.
          $TTL 3600
          @ IN SOA ns admin 1 86400 7200 4000000 11200

          @ IN NS ns
          ns IN A ${hostAddress}

          ${zone.records}
        '';
      }
    ) cfg.zones;

    services.coredns = {
      enable = true;
      config = ''
        .:53 {
          errors
          ${concatStringsSep "\n" (
            mapAttrsToList (name: zone: "file /etc/coredns/${name}.db ${name}") cfg.zones
          )}
          forward . /etc/resolv.conf
          cache 30
          loop
          loadbalance
        }
      '';
    };
  };
}
