{ pkgs, ... }:

{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # нужно для Wine/DXVK
    extraPackages = with pkgs; [
        libva-vdpau-driver
    ];
  };
}