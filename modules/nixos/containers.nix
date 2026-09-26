{ ... }:

{
  # Podman в rootless-режиме: обычный пользователь обходится без прав root,
  # образы и контейнеры живут в ~/.local/share/containers.
  virtualisation.podman.enable = true;

  # Намеренно НЕ включаем dockerSocket и НЕ добавляем пользователя в группу
  # podman: и то, и другое открывает доступ к системному (rootful) сокету.
  # Для rootless docker-совместимый сокет поднимается позже пользовательским
  # юнитом: systemctl --user enable --now podman.socket
  # (сокет появится в $XDG_RUNTIME_DIR/podman/podman.sock).
}
