# Kadr — многодорожечный видеоредактор с GPU-композитингом (Electron + React).
#
# Требования из README и то, как они закрыты здесь:
#   * Node.js >= 20            — только на время сборки (nodejs ниже)
#   * ffmpeg + ffprobe         — в PATH обёртки: импорт, аудиомикс, экспорт
#   * python3 + faster-whisper — в PATH обёртки (withSpeechRecognition)
#   * Claude Code CLI          — НЕ ставится: панель «Claude» просто не найдёт
#                                `claude` в PATH и останется выключенной
#   * сеть (один раз)          — workspace Remotion-фрагментов (~/kadr-fragments)
#                                ставится самим приложением при первом фрагменте
#   * ключ ElevenLabs          — вводится в приложении, хранится вне проекта
#   * python >= 3.11 + torch   — не тянем (многогигабайтный torch); путь к своему
#                                интерпретатору задаётся в настройках озвучки
{
  lib,
  stdenv,
  buildNpmPackage,
  copyDesktopItems,
  electron_42,
  ffmpeg,
  glib,
  importNpmLock,
  makeDesktopItem,
  makeWrapper,
  node-gyp,
  nodejs,
  pkg-config,
  python3,
  runCommand,
  src,
  # Распознавание речи и авто-субтитры (scripts/transcribe.py через `python3`).
  # Без них редактор работает, но эти кнопки честно откажутся.
  withSpeechRecognition ? true,
  # Дополнительные бинарники в PATH обёртки (например, свой python с torch для
  # детектора дефектов озвучки).
  extraRuntimeInputs ? [ ],
  # Дополнительные ключи Electron/Chromium, например
  # [ "--enable-features=VaapiVideoDecoder" ].
  extraElectronFlags ? [ ],
}:

let
  # Версия берётся из исходников, так что `nix flake update` её и обновит.
  packageJson = builtins.fromJSON (builtins.readFile (src + "/package.json"));

  # `python3` из nixpkgs (сейчас 3.14) — не случайный выбор: только эта ветка
  # python-пакетов реально собрана в cache.nixos.org, так что faster-whisper с
  # зависимостями приезжает готовым. У python312Packages сборки нет, и ctranslate2
  # под ним тянет torch как тестовую зависимость — это часы сборки C++.
  whisperPython = python3.withPackages (ps: [ ps.faster-whisper ]);

  # Приложение зовёт голый `python3` (scripts/transcribe.py), поэтому
  # интерпретатор должен быть доступен ровно под этим именем.
  python3ForKadr = runCommand "kadr-python3" { } ''
    mkdir -p $out/bin
    if [ -x ${whisperPython}/bin/python3 ]; then
      ln -s ${whisperPython}/bin/python3 $out/bin/python3
    else
      for py in ${whisperPython}/bin/python3.*; do
        ln -s "$py" $out/bin/python3
        break
      done
    fi
  '';

  # `npm`/`npx` нужны для workspace Remotion-фрагментов, `node` — для MCP-моста,
  # `gdbus` — для XDG-перетаскиваний из песочных приложений.
  runtimeInputs = [
    ffmpeg
    glib
    nodejs
  ] ++ lib.optional withSpeechRecognition python3ForKadr ++ extraRuntimeInputs;
in
buildNpmPackage rec {
  pname = "kadr";
  version = packageJson.version;

  inherit src;

  # importNpmLock ставит зависимости прямо из store по integrity-хешам
  # package-lock.json — без npmDepsHash, который пришлось бы руками править
  # после каждой смены lock-файла. С ним `nix flake update kadr` — это всё,
  # что нужно для обновления редактора.
  npmDeps = importNpmLock { npmRoot = src; };
  npmConfigHook = importNpmLock.npmConfigHook;

  # `npm rebuild` здесь бесполезен: node-pty всё равно пересобирается ниже
  # против ABI Electron, а с --ignore-scripts он не лезет писать в store.
  npmRebuildFlags = [ "--ignore-scripts" ];

  env = {
    # devDependency `electron` не должен пытаться скачать свой бинарник
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    NODE_OPTIONS = "--max-old-space-size=4096";
  };

  nativeBuildInputs = [
    copyDesktopItems
    makeWrapper
    node-gyp
    nodejs
    pkg-config
    python3
    stdenv.cc # node-gyp нужен компилятор
  ];

  buildPhase = ''
    runHook preBuild

    # node-pty — нативный аддон, и собранный main-процесс требует его в рантайме,
    # значит он обязан совпасть по ABI с Electron, а не с тем Node, которым
    # ставились зависимости. Заголовки кладёт рядом со своим бинарником
    # nixpkgs — качать ничего не нужно. node-gyp пишет build/ рядом с исходником,
    # а запись в node_modules — это симлинк в read-only store, так что сначала
    # делаем себе writable-копию (cp -L разыменует симлинк, если он там).
    rm -rf pty-src
    cp -rL node_modules/node-pty pty-src
    rm -rf node_modules/node-pty
    mv pty-src node_modules/node-pty
    chmod -R u+w node_modules/node-pty
    (
      cd node_modules/node-pty
      HOME="$(mktemp -d)" node-gyp rebuild --nodedir=${electron_42.headers}
    )

    npm run build

    # Рендерер уезжает в бандл, main требует только рантайм-зависимости — так что
    # компилятор (vite/typescript/electron) в замыкании не нужен.
    npm prune --omit=dev

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Приложение ищет свои скрипты и питон-модули через app.getAppPath(), так что
    # в $out/share/kadr кладётся всё дерево, а не только out/.
    mkdir -p $out/share/kadr
    cp -a . $out/share/kadr

    # В рантайме не читается ничем — только раздувает замыкание.
    rm -f $out/share/kadr/demo.gif
    rm -f $out/share/kadr/scripts/e2e*.mjs

    install -Dm644 ${./kadr.svg} $out/share/icons/hicolor/scalable/apps/kadr.svg

    makeWrapper ${lib.getExe electron_42} $out/bin/kadr \
      --add-flags $out/share/kadr \
      --set-default ELECTRON_IS_DEV 0 \
      --prefix PATH : ${lib.makeBinPath runtimeInputs} \
      ${lib.optionalString (
        extraElectronFlags != [ ]
      ) "--add-flags ${lib.escapeShellArg (lib.concatStringsSep " " extraElectronFlags)}"} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "kadr";
      desktopName = "Kadr";
      exec = "kadr %U";
      icon = "kadr";
      comment = packageJson.description;
      categories = [
        "AudioVideo"
        "Video"
      ];
      startupWMClass = "kadr";
    })
  ];

  meta = {
    inherit (packageJson) description;
    homepage = "https://github.com/HelpFreedom/kadr";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "kadr";
  };
}
