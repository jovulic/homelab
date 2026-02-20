{
  nixpkgs,
  deploy-rs,
  lib,
  ...
}:
let
  name = "terra";
  system = "x86_64-linux";
  bootstrapUsb =
    (nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        ../../bootstrap
        {
          bootstrap = {
            enable = true;
            device = "/dev/nvme0n1";
            hostname = name;
          };
          system.stateVersion = lib.trivial.release;
        }
      ];
    }).config.system.build.isoImage;
  targetSystem = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      (
        { modulesPath, ... }:
        {
          imports = [
            (modulesPath + "/installer/scan/not-detected.nix")
          ];
        }
      )
      ../../modules
      {
        system.stateVersion = "25.11";
      }
    ];
  };
in
{
  ${name} = {
    bootstrap = bootstrapUsb;
    system = targetSystem;
    deploy = {
      nodes = {
        ${name} = {
          hostname = "${name}.lan";
          profiles.system = {
            sshUser = "root";
            user = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos targetSystem;
          };
        };
      };

    };
  };
}
