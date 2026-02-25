{
  nixpkgs,
  deploy-rs,
  lib,
  ...
}:
let
  name = "frost";
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

          homelab = {
            boot = {
              initrd.luksDevice = "/dev/nvme0n1p3";
              initrd.luksKeyFile = "/dev/nvme0n1p1";
              initrd.luksKeyFileSize = 4096;
              initrd.availableKernelModules = [
                "xhci_pci"
                "ahci"
                "nvme"
                "sdhci_pci"
              ];
              initrd.kernelModules = [
                "dm-snapshot"
              ];
              kernelModules = [ "kvm-intel" ];
            };

            network = {
              hostName = name;
              hostAddress = "192.168.1.10";
              networkInterfaces = [ "eno1" ];
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
    mac = "1c:69:7a:63:14:a8";
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
