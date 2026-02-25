{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.bootstrap;
in
with lib;
{
  options = {
    bootstrap = {
      enable = mkOption {
        type = types.bool;
        description = "Enable machine bootstrap.";
        default = true;
      };
      device = mkOption {
        type = types.str;
        description = "The target device path to bootstrap.";
        example = "/dev/nvme0n1";
      };
      hostname = mkOption {
        type = types.str;
        description = "The host hostname.";
      };
      user.key = mkOption {
        type = types.str;
        description = "The user authorized key.";
        example = "ssh-ed25519 ...";
      };
      ignoreLidSwitch = mkOption {
        type = types.bool;
        description = "Whether to ignore the lid switch.";
        default = false;
      };
    };
  };
  config =
    let
      bootstrap = pkgs.writeShellApplication {
        name = "bootstrap";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.util-linux
          pkgs.dosfstools
          pkgs.cryptsetup
          pkgs.lvm2
          pkgs.e2fsprogs
          pkgs.nixos-install-tools
          pkgs.systemd
          pkgs.nix
        ];
        text = builtins.readFile (
          pkgs.replaceVars ./bootstrap.sh {
            device = cfg.device;
            hostname = cfg.hostname;
            user_key = cfg.user.key;
            ignore_lid_switch =
              if cfg.ignoreLidSwitch then "services.logind.settings.Login.HandleLidSwitch = \"ignore\";" else "";
          }
        );
      };
    in
    mkIf cfg.enable {
      systemd.services.bootstrap = {
        enable = true;
        wantedBy = [ "multi-user.target" ];
        after = [ "getty@tty1.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "bootstrap-start" ''
            source ${config.system.build.setEnvironment}
            ${bootstrap}/bin/bootstrap
          '';
          StandardInput = "null";
          StandardOutput = "journal+console";
          StandardError = "inherit";
        };
      };
    };
}
