{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.netboot;

  hostImages = map (host: {
    inherit (host) mac hostname build;
  }) cfg.hosts;

  setupHostScript = pkgs.writeShellApplication {
    name = "setup_host";
    runtimeInputs = [
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = builtins.readFile ./setup_host.sh;
  };

  setupNetbootApi = pkgs.writeShellApplication {
    name = "setup_netboot";
    runtimeInputs = [
      pkgs.miniserve
      pkgs.coreutils
    ];
    text = builtins.readFile (
      pkgs.replaceVars ./setup_netboot.sh {
        setup_hosts = lib.concatStringsSep "\n" (
          map (host: ''
            echo "Setting up netboot for ${host.hostname} (${host.mac})..."
            ${setupHostScript}/bin/setup_host "${host.mac}" "${host.build.kernel}/bzImage" "${host.build.netbootRamdisk}/initrd" "${host.build.netbootIpxeScript}" "/srv/http"
          '') hostImages
        );
      }
    );
  };

  setupPixiecore = pkgs.writeShellApplication {
    name = "setup_pixiecore";
    runtimeInputs = [ pkgs.pixiecore ];
    text = builtins.readFile ./setup_pixiecore.sh;
  };
in
with lib;
{
  options.homelab.netboot = {
    enable = mkEnableOption "netboot";
    hosts = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            hostname = mkOption {
              type = types.str;
              description = "The hostname of the host to netboot.";
            };
            mac = mkOption {
              type = types.str;
              description = "The MAC address of the host to netboot.";
            };
            build = mkOption {
              type = types.attrs;
              description = "The pre-built netboot image.";
            };
          };
        }
      );
      default = [ ];
      description = "List of hosts to configure for netboot.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = {
      allowedUDPPorts = [
        67 # dhcp server
        69 # tftp
        4011 # pxe
      ];
      allowedTCPPorts = [
        8080 # pixiecore
        8081 # miniserve (netboot)
      ];
    };

    systemd.services.pixiecore = {
      description = "Pixiecore Netboot Server";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "miniserve.service"
      ];
      serviceConfig = {
        ExecStart = "${setupPixiecore}/bin/setup_pixiecore";
        Restart = "always";
      };
    };

    systemd.services.miniserve = {
      description = "Miniserve Netboot API and File Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${setupNetbootApi}/bin/setup_netboot";
        Restart = "always";
      };
    };
  };
}
