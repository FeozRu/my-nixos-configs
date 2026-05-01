{ config, pkgs, lib, ... }:

{
  xdg.enable = true;

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
    '';
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
