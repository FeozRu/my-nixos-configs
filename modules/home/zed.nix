{ pkgs, lib, ... }:

let
  cursorAgentExe = lib.getExe pkgs.cursor-cli;

  python = pkgs.python3.withPackages (ps: [ ps.json5 ]);

  mergeCursorAgent = pkgs.writeShellScript "zed-merge-cursor-agent" ''
    ${python}/bin/python3 <<'PY'
import json5
import json
import os
import sys

exe = "${cursorAgentExe}"
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

agent_servers = data.setdefault("agent_servers", {})
agent_servers["cursor"] = {
    "type": "custom",
    "command": exe,
    "args": ["acp"],
}

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
  '';
in
{
  home.activation.zedCursorAgent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${mergeCursorAgent}
  '';
}
