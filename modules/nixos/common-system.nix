{ config, pkgs, lib, userName, ... }:

let
  # Пути к системным библиотекам для ldconfig cache
  # (нужен pressure-vessel / capsule-capture-libs в PortProtonQT / Steam)
  ldcacheConf = pkgs.writeText "ld.so.conf" (lib.concatMapStringsSep "\n" (pkg: "${pkg}/lib") (
    # 64-bit
    (with pkgs; [
      glibc
      stdenv.cc.cc.lib
      mesa
      libdrm
      libgbm
      libusb1
      vulkan-loader
      libglvnd
      wayland
      libxkbcommon
      zlib
      zstd
      alsa-lib
      fontconfig
      freetype
      expat
      libpulseaudio
      libx11
      libxext
      libxrandr
      libxcursor
      libxrender
      libxi
      libxtst
      libxxf86vm
      libxcomposite
      libxfixes
      libxinerama
      libxdamage
      libxcb
    ])
    ++
    # 32-bit (нужно Wine)
    (with pkgs.pkgsi686Linux; [
      glibc
      stdenv.cc.cc.lib
      mesa
      libdrm
      libgbm
      libusb1
      vulkan-loader
      libglvnd
      zlib
      zstd
      alsa-lib
      fontconfig
      freetype
      expat
      libpulseaudio
      libx11
      libxext
      libxrandr
      libxcursor
      libxrender
      libxi
      libxtst
      libxxf86vm
      libxcomposite
      libxfixes
      libxinerama
      libxdamage
      libxcb
    ])
  ));
in
{
  # Загрузчик (GRUB + EFI) — useOSProber переопределяется на хосте
  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = lib.mkDefault true;
    };
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [ networkmanager-openvpn ];
  };
  networking.firewall.enable = true;

  programs.amnezia-vpn.enable = true;

  time.timeZone = "Asia/Yekaterinburg";

  i18n = {
    defaultLocale = "ru_RU.UTF-8";
    extraLocaleSettings = {
      LC_ALL = "ru_RU.UTF-8";
    };
  };

  console.keyMap = "us";

  programs.niri.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.common = {
      default = [ "gnome" ];
    };
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = lib.mkDefault true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;

    extraConfig.pipewire."92-usb-mic-quality" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.allowed-rates" = [ 44100 48000 96000 ];
      };
    };

    wireplumber.extraConfig = {
      "10-bluez" = {
        "monitor.bluez.properties" = {
          "bluez5.enable-sbc-xq" = true;
          "bluez5.enable-msbc" = true;
          "bluez5.enable-hw-volume" = true;
        };
      };

      "99-usb-mic-quality" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_input.usb-*"; }
            ];
            actions = {
              update-props = {
                "audio.rate" = 48000;
                "audio.format" = "S24_LE";
              };
            };
          }
        ];
      };
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
        JustWorksRepairing = "always";
        ControllerMode = "dual";
      };
    };
  };

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

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    libx11
    libxext
    libxcursor
    libxrandr
    libxrender
    libxi
    libxtst
    libxxf86vm
    libxcb
    libGL
    alsa-lib
    fontconfig
    freetype
    # Графика / Vulkan (pressure-vessel, Wine/Proton)
    mesa
    libdrm
    libgbm
    zstd
    vulkan-loader
    libglvnd
    wayland
    libxkbcommon
    # Звук / X11 extensions (драйверы дисплея и аудио Wine)
    libpulseaudio
    libxcomposite
    libxfixes
    libxinerama
    libxdamage
    # 32-bit Wine/Proton dependencies for AppImage/FHS launchers.
    pkgsi686Linux.stdenv.cc.cc.lib
    pkgsi686Linux.zlib
    pkgsi686Linux.alsa-lib
    pkgsi686Linux.fontconfig
    pkgsi686Linux.freetype
    pkgsi686Linux.libpulseaudio
    pkgsi686Linux.libdrm
    pkgsi686Linux.libgbm
    pkgsi686Linux.mesa
    pkgsi686Linux.zstd
    pkgsi686Linux.libusb1
    pkgsi686Linux.vulkan-loader
    pkgsi686Linux.libglvnd
    pkgsi686Linux.wayland
    pkgsi686Linux.libxkbcommon
    pkgsi686Linux.libx11
    pkgsi686Linux.libxext
    pkgsi686Linux.libxcursor
    pkgsi686Linux.libxrandr
    pkgsi686Linux.libxrender
    pkgsi686Linux.libxi
    pkgsi686Linux.libxtst
    pkgsi686Linux.libxxf86vm
    pkgsi686Linux.libxcomposite
    pkgsi686Linux.libxfixes
    pkgsi686Linux.libxinerama
    pkgsi686Linux.libxdamage
  ];

  programs.fish.enable = true;
  users.defaultUserShell = pkgs.fish;
  environment.shells = with pkgs; [ fish ];

  users.users.${userName} = {
    isNormalUser = true;
    description = userName;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ];
    shell = pkgs.fish;
  };

  nixpkgs.config = {
    allowUnfree = true;
    joypixels.acceptLicense = true;
    permittedInsecurePackages = [
      "ventoy-gtk3-1.1.17"
      # vesktop still depends on EOL electron_40
      "electron-40.10.5"
    ];
  };

  services.openssh.enable = true;
  services.printing.enable = true;
  services.timesyncd.enable = true;

  services.v2raya.enable = true;

  systemd.tmpfiles.rules = [
    "L+ /usr/bin/sh - - - - ${pkgs.bash}/bin/sh"
    "L+ /usr/bin/true - - - - ${pkgs.coreutils}/bin/true"
    # 32-битный линкер для Wine
    "L+ /lib/ld-linux.so.2 - - - - ${pkgs.pkgsi686Linux.glibc}/lib/ld-linux.so.2"
    # pressure-vessel ожидает эти утилиты по FHS-путям
    "L+ /usr/sbin/ldconfig - - - - ${pkgs.glibc.bin}/bin/ldconfig"
    "L+ /sbin/ldconfig - - - - ${pkgs.glibc.bin}/bin/ldconfig"
    "L+ /usr/bin/ldd - - - - ${pkgs.glibc.bin}/bin/ldd"
    "L+ /usr/bin/locale - - - - ${pkgs.glibc.bin}/bin/locale"
    "L+ /usr/bin/localedef - - - - ${pkgs.glibc.bin}/bin/localedef"
  ];

  # pressure-vessel / capsule-capture-libs читает /var/cache/ldconfig/ld.so.cache,
  # а glibc ld.so и capsule-capture-libs резолвят зависимости через /etc/ld.so.cache
  system.activationScripts.ldconfig = {
    text = ''
      mkdir -p /var/cache/ldconfig
      ${pkgs.glibc.bin}/bin/ldconfig -f ${ldcacheConf} -C /var/cache/ldconfig/ld.so.cache 2>/dev/null || true
      ${pkgs.glibc.bin}/bin/ldconfig -f ${ldcacheConf} -C /etc/ld.so.cache 2>/dev/null || true
    '';
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Ограничиваем ресурсы сборки — Ryzen 3600 (6 ядер / 12 потоков).
  # cores = 6 → половина потоков на одну сборку.
  # max-jobs = 1 → одна сборка за раз, чтобы суммарно не превышать 6 потоков.
  nix.settings.cores = 6;
  nix.settings.max-jobs = 1;

  # Жёсткий лимит nix-daemon через cgroup:
  # CPUQuota 50% — демон физически не может занять больше половины CPU.
  systemd.services.nix-daemon.serviceConfig = {
    CPUQuota = "50%";
    MemoryMax = "8G";
    Nice = 19;
    CPUWeight = 20;
    IOSchedulingClass = lib.mkForce "idle";
    IOSchedulingPriority = lib.mkForce 7;
  };

  nix.settings.substituters = [
    "https://cache.nixos.org"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  ];

  nix.settings.keep-outputs = true;
  nix.settings.keep-derivations = true;

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  programs.gamemode.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-vaapi # плагин для вывода кодировщика VAAPI в OBS
    ];
  };

  system.stateVersion = "25.05";
}
