{ pkgs, lib, ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  nix.settings.substituters = lib.mkBefore [
    "https://cuda-maintainers.cachix.org"
  ];
  nix.settings.trusted-public-keys = lib.mkBefore [
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
  ];
}
