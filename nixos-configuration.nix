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
    networkmanager.enable = true;
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
    extraPortals = [ pkgs.xdg-desktop-portal-kde ];
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
        ovmf.enable = true;
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
      meslo-lgs-nf
      (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "Meslo" ]; })
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
      "adbusers"
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
  # Системные пакеты
  # ========================
  environment.systemPackages = with pkgs; [
    # Утилиты
    wget curl git neovim htop
    unzip unrar p7zip less
    gum screenfetch
    file pciutils usbutils
    smartmontools tcpdump

    # Терминал
    kitty thefuck

    # Файловые менеджеры
    dolphin

    # Браузеры
    firefox chromium

    # Общение
    telegram-desktop discord vesktop thunderbird

    # Медиа
    vlc obs-studio kdenlive krita inkscape
    gwenview shotwell elisa

    # Офис
    onlyoffice-desktopeditors obsidian

    # Разработка
    vscode dbeaver-bin filezilla putty
    docker-compose android-studio
    jetbrains.idea-community
    jetbrains.pycharm-community
    jetbrains.rider

    # Языки / SDK
    dotnet-sdk_8 jdk17 jdk21 deno
    flutter

    # Сборка
    clang cmake ninja pkg-config gnumake gcc

    # KDE
    ark kate konsole kdeconnect-kde
    kalk krdc kpat

    # Сеть
    wireguard-tools networkmanager-openvpn

    # Диски
    gparted btrfs-progs efibootmgr os-prober

    # Виртуализация
    qemu_kvm gnome-boxes

    # Игры
    lutris heroic prismlauncher
    gamescope wine winetricks

    # Прочее
    bitwarden-desktop keepassxc qbittorrent
    kooha qpwgraph
    nvidia-vaapi-driver lact
    appimage-run  # Для запуска AppImage
  ];

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
