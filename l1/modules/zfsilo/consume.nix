{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.zfsilo.consume;
in
with lib;
{
  options.homelab.zfsilo.consume = {
    enable = mkEnableOption "zfsilo consumer";
    user = {
      name = mkOption {
        type = types.str;
        default = "zfsilo";
        description = "The zfsilo user name";
      };
      hashedPasswordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "The hashed password file.";
      };
    };
  };

  config = mkIf cfg.enable {
    users.groups.${cfg.user.name} = { };
    users.users.${cfg.user.name} = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPasswordFile = cfg.user.hashedPasswordFile;
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
