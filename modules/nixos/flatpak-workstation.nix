{ ... }:

{
  services.flatpak = {
    enable = true;
    packages = [
      "org.gimp.GIMP"
      "io.mrarm.mcpelauncher"
      "com.poweriso.PowerISO"
      "com.ml4w.dotfilesinstaller"
      "ru.yandex.Browser"
      "ru.linux_gaming.PortProton"
    ];
  };
}
