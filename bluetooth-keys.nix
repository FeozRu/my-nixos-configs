# ========================
# Bluetooth pairing keys (dual-boot: Linux + Windows)
# ========================
# Этот модуль декларативно сохраняет ключи сопряжения Bluetooth,
# чтобы после переустановки NixOS не нужно было заново
# pair'ить устройства и синхронизировать ключи с Windows.
#
# Адаптер: 8C:F8:C5:56:D0:55
# Устройства:
#   - JBL TUNE770NC            (84:D3:52:F4:EF:33) — BR/EDR
#   - Xbox Wireless Controller (C8:3F:26:99:39:BE) — BLE
#
# ⚠ Если перепарите устройство на любой ОС — обновите ключи здесь!

{ config, pkgs, lib, ... }:

let
  btDir = "/var/lib/bluetooth";
  adapter = "8C:F8:C5:56:D0:55";

  # ---------- JBL TUNE770NC ----------
  jblInfo = pkgs.writeText "bt-jbl-info" ''
[General]
Name=JBL TUNE770NC
Class=0x240404
SupportedTechnologies=BR/EDR;
Trusted=true
Blocked=false
CablePairing=false
Services=00000000-0000-0000-0099-aabbccddeeff;0000110b-0000-1000-8000-00805f9b34fb;0000110c-0000-1000-8000-00805f9b34fb;0000110d-0000-1000-8000-00805f9b34fb;0000110e-0000-1000-8000-00805f9b34fb;0000111e-0000-1000-8000-00805f9b34fb;00001200-0000-1000-8000-00805f9b34fb;00001800-0000-1000-8000-00805f9b34fb;00001801-0000-1000-8000-00805f9b34fb;0000ff01-0000-1000-8000-00805f9b34ff;5052494d-2dab-0341-6972-6f6861424c45;85dbf2f9-73e3-43f5-a129-971b91c72f1e;fa349b5f-8050-0030-0010-00001bbb231d;

[LinkKey]
Key=2345759442D2A78C5D5944B6AAF1F9EC
Type=4
PINLength=0

[DeviceID]
Source=1
Vendor=3787
Product=8376
Version=256
  '';

  # ---------- Xbox Wireless Controller ----------
  xboxInfo = pkgs.writeText "bt-xbox-info" ''
[General]
Name=Xbox Wireless Controller
Appearance=0x03c4
AddressType=public
SupportedTechnologies=LE;
Trusted=true
Blocked=false
CablePairing=false
WakeAllowed=true
Services=00000001-5f60-4c4f-9c83-a7953298d40d;00001800-0000-1000-8000-00805f9b34fb;00001801-0000-1000-8000-00805f9b34fb;0000180a-0000-1000-8000-00805f9b34fb;0000180f-0000-1000-8000-00805f9b34fb;00001812-0000-1000-8000-00805f9b34fb;

[IdentityResolvingKey]
Key=7637BE3999263FC843DAEAEBCCED3776

[PeripheralLongTermKey]
Key=94CC6BD0B5E3A59FAE56D222F11CEF39
Authenticated=2
EncSize=16
EDiv=0
Rand=0

[SlaveLongTermKey]
Key=94CC6BD0B5E3A59FAE56D222F11CEF39
Authenticated=2
EncSize=16
EDiv=0
Rand=0

[ConnectionParameters]
MinInterval=6
MaxInterval=6
Latency=0
Timeout=300

[DeviceID]
Source=2
Vendor=1118
Product=2848
Version=1303
  '';

in
{
  # Записываем ключи при активации системы (до старта bluetooth.service)
  system.activationScripts.bluetoothKeys = {
    text = ''
      echo ":: Восстанавливаем Bluetooth pairing keys..."

      install -d -m 0700 "${btDir}/${adapter}/84:D3:52:F4:EF:33"
      install -d -m 0700 "${btDir}/${adapter}/C8:3F:26:99:39:BE"

      cp -f ${jblInfo}  "${btDir}/${adapter}/84:D3:52:F4:EF:33/info"
      cp -f ${xboxInfo} "${btDir}/${adapter}/C8:3F:26:99:39:BE/info"

      chmod 0600 "${btDir}/${adapter}/84:D3:52:F4:EF:33/info"
      chmod 0600 "${btDir}/${adapter}/C8:3F:26:99:39:BE/info"
    '';
  };
}
