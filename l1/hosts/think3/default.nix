{
  nixpkgs,
  deploy-rs,
  lib,
  ...
}:
let
  name = "think3";
  userKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDGdXDo+F2+TVAwH3CLJnK2SUIJR/6HvBeHEcfQbYxjk cardno:17_742_648";
  system = "x86_64-linux";
  bootstrapNetboot =
    (nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        "${nixpkgs}/nixos/modules/installer/netboot/netboot-minimal.nix"
        ../../bootstrap
        {
          services.logind.settings.Login.HandleLidSwitch = "ignore";

          bootstrap = {
            enable = true;
            device = "/dev/nvme0n1";
            hostname = name;
            user.key = userKey;
            ignoreLidSwitch = true;
          };
          system.stateVersion = lib.trivial.release;
        }
      ];
    }).config.system.build;
  targetSystem = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
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

          services.logind.settings.Login.HandleLidSwitch = "ignore";

          homelab = {
            boot = {
              initrd.luksDevice = "/dev/nvme0n1p3";
              initrd.luksKeyFile = "/dev/nvme0n1p1";
              initrd.luksKeyFileSize = 4096;
              initrd.availableKernelModules = [
                "xhci_pci"
                "ahci"
                "sd_mod"
                "sdhci_pci"
              ];
              initrd.kernelModules = [ "dm-snapshot" ];
              kernelModules = [ "kvm-intel" ];
            };

            network = {
              hostName = name;
              hostAddress = "192.168.1.16";
              networkInterfaces = [ "enp3s0" ];
            };

            user.key = userKey;
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
    mac = "8c:16:45:1e:97:91";
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
