{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.certificate.trust;
in
with lib;
{
  options.homelab.certificate.trust = {
    enable = mkEnableOption "trust certificate authority";
  };
  config = mkIf cfg.enable {
    security.pki.certificates =
      let
        caPath = ../../../.data/ca.pem;
        k8sCaPath = ../../../.data/k8s-ca.pem;
      in
      (optional (builtins.pathExists caPath) (builtins.readFile caPath))
      ++ (optional (builtins.pathExists k8sCaPath) (builtins.readFile k8sCaPath));
  };
}
