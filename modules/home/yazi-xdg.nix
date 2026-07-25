{ config, pkgs, lib, ... }:

let
  yaziOpenWith = pkgs.writeShellScriptBin "yazi-open-with" ''
    set -euo pipefail

    if [ "$#" -lt 1 ]; then
      echo "usage: yazi-open-with FILE..." >&2
      exit 1
    fi

    files=("$@")
    mime="$(${pkgs.xdg-utils}/bin/xdg-mime query filetype "''${files[0]}" 2>/dev/null || true)"
    if [ -z "''${mime:-}" ]; then
      mime="$(${pkgs.file}/bin/file --brief --mime-type "''${files[0]}" 2>/dev/null || true)"
    fi
    major=""
    if [ -n "''${mime:-}" ]; then
      major="''${mime%%/*}"
    fi

    list_apps() {
      local mode="$1"
      local data_dirs="''${XDG_DATA_HOME:-$HOME/.local/share}:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
      local old_ifs="$IFS"
      IFS=':'
      # shellcheck disable=SC2086
      set -- $data_dirs
      IFS="$old_ifs"

      local -A seen=()
      local dir appdir desktop id name mtypes ok t prefix
      for dir in "$@"; do
        appdir="$dir/applications"
        [ -d "$appdir" ] || continue
        for desktop in "$appdir"/*.desktop; do
          [ -f "$desktop" ] || continue
          if grep -qE '^(NoDisplay|Hidden)=true' "$desktop" 2>/dev/null; then
            continue
          fi
          id="$(basename "$desktop")"
          [ -n "''${seen[$id]:-}" ] && continue

          name="$(grep -m1 -E '^Name=' "$desktop" 2>/dev/null | head -n1 | cut -d= -f2- || true)"
          [ -n "$name" ] || name="$id"

          if [ "$mode" = matching ] && [ -n "''${mime:-}" ]; then
            mtypes="$(grep -m1 '^MimeType=' "$desktop" 2>/dev/null | cut -d= -f2- || true)"
            [ -n "$mtypes" ] || continue
            ok=0
            old_ifs="$IFS"
            IFS=';'
            for t in $mtypes; do
              IFS="$old_ifs"
              [ -n "$t" ] || continue
              if [ "$t" = "$mime" ] || [ "$t" = "*/*" ]; then
                ok=1
                break
              fi
              if [ -n "$major" ] && [ "$t" = "$major/*" ]; then
                ok=1
                break
              fi
              case "$t" in
                */*)
                  prefix="''${t%/\*}"
                  if [ "$prefix" != "$t" ] && [ "''${mime#"$prefix"/}" != "$mime" ]; then
                    ok=1
                    break
                  fi
                  ;;
              esac
            done
            IFS="$old_ifs"
            [ "$ok" -eq 1 ] || continue
          fi

          seen[$id]=1
          printf '%s\t%s\n' "$name" "$desktop"
        done
      done
    }

    pick_and_launch() {
      local mode="$1"
      local lines names idx desktop
      mapfile -t lines < <(list_apps "$mode" | LC_ALL=C sort -t $'\t' -k1,1)

      if [ "$mode" = matching ]; then
        lines+=("All applications…"$'\t'"__ALL__")
      fi

      if [ "''${#lines[@]}" -eq 0 ]; then
        echo "No applications found" >&2
        exit 1
      fi

      names=()
      local line
      for line in "''${lines[@]}"; do
        names+=("''${line%%$'\t'*}")
      done

      idx="$(printf '%s\n' "''${names[@]}" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --index --prompt="Open with: " --width=60 || true)"
      if [ -z "''${idx:-}" ]; then
        exit 0
      fi

      desktop="''${lines[$idx]#*$'\t'}"
      if [ "$desktop" = "__ALL__" ]; then
        pick_and_launch all
        return
      fi

      ${pkgs.glib.bin}/bin/gio launch "$desktop" "''${files[@]}" >/dev/null 2>&1 &
      disown || true
    }

    if [ -n "''${mime:-}" ]; then
      pick_and_launch matching
    else
      pick_and_launch all
    fi
  '';
in
{
  xdg.enable = true;

  home.packages = [ yaziOpenWith ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
    "inode/directory" = "yazi.desktop";

    "x-scheme-handler/http" = "vivaldi-stable.desktop";
    "x-scheme-handler/https" = "vivaldi-stable.desktop";
    "text/html" = "vivaldi-stable.desktop";

    "x-scheme-handler/mailto" = "thunderbird.desktop";
    "message/rfc822" = "thunderbird.desktop";

    "x-scheme-handler/discord" = "vesktop.desktop";

    "x-scheme-handler/bitwarden" = "bitwarden.desktop";

    "x-scheme-handler/ss" = "Outline.desktop";
    "x-scheme-handler/ssconf" = "Outline.desktop";
    };
  };

  xdg.desktopEntries.yazi = {
    name = "Yazi";
    genericName = "File Manager";
    exec = "kitty -e yazi %u";
    icon = "system-file-manager";
    terminal = false;
    categories = [ "System" "FileTools" "FileManager" ];
    mimeType = [ "inode/directory" ];
  };

  xdg.configFile = {
    "yazi/yazi.toml".text = ''
      [preview]
      wrap = "yes"
      max_width  = 2000
      max_height = 2000
      image_filter = "triangle"

      [[plugin.prepend_previewers]]
      url = "*.md"
      run = 'faster-piper -- mdcat --columns $w "$1"'

      [[plugin.prepend_previewers]]
      url = "*.mdx"
      run = 'faster-piper -- mdcat --columns $w "$1"'
    '';

    "yazi/keymap.toml".text = ''
      [[mgr.prepend_keymap]]
      on   = "T"
      run  = "plugin toggle-pane max-preview"
      desc = "Maximize or restore the preview pane"

      [[mgr.prepend_keymap]]
      on   = "\\"
      run  = "plugin actions -- hovered"
      desc = "Actions menu (hovered file)"

      [[mgr.prepend_keymap]]
      on   = "|"
      run  = "plugin actions -- selected"
      desc = "Actions menu (selected files)"
    '';

    "yazi/plugins/actions.yazi/main.lua".source =
      ./yazi/plugins/actions.yazi/main.lua;
  };

  home.activation.yaziMimeCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CACHE="$HOME/.local/share/applications/mimeinfo.cache"
    mkdir -p "$(dirname "$CACHE")"
    if [ ! -f "$CACHE" ]; then
      printf '[MIME Cache]\n' > "$CACHE"
    fi
    if grep -q '^inode/directory=' "$CACHE" 2>/dev/null; then
      sed -i 's|^inode/directory=.*|inode/directory=yazi.desktop;|' "$CACHE"
    else
      printf 'inode/directory=yazi.desktop;\n' >> "$CACHE"
    fi
  '';
}
