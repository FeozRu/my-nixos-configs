{ config, pkgs, lib, ... }:

let
  pmbootstrapRepo = pkgs.fetchgit {
    url = "https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git";
    rev = "845cda033ab534f8350f71baea9226603f1c5693"; # 3.10.3
    hash = "sha256-Zl7Ti0HwMQSjMeW4GjdEKIRoCNjV15Qiv8bzhktNoyQ=";
  };

  pmbootstrapWrapper = pkgs.writeShellScriptBin "pmbootstrap" ''
    exec ${pkgs.python3}/bin/python3 \
      "${config.home.homeDirectory}/.local/share/pmbootstrap-git/pmbootstrap.py" "$@"
  '';

  pmosSuryaEnvkernel = pkgs.writeShellScriptBin "pmos-surya-envkernel" ''
    set -euo pipefail
    KERNEL_DIR="''${1:-$HOME/src/sm7150-linux}"
    if [ ! -d "$KERNEL_DIR" ]; then
      echo "Сначала: git clone https://github.com/sm7150-mainline/linux.git $KERNEL_DIR" >&2
      exit 1
    fi
    source "${config.home.homeDirectory}/.local/share/pmbootstrap-git/helpers/envkernel.sh"
    cd "$KERNEL_DIR"
    export ARCH=arm64
    export CROSS_COMPILE=aarch64-unknown-linux-gnu-
    make defconfig sm7150.config
    make -j"$(nproc)"
    pmbootstrap build --arch aarch64 --force --envkernel linux-postmarketos-qcom-sm7150
  '';
in
{
  # Wiki: pmbootstrap из git — в nixpkgs нет helpers/envkernel.sh
  home.file.".local/share/pmbootstrap-git".source = pmbootstrapRepo;

  home.packages = [
    pmbootstrapWrapper
    pmosSuryaEnvkernel
  ];
}
