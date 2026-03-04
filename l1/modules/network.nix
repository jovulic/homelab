{
  config,
  options,
  lib,
  ...
}:
let
  cfg = config.homelab.network;

  isBond = builtins.length cfg.networkInterfaces > 1;
  # Decide which interface actually gets the IP address. If bonding, it's
  # bond0. Otherwise, it's the first (and only) item in the list.
  activeInterface = if isBond then "bond0" else builtins.head cfg.networkInterfaces;
in
with lib;
{
  options.homelab.network = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable network configuration.";
    };
    hostName = mkOption {
      type = types.str;
      example = "terra";
      description = options.networking.hostName.description;
    };
    hostAddress = mkOption {
      type = types.str;
      example = "192.168.1.5";
      description = ''
        List of IPv4 addresses that will be statically assigned to the interface.
      ''; # https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/tasks/network-interfaces.nix#L199
    };
    networkInterfaces = mkOption {
      type = types.listOf types.str;
      example = [
        "enp1s0"
        "enp2s0"
      ];
      description = "The physical network interface(s). If multiple are provided, they are automatically bonded.";
    };
  };

  config = mkIf cfg.enable {
    networking = {
      hostName = cfg.hostName;
      useDHCP = false;
      defaultGateway = "192.168.1.1";
      nameservers = [ "192.168.1.1" ];

      # Conditionally create the bond.
      bonds = mkIf isBond {
        bond0 = {
          interfaces = cfg.networkInterfaces;
          driverOptions = {
            mode = "active-backup";
            miimon = "100";
          };
        };
      };

      # Assign the IP and conditionally disable DHCP on physical interfaces.
      interfaces = {
        "${activeInterface}" = {
          ipv4.addresses = [
            {
              address = cfg.hostAddress;
              prefixLength = 24;
            }
          ];
        };
      }
      // lib.optionalAttrs isBond (
        # The operation here generates { "enp1s0" = { useDHCP = false; }; ... }
        # for all physical interfaces so they don't try to grab their own
        # IPs.
        lib.genAttrs cfg.networkInterfaces (name: {
          useDHCP = false;
        })
      );

      firewall = {
        enable = true;
        allowedUDPPortRanges = [
          {
            from = 33434;
            to = 33534;
          } # traceroute ports
        ];
      };

    };

    services.openssh = {
      enable = true;
      settings = {
        AllowUsers = [
          "root"
          "me"
        ];
      };
    };
  };
}
