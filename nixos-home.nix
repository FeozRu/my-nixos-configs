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
  home.enableNixpkgsReleaseCheck = false; # На unstable версии HM и nixpkgs бампаются не синхронно — это нормально

  home.packages = with pkgs; [
    #zsh-powerlevel10k
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

  programs.fish = {
    enable = true;

    shellAliases = {
      ssh = "kitty +kitten ssh";
      sshp = "command ssh";  # ssh без kitty kitten (для хостов без base64)

      vim = "nvim";
      vi = "nvim";
      "ventoy-gui" = "xhost +SI:localuser:root && command ventoy-gui";

      rebuild = "sudo nixos-rebuild switch --flake ${flakeDirectory}#${hostName}";
      update = "sudo nix flake update --flake ${flakeDirectory} && sudo nixos-rebuild switch --flake ${flakeDirectory}#${hostName}";
      cleanup = "sudo nix-collect-garbage -d";
      nixedit = "nvim ${flakeDirectory}/flake.nix";
    };

    interactiveShellInit = ''
      # === .NET tools ===
      fish_add_path $HOME/.dotnet/tools

      # === SDKMAN ===
      set -x SDKMAN_DIR $HOME/.sdkman

      # === Yazi shell wrapper ===
      function y
        set tmp (mktemp -t yazi-cwd.XXXXXX)
        yazi $argv --cwd-file=$tmp
        set cwd (command cat -- $tmp)
        if test -n "$cwd" -a "$cwd" != "$PWD"
          builtin cd -- $cwd
        end
        rm -f -- $tmp
      end

      # === MiMo Code updater ===
      function mimo-update
        set ver (curl -s https://registry.npmjs.org/@mimo-ai/mimocode-linux-x64/latest | jq -r .version)
        if test -z "$ver" -o "$ver" = "null"
          echo "Failed to fetch latest version" >&2
          return 1
        end
        set url "https://registry.npmjs.org/@mimo-ai/mimocode-linux-x64/-/mimocode-linux-x64-$ver.tgz"
        echo "Fetching version $ver ..."
        set raw_hash (nix-prefetch-url --type sha512 "$url")
        set hash (nix hash convert --hash-algo sha512 --to sri "$raw_hash")
        echo ""
        echo "version = \"$ver\";"
        echo "url     = \"$url\";"
        echo "hash    = \"$hash\";"
      end
    '';
  };
  
  programs.kitty = {
    enable = true;
    shellIntegration.enableFishIntegration = true;
    settings = {
      shell = "${pkgs.fish}/bin/fish";
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
    enableFishIntegration = true;
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
    GTK_THEME = "Breeze-Dark";
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
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.theme = config.gtk.theme;
  };

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "breeze";
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };



  home.pointerCursor = {
    name = "breeze_cursors";
    package = pkgs.kdePackages.breeze;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # Фиксация громкости микрофона USB Advanced Audio Device на 100%.
  # Приложения (Chromium и т.д.) любят дёргать громкость через AGC —
  # этот сервис мгновенно возвращает её обратно.
  systemd.user.services.mic-volume-lock = {
    Unit = {
      Description = "Lock USB Advanced Audio Device mic volume at 100%";
      After = [ "pipewire.service" "wireplumber.service" ];
      Requires = [ "pipewire.service" "wireplumber.service" ];
    };
    Service = {
      Type = "simple";
      Restart = "always";
      RestartSec = 3;
      ExecStart = let
        script = pkgs.writeShellScript "mic-volume-lock" ''
          NODE_NAME="alsa_input.usb-C-Media_Electronics_Inc._USB_Advanced_Audio_Device-00.analog-stereo"
          TARGET_VOL="1.00"

          # Выставляем громкость при старте
          ${pkgs.wireplumber}/bin/wpctl set-volume "$(
            ${pkgs.wireplumber}/bin/wpctl status | 
            ${pkgs.gnugrep}/bin/grep -oP '\d+(?=\.\s+USB Advanced Audio Device Analog Stereo)' |
            head -1
          )" "$TARGET_VOL" 2>/dev/null || true

          # Слушаем изменения через pw-dump --monitor и реагируем
          ${pkgs.pipewire}/bin/pw-dump --monitor --no-colors 2>/dev/null |
            ${pkgs.gnugrep}/bin/grep --line-buffered "$NODE_NAME" |
            while read -r _line; do
              ${pkgs.wireplumber}/bin/wpctl set-volume "$(
                ${pkgs.wireplumber}/bin/wpctl status |
                ${pkgs.gnugrep}/bin/grep -oP '\d+(?=\.\s+USB Advanced Audio Device Analog Stereo)' |
                head -1
              )" "$TARGET_VOL" 2>/dev/null || true
            done
        '';
      in "${script}";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
