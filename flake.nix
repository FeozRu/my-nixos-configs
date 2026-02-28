{
  description = "NixOS конфигурация seevser";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";

    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-stable, home-manager, nix-flatpak, antigravity-nix, ... }: {
    nixosConfigurations.seevser-nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        pkgs-stable = import nixpkgs-stable {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      };
      modules = [
        ./nixos-configuration.nix

        # Google Antigravity IDE (overlay)
        {
          nixpkgs.overlays = [ antigravity-nix.overlays.default ];
        }

        # Декларативный Flatpak
        nix-flatpak.nixosModules.nix-flatpak

        # Home Manager как NixOS-модуль
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.seevser = import ./nixos-home.nix;
        }
      ];
    };
  };
}
