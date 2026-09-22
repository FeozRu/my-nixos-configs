# Kadr — многодорожечный видеоредактор с GPU-композитингом (Electron + React).
#
# Требования из README и то, как они закрыты здесь:
#   * Node.js >= 20            — только на время сборки (nodejs ниже)
#   * ffmpeg + ffprobe         — в PATH обёртки: импорт, аудиомикс, экспорт
#   * python3 + faster-whisper — в PATH обёртки (withSpeechRecognition)
#   * Claude Code CLI          — claudeCode: панель «Claude» (по умолчанию нет)
#   * сеть (один раз)          — workspace Remotion-фрагментов (~/kadr-fragments)
#                                ставится самим приложением при первом фрагменте
#   * ключ ElevenLabs          — вводится в приложении, хранится вне проекта
#   * python >= 3.11 + torch   — withVoiceDefectDetector: детектор дефектов озвучки
#
# Готовые наборы:
#   kadr       — минимум: редактор + ffmpeg + распознавание речи
#   kadr-full  — то же плюс детектор дефектов озвучки (torch) и CLI claude
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
  # CLI claude для встроенной панели. Передаётся явно, потому что пакет
  # unfree: сам вызов `final.claude-code` требует allowUnfree = true.
  claudeCode ? null,
  # Распознавание речи и авто-субтитры (scripts/transcribe.py через `python3`).
  withSpeechRecognition ? true,
  # Детектор дефектов озвучки: scripts/ttsqc_run.py, ему нужны torch, whisperx,
  # scikit-learn и matplotlib.
  withVoiceDefectDetector ? false,
  # Дополнительные бинарники в PATH обёртки.
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
  # зависимостями (и torch тоже) приезжает готовым. У python312Packages сборки
  # нет, и ctranslate2 под ним тянет torch как тестовую зависимость — это часы
  # сборки C++, ровно то, на чём легко просидеть всю ночь.
  pythonPackages = ps:
    [ ps.faster-whisper ]
    ++ lib.optionals withVoiceDefectDetector [
      ps.torch
      ps.whisperx # CTC-выравниватель (whisperx.alignment)
      ps.scikit-learn
      ps.matplotlib
    ];

  whisperPython = python3.withPackages pythonPackages;

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
  ]
  ++ lib.optional withSpeechRecognition python3ForKadr
  ++ lib.optional (claudeCode != null) claudeCode
  ++ extraRuntimeInputs;

  # ttsqc держит веса и настройки рядом с собой, а пишет в них («Переобучить»
  # перезаписывает scorer.pkl). Store только для чтения, поэтому при первом
  # запуске копируем их в каталог пользователя — иначе и переобучение, и
  # правка [asr] под свою машину упираются в read-only.
  seedScript = lib.optionalString withVoiceDefectDetector ''
    # ttsqc держит веса и настройки рядом с пакетом и пишет в них («Переобучить»
    # перезаписывает scorer.pkl), а store в Nix только для чтения. Копируем их в
    # каталог пользователя и переключаем туда переменные ttsqc: правки там живут
    # дальше и не теряются при обновлении пакета.
    data="''${XDG_DATA_HOME:-$HOME/.local/share}/kadr/ttsqc"
    mkdir -p "$data/models"
    cp -nr @out@/share/kadr/python/models/. "$data/models/" 2>/dev/null || true
    [ -e "$data/ttsqc.toml" ] || cp @out@/share/kadr/python/ttsqc.toml "$data/ttsqc.toml"
    # store отдаёт файлы 0444, а «Переобучить» перезаписывает scorer.pkl на месте
    chmod -R u+w "$data"
    export KADR_TTSQC_MODELS="$data/models"
    export KADR_TTSQC_CONFIG="$data/ttsqc.toml"
  '';
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

  # Сам ttsqc считает CPU штатным режимом («на CPU медленно, но работает»), но
  # на деле редактор всегда передаёт --device cuda, а ни whisperx, ни ctranslate2
  # доступность CUDA не проверяют: выравниватель падает на .to("cuda"), ASR — на
  # compute_type int8_float16. На машине без NVIDIA детектор из-за этого не
  # запускается вообще, поэтому выбор устройства доводим до конца одним патчем.
  # На машине с CUDA обе вставки не срабатывают.
  patches = lib.optional withVoiceDefectDetector ./kadr-cpu-fallback.patch;

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

    makeWrapper ${lib.getExe electron_42} $out/bin/.kadr-wrapped \
      --add-flags $out/share/kadr \
      --set-default ELECTRON_IS_DEV 0 \
      --prefix PATH : ${lib.makeBinPath runtimeInputs} \
      ${lib.optionalString withVoiceDefectDetector "--set KADR_TTSQC_PYTHON ${python3ForKadr}/bin/python3"} \
      ${lib.optionalString (
        extraElectronFlags != [ ]
      ) "--add-flags ${lib.escapeShellArg (lib.concatStringsSep " " extraElectronFlags)}"} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    # $out/bin/kadr — обёртка поверх .kadr-wrapped: подготавливает данные ttsqc.
    # Замены идут в два прохода нарочно: текст, подставленный вместо @seed@,
    # сам содержит @out@, а одна замена его уже не перечитывает.
    install -Dm755 ${./kadr-launcher.sh} $out/bin/kadr
    substituteInPlace $out/bin/kadr --replace-fail '@seed@' ${lib.escapeShellArg seedScript}
    substituteInPlace $out/bin/kadr --subst-var out

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

  passthru = {
    inherit python3ForKadr;
  };

  meta = {
    inherit (packageJson) description;
    homepage = "https://github.com/HelpFreedom/kadr";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "kadr";
  };
}
