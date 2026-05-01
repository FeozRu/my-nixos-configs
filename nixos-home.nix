{ config, pkgs, lib, inputs, userName, hostName, flakeDirectory, ... }:

{
  imports = [
    ./modules/home/niri-dms.nix
    ./modules/home/filemanager1.nix
    ./modules/home/yazi-xdg.nix
    ./modules/home/vivaldi.nix
  ];

  home.username = userName;
  home.homeDirectory = "/home/${userName}";
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    zsh-powerlevel10k
    meslo-lgs-nf

    yazi
    chafa
    ueberzugpp
    ffmpegthumbnailer
    poppler-utils
    bottom
    mdcat
  ];

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

      # === SDKMAN ===
      export SDKMAN_DIR="$HOME/.sdkman"
      [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

      # === .NET tools ===
      export PATH="$PATH:$HOME/.dotnet/tools"
      # === Yazi shell wrapper ===
      function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
          builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
      }
    '';

    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ${flakeDirectory}#${hostName}";
      update = "sudo nix flake update --flake ${flakeDirectory} && sudo nixos-rebuild switch --flake ${flakeDirectory}#${hostName}";
      cleanup = "sudo nix-collect-garbage -d";
      nixedit = "nvim ${flakeDirectory}/flake.nix";

      gs = "git status";
      gd = "git diff";
      gp = "git push";
      gl = "git pull";
      gco = "git checkout";
      gcm = "git commit -m";

      vim = "nvim";
      vi = "nvim";

      y = "yazi";
    };
  };

  programs.kitty = {
    enable = true;
    settings = {
      font_family = "MesloLGS NF";
      bold_font = "auto";
      italic_font = "auto";
      font_size = 12;

      term = "xterm-kitty";

      background_opacity = "0.92";
      dynamic_background_opacity = true;
      window_padding_width = 8;
      confirm_os_window_close = 0;
      hide_window_decorations = false;

      foreground = "#e6e0e9";
      background = "#141218";
      selection_foreground = "#e6e0e9";
      selection_background = "#4f378b";
      cursor = "#d0bcff";
      cursor_text_color = "#141218";

      color0 = "#141218";
      color1 = "#ff728f";
      color2 = "#7fff9a";
      color3 = "#ffda72";
      color4 = "#bca5f2";
      color5 = "#4e3d76";
      color6 = "#D0BCFF";
      color7 = "#f4efff";

      color8 = "#9d99a5";
      color9 = "#ff9fb2";
      color10 = "#a5ffb8";
      color11 = "#ffe7a5";
      color12 = "#d7c6ff";
      color13 = "#ded0ff";
      color14 = "#e9e0ff";
      color15 = "#faf8ff";

      cursor_shape = "beam";
      cursor_blink_interval = "0.5";

      scrollback_lines = 10000;

      url_style = "curly";
      open_url_with = "default";

      linux_display_server = "wayland";
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;
  };

  programs.pay-respects = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.htop = {
    enable = true;
    settings = {
      show_program_path = false;
      highlight_base_name = true;
      tree_view = true;
    };
  };

  home.sessionVariables = {
    LANGUAGE = "en_US";
    LANG = "en_US.UTF-8";
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    XCURSOR_THEME = "breeze_cursors";
    XCURSOR_SIZE = "24";
  };

  programs.home-manager.enable = true;

  gtk = {
    enable = true;
    theme = {
      name = "Breeze-Dark";
      package = pkgs.kdePackages.breeze-gtk;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk4.theme = null;
  };

  home.pointerCursor = {
    name = "breeze_cursors";
    package = pkgs.kdePackages.breeze;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
}
