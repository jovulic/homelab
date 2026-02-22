{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.user;
in
with lib;
{
  options = {
    homelab.user = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable user configuration.";
      };
      key = mkOption {
        type = types.str;
        description = "The user authorized key.";
        example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDGdXDo+F2+TVAwH3CLJnK2SUIJR/6HvBeHEcfQbYxjk cardno:17_742_648";
      };
    };
  };
  config = mkIf cfg.enable {
    users.users.root = {
      openssh.authorizedKeys.keys = [ cfg.key ];
    };

    users.users.me = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ cfg.key ];
    };

    security.sudo.extraRules = [
      {
        users = [ "me" ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    services.getty.autologinUser = "root";
  };
}
