#!/usr/bin/env bash
# Собирает zip-архивы скиллов для загрузки в аккаунт claude.ai.
#
#   ./make-zips.sh              # ядро: 5 скиллов, которые нужны везде
#   ./make-zips.sh --all        # все десять, включая полосу B
#
# Загружаются они по одному через Customize -> Skills на claude.ai или в
# десктопном приложении. Оттуда синхронизируются в Cowork, облачные сессии и
# routines — эти поверхности папку ~/.claude/skills/ не читают вообще.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/dist"

# Ядро: работает на любом проекте. GSAP-скиллы нужны только в полосе B,
# а лишние записи засоряют меню и размывают срабатывание.
CORE="design-council design-taste-frontend impeccable emil-design-eng review-animations visual-qa"
EXTRA="improve-animations gsap-core gsap-timeline gsap-scrolltrigger gsap-react"

LIST="$CORE"
[ "${1:-}" = "--all" ] && LIST="$CORE $EXTRA"

command -v zip >/dev/null 2>&1 || { echo "Нужна утилита zip." >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"

for name in $LIST; do
  if [ -d "$HERE/skills/$name" ]; then
    src="$HERE/skills"
  elif [ -d "$HERE/vendor/skills/$name" ]; then
    src="$HERE/vendor/skills"
  else
    echo "  ПРОПУСК $name — не найден" >&2
    continue
  fi
  # Архив содержит саму папку скилла, а SKILL.md лежит внутри неё.
  (cd "$src" && zip -qr "$OUT/$name.zip" "$name" -x '*.DS_Store')
  printf '  %-24s %s\n' "$name" "$(du -h "$OUT/$name.zip" | cut -f1)"
done

echo
echo "Архивы в: $OUT"
echo "Загрузите каждый через Customize -> Skills на claude.ai."
echo "Если загрузчик не примет архив, пересоберите его так, чтобы SKILL.md"
echo "лежал в корне: cd skills/<имя> && zip -r ../../dist/<имя>.zip ."
