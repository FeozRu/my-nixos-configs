{ lib, fetchurl, makeWrapper, appimage-run, stdenvNoCC }:

stdenvNoCC.mkDerivation rec {
  pname = "ubports-installer";
  version = "0.11.2";

  src = fetchurl {
    url = "https://github.com/ubports/ubports-installer/releases/download/${version}/ubports-installer_${version}_linux_x86_64.AppImage";
    hash = "sha256-N22L+KnjjtGA9syo5aLldbP6K8IXV8CZ3trpYBxBSYY=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin $out/share/${pname}
    install -m755 "$src" "$out/share/${pname}/${pname}.AppImage"
    makeWrapper ${appimage-run}/bin/appimage-run $out/bin/${pname} \
      --add-flags "$out/share/${pname}/${pname}.AppImage"
  '';

  meta = with lib; {
    description = "GUI installer for Ubuntu Touch on supported mobile devices";
    homepage = "https://devices.ubuntu-touch.io/installer/";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
