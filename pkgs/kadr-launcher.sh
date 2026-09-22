#!/bin/sh
# Запуск Kadr.
#
# Основную работу делает .kadr-wrapped (makeWrapper вокруг Electron); здесь —
# всё, что должно случиться до старта приложения.
@seed@
exec @out@/bin/.kadr-wrapped "$@"
