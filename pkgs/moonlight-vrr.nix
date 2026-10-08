{ lib
, fetchurl
, makeWrapper
, makeDesktopItem
, appimage-run
, stdenvNoCC
}:

# Кастомный клиент Moonlight — форк Nonary/moonlight-qt (ветка VRR).
# Он нужен, чтобы работать с хостом Vibepollo и получить то, чего нет в
# стоковом moonlight-qt из nixpkgs: VRR-пейсинг, кодек PyroWave и передачу
# микрофона на хост.
#
# Почему AppImage, а не сборка из исходников:
#   * апстрим-форк не собирается из nixpkgs одним override (свои сабмодули,
#     libplacebo/Vulkan-рендер, SDL3, USB-хаптика DualSense);
#   * автор форка публикует готовые AppImage — это путь с минимальным риском.
# Обёртка идёт через `appimage-run` (NixOS FHS+bwrap окружение) — тот же
# приём, что у pkgs/ubports-installer.nix.
#
# Отдельное имя `moonlight-vrr` + собственный .desktop, чтобы не конфликтовать
# со стоковым `moonlight-qt` (внутренний desktop-exec у обоих `moonlight`).
stdenvNoCC.mkDerivation rec {
  pname = "moonlight-vrr";
  version = "6.1.0-vrr18";

  src = fetchurl {
    url = "https://github.com/Nonary/moonlight-qt/releases/download/v${version}/Moonlight-${version}-x86_64.AppImage";
    hash = "sha256-W1mS6w2dZSjKbbg8M9o79svs6g9aj3ubNNzV0i0T9Aw=";
  };

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/Nonary/moonlight-qt/v${version}/app/res/moonlight.svg";
    hash = "sha256-b9DuT+W0qtWrql1cmsuffRvaCrrf6dFYIRXem0uhaqI=";
  };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "Moonlight VRR";
    genericName = "Game streaming client";
    comment = "VRR Moonlight client (Nonary fork) for Vibepollo/Sunshine hosts";
    exec = pname;
    icon = pname;
    categories = [ "Game" "Network" "RemoteAccess" ];
    keywords = [ "moonlight" "vibepollo" "sunshine" "gamestream" "vrr" "microphone" ];
    startupNotify = false;
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/${pname}
    install -m755 "$src" "$out/share/${pname}/${pname}.AppImage"

    # AppImage тащит собственную (не патченную NixOS) libva, поэтому её дефолтный
    # поиск драйверов не видит /run/opengl-driver/lib/dri — задаём путь явно,
    # иначе ломается аппаратное декодирование VA-API.
    # (Vulkan ICD при этом находится сам: appimage-run кладёт
    #  /run/opengl-driver/share в XDG_DATA_DIRS.)
    makeWrapper ${appimage-run}/bin/appimage-run $out/bin/${pname} \
      --add-flags "$out/share/${pname}/${pname}.AppImage" \
      --set LIBVA_DRIVERS_PATH /run/opengl-driver/lib/dri

    install -Dm644 "$icon" "$out/share/icons/hicolor/scalable/apps/${pname}.svg"
    install -Dm644 "${desktopItem}/share/applications/${pname}.desktop" \
      "$out/share/applications/${pname}.desktop"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Moonlight VRR client (Nonary fork) for Vibepollo/Sunshine hosts";
    homepage = "https://github.com/Nonary/moonlight-qt";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
