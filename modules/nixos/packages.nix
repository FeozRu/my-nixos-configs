{ pkgs, pkgs-stable, ... }:

{
  environment.systemPackages = with pkgs; [
    wget curl git neovim htop
    lazygit ripgrep fd fzf tree-sitter
    unzip p7zip less
    gum
    file pciutils usbutils

    kitty alacritty

    kdePackages.dolphin

    firefox chromium

    telegram-desktop thunderbird
    vesktop

    ventoy

    vlc
    pavucontrol
    inkscape
    pkgs-stable.krita
    kdePackages.gwenview shotwell kdePackages.elisa

    onlyoffice-desktopeditors obsidian

    vscode-fhs
    code-cursor google-antigravity
    dbeaver-bin
    bruno
    pkgs.nodejs

    dotnet-sdk_8 jdk21
    python3

    clang cmake ninja pkg-config gnumake gcc

    kdePackages.ark kdePackages.kate kdePackages.konsole kdePackages.kdeconnect-kde
    kdePackages.kalk kdePackages.kpat

    wireguard-tools networkmanager-openvpn

    gparted btrfs-progs efibootmgr

    waybar swaynotificationcenter fuzzel awww xwayland-satellite
    wl-clipboard grim slurp satty
    networkmanagerapplet blueman udiskie
    nwg-look hyprlock
    kdePackages.polkit-kde-agent-1

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

    bitwarden-desktop keepassxc

    moonlight-qt
  ];
}
