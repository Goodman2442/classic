#!/usr/bin/env bash
# Устанавливает пятислойный дизайн-стек в Claude Code.
#
#   ./install-design-stack.sh                  # в ~/.claude/skills (все проекты)
#   ./install-design-stack.sh --project .      # в ./.claude/skills (один проект)
#   ./install-design-stack.sh --no-gsap        # без полосы B
#   ./install-design-stack.sh --dry-run        # показать, что будет сделано
#   ./install-design-stack.sh --update         # обновить копии из upstream и поставить
#
# По умолчанию ставит из копий, лежащих в vendor/ этого репозитория: интернет
# не нужен, версия зафиксирована, апстрим не может её изменить задним числом.
# Происхождение и коммиты — в vendor/MANIFEST.md.
#
# Флаг --update заново клонирует четыре репозитория, обновляет vendor/ и ставит
# уже обновлённое. Это единственный режим, которому нужен GitHub.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET_MODE="user"
PROJECT_DIR=""
WITH_GSAP=1
DRY_RUN=0
UPDATE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      TARGET_MODE="project"
      PROJECT_DIR="${2:-.}"
      shift 2
      ;;
    --no-gsap) WITH_GSAP=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --update)  UPDATE=1; shift ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный аргумент: $1" >&2; exit 2 ;;
  esac
done

if [ "$TARGET_MODE" = "project" ]; then
  SKILLS_DIR="$(cd "$PROJECT_DIR" && pwd)/.claude/skills"
else
  SKILLS_DIR="$HOME/.claude/skills"
fi

# Порядок: имя папки | слой. Первый — наш собственный, лежит в skills/.
CORE="design-taste-frontend|01 направление и генерация
impeccable|02 ревизия готового
emil-design-eng|03 решения о движении
review-animations|03 проверка анимаций
improve-animations|03 поиск мест для движения"

GSAP="gsap-core|04 реализация, полоса B
gsap-timeline|04 реализация, полоса B
gsap-scrolltrigger|04 реализация, полоса B
gsap-react|04 реализация, полоса B"

PLAN="$CORE"
[ "$WITH_GSAP" -eq 1 ] && PLAN="$PLAN
$GSAP"

echo "Цель:     $SKILLS_DIR"
echo "Источник: $([ "$UPDATE" -eq 1 ] && echo "GitHub (обновление vendor/)" || echo "vendor/ этого репозитория")"
echo

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Будет установлено:"
  printf '  %-22s  %s\n' "visual-qa" "05 визуальная проверка (свой скилл)"
  echo "$PLAN" | while IFS='|' read -r name role; do
    [ -z "${name:-}" ] && continue
    printf '  %-22s  %s\n' "$name" "$role"
  done
  exit 0
fi

# --- обновление копий из upstream -------------------------------------------
if [ "$UPDATE" -eq 1 ]; then
  command -v git >/dev/null 2>&1 || { echo "Для --update нужен git." >&2; exit 1; }
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT

  # репозиторий | путь внутри репозитория | имя папки у нас
  SOURCES="Leonxlnx/taste-skill|skills/taste-skill|design-taste-frontend
pbakaus/impeccable|.claude/skills/impeccable|impeccable
emilkowalski/skills|skills/emil-design-eng|emil-design-eng
emilkowalski/skills|skills/review-animations|review-animations
emilkowalski/skills|skills/improve-animations|improve-animations
greensock/gsap-skills|skills/gsap-core|gsap-core
greensock/gsap-skills|skills/gsap-timeline|gsap-timeline
greensock/gsap-skills|skills/gsap-scrolltrigger|gsap-scrolltrigger
greensock/gsap-skills|skills/gsap-react|gsap-react"

  echo "$SOURCES" | while IFS='|' read -r repo src name; do
    [ -z "${repo:-}" ] && continue
    dest="$WORK/$(echo "$repo" | tr '/' '_')"
    if [ ! -d "$dest" ]; then
      echo "  клонирую $repo"
      git clone --depth 1 --quiet "https://github.com/$repo.git" "$dest"
    fi
    if [ ! -d "$dest/$src" ]; then
      echo "  ПРОПУСК $name — не найдено $repo/$src, оставляю прежнюю копию" >&2
      continue
    fi
    rm -rf "$HERE/vendor/skills/$name"
    cp -R "$dest/$src" "$HERE/vendor/skills/$name"
    echo "  обновлён $name"
  done
  echo "  vendor/ обновлён; сверьте diff перед коммитом"
  echo
fi

# --- установка ---------------------------------------------------------------
mkdir -p "$SKILLS_DIR"

install_dir() {
  src="$1"; name="$2"
  if [ ! -d "$src" ]; then
    echo "  ПРОПУСК $name — нет $src" >&2
    return
  fi
  rm -rf "${SKILLS_DIR:?}/$name"
  cp -R "$src" "$SKILLS_DIR/$name"
  echo "  поставлен $name"
}

install_dir "$HERE/skills/visual-qa" visual-qa
echo "$PLAN" | while IFS='|' read -r name role; do
  [ -z "${name:-}" ] && continue
  install_dir "$HERE/vendor/skills/$name" "$name"
done

# Правила стыковки слоёв. Без них скиллы спорят об одном и том же,
# а модель их усредняет.
RULES_FILE="$(cd "$SKILLS_DIR/.." && pwd)/design-stack-rules.md"
cat > "$RULES_FILE" <<'RULES'
## Дизайн-стек

Слои и зоны ответственности:
- design-taste-frontend — направление, композиция, визуальный язык
- impeccable — ревизия готового, только по явной команде
- emil-design-eng — все решения о движении: надо ли, сколько мс, какая кривая
- gsap-* — реализация движения, только в полосе B
- visual-qa — рендер, снимок, критика по снимку, правка

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
6. Интерфейс не считается готовым, пока его не увидели: после сборки или
   правки вёрстки прогонять visual-qa. Максимум два цикла правок, дальше
   замечания отдаются человеку списком.
RULES

echo
echo "Готово."
echo
echo "Правила стыковки слоёв записаны в:"
echo "  $RULES_FILE"
echo "Вставьте их в CLAUDE.md — без этого слои спорят друг с другом."
echo
echo "Проверка: откройте Claude Code и наберите /skills — в списке должны быть"
echo "design-taste-frontend, impeccable, emil-design-eng, visual-qa."
echo "Скилл с именем, занятым другой командой, пропускается молча."
