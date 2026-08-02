{ pkgs, lib, ... }:

{
  programs.vivaldi = {
    enable = true;
    package = pkgs.vivaldi;

    # ID = последний сегмент URL в Chrome Web Store, 32 символа латиницы
    extensions = [
      "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
      "nngceckbapebfimnlniihkifadpnglme" # Bitwarden
    ];

    nativeMessagingHosts = [ pkgs.keepassxc ];
  };

  # Home Manager теперь линкует NativeMessagingHosts recursively (каталог + json),
  # а раньше это была одна симлинка на директорию в nix store. Старая симлинка
  # блокирует mkdir при активации («Файл существует»).
  home.activation.vivaldiNativeMessagingHosts = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    nmh="$HOME/.config/vivaldi/NativeMessagingHosts"
    if [ -L "$nmh" ]; then
      $DRY_RUN_CMD rm -f "$nmh"
    fi
  '';
}
