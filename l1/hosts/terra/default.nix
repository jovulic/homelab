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

          boot = {
            initrd = {
              luks.devices.luksroot = {
                device = "/dev/nvme0n1p3";
                allowDiscards = true;
                keyFile = "/dev/nvme0n1p1";
                keyFileSize = 4096;
              };
              availableKernelModules = [
                "xhci_pci"
                "ahci"
                "nvme"
                "usb_storage"
                "sd_mod"
              ];
              kernelModules = [ "dm-snapshot" ];
            };
            kernelModules = [ "kvm-intel" ];
            extraModulePackages = [ ];
          };

          fileSystems."/" = {
            device = "/dev/disk/by-label/root";
            fsType = "ext4";
          };

          fileSystems."/boot" = {
            device = "/dev/disk/by-label/boot";
            fsType = "vfat";
            options = [
              "fmask=0022"
              "dmask=0022"
            ];
          };

          swapDevices = [ ];

          nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
          hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
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
