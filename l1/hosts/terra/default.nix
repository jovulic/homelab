{
  nixpkgs,
  deploy-rs,
  sops-nix,
  lib,
  hosts ? { },
  ...
}:
let
  name = "terra";
  address = "192.168.1.5";
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
            secrets.cfssl-auth-key = {
              sopsFile = ../../../.data/enc.certificate.cfssl-auth-key;
              format = "binary";
            };
            secrets.admin-password = {
              sopsFile = ../../../.data/enc.identity.admin-password;
              format = "binary";
              owner = "kanidm";
              group = "kanidm";
            };
            secrets.idm-admin-password = {
              sopsFile = ../../../.data/enc.identity.idm-admin-password;
              format = "binary";
              owner = "kanidm";
              group = "kanidm";
            };
            secrets.oauth-secret = {
              sopsFile = ../../../.data/enc.identity.oauth-secret-kubernetes;
              format = "binary";
              owner = "kanidm";
              group = "kanidm";
            };
          };

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
              hostAddress = address;
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
              address = "127.0.0.1";
              port = 5000;
            };

            identity = {
              enable = true;
              domain = "identity.lab";
              certificate = "identity";
              adminPasswordFile = config.sops.secrets.admin-password.path;
              idmAdminPasswordFile = config.sops.secrets.idm-admin-password.path;
              kubernetes = {
                enable = true;
                secretFile = config.sops.secrets.oauth-secret.path;
              };
            };

            certificate.authority = {
              enable = true;
              server = {
                enable = true;
                address = "127.0.0.1";
                port = 23775;
                authKeyFile = config.sops.secrets.cfssl-auth-key.path;
              };
              certificates = {
                registry = {
                  commonName = "registry.lab";
                  hosts = [
                    "registry.lab"
                    "*.registry.lab"
                  ];
                };
                certificate = {
                  commonName = "certificate.lab";
                  hosts = [
                    "certificate.lab"
                    "*.certificate.lab"
                  ];
                };
                identity = {
                  commonName = "identity.lab";
                  hosts = [
                    "identity.lab"
                    "*.identity.lab"
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
              hosts."certificate.lab" = {
                certificate = "certificate";
                locations."/" = {
                  proxyPass = "http://127.0.0.1:23775";
                };
              };
              hosts."identity.lab" = {
                certificate = "identity";
                locations."/" = {
                  proxyPass = "http://127.0.0.1:8443";
                };
              };
            };

            dns = {
              enable = true;
              zones."lab" = {
                records = ''
                  registry.lab. IN A ${address}
                  *.registry.lab. IN A ${address}

                  certificate.lab. IN A ${address}
                  *.certificate.lab. IN A ${address}

                  identity.lab. IN A ${address}
                  *.identity.lab. IN A ${address}
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
