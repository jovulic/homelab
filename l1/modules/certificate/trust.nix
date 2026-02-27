{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.certificate.trust;
  caPath = "/etc/ssl/certs/ca-homelab.crt";
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
    security.pki.certificates = (optional (builtins.pathExists caPath) (builtins.readFile caPath));
  };
}
