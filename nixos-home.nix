{ config, pkgs, lib, ... }:

{
  home.username = "seevser";
  home.homeDirectory = "/home/seevser";
  home.stateVersion = "25.05";

  # ========================
  # Пакеты пользователя
  # ========================
  home.packages = with pkgs; [
    # Powerlevel10k
    zsh-powerlevel10k
    meslo-lgs-nf

    # Deno (ставим глобально)
    deno
  ];

  # ========================
  # Git
  # ========================
  programs.git = {
    enable = true;
    settings = {
      user.name = "Sebyanin";
      user.email = "feozru@yahoo.com";
      credential.helper = "store";
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  # ========================
  # Zsh + Oh My Zsh + Powerlevel10k
  # ========================
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      share = true;
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "extract" ];
    };

    initContent = ''
      # === Powerlevel10k instant prompt ===
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      # === Powerlevel10k theme ===
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

      # === Deno ===
      export PATH="$HOME/.deno/bin:$PATH"

      # === SDKMAN ===
      export SDKMAN_DIR="$HOME/.sdkman"
      [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

      # === .NET tools ===
      export PATH="$PATH:$HOME/.dotnet/tools"
    '';

    shellAliases = {
      # NixOS (flakes)
      rebuild = "sudo nixos-rebuild switch --flake /home/seevser/nix-configs-git#seevser-nixos";
      update  = "sudo nix flake update --flake /home/seevser/nix-configs-git && sudo nixos-rebuild switch --flake /home/seevser/nix-configs-git#seevser-nixos";
      cleanup = "sudo nix-collect-garbage -d";
      nixedit = "nvim /home/seevser/nix-configs-git/nixos-configuration.nix";

      # Docker
      dcu  = "docker compose up -d";
      dcd  = "docker compose down";
      dcl  = "docker compose logs -f";
      dps  = "docker ps";
      dpsa = "docker ps -a";

      # Git (дополнительно к плагину oh-my-zsh)
      gs  = "git status";
      gd  = "git diff";
      gp  = "git push";
      gl  = "git pull";
      gco = "git checkout";
      gcm = "git commit -m";

      # Neovim
      vim = "nvim";
      vi  = "nvim";
    };
  };

  # ========================
  # Kitty (терминал)
  # ========================
  programs.kitty = {
    enable = true;
    settings = {
      font_family      = "MesloLGS NF";
      bold_font        = "auto";
      italic_font      = "auto";
      font_size        = 12;

      # Внешний вид
      background_opacity  = "0.92";
      dynamic_background_opacity = true;
      window_padding_width = 8;
      confirm_os_window_close = 0;
      hide_window_decorations = false;

      # Курсор
      cursor_shape     = "beam";
      cursor_blink_interval = "0.5";

      # Скроллинг
      scrollback_lines = 10000;

      # URL
      url_style   = "curly";
      open_url_with = "default";

      # Wayland
      linux_display_server = "wayland";
    };
  };

  # ========================
  # Neovim
  # ========================
  programs.neovim = {
    enable = true;
    defaultEditor = true;  # $EDITOR=nvim
    viAlias = true;        # vi → nvim
    vimAlias = true;       # vim → nvim
    extraConfig = ''
      set number
      set relativenumber
      set tabstop=2
      set shiftwidth=2
      set expandtab
      set smartindent
      set termguicolors
      set clipboard=unnamedplus
      set mouse=a
      set ignorecase
      set smartcase
      set undofile
    '';
  };

  # ========================
  # Pay-respects (замена thefuck)
  # ========================
  programs.pay-respects = {
    enable = true;
    enableZshIntegration = true;
  };

  # ========================
  # htop
  # ========================
  programs.htop = {
    enable = true;
    settings = {
      show_program_path = false;
      highlight_base_name = true;
      tree_view = true;
    };
  };

  # ========================
  # Настройки XDG (приложения по умолчанию)
  # ========================
  xdg = {
    enable = true;

    mimeApps = {
      enable = true;
      defaultApplications = {
        # Браузер
        "x-scheme-handler/http"  = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "text/html"              = "firefox.desktop";

        # Почта
        "x-scheme-handler/mailto" = "thunderbird.desktop";
        "message/rfc822"          = "thunderbird.desktop";

        # Discord → Vesktop
        "x-scheme-handler/discord" = "vesktop.desktop";

        # Bitwarden
        "x-scheme-handler/bitwarden" = "bitwarden.desktop";

        # Outline VPN
        "x-scheme-handler/ss"     = "Outline.desktop";
        "x-scheme-handler/ssconf" = "Outline.desktop";
      };
    };

    # Настройки конфигов приложений
    configFile = {
      "steamtinkerlaunch/custom/yad-wrapper.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          export FONTCONFIG_FILE=/etc/fonts/fonts.conf
          exec yad "$@"
        '';
      };
    };
  };

  # Создаем global.conf как копию, чтобы STL мог в него писать, а не симлинк
  # Также исправляем симлинк в Steam, чтобы он использовал наш wrapper с steam-run
  home.activation.steamtinkerlaunchConf = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # 1. Исправляем конфиг (YAD, путь к шрифтам и Proton для MO2)
    mkdir -p ~/.config/steamtinkerlaunch
    touch ~/.config/steamtinkerlaunch/global.conf
    if ! grep -q 'YAD=' ~/.config/steamtinkerlaunch/global.conf 2>/dev/null; then
      echo 'YAD="/home/seevser/.config/steamtinkerlaunch/custom/yad-wrapper.sh"' >> ~/.config/steamtinkerlaunch/global.conf
    else
      sed -i 's|^YAD=.*|YAD="/home/seevser/.config/steamtinkerlaunch/custom/yad-wrapper.sh"|' ~/.config/steamtinkerlaunch/global.conf || true
    fi

    if ! grep -q 'USEMO2PROTON=' ~/.config/steamtinkerlaunch/global.conf 2>/dev/null; then
      echo 'USEMO2PROTON="Proton-CachyOS Latest"' >> ~/.config/steamtinkerlaunch/global.conf
    else
      sed -i 's|^USEMO2PROTON=.*|USEMO2PROTON="Proton-CachyOS Latest"|' ~/.config/steamtinkerlaunch/global.conf || true
    fi

    # 2. Исправляем интеграцию со Steam (перенаправляем на наш wrapper)
    STL_STEAM_DIR="$HOME/.local/share/Steam/compatibilitytools.d/SteamTinkerLaunch"
    if [ -d "$STL_STEAM_DIR" ]; then
      ln -sf /run/current-system/sw/bin/steamtinkerlaunch "$STL_STEAM_DIR/steamtinkerlaunch"
    fi

    # 3. Удаляем старые блокировки MO2
    rm -f /dev/shm/steamtinkerlaunch/ModOrganizer-failed.txt || true

    # 4. Исправляем DPI (размер шрифтов) для MO2 (Skyrim SE - 489830)
    # По умолчанию Wine использует 96 DPI, что слишком мелко на 2K/4K. 
    # Ставим 120 (125%) или 144 (150%). Начнем с 120.
    SKYRIM_PFX="$HOME/.local/share/Steam/steamapps/compatdata/489830/pfx"
    if [ -d "$SKYRIM_PFX" ]; then
      # Используем прямое редактирование файлов реестра или wine reg
      # Для стабильности просто создаем временный .reg файл и применяем его
      cat > /tmp/stl-dpi.reg <<EOF
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Control Panel\Desktop]
"LogPixels"=dword:00000078
EOF
      # Пытаемся применить через steam-run wine, если префикс уже существует
      # Мы используем || true, чтобы не ломать активацию если wine еще не настроен
      /run/current-system/sw/bin/steam-run /run/current-system/sw/bin/wine regedit /tmp/stl-dpi.reg || true
      rm /tmp/stl-dpi.reg
    fi
  '';

  # ========================
  # Локализация (переменные окружения)
  # ========================
  home.sessionVariables = {
    LANGUAGE        = "en_US";
    LANG            = "en_US.UTF-8";
    LC_ADDRESS      = "ru_RU.UTF-8";
    LC_MONETARY     = "ru_RU.UTF-8";
    LC_PAPER        = "ru_RU.UTF-8";
    LC_TELEPHONE    = "ru_RU.UTF-8";
    LC_MEASUREMENT  = "ru_RU.UTF-8";
    LC_TIME         = "ru_RU.UTF-8";
    LC_NUMERIC      = "ru_RU.UTF-8";
    XCURSOR_THEME = "breeze_cursors";
    XCURSOR_SIZE = "24";
  };

  # ========================
  # Управление home-manager
  # ========================
  programs.home-manager.enable = true;


  # ========================
  # Pointer cursor
  # ========================
  home.pointerCursor = {
    name = "breeze_cursors";
    package = pkgs.kdePackages.breeze;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
}
