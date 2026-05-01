{ config, pkgs, ... }:

{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  systemd.services.nvidia-power-limit = {
    description = "NVIDIA GPU Power Limit";
    wantedBy = [ "multi-user.target" ];
    after = [ "nvidia-persistenced.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.linuxPackages.nvidia_x11.bin}/bin/nvidia-smi -pl 280";
      RemainAfterExit = true;
    };
  };
}
