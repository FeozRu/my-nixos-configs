# Переход на NixOS с Arch Linux

## Содержание

1. [Зачем NixOS](#зачем-nixos)
2. [Ключевые отличия от Arch](#ключевые-отличия-от-arch)
3. [Подготовка к установке](#подготовка-к-установке)
4. [Установка NixOS](#установка-nixos)
5. [Структура конфигурации](#структура-конфигурации)
6. [Пример configuration.nix под твою систему](#пример-configurationnix-под-твою-систему)
7. [Home Manager — пользовательские настройки](#home-manager--пользовательские-настройки)
8. [Flakes — современный подход](#flakes--современный-подход)
9. [Маппинг пакетов Arch → NixOS](#маппинг-пакетов-arch--nixos)
10. [Решение частых проблем](#решение-частых-проблем)
11. [Полезные команды](#полезные-команды)
12. [Ресурсы](#ресурсы)

---

## Зачем NixOS

| Arch Linux | NixOS |
|---|---|
| Rolling release, мануальное управление | Декларативная конфигурация — вся система описана в `.nix` файлах |
| Сломал систему → переустановка / `arch-chroot` | Атомарные обновления + мгновенный откат к предыдущему поколению |
| `pacman -Syu` может сломать что угодно | `nixos-rebuild switch` — если не работает, перезагрузись в предыдущее поколение |
| Конфиги разбросаны по `/etc` | Один `configuration.nix` описывает всё |
| AUR — без гарантий | Nixpkgs — крупнейший репозиторий пакетов в мире (100k+) |

---

## Ключевые отличия от Arch

### Пакетный менеджер

```bash
# Arch:
sudo pacman -S firefox
yay -S android-studio

# NixOS (декларативно в configuration.nix):
environment.systemPackages = with pkgs; [ firefox ];
# Затем:
sudo nixos-rebuild switch

# NixOS (императивно, временно):
nix-env -iA nixpkgs.firefox

# Nix shell (попробовать пакет без установки):
nix-shell -p firefox
```

### Файловая система

- Пакеты хранятся в `/nix/store/` — хешированные, неизменяемые.
- Системная конфигурация в `/etc/nixos/`.
- Нет `/usr/bin` с кучей бинарников — всё через симлинки из `/nix/store`.

### Сервисы

```bash
# Arch:
sudo systemctl enable docker

# NixOS (в configuration.nix):
virtualisation.docker.enable = true;
```

> [!IMPORTANT]
> В NixOS **нельзя** редактировать файлы в `/etc` напрямую (они генерируются при rebuild). Вся конфигурация — через `.nix` файлы.

---

## Подготовка к установке

### 1. Бэкап данных

```bash
# Бэкап домашней директории (у тебя /home на отдельном NVMe)
# Можно просто оставить /home как есть, NixOS подключит его

# Бэкап списка пакетов (уже сделано)
pacman -Qe > ~/arch-packages.txt

# Бэкап важных конфигов
cp -r ~/.zshrc ~/.config ~/.ssh ~/.gitconfig ~/backup/
```

### 2. Скачать ISO

Скачай NixOS ISO с [nixos.org/download](https://nixos.org/download/):
- **Graphical ISO** — с графическим установщиком (Calamares с KDE)
- **Minimal ISO** — только консоль (для продвинутых)

> [!TIP]
> Рекомендую **Graphical ISO**. Устанавливать можно с любого ISO (stable) — после установки канал переключим на **unstable**.

### 3. Схема разделов

Твоя текущая разметка:

```
sda1  (vfat, 1G)   → /boot      (EFI)
sda2  (ext4)        → /          (корень — NixOS откатывает через поколения, btrfs не нужен)
nvme0n1p1 (btrfs)   → /home      (NVMe, 1 ТБ — btrfs со snapper для снэпшотов)
sdb                  → Windows    (не трогаем)
zram0                → swap
```

> [!WARNING]
> При установке NixOS на `sda` — **не форматируй** `nvme0n1p1` (`/home`), просто подключи его. Также не трогай `sdb` с Windows.

---

## Установка NixOS

### Через графический установщик (рекомендуется)

1. Загрузись с USB.
2. Установщик Calamares:
   - Выбери **Replace partition** для `sda2` (корень).
   - `/boot` — оставь `sda1` (EFI, vfat).
   - `/home` — укажи `nvme0n1p1` (btrfs, **не форматировать**).
   - Swap — zram настроим позже в конфиге.
3. Установи, перезагрузись.

### Ручная установка (если нужен полный контроль)

```bash
# 1. Разметка (если нужно переразметить sda)
# sda1 уже есть — EFI, не трогаем
# Форматируем корень в ext4 (btrfs не нужен — NixOS и так откатывает через поколения):
mkfs.ext4 /dev/sda2

# 2. Монтирование
mount /dev/sda2 /mnt
mkdir -p /mnt/boot /mnt/home
mount /dev/sda1 /mnt/boot
mount /dev/nvme0n1p1 /mnt/home

# 3. Генерация начальной конфигурации
nixos-generate-config --root /mnt

# 4. Редактирование конфигурации
nano /mnt/etc/nixos/configuration.nix
# (вставь конфиг из раздела ниже)

# 5. Установка
nixos-install

# 6. Установка пароля root
nixos-install --root /mnt
# Задаст пароль для root

# 7. Перезагрузка
reboot
```

### После первой загрузки — подключение flake-конфигурации

Вместо каналов используем Flakes — канал `nixos-unstable` указан как input в `flake.nix`.

```bash
# 1. Клонируй репозиторий с конфигами (или скопируй файлы)
cd /home/seevser
git clone <url-репозитория> nix-configs-git

# 2. Скопируй hardware-configuration.nix (он уникален для каждой машины)
cp /etc/nixos/hardware-configuration.nix ~/nix-configs-git/

# 3. Сгенерируй flake.lock (зафиксирует версии всех inputs)
cd ~/nix-configs-git
nix flake lock

# 4. Применяй конфигурацию через flake
sudo nixos-rebuild switch --flake ~/nix-configs-git#seevser-nixos
```

> [!IMPORTANT]
> `hardware-configuration.nix` генерируется автоматически при установке NixOS и специфичен для твоего железа. Его нужно скопировать из `/etc/nixos/` в папку с конфигами.

> [!NOTE]
> `system.stateVersion` в `configuration.nix` менять **не нужно** — это НЕ версия канала, а маркер для обратной совместимости.

---

## Структура конфигурации

```
/etc/nixos/
├── configuration.nix          # Основной конфиг системы
├── hardware-configuration.nix # Сгенерирован автоматически (диски, модули)
└── (опционально)
    ├── desktop.nix            # Настройки DE
    ├── gaming.nix             # Игровые пакеты
    ├── dev.nix                # Инструменты разработки
    └── networking.nix         # Сеть и VPN
```

> [!TIP]
> Можно разбить конфиг на модули через `imports`:
> ```nix
> imports = [
>   ./hardware-configuration.nix
>   ./desktop.nix
>   ./gaming.nix
> ];
> ```

---

## Пример configuration.nix под твою систему

Этот конфиг написан на основе твоего Arch-окружения:
- **AMD Ryzen 7 5700X + NVIDIA RTX 3080 Ti**
- **KDE Plasma 6 + Wayland + SDDM**
- **ext4 корень + btrfs /home на NVMe (со snapper)**
- **zsh + Oh My Zsh + Powerlevel10k**

Файл: [configuration.nix](./nixos-configuration.nix)

```nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ========================
  # Загрузчик (GRUB + EFI)
  # ========================
  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;  # Обнаружение Windows на sdb
    };
  };

  # Ядро
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # zram swap
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # btrfs scrub (только /home — корень на ext4)
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/home" ];
  };

  # ========================
  # Сеть
  # ========================
  networking = {
    hostName = "seevser-nixos";  # Поменяй на своё
    networkmanager.enable = true;
    firewall.enable = true;
  };

  # ========================
  # Локализация
  # ========================
  time.timeZone = "Asia/Yekaterinburg";  # UTC+5

  i18n = {
    defaultLocale = "ru_RU.UTF-8";
    extraLocaleSettings = {
      LC_ALL = "ru_RU.UTF-8";
    };
  };

  console.keyMap = "us";  # или "ru" если нужна русская консоль

  # ========================
  # NVIDIA (RTX 3080 Ti)
  # ========================
  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;  # Open-source kernel module (GA102 поддерживается)
    nvidiaSettings = true;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # ========================
  # Рабочий стол: KDE Plasma 6 + Wayland
  # ========================
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.desktopManager.plasma6.enable = true;

  # XDG Portal для Wayland
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-kde ];
  };

  # ========================
  # Звук (PipeWire)
  # ========================
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # ========================
  # Bluetooth
  # ========================
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # ========================
  # Виртуализация
  # ========================
  virtualisation = {
    docker.enable = true;

    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        swtpm.enable = true;    # TPM для Windows VM
        ovmf.enable = true;     # UEFI для VM
      };
    };
  };
  programs.virt-manager.enable = true;

  # ========================
  # Игры
  # ========================
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
  };

  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  # ========================
  # Шрифты
  # ========================
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      joypixels
      meslo-lgs-nf  # Для Powerlevel10k
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.meslo-lg
    ];
  };

  # ========================
  # Оболочка: Zsh
  # ========================
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  environment.shells = with pkgs; [ zsh ];

  # ========================
  # Пользователь
  # ========================
  users.users.seevser = {
    isNormalUser = true;
    description = "seevser";
    extraGroups = [
      "wheel"           # sudo
      "networkmanager"
      "docker"
      "libvirtd"
      "kvm"
      "adbusers"        # Android Debug Bridge
      "video"
    ];
    shell = pkgs.zsh;
  };

  # ========================
  # Разрешить несвободные пакеты
  # ========================
  nixpkgs.config = {
    allowUnfree = true;
    joypixels.acceptLicense = true;
  };

  # ========================
  # Системные пакеты
  # ========================
  environment.systemPackages = with pkgs; [
    # --- Утилиты ---
    wget
    curl
    git
    vim
    nano
    htop
    unzip
    unrar
    p7zip
    less
    gum
    screenfetch
    file
    pciutils
    usbutils
    smartmontools
    tcpdump

    # --- Терминал ---
    kitty
    zsh
    thefuck

    # --- Файловые менеджеры ---
    dolphin
    nautilus

    # --- Браузеры ---
    firefox
    chromium

    # --- Общение ---
    telegram-desktop
    discord
    vesktop
    thunderbird

    # --- Медиа ---
    vlc
    obs-studio
    kdenlive
    krita
    inkscape
    gwenview
    shotwell
    elisa

    # --- Офис ---
    onlyoffice-desktopeditors
    obsidian

    # --- Разработка ---
    vscode
    dbeaver-bin
    filezilla
    putty
    docker-compose

    # --- .NET ---
    dotnet-sdk_8
    dotnet-runtime

    # --- Java ---
    jdk17
    jdk21

    # --- Node / Deno ---
    deno

    # --- Сборка ---
    clang
    cmake
    ninja
    pkg-config
    gnumake
    gcc

    # --- KDE приложения ---
    ark
    kate
    konsole
    kdeconnect-kde
    kalk
    krdc
    kpat

    # --- Сеть и VPN ---
    wireguard-tools
    networkmanager-openvpn

    # --- Управление дисками ---
    gparted
    btrfs-progs
    efibootmgr

    # --- Виртуализация ---
    qemu_kvm
    virt-manager
    gnome-boxes

    # --- Игры ---
    lutris
    heroic
    prismlauncher
    gamescope
    wine
    winetricks

    # --- Screencasting ---
    kooha
    qpwgraph

    # --- NVIDIA ---
    nvidia-vaapi-driver
    lact

    # --- Прочее ---
    bitwarden-desktop
    keepassxc
    qbittorrent
    remmina
    ventoy
  ];

  # AppImage
  programs.appimage = {
    enable = true;
    binfmt = true;  # Запуск AppImage напрямую
  };

  # ========================
  # Flatpak (декларативный, через nix-flatpak)
  # ========================
  services.flatpak = {
    enable = true;
    packages = [
      "org.gimp.GIMP"                    # GIMP (PhotoGIMP)
      "io.mrarm.mcpelauncher"            # Minecraft Bedrock Launcher
      "com.hypixel.HytaleLauncher"       # Hytale Launcher
      "com.poweriso.PowerISO"            # PowerISO
      "io.github.recol.dlss-updater"     # DLSS Updater
      "com.ml4w.dotfilesinstaller"       # Dotfiles Installer
    ];
  };

  # ========================
  # Android (ADB)
  # ========================
  programs.adb.enable = true;

  # ========================
  # Snapper (btrfs снэпшоты только для /home)
  # ========================
  # Корень на ext4 — откат через NixOS поколения
  services.snapper = {
    configs = {
      home = {
        SUBVOLUME = "/home";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_MIN_AGE = "1800";
        TIMELINE_LIMIT_HOURLY = "5";
        TIMELINE_LIMIT_DAILY = "7";
        TIMELINE_LIMIT_WEEKLY = "0";
        TIMELINE_LIMIT_MONTHLY = "0";
        TIMELINE_LIMIT_YEARLY = "0";
      };
    };
  };

  # ========================
  # Прочие сервисы
  # ========================
  services.openssh.enable = false;
  services.printing.enable = true;  # CUPS

  # Время
  services.timesyncd.enable = true;

  # Сборка мусора Nix
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.05";  # Не менять после установки!
}
```

---

## Home Manager — пользовательские настройки

Home Manager — модуль для декларативного управления пользовательским окружением (dotfiles, zsh, git, kitty и т.д.).

### Подключение (через Flakes)

Home Manager подключается как flake input и NixOS-модуль. Каналы **не нужны** — всё через `flake.nix`:

```nix
# В flake.nix:
home-manager = {
  url = "github:nix-community/home-manager";
  inputs.nixpkgs.follows = "nixpkgs";
};

# В modules:
home-manager.nixosModules.home-manager
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.seevser = import ./nixos-home.nix;
}
```

### Конфигурация Home Manager

Файл: [nixos-home.nix](./nixos-home.nix) — содержит настройки:
- **Git** — имя, email, credential helper
- **Zsh** — Oh My Zsh, Powerlevel10k, алиасы (`rebuild`, `update`, `cleanup`)
- **Kitty** — шрифт, прозрачность, Wayland
- **Neovim** — как дефолтный редактор
- **Thefuck, htop** — утилиты
- **XDG** — приложения по умолчанию (браузер, почта, Discord)
- **Локализация** — `LANG`, `LC_*`

---

## Flakes — управление конфигурацией

Flakes заменяют каналы и обеспечивают воспроизводимость сборок. Конфигурация живёт в Git-репозитории `~/nix-configs-git/`.

### Структура репозитория

```
~/nix-configs-git/
├── flake.nix                  # Входная точка — inputs и outputs
├── flake.lock                 # Зафиксированные версии inputs (авто)
├── nixos-configuration.nix    # Системный конфиг
├── nixos-home.nix             # Пользовательский конфиг (Home Manager)
├── hardware-configuration.nix # Скопировать из /etc/nixos/ после установки
└── nixos-migration-guide.md   # Эта инструкция
```

### Файл: [flake.nix](./flake.nix)

```nix
{
  description = "NixOS конфигурация seevser";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";
  };

  outputs = { nixpkgs, home-manager, nix-flatpak, ... }: {
    nixosConfigurations.seevser-nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./nixos-configuration.nix
        nix-flatpak.nixosModules.nix-flatpak
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.seevser = import ./nixos-home.nix;
        }
      ];
    };
  };
}
```

### Основные команды

```bash
# Применить конфигурацию
sudo nixos-rebuild switch --flake ~/nix-configs-git#seevser-nixos

# Обновить все inputs (nixpkgs, home-manager, nix-flatpak)
nix flake update --flake ~/nix-configs-git

# Обновить конкретный input
nix flake update home-manager --flake ~/nix-configs-git

# Посмотреть текущие версии inputs
nix flake metadata ~/nix-configs-git
```

### Алиасы (настроены в nixos-home.nix)

| Алиас | Команда |
|---|---|
| `rebuild` | `sudo nixos-rebuild switch --flake ...` |
| `update` | `nix flake update` + `nixos-rebuild switch` |
| `cleanup` | `sudo nix-collect-garbage -d` |
| `nixedit` | `nvim ~/nix-configs-git/nixos-configuration.nix` |

> [!TIP]
> С flakes каналы больше не нужны. Версия nixpkgs фиксируется в `flake.lock` и обновляется только через `nix flake update`.

---

## Маппинг пакетов Arch → NixOS

Ниже — маппинг ключевых пакетов из твоей системы. Пакеты, которых **нет** в nixpkgs, отмечены способом установки.

### Разработка

| Arch (pacman/AUR) | NixOS (nixpkgs) | Примечание |
|---|---|---|
| `android-studio` | `android-studio` | ✅ |
| `code` (VS Code) | `vscode` | ✅ |
| `cursor-bin` | — | Flatpak или AppImage |
| `intellij-idea-community-edition` | `jetbrains.idea-community` | ✅ |
| `pycharm-community-edition` | `jetbrains.pycharm-community` | ✅ |
| `rider` | `jetbrains.rider` | ✅ (unfree) |
| `dbeaver` | `dbeaver-bin` | ✅ |
| `docker` + `docker-compose` | `virtualisation.docker.enable` | Сервис |
| `dotnet-sdk-8.0` | `dotnet-sdk_8` | ✅ |
| `jdk17-openjdk` | `jdk17` | ✅ |
| `jdk21-openjdk` | `jdk21` | ✅ |
| `deno` | `deno` | ✅ |
| `flutter-bin` | `flutter` | ✅ |
| `git` | `git` | ✅ |
| `mariadb` | `mariadb` | `services.mysql.enable` |
| `postgresql` | `postgresql` | `services.postgresql.enable` |

### Коммуникации

| Arch | NixOS | Примечание |
|---|---|---|
| `telegram-desktop` | `telegram-desktop` | ✅ |
| `discord` | `discord` | ✅ (unfree) |
| `vesktop-bin` | `vesktop` | ✅ |
| `webcord-bin` | `webcord` | ✅ |
| `thunderbird` | `thunderbird` | ✅ |
| `teamspeak3` | `teamspeak_client` | ✅ |
| `revolt-desktop-appimage` | — | AppImage/Flatpak |

### Игры

| Arch | NixOS | Примечание |
|---|---|---|
| `steam` | `programs.steam.enable` | Модуль |
| `lutris` | `lutris` | ✅ |
| `heroic-games-launcher-bin` | `heroic` | ✅ |
| `prismlauncher` | `prismlauncher` | ✅ |
| `gamescope` | `programs.gamescope.enable` | Модуль |
| `portproton` | — | AUR-only, Wine/Proton вручную |
| `minecraft-launcher` | `minecraft` | ✅ (unfree) |

### VPN / Прокси

| Arch | NixOS | Примечание |
|---|---|---|
| `v2raya-bin` | `services.v2raya.enable = true;` | ✅ Модуль |
| `v2ray` | `v2ray` | ✅ |
| `wireguard-tools` | `wireguard-tools` | ✅ |
| `networkmanager-openvpn` | `networkmanager-openvpn` | ✅ |
| `nekoray-bin` | — | Flatpak/AppImage |
| `outline-client-appimage` | — | AppImage |
| AmneziaVPN | — | Собирать/AppImage |

### Браузеры

| Arch | NixOS | Примечание |
|---|---|---|
| `firefox` | `firefox` | ✅ |
| `chromium` | `chromium` | ✅ |
| `yandex-browser` | — | Flatpak/AppImage |

### Мультимедиа

| Arch | NixOS | Примечание |
|---|---|---|
| `obs-studio` | `obs-studio` | ✅ |
| `vlc` | `vlc` | ✅ |
| `kdenlive` | `kdenlive` | ✅ |
| `krita` | `krita` | ✅ |
| `inkscape` | `inkscape` | ✅ |

---

## Решение частых проблем

### NVIDIA + Wayland — чёрный экран

Убедись, что в конфиге:
```nix
hardware.nvidia.modesetting.enable = true;
```

Если не помогает, добавь параметры ядра:
```nix
boot.kernelParams = [ "nvidia-drm.modeset=1" "nvidia-drm.fbdev=1" ];
```

### Пакета нет в nixpkgs

Варианты:
1. **Flatpak** — декларативно через `nix-flatpak` (см. секцию Flatpak в конфиге).
2. **AppImage** — включи поддержку в конфиге:
   ```nix
   programs.appimage = {
     enable = true;
     binfmt = true;  # Запуск .AppImage напрямую
   };
   ```
   После этого AppImage-файлы можно запускать напрямую: `./SomeApp.AppImage`.
3. **nix-alien** — запуск бинарников, собранных не для NixOS.

### Steam / игры не запускаются

Для 32-битных библиотек:
```nix
hardware.graphics.enable32Bit = true;  # Для 32-bit игр
```

### Шрифты выглядят некрасиво

```nix
fonts.fontconfig = {
  defaultFonts = {
    serif = [ "Noto Serif" ];
    sansSerif = [ "Noto Sans" ];
    monospace = [ "JetBrainsMono Nerd Font" ];
    emoji = [ "JoyPixels" ];
  };
};
```

### Windows не видна в GRUB

```nix
boot.loader.grub.useOSProber = true;
```

И установи `os-prober`:
```nix
environment.systemPackages = [ pkgs.os-prober ];
```

### Не работает Bluetooth-геймпад (Xbox через xpadneo)

```nix
# xpadneo в nixpkgs:
boot.extraModulePackages = with config.boot.kernelPackages; [ xpadneo ];
hardware.xpadneo.enable = true;
```

---

## Полезные команды

```bash
# ==== Системное управление (flakes) ====
sudo nixos-rebuild switch --flake ~/nix-configs-git#seevser-nixos   # Применить изменения
sudo nixos-rebuild boot --flake ~/nix-configs-git#seevser-nixos     # Применить после перезагрузки
sudo nixos-rebuild test --flake ~/nix-configs-git#seevser-nixos     # Применить без добавления в GRUB

# ==== Обновление inputs ====
nix flake update --flake ~/nix-configs-git                         # Обновить все inputs
nix flake update nixpkgs --flake ~/nix-configs-git                 # Обновить только nixpkgs
nix flake metadata ~/nix-configs-git                               # Посмотреть версии inputs

# ==== Откат ====
# При загрузке в GRUB — выбери предыдущее поколение
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo nixos-rebuild switch --rollback

# ==== Поиск пакетов ====
nix search nixpkgs firefox                                         # Поиск пакета

# ==== Очистка ====
sudo nix-collect-garbage -d                                        # Удалить все старые поколения
sudo nix-store --optimise                                          # Дедупликация /nix/store

# ==== Попробовать пакет без установки ====
nix run nixpkgs#cowsay -- "hello"
nix shell nixpkgs#python3                                          # Открыть shell с пакетом

# ==== Информация ====
nixos-version                                                      # Текущая версия NixOS
```

---

## Ресурсы

| Ресурс | Ссылка |
|---|---|
| Официальная документация | [nixos.org/manual](https://nixos.org/manual/nixos/stable/) |
| Поиск пакетов | [search.nixos.org](https://search.nixos.org/packages) |
| Поиск опций | [search.nixos.org/options](https://search.nixos.org/options) |
| Home Manager | [nix-community.github.io/home-manager](https://nix-community.github.io/home-manager/) |
| Nix Pills (обучение) | [nixos.org/guides/nix-pills](https://nixos.org/guides/nix-pills/) |
| NixOS Wiki | [wiki.nixos.org](https://wiki.nixos.org/) |
| Сообщество (Telegram RU) | [@nixos_ru](https://t.me/nixos_ru) |
| Awesome Nix | [github.com/nix-community/awesome-nix](https://github.com/nix-community/awesome-nix) |

> [!TIP]
> Лучший способ искать пакеты и опции — [search.nixos.org](https://search.nixos.org). Введи название пакета из Arch и почти всегда найдётся аналог.
