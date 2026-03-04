{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.kubernetes.node;
in
with lib;
{
  options.homelab.kubernetes.node = {
    enable = mkEnableOption "kubernetes node";
    apitokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to the apitoken secret file.";
    };
  };
  config = mkIf cfg.enable {
    systemd.services.kubernetes-apitoken = mkIf (cfg.apitokenFile != null) {
      description = "Setup Kubernetes Node API Token";
      enable = true;
      wantedBy = [ "multi-user.target" ];
      after = [ "sops-nix.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${
          pkgs.writeShellApplication {
            name = "setup_apitoken";
            runtimeInputs = [ pkgs.coreutils ];
            text = builtins.readFile (
              pkgs.replaceVars ./setup_apitoken.sh {
                apitoken_file = builtins.toString cfg.apitokenFile;
              }
            );
          }
        }/bin/setup_apitoken";
      };
    };
    systemd.services.kubelet = mkIf (cfg.apitokenFile != null) {
      after = [ "kubernetes-apitoken.service" ];
      requires = [ "kubernetes-apitoken.service" ];
    };

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
