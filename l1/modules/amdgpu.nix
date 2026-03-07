{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.homelab.amdgpu;
in
with lib;
{
  options.homelab.amdgpu = {
    enable = mkEnableOption "amdgpu";
  };

  config = mkIf cfg.enable {
    boot.initrd.kernelModules = [ "amdgpu" ];
    services.xserver.videoDrivers = [ "amdgpu" ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = with pkgs; [
        rocmPackages.clr.icd # OpenCL support
        rocmPackages.clr # HIP support
      ];
    };

    # NOTE: Standard containerd and runc work as amdgpu is open source and
    # baked into the kernel, so no virtualization settings needed.

    environment.systemPackages = with pkgs; [
      radeontop # top-like tool for viewing amd radeon gpu utilization
      amdgpu_top # tool to display amdgpu usage
    ];
  };
}
