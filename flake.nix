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

  outputs = { nixpkgs, nixpkgs-stable, home-manager, nix-flatpak, antigravity-nix, comfyui-nix, nur, dms, ... }@inputs:
    let
      lib = nixpkgs.lib;

      pkgs-stable = import nixpkgs-stable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };

      openldapNoTests = final: prev: {
        openldap = prev.openldap.overrideAttrs (_: { doCheck = false; });
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

      workstationOverlays = [
        antigravity-nix.overlays.default
        nur.overlays.default
        openldapNoTests
        vivaldiLibPath
      ];

      codingOverlays = [
        antigravity-nix.overlays.default
        vivaldiLibPath
      ];

      mkNixos =
        { hostModule
        , flakeHost
        , overlays
        , specialArgs
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          inherit specialArgs;
          modules = [
            hostModule
            { nixpkgs.overlays = overlays; }
            nix-flatpak.nixosModules.nix-flatpak
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = {
                inherit inputs;
                inherit flakeHost;
              };
              home-manager.users.seevser = import ./nixos-home.nix;
            }
          ];
        };
    in
    {
      nixosConfigurations.seevser-nixos = mkNixos {
        hostModule = ./hosts/seevser-nixos.nix;
        flakeHost = "seevser-nixos";
        overlays = workstationOverlays;
        specialArgs = {
          inherit pkgs-stable comfyui-nix nur;
        };
      };

      nixosConfigurations.seevser-coding = mkNixos {
        hostModule = ./hosts/seevser-coding.nix;
        flakeHost = "seevser-coding";
        overlays = codingOverlays;
        specialArgs = {
          inherit pkgs-stable;
        };
      };
    };
}
