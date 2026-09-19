{ pkgs, config, ... }:

# Веб-приложения — отдельные окна Chromium в app-режиме (--app=URL): без вкладок,
# адресной строки и меню, как у нативных приложений. App-режим есть только у
# Chromium-движка (Vivaldi флаг --app игнорирует).
#
# У каждого приложения свой --user-data-dir, поэтому это самостоятельный процесс
# со своим WM-классом и своей сессией: логин сохраняется между запусками и не
# пересекается с основным браузером.
let
  # id — это и имя .desktop-файла, и WM-класс окна (--class + startupWMClass),
  # по которому DE находит иконку. Новые приложения добавляй в webApps ниже.
  webApp = { id, name, comment, url, icon ? "applications-internet", categories ? [ "Network" ] }: {
    inherit name comment icon categories;
    exec = "${pkgs.chromium}/bin/chromium --app=${url} --class=${id}"
      + " --user-data-dir=${config.home.homeDirectory}/.local/share/${id}"
      + " --no-first-run --no-default-browser-check";
    terminal = false;
    type = "Application";
    # Произвольные ключи Desktop Entry идут через settings.
    settings.StartupWMClass = id;
  };

  webApps = {
    max-web = webApp {
      id = "max-web";
      name = "MAX";
      comment = "Мессенджер MAX (web.max.ru)";
      url = "https://web.max.ru";
      icon = "MAX"; # иконка мессенджера из Papirus
      categories = [ "Network" "InstantMessaging" ];
    };
  };
in
{
  xdg.desktopEntries = webApps;
}
