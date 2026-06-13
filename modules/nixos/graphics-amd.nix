{ pkgs, ... }:

{
  hardware.graphics = {
    enable = true;
    enable32Bit = false;
    extraPackages = with pkgs; [
        libva-vdpau-driver
    ];
  };
}