#!/usr/bin/env bash
# Устанавливает четырёхслойный дизайн-стек в Claude Code.
#
#   ./install-design-stack.sh                  # в ~/.claude/skills (все проекты)
#   ./install-design-stack.sh --project .      # в ./.claude/skills (один проект)
#   ./install-design-stack.sh --no-gsap        # без полосы B
#   ./install-design-stack.sh --dry-run        # показать, что будет сделано
#
# Ставит только отобранные скиллы, а не паки целиком: описания всех включённых
# скиллов лежат в контексте каждой сессии постоянно, поэтому лишнее размывает
# срабатывание.

set -euo pipefail

TARGET_MODE="user"
PROJECT_DIR=""
WITH_GSAP=1
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      TARGET_MODE="project"
      PROJECT_DIR="${2:-.}"
      shift 2
      ;;
    --no-gsap) WITH_GSAP=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный аргумент: $1" >&2; exit 2 ;;
  esac
done

if [ "$TARGET_MODE" = "project" ]; then
  SKILLS_DIR="$(cd "$PROJECT_DIR" && pwd)/.claude/skills"
else
  SKILLS_DIR="$HOME/.claude/skills"
fi

command -v git >/dev/null 2>&1 || { echo "Нужен git." >&2; exit 1; }

echo "Цель: $SKILLS_DIR"
echo

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# repo                          исходная папка                       имя команды
PLAN="
Leonxlnx/taste-skill|skills/taste-skill|design-taste-frontend|01 направление и генерация
pbakaus/impeccable|.claude/skills/impeccable|impeccable|02 ревизия готового
emilkowalski/skills|skills/emil-design-eng|emil-design-eng|03 решения о движении
emilkowalski/skills|skills/review-animations|review-animations|03 проверка анимаций
emilkowalski/skills|skills/improve-animations|improve-animations|03 поиск мест для движения
"

if [ "$WITH_GSAP" -eq 1 ]; then
  PLAN="$PLAN
greensock/gsap-skills|skills/gsap-core|gsap-core|04 реализация, полоса B
greensock/gsap-skills|skills/gsap-timeline|gsap-timeline|04 реализация, полоса B
greensock/gsap-skills|skills/gsap-scrolltrigger|gsap-scrolltrigger|04 реализация, полоса B
greensock/gsap-skills|skills/gsap-react|gsap-react|04 реализация, полоса B
"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Будет установлено:"
  echo "$PLAN" | while IFS='|' read -r repo src name role; do
    [ -z "${repo:-}" ] && continue
    printf '  %-22s  %s\n' "$name" "$role"
  done
  exit 0
fi

mkdir -p "$SKILLS_DIR"

clone_once() {
  repo="$1"
  dest="$WORK/$(echo "$repo" | tr '/' '_')"
  if [ ! -d "$dest" ]; then
    echo "  клонирую $repo"
    git clone --depth 1 --quiet "https://github.com/$repo.git" "$dest"
  fi
}

echo "$PLAN" | while IFS='|' read -r repo src name role; do
  [ -z "${repo:-}" ] && continue
  clone_once "$repo"
  SRC="$WORK/$(echo "$repo" | tr '/' '_')/$src"
  if [ ! -d "$SRC" ]; then
    echo "  ПРОПУСК $name — не найдено $repo/$src (структура репозитория изменилась)" >&2
    continue
  fi
  rm -rf "${SKILLS_DIR:?}/$name"
  cp -R "$SRC" "$SKILLS_DIR/$name"
  echo "  поставлен $name"
done

# Правила стыковки слоёв. Без них четыре скилла спорят об одном и том же,
# а модель их усредняет.
RULES_FILE="$(cd "$SKILLS_DIR/.." && pwd)/design-stack-rules.md"
cat > "$RULES_FILE" <<'RULES'
## Дизайн-стек

Слои и зоны ответственности:
- design-taste-frontend — направление, композиция, визуальный язык
- impeccable — ревизия готового, только по явной команде
- emil-design-eng — все решения о движении: надо ли, сколько мс, какая кривая
- gsap-* — реализация движения, только в полосе B

Правила:
1. Длительности и кривые берутся у Emil. Ручка MOTION_INTENSITY у Taste
   задаёт количество и амбицию движения, но не миллисекунды.
2. Impeccable не запускается автоматически после Taste. Пре-флайта Taste
   достаточно для первой версии; Impeccable — отдельный второй проход.
3. Лестница выбора библиотеки: CSS-переход → Motion → GSAP. GSAP оправдан
   таймлайном с метками, скролл-пиннингом или SplitText. Строку
   «рекомендуй GSAP по умолчанию» из описания gsap-scrolltrigger игнорировать.
4. Любой код, написанный по GSAP-скиллам, проходит review-animations:
   сами они не знают про prefers-reduced-motion и бюджеты производительности.
5. Один акцент, одна система радиусов, ноль длинных тире — правила Taste,
   они выше стилевых предпочтений Impeccable.
RULES

echo
echo "Готово."
echo
echo "Правила стыковки слоёв записаны в:"
echo "  $RULES_FILE"
echo "Вставьте их в CLAUDE.md — без этого слои спорят друг с другом."
echo
echo "Проверка: откройте Claude Code и наберите /skills — в списке должны быть"
echo "design-taste-frontend, impeccable, emil-design-eng, review-animations."
echo "Скилл с именем, занятым другой командой, пропускается молча."
