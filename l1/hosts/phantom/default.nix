{
  nixpkgs,
  deploy-rs,
  sops-nix,
  lib,
  ...
}:
let
  name = "phantom";
  userKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDGdXDo+F2+TVAwH3CLJnK2SUIJR/6HvBeHEcfQbYxjk cardno:17_742_648";
  system = "x86_64-linux";
  bootstrapNetboot =
    (nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        "${nixpkgs}/nixos/modules/installer/netboot/netboot-minimal.nix"
        ../../bootstrap
        {
          bootstrap = {
            enable = true;
            device = "/dev/nvme0n1";
            hostname = name;
            user.key = userKey;
          };
          system.stateVersion = lib.trivial.release;
        }
      ];
    }).config.system.build;
  targetSystem = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      sops-nix.nixosModules.sops
      ../../modules
      (
        {
          config,
          modulesPath,
          ...
        }:
        {
          imports = [
            (modulesPath + "/installer/scan/not-detected.nix")
          ];

          sops = {
            secrets.apitoken = {
              sopsFile = ../../../.data/enc.kubernetes.apitoken;
              format = "binary";
            };
            secrets.zfsilo-password = {
              sopsFile = ../../../.data/enc.zfsilo.password;
              format = "binary";
            };
            secrets.zfsilo-password-hashed = {
              sopsFile = ../../../.data/enc.zfsilo.password-hashed;
              format = "binary";
              neededForUsers = true;
            };
          };

          homelab = {
            boot = {
              initrd.luksDevice = "/dev/nvme0n1p3";
              initrd.luksKeyFile = "/dev/nvme0n1p1";
              initrd.luksKeyFileSize = 4096;
              initrd.availableKernelModules = [
                "xhci_pci"
                "thunderbolt"
                "nvme"
                "rtsx_pci_sdmmc"
              ];
              kernelModules = [ "kvm-intel" ];
            };

            network = {
              hostName = name;
              hostAddress = "192.168.1.11";
              networkInterfaces = [ "enp89s0" ];
            };

            user.key = userKey;

            iscsi.initiator = {
              enable = true;
              iqn = "iqn.2006-01.org.linux-iscsi.${name}";
            };

            zfsilo.consume = {
              enable = true;
              user = {
                hashedPasswordFile = config.sops.secrets.zfsilo-password-hashed.path;
              };
            };

            certificate.trust.enable = true;

            kubernetes = {
              masterAddress = "frost.lan";
              node = {
                enable = true;
                apitokenFile = config.sops.secrets.apitoken.path;
              };
            };
          };

          system.stateVersion = "25.11";
        }
      )
    ];
  };
in
{
  netboot = {
    hostname = name;
    mac = "54:b2:03:f0:c0:aa";
    build = bootstrapNetboot;
  };
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
}
