{ config, pkgs, lib, ... }:

# Стрим микрофона на Windows-ПК по VBAN (для Moonlight/Vibepollo-сессий).
#
# Механика:
#  - systemd user-сервис vban-mic.service держит pw-cli с загруженным
#    libpipewire-module-vban-send. Модуль создаёт capture-стрим "vban-mic",
#    WirePlumber сам линкует его к микрофону по умолчанию.
#  - ВАЖНО: pw-cli (pipewire 1.6.8) не выходит по EOF stdin и при этом
#    busy-loop'ит на 100% CPU, поэтому stdin держим открытым через
#    sleep infinity, а жизненным циклом управляет systemd (stop = kill cgroup).
#  - One-shot `pw-cli load-module ...` не подходит: клиент отключается
#    до обработки команды, и модуль не создаётся.
#  - ExecStopPost добивает ноду вручную — на случай, если модуль переживёт клиента.
#
# Управление: `vban-mic-toggle [on|off|status|toggle]` или кнопка
# "Game Mic" в Control Center DMS (плагин ниже).
# На Windows-стороне: VoiceMeeter Banana -> VBAN -> incoming stream
# "GameMicStream", порт 6980 -> маршрут на B1 -> микрофон в приложениях
# = "VoiceMeeter Output".

let
  pwcli = "${pkgs.pipewire}/bin/pw-cli";
  pwdump = "${pkgs.pipewire}/bin/pw-dump";
  jq = "${pkgs.jq}/bin/jq";
  systemctl = "${pkgs.systemd}/bin/systemctl";

  destIp = "192.168.1.154";
  port = 6980;
  streamName = "GameMicStream";
  nodeName = "vban-mic";

  # Держит pw-cli живым с загруженным модулем (ExecStart сервиса).
  vbanMicHold = pkgs.writeShellScriptBin "vban-mic-hold" ''
    set -eu
    { printf 'load-module libpipewire-module-vban-send { destination.ip="${destIp}" destination.port=${toString port} sess.name="${streamName}" audio.format="S16LE" audio.rate=48000 audio.channels=2 stream.props={ node.name="${nodeName}" node.description="VBAN Mic to Windows" } }\n'
      sleep infinity
    } | ${pwcli}
  '';

  # Страховка на stop: снести ноду, если модуль пережил клиента (ExecStopPost).
  vbanMicRelease = pkgs.writeShellScriptBin "vban-mic-release" ''
    ids=$(${pwdump} | ${jq} -r '.[] | select(.type=="PipeWire:Interface:Node" and .info.props["node.name"]=="${nodeName}") | .id')
    for id in $ids; do
      ${pwcli} destroy "$id" >/dev/null 2>&1 || true
    done
    exit 0
  '';

  # Пользовательская обёртка: on/off/status/toggle через systemctl --user.
  vbanMicToggle = pkgs.writeShellScriptBin "vban-mic-toggle" ''
    set -eu
    case "''${1:-toggle}" in
      on)      ${systemctl} --user start vban-mic.service ;;
      off)     ${systemctl} --user stop vban-mic.service ;;
      status)  if ${systemctl} --user is-active -q vban-mic.service; then echo on; else echo off; exit 1; fi ;;
      toggle)  if ${systemctl} --user is-active -q vban-mic.service; then
                 ${systemctl} --user stop vban-mic.service
               else
                 ${systemctl} --user start vban-mic.service
               fi ;;
      *) echo "usage: vban-mic-toggle [on|off|status|toggle]" >&2; exit 2 ;;
    esac
  '';
in
{
  home.packages = [ vbanMicToggle ];

  systemd.user.services.vban-mic = {
    Unit = {
      Description = "VBAN mic stream to Windows PC (${streamName} -> ${destIp})";
      After = [ "pipewire.service" "wireplumber.service" ];
      Requires = [ "pipewire.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${vbanMicHold}/bin/vban-mic-hold";
      ExecStopPost = "${vbanMicRelease}/bin/vban-mic-release";
    };
    # Без [Install]: сервис не автостартует, включается только кнопкой/скриптом.
  };

  # Плагин DankMaterialShell: тумблер "Game Mic" в Control Center (+ иконка в баре).
  xdg.configFile."DankMaterialShell/plugins/vbanMicToggle/plugin.json".text = builtins.toJSON {
    id = "vbanMicToggle";
    name = "Game Mic (VBAN)";
    description = "Стрим микрофона на Windows-ПК (${destIp}) по VBAN";
    version = "1.0.0";
    author = "sebyanin";
    type = "widget";
    capabilities = [ "control-center" ];
    component = "./VbanMicToggle.qml";
    icon = "mic";
  };

  xdg.configFile."DankMaterialShell/plugins/vbanMicToggle/VbanMicToggle.qml".text = ''
    import QtQuick
    import qs.Common
    import qs.Widgets
    import qs.Modules.Plugins

    PluginComponent {
        id: root

        property bool micOn: false

        function refresh() {
            Proc.runCommand("vban-mic-status", ["${vbanMicToggle}/bin/vban-mic-toggle", "status"], (out, code) => {
                root.micOn = (out || "").trim() === "on";
            });
        }

        Component.onCompleted: refresh()

        Timer {
            interval: 3000
            running: true
            repeat: true
            onTriggered: root.refresh()
        }

        ccWidgetIcon: micOn ? "mic" : "mic_off"
        ccWidgetPrimaryText: "Game Mic"
        ccWidgetSecondaryText: micOn ? "стрим → ${destIp}" : "выкл"
        ccWidgetIsActive: micOn

        onCcWidgetToggled: {
            Proc.runCommand("vban-mic-toggle", ["${vbanMicToggle}/bin/vban-mic-toggle", "toggle"], (out, code) => {
                root.refresh();
            });
        }

        horizontalBarPill: Component {
            DankIcon {
                name: root.micOn ? "mic" : "mic_off"
                color: root.micOn ? Theme.primary : Theme.surfaceVariantText
                size: Theme.iconSize - 4
            }
        }

        verticalBarPill: Component {
            DankIcon {
                name: root.micOn ? "mic" : "mic_off"
                color: root.micOn ? Theme.primary : Theme.surfaceVariantText
                size: Theme.iconSize - 4
            }
        }
    }
  '';
}
