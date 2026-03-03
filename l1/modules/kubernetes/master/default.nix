{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.kubernetes.master;
in
with lib;
{
  options = {
    homelab.kubernetes.master = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable kubernetes master configuration.";
      };
      certificateName = mkOption {
        type = types.str;
        default = "ca";
        description = "Name of the certificate to use as Kubernetes CA (found in /var/lib/certs/)";
      };
    };
  };
  config = mkIf cfg.enable {
    networking = {
      firewall = {
        allowedTCPPorts = [
          # https://kubernetes.io/docs/reference/ports-and-protocols/#control-plane
          6443 # kubernetes api server
          8888 # certmgr (cfssl)
          2379 # etcd (client)
          2380 # etcd (peer)
          2381 # etcd (metrics)
          10259 # kube-scheduler
          10257 # kube-controller-manager
        ];
      };
    };
    systemd.services.kubernetes-secrets = {
      description = "Setup Kubernetes Secrets";
      enable = true;
      wantedBy = [ "multi-user.target" ];
      after = [ "setup-certs.service" ];
      requires = [ "setup-certs.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${
          pkgs.writeShellApplication {
            name = "setup_secrets";
            runtimeInputs = [ pkgs.coreutils ];
            text = builtins.readFile (
              pkgs.replaceVars ./setup_secrets.sh {
                certificate_name = cfg.certificateName;
              }
            );
          }
        }/bin/setup_secrets";
      };
    };
    # NOTE: We must run cfssl after the above setup in order to get easy certs
    # to use our custom certificate.
    systemd.services.cfssl = {
      after = [ "kubernetes-secrets.service" ];
      requires = [ "kubernetes-secrets.service" ];
    };
    services.kubernetes = {
      # NOTE: By specifying a role things like easyCert and flannel networking
      # are enabled.
      roles = [ "master" ];
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
      apiserver = {
        # Introduce requestheader apiserver options to support the
        # kubernetes aggregation layer (metrics-server, for
        # example).
        #
        # --requestheader-allowed-names="" means any CN is acceptable.
        # See https://kubernetes.io/docs/tasks/extend-kubernetes/configure-aggregation-layer/#ca-reusage-and-conflicts.
        extraOpts = ''
          --requestheader-client-ca-file=/var/lib/kubernetes/secrets/ca.pem \
          --requestheader-allowed-names="" \
          --oidc-issuer-url=https://identity.lab/oauth2/openid/kubernetes \
          --oidc-client-id=kubernetes \
          --oidc-username-claim=email \
          --oidc-groups-claim=groups
        '';
      };
      controllerManager = {
        bindAddress = "0.0.0.0";
        securePort = 10257;
        # Reasons for extra options.
        # --authorization-always-allow-paths - we add /metrics to more easily allow for scraping by prometheus.
        extraOpts = ''
          --cluster-signing-cert-file /var/lib/kubernetes/secrets/ca.pem \
          --cluster-signing-key-file /var/lib/kubernetes/secrets/ca-key.pem \
          --authorization-always-allow-paths "/healthz,/readyz,/livez,/metrics"
        '';
      };
      scheduler = {
        address = "0.0.0.0";
        port = 10259;
        # Reasons for extra options.
        # --authorization-always-allow-paths - we add /metrics to more easily allow for scraping by prometheus.
        extraOpts = ''
          --authorization-always-allow-paths "/healthz,/readyz,/livez,/metrics"
        '';
      };
    };
    services.etcd = {
      extraConf = {
        "LISTEN_METRICS_URLS" = "http://0.0.0.0:2381";
      };
    };
  };
}
