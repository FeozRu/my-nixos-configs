{
  description = "NixOS (lite)";

  # Если flake.lock не обновляется (Permission denied): sudo chown "$USER" flake.lock && nix flake update
  # Либо: mv flake.lock.new flake.lock — актуальный lock без nur/comfyui лежит рядом как шаблон.

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";

    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

  outputs = { nixpkgs, nixpkgs-stable, home-manager, nix-flatpak, antigravity-nix, dms, ... }@inputs:
    let
      lib = nixpkgs.lib;

      # Единственное место: логин Linux, hostname и каталог flake (имя папки репозитория).
      userName = "sebyanin";
      hostName = "nixos";
      flakeRepo = "my-nixos-configs";
      flakeDirectory = "/home/${userName}/${flakeRepo}";

      pkgs-stable = import nixpkgs-stable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };

      vivaldiLibPath = final: prev: {
        vivaldi = prev.vivaldi.overrideAttrs (old: let
          libPathFixed =
            final.lib.replaceStrings [ ":$out/opt/vivaldi/lib" ] [ ":$out/opt/vivaldi" ] old.libPath;
        in {
          libPath = libPathFixed;
          buildPhase = final.lib.replaceStrings [ old.libPath ] [ libPathFixed ] old.buildPhase;
          installPhase = final.lib.replaceStrings [ old.libPath ] [ libPathFixed ] old.installPhase;
        });
      };

      overlays = [
        antigravity-nix.overlays.default
        vivaldiLibPath
      ];

      specialArgs = {
        inherit userName hostName flakeDirectory pkgs-stable;
      };
    in
    {
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = [
          ./hosts/default.nix
          { nixpkgs.overlays = overlays; }
          nix-flatpak.nixosModules.nix-flatpak
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = {
              inherit inputs userName hostName flakeDirectory;
            };
            home-manager.users.${userName} = import ./nixos-home.nix;
          }
        ];
      };
    };
}
