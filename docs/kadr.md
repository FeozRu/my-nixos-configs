# Kadr (видеоредактор)

Пакет собирается из исходников `github:HelpFreedom/kadr` — сам репозиторий
подключён flake-инпутом `kadr` (с `flake = false`, т.к. своего `flake.nix` у
проекта нет). Рецепт: `pkgs/kadr.nix`, подключён оверлеем в `flake.nix` и
добавлен в `modules/nixos/packages.nix`.

Два набора:

| Пакет | Что внутри | Кому |
|-------|------------|------|
| `kadr` | редактор + ffmpeg + распознавание речи (faster-whisper) | обычная работа |
| `kadr-full` | плюс детектор дефектов озвучки (torch, whisperx, sklearn, matplotlib) и CLI `claude` | озвучка и панель «Claude» |

Сейчас в системе стоит `kadr-full`; поменять — одна строка в
`modules/nixos/packages.nix`.

## Обновление

```bash
nix flake update kadr                    # подтянуть свежий main
sudo nixos-rebuild switch --flake .#nixos
```

Хеши руками править не нужно: зависимости ставятся через `importNpmLock`
прямо из `package-lock.json` (без `npmDepsHash`), а версия пакета берётся из
`package.json` самих исходников.

Запуск без пересборки системы: `nix run .#kadr` или `nix run .#kadr-full`.

## Почему сборка быстрая

Python-окружение берётся из ветки `python3` (сейчас 3.14). Это принципиально:
только она собирается в Hydra и лежит в `cache.nixos.org`, поэтому
`faster-whisper`, `torch`, `whisperx` и остальное **скачиваются**, а не
собираются. `python312Packages` в кэше нет, и `ctranslate2` под ним тянет
`torch` как тестовую зависимость — это компиляция C++ на несколько часов.
Зеркало искать не нужно: кэш nixpkgs и есть это зеркало.

`torch-bin` (готовое колесо с PyPI) в nixpkgs тоже есть, но он unfree и
не нужен: исходный `torch` и так приезжает собранным.

## Что в PATH

| Что | Зачем |
|-----|-------|
| `ffmpeg` + `ffprobe` | импорт, аудиомикс, экспорт |
| `node` / `npm` / `npx` | workspace Remotion-фрагментов (`~/kadr-fragments`) |
| `gdbus` | XDG-перетаскивания из песочных приложений |
| `python3` (+ faster-whisper) | распознавание речи, авто-субтитры |
| `claude` | только в `kadr-full`; панель «Claude» (пакет unfree — нужен `allowUnfree`) |

## Данные ttsqc (детектор дефектов озвучки)

ttsqc держит веса и настройки рядом с собой и **пишет в них** («Переобучить»
перезаписывает `scorer.pkl`), а store в Nix только для чтения. Поэтому
`$out/bin/kadr` — обёртка, которая при первом запуске копирует их в
`~/.local/share/kadr/ttsqc/` и переключает туда `KADR_TTSQC_MODELS` и
`KADR_TTSQC_CONFIG`. Ваши правки там живут и не теряются при обновлении пакета.

## Известное: CUDA

Редактор всегда передаёт детектору `--device cuda`, а whisperx и ctranslate2
доступность CUDA не проверяют: выравниватель падает на `.to("cuda")`, ASR — на
`compute_type = "int8_float16"`. На машине без NVIDIA это означало, что детектор
не запускается вообще. Патч `pkgs/kadr-cpu-fallback.patch` добавляет проверку
`torch.cuda.is_available()` в оба места; на машине с CUDA он не срабатывает.

Если после `nix flake update kadr` патч перестанет применяться (upstream правит
те же функции), сборка честно упадёт с ошибкой `patch` — либо обновите патч,
либо уберите строку `patches = ...` в `pkgs/kadr.nix`.

Порт системы и прочие калибровки — в `~/.local/share/kadr/ttsqc/ttsqc.toml`.

## Про PR #5 (devShell для NixOS)

В апстриме есть PR #5 с `flake.nix` для `npm run dev` и пятью пунктами проблем. Как они
касаются этой сборки (production, не dev):

| Пункт | Здесь |
|-------|-------|
| 1. node-pty без тулчейна | закрыто структурно: `stdenv.cc`/`node-gyp` при сборке, аддон собирается под ABI Electron |
| 2. нет бинарника `node_modules/electron` | закрыто структурно: редактор запускается бинарником Electron из nixpkgs, npm-постинсталл выключен (`ELECTRON_SKIP_BINARY_DOWNLOAD`) |
| 3. пустое серое окно на Wayland/Ozone | **не воспроизводится**: с нашим `--ozone-platform-hint=auto` интерфейс рисуется (проверено через CDP: виден RU-интерфейс, `#root` заполнен) |
| 4. preload вычищается tree-shaking'ом | **не воспроизводится**: `out/preload/preload.js` — 11.5 КБ, `window.kadr` отдаёт 85 методов, `fileUrl('/etc/hostname')` → `kadr://media/…?t=<48 hex>` |
| 5. `ERR_NETWORK_CHANGED` | только dev-сервер, у production-сборки его нет (`loadFile`) |

Пункты 3 и 4 стоит перепроверить перед тем, как доверять им в issue: возможно, они
проявляются только в `npm run dev`, а в `electron-vite build` бандлер ведёт себя иначе.

Пункт 5 в PR закрыт двумя правками, и верна из них только первая. `host: '127.0.0.1'`
в `electron.vite.config.ts` — настоящий фикс (резолв `localhost` идёт IPv6-first).
А `setTimeout(() => win.loadURL(...), 1500)` в `main.ts` — не «максимум ожидания»:
это фиксированная задержка без `clearTimeout`/`Promise.race`, то есть ждать нечего и
нельзя кончить раньше. Ждать, кстати, и не нужно: `electron-vite` делает
`await server.listen()` и выставляет `ELECTRON_RENDERER_URL` **до** `startElectron`,
так что к моменту `createWindow()` сервер уже слушает. Задержка при этом задевает и
ветку `loadFile` — то есть видна на любом запуске как пустое окно цвета
`backgroundColor`, потому что окно создаётся с дефолтным `show: true` и без
`ready-to-show`. Если в PR понадобится «ждать, но не дольше» — это `did-fail-load`
с повторами, а не сон.

Если серое окно всё-таки случится (другой компоузер), рабочий обход:

```nix
pkgs.kadr-full.override { extraElectronFlags = [ "--ozone-platform=x11" ]; }
```

Ключ идёт после `--ozone-platform-hint`, поэтому перебивает его — проверено.

## Первый запуск

* Модели whisper (~1 ГБ) скачиваются при первом распознавании.
* Первый Remotion-фрагмент ставит workspace (~150 МБ) из сети.
* Детектор скачивает выравниватель с HuggingFace и данные NLTK при первом
  разборе.
* Ключ ElevenLabs вводится в приложении и хранится вне проекта.

## Мелочи

При старте в логе видно `'--ozone-platform=wayland' is not compatible with
Vulkan` — информационное сообщение Chromium при Wayland + доступном Vulkan, на
WebGL-композитинг не влияет. Лишние ключи Electron можно доклеить через
`extraElectronFlags`.

Аргументы пакета: `claudeCode`, `withSpeechRecognition`,
`withVoiceDefectDetector`, `extraRuntimeInputs`, `extraElectronFlags` — см.
шапку `pkgs/kadr.nix`.
