{ pkgs }:

# Кастомный клиент Moonlight — форк Nonary/moonlight-qt (ветка VRR) для Vibepollo:
# VRR-пейсинг, кодек PyroWave, передача микрофона.
#
# Собираем из ИСХОДНИКОВ, а не из AppImage: у AppImage нет плагина Wayland
# (только xcb), поэтому клиент работал под X11 и не мог перехватывать системные
# клавиши (Mod, Alt+Tab) через keyboard-shortcuts-inhibit. Сборка на nixpkgs-Qt
# (6.11) + qtwayland даёт нативный Wayland, а конфиг
# (~/.config/Moonlight Game Streaming Project) общий со стоковым moonlight-qt —
# спаривание с хостом и настройки (capturesyskeys и т.п.) сохраняются.
#
# База — pkgkgs.moonlight-qt: у этой деривации уже есть все нужные зависимости
# (qt6.qtwayland, libplacebo, vulkan-headers, ffmpeg_8, libva, libvdpau, wayland,
# SDL2, libopus…), форк отличается только исходником (добавляется подкаталог
# pyrowave и обновлённые сабмодули).
let
  desktopItem = pkgs.makeDesktopItem {
    name = "moonlight-vrr";
    desktopName = "Moonlight VRR";
    genericName = "Game streaming client";
    comment = "VRR Moonlight client (Nonary fork) for Vibepollo/Sunshine hosts";
    exec = "moonlight-vrr";
    icon = "moonlight-vrr";
    categories = [ "Game" "Network" "RemoteAccess" ];
    keywords = [ "moonlight" "vibepollo" "sunshine" "gamestream" "vrr" "microphone" ];
    startupNotify = false;
  };
in
(pkgs.moonlight-qt.overrideAttrs (old: rec {
  pname = "moonlight-vrr";
  version = "6.1.0-vrr18";

  src = pkgs.fetchFromGitHub {
    owner = "Nonary";
    repo = "moonlight-qt";
    tag = "v${version}";
    hash = "sha256-Msv+rIv6KMuqa8tMP9yizpI8BdH2pishsHgJ4tKE2nw=";
    fetchSubmodules = true;
  };

  # Патч апстрима (сборка под Xcode < 14) к форку не относится.
  patches = [ ];

  postInstall = (old.postInstall or "") + ''
    # Переименовываем выводы, чтобы не пересекаться со стоковым moonlight-qt в
    # systemPackages (иначе коллизия одинаковых путей в профиле).
    mv $out/bin/moonlight $out/bin/moonlight-vrr

    rm -f $out/share/applications/com.moonlight_stream.Moonlight.desktop
    cp ${desktopItem}/share/applications/moonlight-vrr.desktop \
       $out/share/applications/moonlight-vrr.desktop

    mv $out/share/icons/hicolor/scalable/apps/moonlight.svg \
       $out/share/icons/hicolor/scalable/apps/moonlight-vrr.svg

    mv $out/share/metainfo/com.moonlight_stream.Moonlight.appdata.xml \
       $out/share/metainfo/moonlight-vrr.appdata.xml
  '';

  meta = old.meta // {
    description = "Moonlight VRR client (Nonary fork) for Vibepollo/Sunshine hosts";
    mainProgram = "moonlight-vrr";
  };
}))
