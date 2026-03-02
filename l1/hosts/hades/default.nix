{
  nixpkgs,
  deploy-rs,
  sops-nix,
  lib,
  ...
}:
let
  name = "hades";
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
          lib,
          modulesPath,
          ...
        }:
        {
          imports = [
            (modulesPath + "/installer/scan/not-detected.nix")
          ];

          nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
          hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

          sops = {
            secrets.apitoken = {
              sopsFile = ../../../.data/enc.kubernetes.apitoken;
              format = "binary";
            };
          };

          homelab = {
            boot = {
              initrd.luksDevice = "/dev/nvme0n1p3";
              initrd.luksKeyFile = "/dev/nvme0n1p1";
              initrd.luksKeyFileSize = 4096;
              initrd.availableKernelModules = [
                "xhci_pci"
                "nvme"
                "usb_storage"
                "usbhid"
                "sd_mod"
                "sdhci_pci"
              ];
              initrd.kernelModules = [ "dm-snapshot" ];
              kernelModules = [ "kvm-intel" ];
            };

            network = {
              hostName = name;
              hostAddress = "192.168.1.12";
              networkInterfaces = [ "enp5s0" ];
            };

            user.key = userKey;

            iscsi.initiator = {
              enable = true;
              iqn = "iqn.2006-01.org.linux-iscsi.${name}";
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
    mac = "54:b2:03:0a:a8:ff";
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
