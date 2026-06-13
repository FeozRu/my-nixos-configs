{ config, pkgs, pkgs-stable, lib, hostName, ... }:

{
  imports = [
    ../hardware-configuration.nix
    ../modules/nixos/common-system.nix
    ../modules/nixos/graphics-amd.nix
    ../modules/nixos/packages.nix
    ../modules/nixos/flatpak.nix
    ../modules/nixos/mimo-code.nix
  ];

  networking.hostName = hostName;

  boot.loader.grub.useOSProber = false;

  services.pipewire.alsa.support32Bit = false;
}
