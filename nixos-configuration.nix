{ config, pkgs, pkgs-stable, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./bluetooth-keys.nix
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
    hostName = "seevser-nixos";
    networkmanager = {
      enable = true;
      plugins = with pkgs; [ networkmanager-openvpn ];
    };
    firewall.enable = true;
  };

  # ========================
  # Локализация
  # ========================
  time.timeZone = "Asia/Yekaterinburg";

  i18n = {
    defaultLocale = "ru_RU.UTF-8";
    extraLocaleSettings = {
      LC_ALL = "ru_RU.UTF-8";
    };
  };

  console.keyMap = "us";

  # ========================
  # NVIDIA (RTX 3080 Ti)
  # ========================
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # Для Steam / 32-битных игр
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # ========================
  # KDE Plasma 6 + Wayland
  # ========================
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.desktopManager.plasma6.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  };

  # ========================
  # PipeWire (звук)
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

    # Улучшение качества USB-микрофона:
    # - sample rate 48 кГц (студийный стандарт)
    # - quantum 256 / min.quantum 32 — низкая задержка без артефактов
    extraConfig.pipewire."92-usb-mic-quality" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.allowed-rates" = [ 44100 48000 96000 ];
      };
    };

    # WirePlumber: Bluetooth кодеки + suspend + USB-микрофон
    wireplumber.extraConfig = {
      # Улучшенные Bluetooth-кодеки и hardware volume
      "10-bluez" = {
        "monitor.bluez.properties" = {
          "bluez5.enable-sbc-xq" = true;   # SBC-XQ — лучшее качество A2DP
          "bluez5.enable-msbc" = true;      # mSBC — лучшее качество HSP/HFP (звонки)
          "bluez5.enable-hw-volume" = true; # Аппаратная регулировка громкости
        };
      };



      # Улучшение качества USB-микрофона (более высокий sample rate по умолчанию)
      "99-usb-mic-quality" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_input.usb-*"; }
            ];
            actions = {
              update-props = {
                "audio.rate" = 48000;
                "audio.format" = "S24_LE";  # 24 бит (если микрофон поддерживает)
              };
            };
          }
        ];
      };
    };
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
        swtpm.enable = true;
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
    fontDir.enable = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      joypixels
      meslo-lgs-nf
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.meslo-lg
      corefonts
      vista-fonts
      dejavu_fonts
      liberation_ttf
      ubuntu-classic
    ];
    fontconfig.defaultFonts = {
      serif = [ "Noto Serif" ];
      sansSerif = [ "Noto Sans" ];
      monospace = [ "JetBrainsMono Nerd Font" ];
      emoji = [ "JoyPixels" ];
    };
  };

  # ========================
  # Zsh
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
      "wheel"
      "networkmanager"
      "docker"
      "libvirtd"
      "kvm"
      "video"
    ];
    shell = pkgs.zsh;
  };

  # ========================
  # Несвободные пакеты
  # ========================
  nixpkgs.config = {
    allowUnfree = true;
    joypixels.acceptLicense = true;
  };

  # ========================
  # Системные пакеты и переменные
  # ========================
  environment.systemPackages = with pkgs; [
    # Утилиты
    wget curl git neovim htop
    unzip unrar p7zip less
    gum screenfetch
    file pciutils usbutils
    smartmontools tcpdump

    # Терминал
    kitty

    # Файловые менеджеры
    kdePackages.dolphin

    # Браузеры
    firefox chromium

    # Общение
    telegram-desktop discord thunderbird
    teamspeak6-client
    vesktop

    # Медиа
    vlc obs-studio
    yandex-music
    vlc obs-studio inkscape
    pkgs-stable.krita
    kdePackages.kdenlive
    kdePackages.gwenview shotwell kdePackages.elisa
    gimp2

    # Офис
    onlyoffice-desktopeditors obsidian

    # Разработка
    vscode code-cursor google-antigravity
    dbeaver-bin filezilla putty
    docker-compose android-studio
    jetbrains.idea-oss
    jetbrains.pycharm-oss
    # jetbrains.rider  # временно убран — JetBrains блокирует скачивание (HTTP 451)

    # Языки / SDK
    dotnet-sdk_8 jdk17 jdk21 deno
    flutter

    # Сборка
    clang cmake ninja pkg-config gnumake gcc

    # Android
    android-tools

    # KDE
    kdePackages.ark kdePackages.kate kdePackages.konsole kdePackages.kdeconnect-kde
    kdePackages.kalk kdePackages.krdc kdePackages.kpat

    # Сеть
    wireguard-tools networkmanager-openvpn

    # Диски
    gparted btrfs-progs efibootmgr os-prober

    # Виртуализация
    qemu_kvm gnome-boxes

    # Игры
    lutris heroic prismlauncher
    gamescope wine winetricks
    (pkgs.writeShellScriptBin "innoextract" ''
      if [[ "$1" == "--version" ]]; then
        ${pkgs.innoextract}/bin/innoextract "$@" | sed 's/-dev//g'
      else
        exec ${pkgs.innoextract}/bin/innoextract "$@"
      fi
    '')
    (pkgs.writeShellScriptBin "steamtinkerlaunch" ''
      # Запускаем STL и фоновый слушатель NXM в одном FHS контейнере
      exec ${pkgs.steam-run}/bin/steam-run bash -c '
        /home/seevser/.config/steamtinkerlaunch/custom/nxm-listener.sh &
        LPID=$!
        ${pkgs.steamtinkerlaunch}/bin/steamtinkerlaunch "$@"
        kill $LPID 2>/dev/null
      ' -- "steamtinkerlaunch" "$@"
    '')
    xdotool yad

    # Прочее
    bitwarden-desktop keepassxc qbittorrent
    kooha qpwgraph
    nvidia-vaapi-driver lact
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
      "com.poweriso.PowerISO"            # PowerISO
      "com.ml4w.dotfilesinstaller"       # Dotfiles Installer
    ];
  };


  # ========================
  # V2RayA
  # ========================
  services.v2raya.enable = true;

  # ========================
  # Xbox gamepad (xpadneo)
  # ========================
  hardware.xpadneo.enable = true;

  # ========================
  # Snapper (btrfs снэпшоты)
  # ========================
  # Снэпшоты только для /home (корень на ext4, откат через NixOS поколения)
  services.snapper.configs = {
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

  # ========================
  # Прочее
  # ========================
  services.openssh.enable = false;
  services.printing.enable = true;
  services.timesyncd.enable = true;

  # Сборка мусора
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Не меняй после установки!
  system.stateVersion = "25.05";
}
