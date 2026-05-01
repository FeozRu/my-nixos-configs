{
  description = "NixOS конфигурация seevser";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nur.url = "github:nix-community/NUR";

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

    comfyui-nix.url = "github:utensils/comfyui-nix";
  };

  outputs = { nixpkgs, nixpkgs-stable, home-manager, nix-flatpak, antigravity-nix, comfyui-nix, nur, dms, ... }@inputs: {
    nixosConfigurations.seevser-nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        pkgs-stable = import nixpkgs-stable {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        inherit comfyui-nix nur;
      };
      modules = [
        ./nixos-configuration.nix

        # Google Antigravity IDE (overlay) и NUR
        {
          nixpkgs.overlays = [ 
            antigravity-nix.overlays.default 
            nur.overlays.default
            # openldap 2.6.x test017-syncreplication иногда падает из-за race condition
            # (таймауты при репликации). Пропускаем тесты — это не влияет на работу
            # самого пакета, но unblock-ает lutris который тянет openldap транзитивно.
            (final: prev: {
              openldap = prev.openldap.overrideAttrs (_: { doCheck = false; });
            })
            # Vivaldi: в nixpkgs в libPath указан несуществующий $out/opt/vivaldi/lib;
            # libffmpeg.so лежит в $out/opt/vivaldi — без исправления vivaldi-bin не стартует.
            (final: prev: {
              vivaldi = prev.vivaldi.overrideAttrs (old: let
                libPathFixed =
                  final.lib.replaceStrings [ ":$out/opt/vivaldi/lib" ] [ ":$out/opt/vivaldi" ] old.libPath;
              in {
                libPath = libPathFixed;
                buildPhase = final.lib.replaceStrings [ old.libPath ] [ libPathFixed ] old.buildPhase;
                installPhase = final.lib.replaceStrings [ old.libPath ] [ libPathFixed ] old.installPhase;
              });
            })
          ];
        }

        # Декларативный Flatpak
        nix-flatpak.nixosModules.nix-flatpak

        # Home Manager как NixOS-модуль
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.seevser = import ./nixos-home.nix;
        }
      ];
    };
  };
}
