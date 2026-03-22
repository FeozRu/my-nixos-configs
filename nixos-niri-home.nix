{ config, pkgs, lib, ... }:

{
  # ========================
  # Niri Desktop Ecosystem (Waybar, Fuzzel, SwayNC, config)
  # ========================
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "MesloLGS NF:size=14";
        terminal = "kitty";
        prompt = "❯ ";
        layer = "overlay";
        inner-pad = 20;
        width = 40;
        lines = 10;
        horizontal-pad = 20;
      };
      colors = {
        background = "1e1e2ebb";
        text = "cdd6f4ff";
        match = "cba6f7ff";
        selection = "585b70ff";
        selection-text = "b4befeff";
        border = "cba6f7ff";
      };
      border = {
        width = 2;
        radius = 12;
      };
    };
  };

  services.swaync = {
    enable = true;
  };

  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 40;
        spacing = 4;
        modules-left = [ "niri/workspaces" "niri/window" ];
        modules-center = [ "clock" ];
        modules-right = [ "pulseaudio" "network" "bluetooth" "tray" ];

        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            active = "";
            default = "";
          };
        };
        "clock" = {
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          format = "{:%H:%M}";
          format-alt = "{:%A, %B %d, %Y}";
        };
        "pulseaudio" = {
          format = "{volume}% {icon} {format_source}";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = " {format_source}";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = ["" "" ""];
          };
          on-click = "pavucontrol";
        };
        "network" = {
          format-wifi = "{essid} ";
          format-ethernet = "{ipaddr}/{cidr} ";
          tooltip-format = "{ifname} via {gwaddr} ";
          format-linked = "{ifname} (No IP) ";
          format-disconnected = "Disconnected ⚠";
        };
        "bluetooth" = {
          format = " {status}";
          format-disabled = "";
          format-connected = " {num_connections}";
          tooltip-format = "{controller_alias}\t{controller_address}";
          tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
        };
        "tray" = {
          spacing = 10;
        };
      };
    };
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "MesloLGS NF", "Font Awesome 6 Free", sans-serif;
        font-size: 14px;
        min-height: 0;
      }
      window#waybar {
        background-color: rgba(30, 30, 46, 0.7);
        color: #cdd6f4;
        transition-property: background-color;
        transition-duration: .5s;
        border-bottom: 2px solid rgba(203, 166, 247, 0.5);
      }
      #workspaces button {
        padding: 0 10px;
        margin: 4px;
        border-radius: 8px;
        background-color: transparent;
        color: #6c7086;
        transition: all 0.3s ease;
      }
      #workspaces button:hover {
        background: rgba(255, 255, 255, 0.1);
        text-shadow: 0 0 5px rgba(255,255,255,0.5);
      }
      #workspaces button.active {
        color: #cba6f7;
        background: rgba(203, 166, 247, 0.15);
      }
      #clock, #battery, #cpu, #memory, #disk, #temperature, #backlight, #network, #pulseaudio, #wireplumber, #custom-media, #tray, #mode, #idle_inhibitor, #scratchpad, #mpd {
        padding: 0 15px;
        margin: 4px;
        border-radius: 8px;
        background-color: rgba(49, 50, 68, 0.5);
        color: #cdd6f4;
      }
      #window {
        margin: 0 15px;
      }
    '';
  };

  # Сам конфиг Niri (KDL)
  xdg.configFile."niri/config.kdl".text = ''
    spawn-at-startup "waybar"
    spawn-at-startup "swaync"
    spawn-at-startup "swww-daemon"
    spawn-at-startup "nm-applet"
    spawn-at-startup "blueman-applet"
    spawn-at-startup "udiskie"
    // Polkit Agent from KDE (автозапуск агента авторизации)
    spawn-at-startup "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1"

    environment {
      DISPLAY ":0"
    }

    input {
      keyboard {
        xkb {
          layout "us,ru"
          options "grp:win_space_toggle"
        }
      }
      mouse {
        accel-profile "flat"
      }
    }

    output "eDP-1" {
      scale 1.0
    }

    layout {
      gaps 12
      center-focused-column "never"

      preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
      }

      default-column-width { proportion 0.5; }

      border {
        width 2
        active-color "#cba6f7"
        inactive-color "#585b70"
      }

      focus-ring {
        width 2
        active-color "#b4befe"
        inactive-color "#313244"
      }
    }

    window-rule {
      geometry-corner-radius 12
      clip-to-geometry true
    }

    binds {
      Mod+Shift+Slash { show-hotkey-overlay; }

      // Лаунчеры и программы
      Mod+T { spawn "kitty"; }
      Mod+Space { spawn "fuzzel"; }

      // Управление окнами
      Mod+Q { close-window; }

      Mod+Left  { focus-column-left; }
      Mod+Down  { focus-window-down; }
      Mod+Up    { focus-window-up; }
      Mod+Right { focus-column-right; }

      Mod+Ctrl+Left  { move-column-left; }
      Mod+Ctrl+Right { move-column-right; }

      // Воркспейсы
      Mod+Page_Down { focus-workspace-down; }
      Mod+Page_Up   { focus-workspace-up; }

      Mod+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
      Mod+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
      Mod+Ctrl+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
      Mod+Ctrl+WheelScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }

      Mod+1 { focus-workspace 1; }
      Mod+2 { focus-workspace 2; }
      Mod+3 { focus-workspace 3; }
      Mod+4 { focus-workspace 4; }
      Mod+5 { focus-workspace 5; }
      Mod+6 { focus-workspace 6; }
      Mod+7 { focus-workspace 7; }
      Mod+8 { focus-workspace 8; }
      Mod+9 { focus-workspace 9; }

      Mod+Shift+1 { move-column-to-workspace 1; }
      Mod+Shift+2 { move-column-to-workspace 2; }
      Mod+Shift+3 { move-column-to-workspace 3; }
      Mod+Shift+4 { move-column-to-workspace 4; }
      Mod+Shift+5 { move-column-to-workspace 5; }
      Mod+Shift+6 { move-column-to-workspace 6; }

      Mod+Minus { set-column-width "-10%"; }
      Mod+Equal { set-column-width "+10%"; }

      // Скриншоты
      Print { screenshot; }
      Mod+Print { screenshot-window; }
      Ctrl+Print { screenshot-screen; }
      Mod+Shift+S { spawn "sh" "-c" "grim -g \"$(slurp)\" - | swappy -f -"; }

      // Выход
      Mod+Shift+Q { quit; }
    }
  '';
}
