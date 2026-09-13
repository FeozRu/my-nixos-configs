{ pkgs, lib, ... }:

let
  python = pkgs.python3.withPackages (ps: [ ps.json5 ]);

  mergeZedSettings = pkgs.writeShellScript "zed-merge-settings" ''
    ${python}/bin/python3 <<'PY'
import json5
import json
import os
import sys

settings_dir = os.path.join(os.path.expanduser("~"), ".config", "zed")
path = os.path.join(settings_dir, "settings.json")

os.makedirs(settings_dir, exist_ok=True)

data = {}
if os.path.isfile(path):
    with open(path, encoding="utf-8") as f:
        raw = f.read()
    if raw.strip():
        try:
            data = json5.loads(raw)
        except Exception as e:
            print(f"zed: не удалось прочитать settings.json, пропуск: {e}", file=sys.stderr)
            sys.exit(0)

if not isinstance(data, dict):
    data = {}

# Убираем agent server, который ранее прописывался этим модулем.
agent_servers = data.get("agent_servers")
if isinstance(agent_servers, dict):
    agent_servers.pop("cursor", None)

languages = data.setdefault("languages", {})
nix = languages.setdefault("Nix", {})
nix["language_servers"] = ["nixd", "!nil"]

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
  '';
in
{
  home.activation.zedSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${mergeZedSettings}
  '';
}
