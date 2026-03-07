{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.homelab.nvidia;
in
with lib;
{
  options.homelab.nvidia = {
    enable = mkEnableOption "nvidia";
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      modesetting.enable = true;
      nvidiaPersistenced = true;
      open = false;
    };

    hardware.nvidia-container-toolkit.enable = true;

    virtualisation.containerd = {
      settings = {
        # The modern approach is to enable CDI instead of a custom runtime
        # engine.
        plugins."io.containerd.grpc.v1.cri" = {
          enable_cdi = true;
        };
      };
    };

    environment.systemPackages = [
      pkgs.nvtopPackages.nvidia # htop-like task monitor for amd, adreno, intel and nvidia gpus
    ];
  };
}
