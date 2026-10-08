{ pkgs, ... }:

let
  # На Polaris (RX 570) с amdgpu после долгого сна периодически не переопределяется
  # DisplayPort-коннектор: ядро помечает монитор как disconnected (при этом
  # физически он подключён), EDID не читается, а нового hotplug-события в
  # композитор не приходит. В итоге niri/smithay видит "disconnecting connector"
  # и больше не перечитывает выходы — пока не переткнуть кабель или не перезагрузиться.
  #
  # Лечим на уровне пользовательского пространства: после resume даём GPU/монитору
  # время заново поднять DP-линк, принудительно запускаем детект коннекторов и
  # генерируем udev change-событие на DRM-устройствах — именно его слушает
  # композитор, чтобы перечитать список выходов.
  drmRedetect = pkgs.writeShellScript "drm-redetect-after-resume" ''
    set -u

    # Повторяем несколько раз: после сна DP-линку нужно время на ре-тренировку.
    i=0
    while [ "$i" -lt 5 ]; do
      sleep 3

      # Запись "detect" сбрасывает возможное форсированное состояние коннектора и
      # заставляет ядро заново определить линк и прочитать EDID.
      for status in /sys/class/drm/card*-*/status; do
        [ -w "$status" ] || continue
        printf 'detect\n' > "$status" || true
      done

      # Синтетический hotplug: заставляет слушателей udev (niri/smithay) перечитать
      # все выходы DRM прямо сейчас, а не только по событию из ядра.
      ${pkgs.systemd}/bin/udevadm trigger --action=change --subsystem-match=drm || true

      i=$((i + 1))
    done
  '';
in
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # нужно для Wine/DXVK
    extraPackages = with pkgs; [
        libva-vdpau-driver
    ];
  };

  # Oneshot-сервис, который дергает resumeCommands ниже.
  systemd.services.drm-redetect-after-resume = {
    description = "Re-probe DRM connectors and emit a hotplug after resume";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = drmRedetect;
    };
  };

  # systemd запускает это после возврата из сна (см. NixOS power-management).
  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/systemctl --no-block start drm-redetect-after-resume.service || true
  '';
}
