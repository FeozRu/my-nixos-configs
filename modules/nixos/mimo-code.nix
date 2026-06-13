{ pkgs, lib, ... }:

let
  mimo-code = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "mimo-code";
    version = "0.1.0";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@mimo-ai/mimocode-linux-x64/-/mimocode-linux-x64-${version}.tgz";
      hash = "sha512-WwUcxjUza62AiMgeKs8Yhl59n5pT7Oq1UB5nYz0jdXAxD/Gy0kOju5TT6V8zb8v5hJSGo+wWurj8aqZKM9CaNQ==";
    };

    sourceRoot = "package";

    installPhase = ''
      mkdir -p $out/bin
      cp bin/mimo $out/bin/mimo
      chmod +x $out/bin/mimo
    '';

    meta = {
      description = "MiMo Code - AI coding agent (binary for Linux x64)";
      homepage = "https://mimo.xiaomi.com/mimocode";
      license = lib.licenses.mit;
      mainProgram = "mimo";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  environment.systemPackages = [ mimo-code ];
}
