# Дизайн-стек для Claude Code

Четыре слоя, у каждого своя зона ответственности:

| Слой | Скилл | Отвечает за |
|---|---|---|
| 01 | `design-taste-frontend` | направление, композиция, визуальный язык |
| 02 | `impeccable` | ревизия готового, по явной команде |
| 03 | `emil-design-eng` | решения о движении: надо ли, сколько мс, какая кривая |
| 04 | `gsap-*` | реализация движения, только полоса B |
| 05 | `visual-qa` | рендер, снимок, критика по снимку, правка |

Слой 05 написан здесь и лежит в `skills/visual-qa/`. Остальные четыре — чужие
паки, они тянутся из upstream. Смысл пятого в том, что ни один из первых
четырёх не смотрит на результат: они судят по исходнику, а страницу видит
только человек.

## Установка

```bash
./install-design-stack.sh              # в ~/.claude/skills, на все проекты
./install-design-stack.sh --project .  # только в этот репозиторий
./install-design-stack.sh --no-gsap    # без полосы B
./install-design-stack.sh --dry-run    # посмотреть, что будет поставлено
```

Скрипт клонирует четыре репозитория и копирует **только отобранные** скиллы.
Паки целиком не ставятся: суммарно там больше сорока скиллов, а описания всех
включённых лежат в контексте каждой сессии постоянно, поэтому лишнее
размывает срабатывание.

Ставится десять папок:

- `visual-qa` — из этого репозитория

- `design-taste-frontend` из [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill)
- `impeccable` из [pbakaus/impeccable](https://github.com/pbakaus/impeccable)
- `emil-design-eng`, `review-animations`, `improve-animations` из [emilkowalski/skills](https://github.com/emilkowalski/skills)
- `gsap-core`, `gsap-timeline`, `gsap-scrolltrigger`, `gsap-react` из [greensock/gsap-skills](https://github.com/greensock/gsap-skills)

После установки скрипт кладёт рядом `design-stack-rules.md` — правила стыковки
слоёв. Их надо перенести в `CLAUDE.md`, иначе четыре скилла спорят об одних и
тех же вещах, а модель их усредняет.

## Проверка

Наберите `/skills` в Claude Code. Скилл, чьё имя занято другой командой,
пропускается молча, без ошибки — поэтому проверять надо глазами.

`review-animations` не появится в автоподхвате: у него стоит
`disable-model-invocation: true`, он вызывается только вручную как
`/review-animations`.

## Где это работает

| Поверхность | Читает скиллы из |
|---|---|
| Claude Code локально | `~/.claude/skills/`, проектный `.claude/skills/`, плагины |
| Cowork | только аккаунт claude.ai, локальную папку не читает |
| Облачные сессии | аккаунт claude.ai + `.claude/skills/` репозитория |
| Routines | как облачные, каждый запуск — свежая удалённая сессия |

Локальная установка не даёт «везде». Чтобы стек работал в Cowork и облаке,
скиллы надо дополнительно включить в аккаунте claude.ai через Customize.
Обратный мост, чтобы аккаунтовые скиллы подтянулись локально:

```bash
CLAUDE_CODE_SYNC_SKILLS=1 claude -p "list skills"
```

## Две полосы движения

Базовый Taste ставит Tailwind v4 + Motion и прямо запрещает «GSAP ради
красоты». GSAP включается только под скролл-нарратив, пиннинг секций,
таймлайны с метками или SplitText — то есть при `MOTION_INTENSITY` от 7.
Для таких проектов базовый Taste заменяется на `gpt-tasteskill`, вместе они
не ставятся.

## Лицензии

Impeccable — Apache 2.0. GSAP-скиллы — MIT. Скрипт ничего не вендорит в этот
репозиторий, он тянет исходники из upstream при каждом запуске.
