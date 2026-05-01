{ config, pkgs, pkgs-stable, lib, comfyui-nix, ... }:

{
  imports = [
    ../hardware-configuration.nix
    ../bluetooth-keys.nix
    ../modules/nixos/common-system.nix
    ../modules/nixos/btrfs-home.nix
    ../modules/nixos/nvidia.nix
    ../modules/nixos/virtualisation.nix
    ../modules/nixos/gaming.nix
    ../modules/nixos/ai-cuda.nix
    ../modules/nixos/packages-workstation.nix
    ../modules/nixos/flatpak-workstation.nix
  ];

  networking.hostName = "seevser-nixos";
}
