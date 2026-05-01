{ config, pkgs, lib, ... }:

{
  programs.zsh.shellAliases.oc = "ollama launch claude";

  xdg.mimeApps.defaultApplications."x-scheme-handler/nxm" = "steamtinkerlaunch-mo2-nxm.desktop";

  xdg.desktopEntries = {
    steamtinkerlaunch-mo2-nxm = {
      name = "SteamTinkerLaunch MO2 NXM";
      exec = "/home/seevser/.config/steamtinkerlaunch/custom/nxm-writer.sh %u";
      mimeType = [ "x-scheme-handler/nxm" ];
      noDisplay = true;
    };
  };

  xdg.configFile = {
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
        mkfifo "$FIFO" 2>/dev/null

        echo "$(date): NXM Listener started, waiting for links..." >> "$LOG"
        while true; do
          if read -r url < "$FIFO"; then
            echo "$(date): Received NXM link: $url" >> "$LOG"
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

  home.activation.steamtinkerlaunchConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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

    STL_STEAM_DIR="$HOME/.local/share/Steam/compatibilitytools.d/SteamTinkerLaunch"
    if [ -d "$STL_STEAM_DIR" ]; then
      ln -sf /run/current-system/sw/bin/steamtinkerlaunch "$STL_STEAM_DIR/steamtinkerlaunch"
    fi

    rm -f /dev/shm/steamtinkerlaunch/ModOrganizer-failed.txt || true

    SKYRIM_PFX="$HOME/.local/share/Steam/steamapps/compatdata/489830/pfx"
    USER_REG="$SKYRIM_PFX/user.reg"
    if [ -f "$USER_REG" ]; then
      sed -i '/\[Control Panel.*Desktop\]/,/^\[/ { /"LogPixels"=dword:/d }' "$USER_REG"
      sed -i '/\[Control Panel.*Desktop\]/ a "LogPixels"=dword:0000007d' "$USER_REG"
    fi

    FIFO="$HOME/.config/steamtinkerlaunch/mo2/nxm.fifo"
    mkdir -p "$(dirname "$FIFO")"
    [ -p "$FIFO" ] || mkfifo "$FIFO"
    chmod 666 "$FIFO"

    mkdir -p ~/.config/steamtinkerlaunch/mo2/dldata
    SKCONF="$HOME/.config/steamtinkerlaunch/mo2/dldata/skyrimspecialedition.conf"
    printf '%s\n' \
      'GMO2EXE="/home/seevser/.local/share/Steam/steamapps/compatdata/489830/pfx/drive_c/Modding/MO2/ModOrganizer.exe"' \
      'RUNPROTON="/home/seevser/.local/share/Steam/steamapps/common/Proton 9.0 (Beta)/proton"' \
      'MO2PFX="/home/seevser/.local/share/Steam/steamapps/compatdata/489830/pfx"' \
      'MO2WINE="/home/seevser/.local/share/Steam/steamapps/common/Proton 9.0 (Beta)/files/bin/wine"' \
      'MO2INST=""' \
      'STEAM_COMPAT_CLIENT_INSTALL_PATH="/home/seevser/.local/share/Steam"' \
      'STEAM_COMPAT_DATA_PATH="/home/seevser/.local/share/Steam/steamapps/compatdata/489830"' \
      > "$SKCONF"
    echo "skyrimspecialedition" > ~/.config/steamtinkerlaunch/mo2/lastinstance.conf
  '';
}
