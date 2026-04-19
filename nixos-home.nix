{ config, pkgs, lib, ... }:

{
  imports = [
    ./nixos-niri-home.nix
  ];

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

    # Yazi и зависимости для предпросмотра
    yazi
    chafa
    ueberzugpp
    ffmpegthumbnailer
    poppler-utils
    bottom
    mdcat # Идеальный парсер Markdown, отлично работает с заголовками и таблицами

    # D-Bus FileManager1 сервис: перехватывает ShowItems/ShowFolders от Electron-приложений
    # (Vivaldi, VSCode, Antigravity) и открывает найденный файл в Kitty+Yazi
    (pkgs.writeTextFile {
      name = "yazi-filemanager1";
      executable = true;
      destination = "/bin/yazi-filemanager1";
      text = ''
        #!${pkgs.python3.withPackages (ps: [ ps.pygobject3 ])}/bin/python3
        import os, subprocess, sys, urllib.parse
        from gi.repository import Gio, GLib

        XML = """<node>
          <interface name="org.freedesktop.FileManager1">
            <method name="ShowFolders">
              <arg name="uris" type="as" direction="in"/>
              <arg name="startupId" type="s" direction="in"/>
            </method>
            <method name="ShowItems">
              <arg name="uris" type="as" direction="in"/>
              <arg name="startupId" type="s" direction="in"/>
            </method>
            <method name="ShowItemProperties">
              <arg name="uris" type="as" direction="in"/>
              <arg name="startupId" type="s" direction="in"/>
            </method>
          </interface>
        </node>"""

        def uri_to_path(uri):
            if uri.startswith("file://"):
                return urllib.parse.unquote(uri[7:])
            return uri

        def open_in_yazi(path):
            # Yazi умеет принимать путь к файлу: откроет родительскую директорию
            # и подсветит нужный файл автоматически
            subprocess.Popen(
                ["kitty", "-e", "yazi", path],
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

        def handle_method_call(conn, sender, obj, iface, method, params, invocation):
            args = params.unpack()
            uris = args[0] if args else []
            if uris:
                open_in_yazi(uri_to_path(uris[0]))
            invocation.return_value(None)

        def on_bus_acquired(conn, name):
            info = Gio.DBusNodeInfo.new_for_xml(XML)
            conn.register_object(
                "/org/freedesktop/FileManager1",
                info.interfaces[0],
                handle_method_call, None, None,
            )

        loop = GLib.MainLoop()
        Gio.bus_own_name(
            Gio.BusType.SESSION,
            "org.freedesktop.FileManager1",
            Gio.BusNameOwnerFlags.REPLACE,
            on_bus_acquired, None,
            lambda *a: loop.quit(),
        )
        loop.run()
      '';
    })
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
      # NixOS (flakes)
      rebuild = "sudo nixos-rebuild switch --flake /home/seevser/nix-configs-git#seevser-nixos";
      update  = "sudo nix flake update --flake /home/seevser/nix-configs-git && sudo nixos-rebuild switch --flake /home/seevser/nix-configs-git#seevser-nixos";
      cleanup = "sudo nix-collect-garbage -d";
      nixedit = "nvim /home/seevser/nix-configs-git/nixos-configuration.nix";

      # Podman
      dcu  = "podman-compose up -d";
      dcd  = "podman-compose down";
      dcl  = "podman-compose logs -f";
      dps  = "podman ps";
      dpsa = "podman ps -a";

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

      # Yazi
      y = "yazi";

      # ollama + claude-code
      oc = "ollama launch claude";
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

      # Протокол терминала — xterm-kitty позволяет Yazi использовать
      # нативный Kitty Graphics Protocol для изображений в полный размер
      term = "xterm-kitty";

      # Внешний вид
      background_opacity  = "0.92";
      dynamic_background_opacity = true;
      window_padding_width = 8;
      confirm_os_window_close = 0;
      hide_window_decorations = false;

      # Цвета (из Alacritty dank-theme)
      foreground            = "#e6e0e9";
      background            = "#141218";
      selection_foreground  = "#e6e0e9";
      selection_background  = "#4f378b";
      cursor                = "#d0bcff";
      cursor_text_color     = "#141218";

      # Normal
      color0                = "#141218";
      color1                = "#ff728f";
      color2                = "#7fff9a";
      color3                = "#ffda72";
      color4                = "#bca5f2";
      color5                = "#4e3d76";
      color6                = "#D0BCFF";
      color7                = "#f4efff";

      # Bright
      color8                = "#9d99a5";
      color9                = "#ff9fb2";
      color10               = "#a5ffb8";
      color11               = "#ffe7a5";
      color12               = "#d7c6ff";
      color13               = "#ded0ff";
      color14               = "#e9e0ff";
      color15               = "#faf8ff";

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
    # Конфигурация управляется AstroNvim (отдельный репозиторий в ~/.config/nvim)
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
        # Файловый менеджер (папки)
        "inode/directory" = "yazi.desktop";
        
        # Браузер
        "x-scheme-handler/http"  = "vivaldi-stable.desktop";
        "x-scheme-handler/https" = "vivaldi-stable.desktop";
        "text/html"              = "vivaldi-stable.desktop";

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

        # Nexus Mods (MO2)
        "x-scheme-handler/nxm" = "steamtinkerlaunch-mo2-nxm.desktop";
      };
    };

    desktopEntries = {
      steamtinkerlaunch-mo2-nxm = {
        name = "SteamTinkerLaunch MO2 NXM";
        exec = "/home/seevser/.config/steamtinkerlaunch/custom/nxm-writer.sh %u";
        mimeType = [ "x-scheme-handler/nxm" ];
        noDisplay = true;
      };
    };

    desktopEntries = {
      yazi = {
        name = "Yazi";
        genericName = "File Manager";
        exec = "kitty -e yazi %u";
        icon = "system-file-manager";
        terminal = false;
        categories = [ "System" "FileTools" "FileManager" ];
        mimeType = [ "inode/directory" ];
      };
    };

    # Настройки конфигов приложений
    configFile = {
      "mimeapps.list".force = true;
      "yazi/yazi.toml".text = ''
        [preview]
        wrap = "yes"
        # Растягиваем изображения на всю панель предпросмотра
        max_width  = 2000
        max_height = 2000
        # Принудительно использовать нативный Kitty Graphics Protocol
        # (без этого Yazi может выбрать Iip/iterm2 который не умеет в размеры)
        image_filter = "triangle"

        [[plugin.prepend_previewers]]
        url = "*.md"
        run = 'faster-piper -- mdcat --columns $w "$1"'

        [[plugin.prepend_previewers]]
        url = "*.mdx"
        run = 'faster-piper -- mdcat --columns $w "$1"'
      '';

      # Keybindings живут в keymap.toml (отдельно от yazi.toml в Yazi 26+)
      "yazi/keymap.toml".text = ''
        # T — развернуть предпросмотр на весь экран / вернуть обратно
        [[mgr.prepend_keymap]]
        on   = "T"
        run  = "plugin toggle-pane max-preview"
        desc = "Maximize or restore the preview pane"
      '';
      "steamtinkerlaunch/custom/yad-wrapper.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          export FONTCONFIG_FILE=/etc/fonts/fonts.conf
          exec yad "$@"
        '';
      };
      "steamtinkerlaunch/custom/nxm-listener.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          FIFO="$HOME/.config/steamtinkerlaunch/mo2/nxm.fifo"
          LOG="$HOME/.config/steamtinkerlaunch/mo2/listener.log"
          # Гарантируем наличие фифо
          mkfifo "$FIFO" 2>/dev/null
          
          echo "$(date): NXM Listener started, waiting for links..." >> "$LOG"
          while true; do
            # Читаем из фифо (блокируется до записи)
            if read -r url < "$FIFO"; then
              echo "$(date): Received NXM link: $url" >> "$LOG"
              # Извлекаем данные из ссылки для правильного вызова
              # NXM ссылки имеют формат nxm://GAME/MOD_ID/...
              # Нам нужно убедиться, что STL вызывает именно skyrimspecialedition
              # Самый надежный способ - подменить GAME на skyrimspecialedition в вызове
              
              CLEAN_URL=$(echo "$url" | sed 's|^nxm://[^/]\+|nxm://skyrimspecialedition|')
              echo "$(date): Forwarding as: $CLEAN_URL" >> "$LOG"
              
              "${pkgs.steamtinkerlaunch}/bin/steamtinkerlaunch" mo2 u "$CLEAN_URL" >> "$LOG" 2>&1
              echo "$(date): Finished processing link" >> "$LOG"
            fi
          done
        '';
      };
      "steamtinkerlaunch/custom/nxm-writer.sh" = {
        executable = true;
        text = ''
          #!/bin/sh
          FIFO="$HOME/.config/steamtinkerlaunch/mo2/nxm.fifo"
          echo "$1" > "$FIFO"
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
    # По умолчанию Wine использует 96 DPI. Ставим 125 (130%) для лучшей читаемости.
    # Прямое редактирование реестра через sed - это самый надежный способ в NixOS.
    SKYRIM_PFX="$HOME/.local/share/Steam/steamapps/compatdata/489830/pfx"
    USER_REG="$SKYRIM_PFX/user.reg"
    if [ -f "$USER_REG" ]; then
      # Сначала удаляем все старые вхождения LogPixels в секции Desktop, чтобы не дублировать
      # Паттерн \[Control Panel.*Desktop\] достаточно гибкий для поиска заголовка
      sed -i '/\[Control Panel.*Desktop\]/,/^\[/ { /"LogPixels"=dword:/d }' "$USER_REG"
      # Вставляем новое значение (125 DPI = 130%) сразу после заголовка секции
      sed -i '/\[Control Panel.*Desktop\]/ a "LogPixels"=dword:0000007d' "$USER_REG"
    fi

    # 5. Исправляем NXM ссылки ( Nexus Mods Download )
    # Создаем фифо для связи между хостом и контейнером
    FIFO="$HOME/.config/steamtinkerlaunch/mo2/nxm.fifo"
    mkdir -p "$(dirname "$FIFO")"
    [ -p "$FIFO" ] || mkfifo "$FIFO"
    chmod 666 "$FIFO"

    # STL нужен конфиг dldata, чтобы знать куда отправлять ссылку
    mkdir -p ~/.config/steamtinkerlaunch/mo2/dldata
    cat > ~/.config/steamtinkerlaunch/mo2/dldata/skyrimspecialedition.conf <<EOF
GMO2EXE="/home/seevser/.local/share/Steam/steamapps/compatdata/489830/pfx/drive_c/Modding/MO2/ModOrganizer.exe"
RUNPROTON="/home/seevser/.local/share/Steam/steamapps/common/Proton 9.0 (Beta)/proton"
MO2PFX="/home/seevser/.local/share/Steam/steamapps/compatdata/489830/pfx"
MO2WINE="/home/seevser/.local/share/Steam/steamapps/common/Proton 9.0 (Beta)/files/bin/wine"
MO2INST=""
STEAM_COMPAT_CLIENT_INSTALL_PATH="/home/seevser/.local/share/Steam"
STEAM_COMPAT_DATA_PATH="/home/seevser/.local/share/Steam/steamapps/compatdata/489830"
EOF
    # Ставим Skyrim как последний запущенный инстанс
    echo "skyrimspecialedition" > ~/.config/steamtinkerlaunch/mo2/lastinstance.conf
  '';

  # Прописываем yazi.desktop в mimeinfo.cache после каждого rebuild.
  # Electron-приложения (Vivaldi, VSCode, Antigravity) читают именно этот кэш напрямую,
  # игнорируя mimeapps.list, поэтому без этого открывается Dolphin.
  home.activation.yaziMimeCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
    CACHE="$HOME/.local/share/applications/mimeinfo.cache"
    mkdir -p "$(dirname "$CACHE")"
    if [ ! -f "$CACHE" ]; then
      printf '[MIME Cache]\n' > "$CACHE"
    fi
    # Обновляем или вставляем запись inode/directory
    if grep -q '^inode/directory=' "$CACHE" 2>/dev/null; then
      sed -i 's|^inode/directory=.*|inode/directory=yazi.desktop;|' "$CACHE"
    else
      printf 'inode/directory=yazi.desktop;\n' >> "$CACHE"
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
  # GTK тема и иконки (для корректного отображения иконок в трее)
  # ========================
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

  # ========================
  # D-Bus FileManager1 → Yazi
  # Перехватывает ShowItems/ShowFolders от Electron-приложений и открывает Yazi
  # ========================
  systemd.user.services.yazi-filemanager1 = {
    Unit = {
      Description = "FileManager1 D-Bus service (opens Yazi instead of Dolphin)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.lib.getExe' (pkgs.writeTextFile {
        name = "yazi-filemanager1";
        executable = true;
        destination = "/bin/yazi-filemanager1";
        text = ''
          #!${pkgs.python3.withPackages (ps: [ ps.pygobject3 ])}/bin/python3
          import os, subprocess, sys, urllib.parse
          from gi.repository import Gio, GLib

          XML = """<node>
            <interface name="org.freedesktop.FileManager1">
              <method name="ShowFolders">
                <arg name="uris" type="as" direction="in"/>
                <arg name="startupId" type="s" direction="in"/>
              </method>
              <method name="ShowItems">
                <arg name="uris" type="as" direction="in"/>
                <arg name="startupId" type="s" direction="in"/>
              </method>
              <method name="ShowItemProperties">
                <arg name="uris" type="as" direction="in"/>
                <arg name="startupId" type="s" direction="in"/>
              </method>
            </interface>
          </node>"""

          def uri_to_path(uri):
              if uri.startswith("file://"):
                  return urllib.parse.unquote(uri[7:])
              return uri

          def open_in_yazi(path):
              subprocess.Popen(
                  ["kitty", "-e", "yazi", path],
                  start_new_session=True,
                  stdout=subprocess.DEVNULL,
                  stderr=subprocess.DEVNULL,
              )

          def handle_method_call(conn, sender, obj, iface, method, params, invocation):
              args = params.unpack()
              uris = args[0] if args else []
              if uris:
                  open_in_yazi(uri_to_path(uris[0]))
              invocation.return_value(None)

          def on_bus_acquired(conn, name):
              info = Gio.DBusNodeInfo.new_for_xml(XML)
              conn.register_object(
                  "/org/freedesktop/FileManager1",
                  info.interfaces[0],
                  handle_method_call, None, None,
              )

          loop = GLib.MainLoop()
          Gio.bus_own_name(
              Gio.BusType.SESSION,
              "org.freedesktop.FileManager1",
              Gio.BusNameOwnerFlags.REPLACE,
              on_bus_acquired, None,
              lambda *a: loop.quit(),
          )
          loop.run()
        '';
      }) "yazi-filemanager1"}";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
