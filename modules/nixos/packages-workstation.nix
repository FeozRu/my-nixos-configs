{ pkgs, pkgs-stable, comfyui-nix, ... }:

{
  environment.systemPackages = with pkgs; [
    wget curl git neovim htop
    lazygit ripgrep fd fzf tree-sitter
    unzip unrar p7zip less
    gum screenfetch
    file pciutils usbutils
    smartmontools tcpdump
    ffmpeg-full
    freerdp

    kitty alacritty

    kdePackages.dolphin

    firefox chromium

    telegram-desktop thunderbird
    teamspeak6-client
    vesktop

    vlc obs-studio
    pavucontrol
    yandex-music
    inkscape
    pkgs-stable.krita
    kdePackages.kdenlive
    kdePackages.gwenview shotwell kdePackages.elisa

    comfyui-nix.packages.${pkgs.stdenv.hostPlatform.system}.cuda
    qwen-code
    claude-code

    onlyoffice-desktopeditors obsidian

    vscode-fhs
    code-cursor google-antigravity
    dbeaver-bin filezilla putty
    podman-compose android-studio
    jetbrains.idea-oss
    jetbrains.pycharm-oss
    lmstudio
    bruno
    pkgs.nodejs

    dotnet-sdk_8 jdk17 jdk21
    flutter
    python3

    clang cmake ninja pkg-config gnumake gcc

    android-tools

    kdePackages.ark kdePackages.kate kdePackages.konsole kdePackages.kdeconnect-kde
    kdePackages.kalk kdePackages.krdc kdePackages.kpat

    wireguard-tools networkmanager-openvpn

    gparted btrfs-progs efibootmgr os-prober

    qemu_kvm gnome-boxes

    waybar swaynotificationcenter fuzzel awww xwayland-satellite
    wl-clipboard grim slurp satty
    networkmanagerapplet blueman udiskie
    nwg-look hyprlock
    kdePackages.polkit-kde-agent-1

    lutris heroic prismlauncher
    gamescope wine winetricks
    pkgs.nur.repos.forkprince.hytale
    (pkgs.writeShellScriptBin "innoextract" ''
      if [[ "$1" == "--version" ]]; then
        ${pkgs.innoextract}/bin/innoextract "$@" | sed 's/-dev//g'
      else
        exec ${pkgs.innoextract}/bin/innoextract "$@"
      fi
    '')
    (pkgs.writeShellScriptBin "steamtinkerlaunch" ''
      exec ${pkgs.steam-run}/bin/steam-run bash -c '
        /home/seevser/.config/steamtinkerlaunch/custom/nxm-listener.sh &
        LPID=$!
        ${pkgs.steamtinkerlaunch}/bin/steamtinkerlaunch "$@"
        kill $LPID 2>/dev/null
      ' -- "steamtinkerlaunch" "$@"
    '')
    xdotool yad

    (pkgs.writeShellScriptBin "niri-screenshot-edit" ''
      FILE="/tmp/screenshot-$(date +%s).png"
      niri msg action screenshot --path "$FILE"
      for i in {1..600}; do
        if [ -s "$FILE" ]; then
           sleep 0.2
           ${pkgs.satty}/bin/satty --filename "$FILE" --copy-command "${pkgs.wl-clipboard}/bin/wl-copy" --output-filename "$HOME/Pictures/Screenshots/Screenshot_$(date +%Y%m%d_%H%M%S).png"
           rm -f "$FILE"
           exit 0
        fi
        sleep 0.1
      done
      rm -f "$FILE"
    '')

    openmw portmod

    bitwarden-desktop keepassxc qbittorrent
    kooha qpwgraph
    nvidia-vaapi-driver lact
  ];
}
