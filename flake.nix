{
  description = "NixOS (lite)";

  # Если flake.lock не обновляется (Permission denied): sudo chown "$USER" flake.lock && nix flake update
  # Либо: mv flake.lock.new flake.lock — актуальный lock без nur/comfyui лежит рядом как шаблон.

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Временный инпут: ревизия nixpkgs#584169 (vencord 1.15.16, фикс серого
    # окна vesktop). Из нашего пина nixos-unstable vencord 1.15.16 не собирается
    # (в lockfile новый pnpm-12-формат, наш pnpm-хук от 5 ноября его не ест).
    # Убрать, когда unstable заберёт этот PR, вместе со строкой в оверлее
    # vesktopSystemVencord. Инпут прибит к полному sha — nix flake update его не тронет.
    nixpkgs-pr584169.url = "github:NixOS/nixpkgs/308f3ebb819769d0288a1855b917009cb81354b6";

    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";

    # Исходники видеоредактора Kadr — собираются pkgs/kadr.nix.
    # Обновление: nix flake update kadr  (у проекта нет своих релизов в nixpkgs).
    kadr = {
      url = "github:HelpFreedom/kadr";
      flake = false;
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    # ZCode (Z.ai GLM ADE) — пакет из официального .deb + Home Manager-модуль.
    # Обновление: nix flake update zcode-nix
    zcode-nix = {
      url = "github:FWW321/zcode-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

  };

  outputs = { nixpkgs, nixpkgs-stable, home-manager, nix-flatpak, dms, ... }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";

      # Единственное место: логин Linux, hostname и каталог flake (имя папки репозитория).
      userName = "sebyanin";
      hostName = "nixos";
      flakeRepo = "my-nixos-configs";
      flakeDirectory = "/home/${userName}/${flakeRepo}";

      pkgs-stable = import nixpkgs-stable {
        inherit system;
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

      kadr = final: prev: {
        kadr = final.callPackage ./pkgs/kadr.nix { src = inputs.kadr; };

        # Всё необязательное сразу: детектор дефектов озвучки (torch и т.п.) и
        # CLI claude для встроенной панели. claude-code unfree — нужен
        # allowUnfree = true (в common-system.nix он уже стоит).
        kadr-full = final.callPackage ./pkgs/kadr.nix {
          src = inputs.kadr;
          withVoiceDefectDetector = true;
          claudeCode = final.claude-code;
        };
      };

      # sphinx-hook в nixpkgs под __structuredAttrs читает только первый элемент
      # sphinxBuilders (eval "__sphinxBuilders=($sphinxBuilders)"), поэтому khal
      # собирает html, но не создаёт объявленный man-выход и падает на
      # «failed to produce output path for output 'man'». Пока чинят upstream,
      # передаём билдеры строкой. khal тянется модулем dms (enableCalendarEvents).
      khalSphinxBuilders = final: prev: {
        khal = prev.khal.overrideAttrs (_: {
          sphinxBuilders = "html man";
        });
      };

      # Vesktop при старте грузит Vencord из ~/.config/vesktop/sessionData/vencordFiles,
      # а если его там нет — качает devbuild с GitHub-ассетов. Когда GitHub отдаёт
      # 504 (или файлы устарели — так и случилось: полугодовой Vencord не понял
      # обновлённый веб-клиент Discord), vesktop вечно висит на «Loading Vesktop...».
      # Вшиваем системный Vencord прямо в сборку (withSystemVencord) — бамп 1.15.16
      # берём из ревизии nixpkgs#584169, т.к. из нашего пина nixos-unstable он
      # пока не собирается. Когда unstable заберёт PR: убрать инпут
      # nixpkgs-pr584169 и строку про vencord ниже; withSystemVencord оставить —
      # обновление Vencord тогда только через nixpkgs, без ходок в GitHub при старте.
      vesktopSystemVencord = final: prev: {
        vencord = inputs.nixpkgs-pr584169.legacyPackages.${prev.system}.vencord;
        vesktop = prev.vesktop.override { withSystemVencord = true; };
      };

      overlays = [
        vivaldiLibPath
        kadr
        khalSphinxBuilders
        vesktopSystemVencord
        inputs.zcode-nix.overlays.default
      ];

      specialArgs = {
        inherit userName hostName flakeDirectory pkgs-stable;
      };
    in
    {
      packages.${system} = let
        pkgs = import nixpkgs {
          inherit system;
          # kadr-full тянет unfree claude-code
          config.allowUnfree = true;
          overlays = [ kadr ];
        };
      in {
        inherit (pkgs) kadr kadr-full;

        # Кастомный клиент Moonlight (форк Nonary) для Vibepollo — VRR, PyroWave,
        # передача микрофона. Ставится отдельно от стокового moonlight-qt.
        moonlight-vrr = pkgs.callPackage ./pkgs/moonlight-vrr.nix { };
      };

      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        inherit system;
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
            home-manager.users.${userName} = {
              imports = [
                (import ./nixos-home.nix)
              ];
            };
          }
        ];
      };
    };
}
