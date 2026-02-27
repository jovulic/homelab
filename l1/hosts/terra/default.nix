{
  nixpkgs,
  deploy-rs,
  lib,
  hosts ? { },
  ...
}:
let
  name = "terra";
  userKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDGdXDo+F2+TVAwH3CLJnK2SUIJR/6HvBeHEcfQbYxjk cardno:17_742_648";
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
            user.key = userKey;
          };
          system.stateVersion = lib.trivial.release;
        }
      ];
    }).config.system.build.isoImage;
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
                "usb_storage"
                "sd_mod"
              ];
              initrd.kernelModules = [ "dm-snapshot" ];
              kernelModules = [ "kvm-intel" ];
              extraModulePackages = [ ];
            };

            network = {
              hostName = name;
              hostAddress = "192.168.1.5";
              networkInterfaces = [
                "enp1s0"
                "enp2s0"
              ];
            };

            user.key = userKey;

            zfs = {
              enable = true;
              hostId = "028406e6";
              vdev = [
                "mirror"
                "wwn-0x5000c500c5cd54c6"
                "wwn-0x5000c500c5ce3e12"
                "mirror"
                "wwn-0x5000c500e9a4e625"
                "wwn-0x5000c500e9927d89"
              ];
              ssd = {
                enable = true;
                device = "/dev/disk/by-id/nvme-EDILOCA_EN605_1TB_AA243050132";
              };
              setup = true;
            };

            iscsi.target = {
              enable = true;
            };

            netboot = {
              enable = true;
              hosts = [
                hosts.frost.netboot
                # hosts.phantom.netboot
                hosts.hades.netboot
                hosts.optiplex.netboot
                hosts.think1.netboot
                hosts.think2.netboot
                hosts.think3.netboot
              ];
            };

            registry = {
              enable = true;
            };

            certificate.authority = {
              enable = true;
              certificates = {
                registry = {
                  commonName = "registry.lab";
                  hosts = [
                    "registry.lab"
                    "*.registry.lab"
                  ];
                };
              };
            };
            certificate.trust.enable = true;

            proxy = {
              enable = true;
              hosts."registry.lab" = {
                certificate = "registry";
                locations."/" = {
                  proxyPass = "http://127.0.0.1:5000";
                  extraConfig = "client_max_body_size 0;";
                };
              };
            };

            dns = {
              enable = true;
              zones."lab" = {
                records = ''
                  registry.lab. IN A 192.168.1.5
                  *.registry.lab. IN A 192.168.1.5
                '';
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
}
