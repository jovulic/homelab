{ config, lib, ... }:
let
  cfg = config.homelab.kubernetes.node;
in
with lib;
{
  options = {
    homelab.kubernetes.node = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable kubernetes node configuration.";
      };
      apitokenFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the apitoken secret file.";
      };
    };
  };
  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = mkIf (cfg.apitokenFile != null) [
      "d /var/lib/kubernetes/secrets 0755 root root - -"
      "C+ /var/lib/kubernetes/secrets/apitoken.secret - - - - ${cfg.apitokenFile}"
    ];
    networking = {
      firewall = {
        allowedTCPPorts = [
          # https://kubernetes.io/docs/reference/ports-and-protocols/#node
          10250 # kubelet api
          10249 # kube-proxy
          9100 # kube-node-exporter
        ];
        allowedTCPPortRanges = [
          # https://kubernetes.io/docs/reference/ports-and-protocols/#node
          {
            from = 30000;
            to = 32767;
          } # nodeport services
        ];
      };
    };
    services.kubernetes = {
      roles = [ "node" ];
      masterAddress = config.homelab.kubernetes.masterAddress;

      kubelet = {
        cni.config = [
          {
            name = "mynet";
            type = "flannel";
            cniVersion = "0.3.1";
            delegate = {
              hairpinMode = true;
              isDefaultGateway = true;
              bridge = "mynet";
            };
          }
        ];
      };
      proxy = {
        # Reasons for extra options.
        # --metrics-bind-address - we bind the metrics server to 0.0.0.0 so it can be scraped by prometheus.
        extraOpts = ''
          --metrics-bind-address=0.0.0.0:10249
        '';
      };
    };
  };
}
