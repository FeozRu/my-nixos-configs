{ config, pkgs, lib, ... }:

let
  ubportsInstaller = pkgs.callPackage ../../pkgs/ubports-installer.nix { };

  aarch64Cross = pkgs.pkgsCross.aarch64-multiplatform.buildPackages;
in
{
  # systemd 258+ даёт uaccess для adb/fastboot; доп. правила — для Xiaomi/Qualcomm
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="2717", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="2ae5", TAG+="uaccess"
  '';

  environment.systemPackages = with pkgs; [
    android-tools

    # postmarketOS: хост-зависимости (pmbootstrap ставится из git через home-manager)
    multipath-tools # kpartx
    qemu_kvm
    parted
    e2fsprogs
    abootimg
    dtc
    lz4
    simg2img
    openssl
    flex
    bison
    perl
    bc
    cpio
    kmod
    ubootTools
    gnumake
    pkg-config
    # кросс-компиляция ядра sm7150 на хосте (envkernel)
    aarch64Cross.gcc
    aarch64Cross.binutils
    aarch64Cross.glibc

    # Ubuntu Touch installer (POCO X3 NFC / surya)
    ubportsInstaller
  ];
}
