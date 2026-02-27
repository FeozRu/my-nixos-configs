{
  description = "NixOS конфигурация seevser";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";
  };

  outputs = { nixpkgs, home-manager, nix-flatpak, ... }: {
    nixosConfigurations.seevser-nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./nixos-configuration.nix

        # Декларативный Flatpak
        nix-flatpak.nixosModules.nix-flatpak

        # Home Manager как NixOS-модуль
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.seevser = import ./nixos-home.nix;
        }
      ];
    };
  };
}
