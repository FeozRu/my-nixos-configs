{ ... }:

{
  services.flatpak = {
    enable = true;
    packages = [
      "org.gimp.GIMP"
      "ru.yandex.Browser"
    ];
  };
}
