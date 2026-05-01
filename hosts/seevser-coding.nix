{ config, pkgs, pkgs-stable, lib, ... }:

{
  imports = [
    ../hardware-configuration-coding.nix
    ../bluetooth-keys.nix
    ../modules/nixos/common-system.nix
    ../modules/nixos/graphics-amd.nix
    ../modules/nixos/packages-coding.nix
    ../modules/nixos/flatpak-coding.nix
  ];

  networking.hostName = "seevser-coding";

  boot.loader.grub.useOSProber = false;

  services.pipewire.alsa.support32Bit = false;
}
