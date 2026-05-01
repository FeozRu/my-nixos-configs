{ pkgs, ... }:

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
}
