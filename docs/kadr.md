# Kadr (видеоредактор)

Пакет собирается из исходников `github:HelpFreedom/kadr` — сам репозиторий
подключён flake-инпутом `kadr` (с `flake = false`, т.к. своего `flake.nix` у
проекта нет). Рецепт: `pkgs/kadr.nix`, подключён оверлеем в `flake.nix` и
добавлен в `modules/nixos/packages.nix`.

## Обновление

```bash
nix flake update kadr                    # подтянуть свежий main
sudo nixos-rebuild switch --flake .#nixos
```

Хеши руками править не нужно: зависимости ставятся через `importNpmLock`
прямо из `package-lock.json` (без `npmDepsHash`), а версия пакета берётся из
`package.json` самих исходников.

Запуск без пересборки системы: `nix run .#kadr`.

## Что уже в комплекте

| Что | Откуда |
|-----|--------|
| `ffmpeg` + `ffprobe` | PATH обёртки — импорт, аудиомикс, экспорт |
| `python3` + `faster-whisper` | PATH обёртки — распознавание речи, авто-субтитры |
| `node` / `npm` / `npx` | workspace Remotion-фрагментов (`~/kadr-fragments`) |
| `gdbus` | XDG-перетаскивания из песочных приложений |

## Чего нет намеренно

* **Claude Code CLI** — панель «Claude» просто не найдёт `claude` в PATH.
* **torch** (детектор дефектов озвучки) — многогигабайтная сборка. Путь к
  своему интерпретатору задаётся в настройках озвучки либо через
  `extraRuntimeInputs`:

  ```nix
  pkgs.kadr.override {
    extraRuntimeInputs = [ (import ./my-python-with-torch.nix { inherit pkgs; }) ];
  }
  ```

## Первый запуск

* Модели whisper (~1 ГБ) скачиваются при первом распознавании.
* Первый Remotion-фрагмент ставит workspace (~150 МБ) из сети.
* Ключ ElevenLabs вводится в приложении и хранится вне проекта.

## Мелочи

При старте в логе видно `'--ozone-platform=wayland' is not compatible with
Vulkan` — это информационное сообщение Chromium при Wayland + доступном
Vulkan, на работу WebGL-композитинга не влияет. Лишние ключи Electron можно
доклеить через `extraElectronFlags` того же `override`.

Дополнительные аргументы пакета: `withSpeechRecognition`, `extraRuntimeInputs`,
`extraElectronFlags` — см. шапку `pkgs/kadr.nix`.
