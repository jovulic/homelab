{
  config,
  options,
  lib,
  ...
}:
let
  cfg = config.homelab.boot;
in
with lib;
{
  options = {
    homelab.boot = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable boot configuration.";
      };
      initrd.luksDevice = mkOption {
        type = types.str;
        example = "/dev/nvme0n1p3";
        description = ''
          Path of the underlying encrypted block device.
        ''; # https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/system/boot/luksroot.nix#L573
      };
      initrd.luksKeyFile = mkOption {
        type = types.str;
        example = "/dev/nvme0n1p1";
        description = ''
          The name of the file (can be a raw device or a partition) that
          should be used as the decryption key for the encrypted device. If
          not specified, you will be prompted for a passphrase instead.
        ''; # https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/system/boot/luksroot.nix#L586
      };
      initrd.luksKeyFileSize = mkOption {
        type = types.int;
        example = 4096;
        description = "The luks key file size.";
      };
      initrd.availableKernelModules = mkOption {
        type = types.listOf types.str;
        example = [
          "xhci_pci"
          "ahci"
          "nvme"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ];
        description = options.boot.initrd.availableKernelModules.description;
        default = [ ];
      };
      initrd.kernelModules = mkOption {
        type = types.listOf types.str;
        example = [ "dm-snapshot" ];
        description = options.boot.initrd.kernelModules.description;
        default = [ ];
      };
      kernelModules = mkOption {
        type = types.listOf types.str;
        example = [ "kvm-intel" ];
        description = options.boot.kernelModules.description;
        default = [ ];
      };
      extraModulePackages = mkOption {
        type = types.listOf types.str;
        example = [ ];
        description = options.boot.extraModulePackages.description;
        default = [ ];
      };
    };
  };
  config = mkIf cfg.enable {
    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };

      initrd = {
        luks.devices.luksroot = {
          device = cfg.initrd.luksDevice;
          allowDiscards = true;
          keyFile = cfg.initrd.luksKeyFile;
          keyFileSize = cfg.initrd.luksKeyFileSize;
        };
        availableKernelModules = cfg.initrd.availableKernelModules;
        kernelModules = cfg.initrd.kernelModules;
      };

      kernelModules = cfg.kernelModules;
      extraModulePackages = cfg.extraModulePackages;
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
  };
}
