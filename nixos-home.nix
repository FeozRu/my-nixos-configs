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
    userName = "Sebyanin";
    userEmail = "feozru@yahoo.com";
    extraConfig = {
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

    initExtra = ''
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
  # Thefuck
  # ========================
  programs.thefuck = {
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
  };

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
  };

  # ========================
  # Управление home-manager
  # ========================
  programs.home-manager.enable = true;
}
