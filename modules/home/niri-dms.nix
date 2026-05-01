{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.dms.homeModules.dank-material-shell
  ];

  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true;
  };

  xdg.configFile."niri/config.kdl".text = ''
    prefer-no-csd

    spawn-at-startup "xwayland-satellite"
    spawn-at-startup "awww-daemon"
    spawn-at-startup "udiskie"
    // Polkit Agent из KDE
    spawn-at-startup "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1"

    include "dms/alttab.kdl"
    include "dms/binds.kdl"
    include "dms/colors.kdl"
    include "dms/cursor.kdl"
    include "dms/layout.kdl"
    include "dms/outputs.kdl"
    include "dms/windowrules.kdl"
    include "dms/wpblur.kdl"

    input {
      focus-follows-mouse max-scroll-amount="1%"
      keyboard {
        xkb {
          layout "us,ru"
          options "grp:caps_toggle"
        }
      }
      mouse {
        accel-profile "flat"
      }
    }

    gestures {
      hot-corners {
        off
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

    window-rule {
      match app-id="com.gabm.satty"
      open-floating true
    }

    window-rule {
      match app-id="blueman-manager"
      open-floating true
    }

    window-rule {
      match app-id="org.pulseaudio.pavucontrol"
      open-floating true
    }

    binds {
      Mod+Shift+Slash { show-hotkey-overlay; }
      Mod+F1 { show-hotkey-overlay; }

      Mod+Escape { toggle-keyboard-shortcuts-inhibit; }

      Mod+T { spawn "kitty"; }

      Mod+Q { close-window; }

      Mod+Left  { focus-column-left; }
      Mod+Up    { maximize-column; }
      Mod+Shift+Up { maximize-window-to-edges; }
      Mod+Shift+F { fullscreen-window; }
      Mod+Down  { toggle-window-floating; }
      Mod+Right { focus-column-right; }

      Mod+Ctrl+Left  { move-column-left; }
      Mod+Ctrl+Right { move-column-right; }

      Mod+Page_Down { focus-workspace-down; }
      Mod+Page_Up   { focus-workspace-up; }

      Mod+Shift+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
      Mod+Shift+WheelScrollUp   cooldown-ms=150 { focus-workspace-up; }
      Mod+Ctrl+WheelScrollDown  cooldown-ms=150 { move-column-to-workspace-down; }
      Mod+Ctrl+WheelScrollUp    cooldown-ms=150 { move-column-to-workspace-up; }
      Mod+WheelScrollUp         cooldown-ms=150 { focus-column-left; }
      Mod+WheelScrollDown       cooldown-ms=150 { focus-column-right; }

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

      Mod+Comma { consume-or-expel-window-left; }
      Mod+Period { consume-or-expel-window-right; }

      Mod+Minus { set-column-width "-10%"; }
      Mod+Equal { set-column-width "+10%"; }
      Mod+Alt+Minus { set-window-height "-10%"; }
      Mod+Alt+Equal { set-window-height "+10%"; }

      Print { spawn "dms" "ipc" "call" "niri" "screenshot"; }
      Mod+Print { spawn "dms" "ipc" "call" "niri" "screenshotWindow"; }
      Ctrl+Print { spawn "dms" "ipc" "call" "niri" "screenshotScreen"; }
      Mod+Shift+S { spawn "niri-screenshot-edit"; }

      Mod+Shift+Q { quit; }
    }
  '';
}
