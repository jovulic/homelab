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
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to trust the homelab CA certificate.";
    };
  };
  config = mkIf cfg.enable {
    security.pki.certificates =
      let
        caPath = ../../../.data/ca.pem;
      in
      [ ] ++ (optional (builtins.pathExists caPath) (builtins.readFile caPath));
  };
}
