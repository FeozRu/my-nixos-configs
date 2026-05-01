# Dry-run: локальные сборки (на машине разработки, 2026-05-01)

Команды:

```bash
nix build .#nixosConfigurations.seevser-nixos.config.system.build.toplevel --dry-run
nix build .#nixosConfigurations.seevser-coding.config.system.build.toplevel --dry-run
```

Результат в момент проверки:

- **seevser-nixos**: сообщение вида «these **31** derivations will be built» — в основном конфигурация репозитория и HM, без полного списка имён в логе.
- **seevser-coding**: «these **90** derivations will be built» — в списке в том числе пакеты KDE Plasma, `moonlight-qt`, `openldap` (транзитивные зависимости; на coding **нет** оверлея `openldap` из lutris, но другие пакеты всё равно могут тянуть openldap).

После первого `nixos-rebuild` на новой машине и при заполненном бинарном кэше число локальных сборок обычно падает. Имеет смысл повторить `--dry-run` на целевом хосте.

# Оценка места (пример с той же машины)

| Путь | Размер (пример) |
|------|-----------------|
| `/nix/store` | ~198 GiB |
| `/run/current-system` (du -shL) | ~16 GiB |
| `~/.config` | ~15 GiB |
| `~/.cache` | ~29 GiB |
| `~/.local/state` | ~748 KiB |

Игры, Steam, загрузки и медиа в эти цифры не входят; `~/.cache` при необходимости можно чистить отдельно.

Btrfs scrub и Snapper для subvolume `/home` подключены только в профиле `seevser-nixos` ([modules/nixos/btrfs-home.nix](modules/nixos/btrfs-home.nix)). На `seevser-coding` при необходимости добавьте свой модуль под разметку диска.
