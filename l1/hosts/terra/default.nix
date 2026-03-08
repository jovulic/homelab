{
  nixpkgs,
  deploy-rs,
  sops-nix,
  lib,
  hosts ? { },
  hlib,
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
      specialArgs = { inherit hlib; };
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
    specialArgs = { inherit hlib; };
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
            secrets.zfsilo-token = {
              sopsFile = ../../../.data/enc.zfsilo.token;
              format = "binary";
              owner = "zfsilo";
              group = "zfsilo";
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
            secrets.zfsilo-produce-password = {
              sopsFile = ../../../.data/enc.zfsilo.produce-password;
              format = "binary";
              owner = "zfsilo";
              group = "zfsilo";
            };
            secrets.zfsilo-consume-password = {
              sopsFile = ../../../.data/enc.zfsilo.consume-password;
              format = "binary";
              owner = "zfsilo";
              group = "zfsilo";
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
              create = {
                enable = true;
                datasets = [
                  {
                    dataset = "pool/default/storage";
                    mount = true;
                    user = "me";
                  }
                ];
              };
            };

            nfs = {
              enable = true;
              exports = [
                "/pool/default/storage 192.168.1.0/24(rw,sync,no_subtree_check)"
              ];
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
              port = 46243;
            };

            identity = {
              enable = true;
              address = "127.0.0.1";
              port = 43368;
              domain = "identity.lab";
              certificate = "identity";
              adminPassword = (hlib.mkSopsSecret config "admin-password");
              idmAdminPassword = (hlib.mkSopsSecret config "idm-admin-password");
              kubernetes = {
                enable = true;
                secret = (hlib.mkSopsSecret config "oauth-secret");
              };
            };

            zfsilo.produce = {
              enable = true;
              address = "127.0.0.1";
              port = 34537;
              service = {
                externalServerUri = "zfsilo.lab:443";
                authorizedKeys = [
                  {
                    identity = "system";
                    token = (hlib.mkSopsSecret config "zfsilo-token");
                  }
                ];
              };
              command = {
                produceTarget = {
                  password = (hlib.mkSopsSecret config "zfsilo-produce-password");
                };
                consumeTargets = [
                  {
                    connect = {
                      address = "frost.lan";
                      password = (hlib.mkSopsSecret config "zfsilo-password");
                    };
                    password = (hlib.mkSopsSecret config "zfsilo-consume-password");
                    iqn = "iqn.2006-01.org.linux-iscsi.frost";
                  }
                  # {
                  #   connect = {
                  #     address = "phantom.lan";
                  #     password = "zfsilo-password";
                  #   };
                  #   password = "zfsilo-consume-password";
                  #   iqn = "iqn.2006-01.org.linux-iscsi.phantom";
                  # }
                  {
                    connect = {
                      address = "hades.lan";
                      password = (hlib.mkSopsSecret config "zfsilo-password");
                    };
                    password = (hlib.mkSopsSecret config "zfsilo-consume-password");
                    iqn = "iqn.2006-01.org.linux-iscsi.hades";
                  }
                  {
                    connect = {
                      address = "optiplex.lan";
                      password = (hlib.mkSopsSecret config "zfsilo-password");
                    };
                    password = (hlib.mkSopsSecret config "zfsilo-consume-password");
                    iqn = "iqn.2006-01.org.linux-iscsi.optiplex";
                  }
                  {
                    connect = {
                      address = "think1.lan";
                      password = (hlib.mkSopsSecret config "zfsilo-password");
                    };
                    password = (hlib.mkSopsSecret config "zfsilo-consume-password");
                    iqn = "iqn.2006-01.org.linux-iscsi.think1";
                  }
                  {
                    connect = {
                      address = "think2.lan";
                      password = (hlib.mkSopsSecret config "zfsilo-password");
                    };
                    password = (hlib.mkSopsSecret config "zfsilo-consume-password");
                    iqn = "iqn.2006-01.org.linux-iscsi.think2";
                  }
                  {
                    connect = {
                      address = "think3.lan";
                      password = (hlib.mkSopsSecret config "zfsilo-password");
                    };
                    password = (hlib.mkSopsSecret config "zfsilo-consume-password");
                    iqn = "iqn.2006-01.org.linux-iscsi.think3";
                  }
                ];
              };
              user = {
                hashedPassword = (hlib.mkSopsSecret config "zfsilo-password-hashed");
              };
            };

            certificate.authority = {
              enable = true;
              server = {
                enable = true;
                address = "127.0.0.1";
                port = 23775;
                authKey = (hlib.mkSopsSecret config "cfssl-auth-key");
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
                zfsilo = {
                  commonName = "zfsilo.lab";
                  hosts = [
                    "zfsilo.lab"
                    "*.zfsilo.lab"
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
                  proxyPass = "http://127.0.0.1:46243";
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
                  proxyPass = "https://127.0.0.1:43368";
                };
              };
              hosts."zfsilo.lab" = {
                certificate = "zfsilo";
                locations."/" = {
                  proxyPass = "https://127.0.0.1:34537";
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

                  zfsilo.lab. IN A ${address}
                  *.zfsilo.lab. IN A ${address}
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
