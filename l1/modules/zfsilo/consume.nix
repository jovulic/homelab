{
  config,
  lib,
  hlib,
  ...
}:
let
  cfg = config.homelab.zfsilo.consume;
in
with lib;
with hlib;
{
  options.homelab.zfsilo.consume = {
    enable = mkEnableOption "zfsilo consumer";
    user = {
      name = mkOption {
        type = types.str;
        default = "zfsilo";
        description = "The zfsilo user name";
      };
      hashedPassword = mkOption {
        type = types.nullOr htypes.sopsSecret;
        default = null;
        description = "The hashed password.";
      };
    };
  };

  config = mkIf cfg.enable {
    users.groups.${cfg.user.name} = { };
    users.users.${cfg.user.name} = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPasswordFile =
        if cfg.user.hashedPassword != null then cfg.user.hashedPassword.secret.path else null;
    };
    security.sudo.extraRules = [
      {
        users = [ cfg.user.name ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
