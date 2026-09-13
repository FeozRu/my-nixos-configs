{ pkgs, lib, inputs, ... }:

let
  # Vivaldi — Chromium-движок, Zen — Firefox-движок, поэтому профиль целиком
  # перенести нельзя. Расширения переустанавливаем декларативно: слева GUID
  # аддона на addons.mozilla.org, справа его slug (плюс в комментарии —
  # Chrome Web Store ID из профиля Vivaldi, откуда взят аналог).
  extensions = [
    { id = "uBlock0@raymondhill.net";                     slug = "ublock-origin"; }             # cjpalhdlnbpafiamejdnhcphjbkeiagm
    { id = "{446900e4-71c2-419f-a6a7-df9c091e268b}";     slug = "bitwarden-password-manager"; } # nngceckbapebfimnlniiiahkandclblb
    { id = "addon@darkreader.org";                       slug = "darkreader"; }                 # eimadpbcbfnmbkopoojfekhnkhdbieeh
    { id = "firefox@tampermonkey.net";                   slug = "tampermonkey"; }               # dhdgffkkebhmkfjojejmpbldmpobfkfo
    { id = "sponsorBlocker@ajay.app";                    slug = "sponsorblock"; }               # mnjggcdmjocbbbhaepdhchncahnbgone
    { id = "frankerfacez@frankerfacez.com";              slug = "frankerfacez"; }               # jgnjpfcdneiofkjkidlokfipfaignogj (Nightly -> обычный FFZ)
    { id = "{5efceaa7-f3a2-4e59-a54b-85319448e305}";     slug = "immersive-translate"; }        # bpoadfkcbjbfhfodiogcnhhhpibjhbnh
    { id = "enhancerforyoutube@maximerf.addons.mozilla.org"; slug = "enhancer-for-youtube"; }   # ponfpcnoihfmfllpaingbgckeeldkhle
  ];

  extensionPolicies = lib.listToAttrs (map (ext: lib.nameValuePair ext.id {
    installation_mode = "normal_installed";
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/${ext.slug}/latest.xpi";
  }) extensions);
in
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;

    # KeePassXC — как было в Vivaldi.
    nativeMessagingHosts = [ pkgs.keepassxc ];

    # Расширения ставятся через policies.json. Пароли отдельно переносить не
    # нужно: в Vivaldi они не хранились, а жили в Bitwarden/KeePassXC.
    policies.ExtensionSettings = extensionPolicies;

    profiles.default = {
      # Поиск по умолчанию — Google (так было в Vivaldi).
      search = {
        force = true;
        default = "google";
      };

      settings = {
        # DRM/Widevine. Официальный FAQ Zen («Why can't Zen Browser play
        # DRM-protected content?») противоречив: текст говорит, что Widevine
        # нет вообще, а пометка «This only affects Microsoft Windows and
        # MacOS» — правда. На Linux CDM от Google ставится в Firefox-движок,
        # достаточно разрешить EME и видимость widevinecdm.
        "media.eme.enabled" = true;
        "media.gmp-widevinecdm.visible" = true;
        "media.gmp-widevinecdm.enabled" = true;
        "media.gmp-manager.updateEnabled" = true;

        # Мелкие удобства (значения — дефолты, меняются в браузере).
        "browser.aboutConfig.showWarning" = false;
        "browser.tabs.warnOnClose" = false;
      };
    };
  };
}
