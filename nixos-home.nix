{ config, pkgs, lib, inputs, userName, hostName, flakeDirectory, ... }:

let
  ruRuCp1251Locale = pkgs.runCommand "ru_RU-cp1251-locale" { } ''
    mkdir -p "$out/lib/locale"
    ${pkgs.glibc.bin}/bin/localedef --no-archive -i ru_RU -f CP1251 "$out/lib/locale/ru_RU.CP1251"
  '';

  portProtonWineLibraryPath = lib.makeLibraryPath (
    (with pkgs; [
      stdenv.cc.cc.lib
      zlib
      zstd
      alsa-lib
      fontconfig
      freetype
      expat
      libpulseaudio
      libdrm
      libgbm
      mesa
      libusb1
      vulkan-loader
      libglvnd
      wayland
      libxkbcommon
      libx11
      libxext
      libxcursor
      libxrandr
      libxrender
      libxi
      libxtst
      libxxf86vm
      libxcomposite
      libxfixes
      libxinerama
      libxdamage
    ])
    ++
    (with pkgs.pkgsi686Linux; [
      stdenv.cc.cc.lib
      zlib
      zstd
      alsa-lib
      fontconfig
      freetype
      expat
      libpulseaudio
      libdrm
      libgbm
      mesa
      libusb1
      vulkan-loader
      libglvnd
      wayland
      libxkbcommon
      libx11
      libxext
      libxcursor
      libxrandr
      libxrender
      libxi
      libxtst
      libxxf86vm
      libxcomposite
      libxfixes
      libxinerama
      libxdamage
    ])
  );

  portProtonNixosEnv = pkgs.writeShellScript "portproton-nixos-env" ''
    # pressure-vessel на NixOS ломает LD_LIBRARY_PATH и тащит nix-ld.
    export PW_USE_RUNTIME="0"
    unset NIX_LD
    unset NIX_LD_LIBRARY_PATH
    unset GIO_EXTRA_MODULES
    unset GTK_PATH
    export GSETTINGS_BACKEND=memory
    export LOCPATH="${ruRuCp1251Locale}/lib/locale:''${LOCPATH:-}"
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib:${portProtonWineLibraryPath}:''${LD_LIBRARY_PATH:-}"
    export LANG="ru_RU.CP1251"
    export LC_ALL="ru_RU.CP1251"
    export LANGUAGE="ru_RU"
    export PW_LOCALE_SELECT="ru_RU.CP1251"
  '';

  portProtonQt = pkgs.writeShellScriptBin "portprotonqt-nixos" ''
    source ${portProtonNixosEnv}
    exec /home/${userName}/Applications/PortProtonQt/AppRun "$@"
  '';

  # Прямой запуск для проверки: обходит pressure-vessel внутри PortProton.
  fraterPortproton = pkgs.writeShellScriptBin "frater-portproton" ''
    source ${portProtonNixosEnv}
    export WINEPREFIX="/home/${userName}/PortProtonQt/data/prefixes/FRATER"
    export WINE="/home/${userName}/PortProtonQt/data/dist/WINE_LG_11-10/bin/wine"
    export WINESERVER="/home/${userName}/PortProtonQt/data/dist/WINE_LG_11-10/bin/wineserver"
    export WINEDEBUG="-all"
    cd "$WINEPREFIX/drive_c/Program Files (x86)/Frater" || exit 1
    exec "$WINE" ./frater.exe "$@"
  '';
in
{
  imports = [
    ./modules/home/niri-dms.nix
    ./modules/home/filemanager1.nix
    ./modules/home/yazi-xdg.nix
    ./modules/home/vivaldi.nix
    ./modules/home/pmbootstrap-git.nix
  ];

  home.username = userName;
  home.homeDirectory = "/home/${userName}";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false; # На unstable версии HM и nixpkgs бампаются не синхронно — это нормально

  # Vendor ID для adb (Xiaomi POCO X3 NFC, Google fastboot, UBports)
  home.file.".android/adb_usb.ini".text = ''
    0x2717
    0x18d1
    0x2ae5
    0x05c6
  '';

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
    portProtonQt
    fraterPortproton
  ];

  home.file.".local/share/portproton-nixos/env.sh".source = portProtonNixosEnv;

  home.activation.portprotonNixosUserConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    env_script="${portProtonNixosEnv}"
    mkdir -p "$HOME/.local/share/portproton-nixos"
    ln -sfn "$env_script" "$HOME/.local/share/portproton-nixos/env.sh"

    user_conf="$HOME/PortProtonQt/data/user.conf"
    if [ ! -f "$user_conf" ]; then
      exit 0
    fi

    marker_start="# portproton-nixos-start"
    marker_end="# portproton-nixos-end"

    # Убрать старый однострочный source и предыдущий managed-блок.
    sed -i '/portproton-nixos-env/d' "$user_conf"
    if grep -q "$marker_start" "$user_conf"; then
      sed -i "/$marker_start/,/$marker_end/d" "$user_conf"
    fi

    cat >> "$user_conf" << EOF

$marker_start
# Managed by home-manager — не редактировать вручную
export PW_USE_RUNTIME="0"
. "$env_script"
$marker_end
EOF
  '';

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

  xdg.desktopEntries.portprotonqt = {
    name = "PortProtonQt";
    comment = "Manage and launch Windows games on Linux";
    exec = "${portProtonQt}/bin/portprotonqt-nixos";
    icon = "applications-games";
    terminal = false;
    type = "Application";
    categories = [ "Game" ];
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
