#!/usr/bin/env bash
# Скрипт поставки tessera — единый механизм установки для любого харнеса.
# Источники раскладываются клонами ветки main в хранилище ~/.local/share/tessera/,
# навыки связываются симлинками с каталогами навыков найденных харнесов, для backlog
# ставится лаунчер на PATH. С параметром --project правила плагина копируются в
# .tessera/rules/ проекта и подключаются секцией в AGENTS.md. Средства харнесов
# для установки плагинов не используются.
# Запускается из клона (scripts/install.sh) или одной командой (curl ... | bash):
# клон служит только способом получить скрипт, источники всегда берутся из репозиториев.

set -euo pipefail

# Без терминала git не ждёт учётных данных, а сразу сообщает об ошибке.
export GIT_TERMINAL_PROMPT=0

PROJECT_DIR="$PWD"
RAW_URL="https://raw.githubusercontent.com/united-software-platform/tessera/main/scripts/install.sh"
LAUNCHER_MARKER="создан скриптом поставки tessera"

# Компоненты поставки: имя (каталог клона в хранилище) | репозиторий |
# каталог навыков внутри клона | каталог правил внутри клона.
COMPONENTS=(
  "tessera|https://github.com/united-software-platform/tessera.git|plugins/tessera-plugin/skills|plugins/tessera-plugin/rules"
  "formular|https://github.com/united-software-platform/formular.git|plugin/backlog/skills"
  "mattpocock-skills|https://github.com/mattpocock/skills.git|skills/engineering skills/productivity"
)

# Таблица харнесов: имя | признак в домашнем каталоге | команда в PATH |
# пользовательский каталог навыков | проектный каталог навыков.
# Признак пуст, когда харнес узнаётся только по каталогу. Каталог-цель один на путь:
# ZCode, Codex и Gemini CLI делят ~/.agents/skills/.
HARNESSES=(
  "zcode|~/.zcode||~/.agents/skills|.agents/skills"
  "codex|~/.codex|codex|~/.agents/skills|.agents/skills"
  "gemini|~/.gemini|gemini|~/.agents/skills|.agents/skills"
  "claude|~/.claude|claude|~/.claude/skills|.claude/skills"
  "opencode|~/.config/opencode|opencode|~/.config/opencode/skills|.agents/skills"
)

PROFILE_ARG=""
HARNESS_ARG=""
SKILLS_DIR=""
RULES_ARG=""
REGISTRY=0
PROJECT_MODE=0
YES=0
UNINSTALL=0
INTERACTIVE=0

# --- Сообщения -------------------------------------------------------------

say() { printf '%s\n' "$*"; }

warn() { printf 'Предупреждение: %s\n' "$*" >&2; }

die() { printf 'Ошибка: %s\n' "$*" >&2; exit "${2:-1}"; }

usage_error() {
  printf 'Ошибка: %s\n\n' "$*" >&2
  usage >&2
  exit 2
}

usage() {
  cat <<EOF
Использование: scripts/install.sh [параметры]
Одной командой: curl -fsSL ${RAW_URL} | bash

Скрипт поставки tessera — единый механизм установки для любого харнеса: источники
раскладываются клонами ветки main в хранилище ~/.local/share/tessera/, навыки
связываются симлинками с каталогами навыков найденных харнесов, для backlog ставится
лаунчер ~/.local/bin/backlog. Запуск из клона даёт тот же результат.

Параметры:

  Параметр                         Действие                                   Умолчание
  --profile full|backlog|tessera   состав установки                          full
                                  full — tessera, backlog и mattpocock-skills
                                  backlog — tessera и backlog
                                  tessera — только tessera
  --project                        регистрация в текущем проекте             пользовательские каталоги
  --rules all|none|<список>        какие правила подключить к проекту        все (в проекте
                                  с --project: копии в .tessera/rules/      с копиями — прежний
                                  и секция в AGENTS.md; имена — имена       перечень)
                                  файлов правил без .md через запятую
  --harness <список>               ограничить харнесы через запятую          все найденные
  --skills-dir <путь>              дополнительный каталог навыков            —
  --registry                       печатать реестр поставки в JSON и выйти   —
  --yes                            без диалога                               диалог при терминале
  --uninstall                      удалить созданное скриптом                —
  -h, --help                       справка                                   —

Повторный запуск обновляет клоны и пересоздаёт ссылки; профиль прежней установки
сохраняется, пока параметр --profile не задал иной. Секция правил AGENTS.md
переписывается, когда её текст изменился; отключённый (--rules none) перечень
не запоминается — без --rules следующий запуск снова предложит прежний перечень
копий, а без копий — все правила.

Харнесы (признак | пользовательский каталог | проектный каталог):
  zcode      ~/.zcode                     ~/.agents/skills           .agents/skills
  codex      ~/.codex или codex в PATH    ~/.agents/skills           .agents/skills
  gemini     ~/.gemini или gemini в PATH  ~/.agents/skills           .agents/skills
  claude     ~/.claude или claude в PATH  ~/.claude/skills           .claude/skills
  opencode   ~/.config/opencode           ~/.config/opencode/skills  .agents/skills
             или opencode в PATH
Для харнеса вне таблицы передайте его каталог навыков параметром --skills-dir.

Коды возврата:
  0   поставка выполнена и прошла самопроверку, либо ничего не требовалось
  1   харнесы не найдены, источник не получен или самопроверка не пройдена
  2   ошибка в параметрах запуска
EOF
}

# --- Пути ------------------------------------------------------------------

# Физический путь: симлинки разрешаются в существующей части, отсутствующий остаток
# добавляется как есть. Заменяет realpath -f, которого нет везде.
canonical() {
  local path="$1" rest="" base
  while [ -n "$path" ] && [ ! -e "$path" ]; do
    rest="/$(basename "$path")$rest"
    path="$(dirname "$path")"
  done
  base="$(cd "${path:-/}" 2>/dev/null && pwd -P)" || return 1
  printf '%s%s' "$base" "$rest"
}

# Путь для отчёта: домашний каталог сокращается до ~ (тильда экранирована,
# иначе bash раскроет её обратно в домашний путь).
display() { printf '%s' "${1/#$HOME_DIR/\~}"; }

expand_home() { printf '%s' "${1/#\~/$HOME_DIR}"; }

# Последняя непустая строка текста — итог сообщения git.
last_line() { printf '%s\n' "$1" | sed '/^[[:space:]]*$/d' | tail -n 1; }

# --- Таблицы ---------------------------------------------------------------

# Поле строки таблицы по номеру: поля разделены вертикальной чертой.
field() { # строка таблицы, номер поля
  local fields=()
  IFS='|' read -r -a fields <<< "$1"
  printf '%s' "${fields[$(( $2 - 1 ))]}"
}

harness_row() { # имя харнеса → строка таблицы
  local row
  for row in "${HARNESSES[@]}"; do
    if [ "$(field "$row" 1)" = "$1" ]; then printf '%s\n' "$row"; return 0; fi
  done
  return 1
}

harness_is_found() { # строка таблицы
  local sign cmd
  sign="$(field "$1" 2)"
  cmd="$(field "$1" 3)"
  if [ -n "$sign" ] && [ -d "$(expand_home "$sign")" ]; then return 0; fi
  if [ -n "$cmd" ] && command -v "$cmd" >/dev/null 2>&1; then return 0; fi
  return 1
}

# Каталог навыков харнеса по режиму запуска: проектному или пользовательскому.
harness_target() { # строка таблицы
  if [ "$PROJECT_MODE" -eq 1 ]; then
    printf '%s' "$PROJECT_DIR/$(field "$1" 5)"
  else
    printf '%s' "$(expand_home "$(field "$1" 4)")"
  fi
}

component_row() { # имя компонента → строка таблицы
  local row
  for row in "${COMPONENTS[@]}"; do
    if [ "$(field "$row" 1)" = "$1" ]; then printf '%s\n' "$row"; return 0; fi
  done
  return 1
}

component_url() { printf '%s' "$(field "$(component_row "$1")" 2)"; }

component_skill_dirs() { printf '%s' "$(field "$(component_row "$1")" 3)"; }

component_rules_dir() { printf '%s' "$(field "$(component_row "$1")" 4)"; }

component_names() {
  local row
  for row in "${COMPONENTS[@]}"; do printf '%s ' "$(field "$row" 1)"; done
}

# --- Профили ---------------------------------------------------------------

profile_components() { # профиль → компоненты через пробел
  case "$1" in
    full) printf '%s' "tessera formular mattpocock-skills" ;;
    backlog) printf '%s' "tessera formular" ;;
    tessera) printf '%s' "tessera" ;;
  esac
}

profile_summary() {
  case "$1" in
    full) printf '%s' "tessera, backlog и mattpocock-skills" ;;
    backlog) printf '%s' "tessera и backlog" ;;
    tessera) printf '%s' "только tessera" ;;
  esac
}

profile_has() { # профиль, компонент
  local component
  for component in $(profile_components "$1"); do
    if [ "$component" = "$2" ]; then return 0; fi
  done
  return 1
}

# Профиль прежней установки выводится из хранилища: есть клон formular — backlog выбран,
# есть клон mattpocock-skills — полный набор. Пусто, когда установки не было.
installed_profile() {
  if [ -d "$STORAGE/mattpocock-skills" ]; then printf '%s' full
  elif [ -d "$STORAGE/formular" ]; then printf '%s' backlog
  elif [ -d "$STORAGE/tessera" ]; then printf '%s' tessera
  fi
  return 0
}

# --- Диалог ----------------------------------------------------------------

# Вопрос с ответом из /dev/tty; конец ввода равен пустому ответу. Диалог читает
# терминал, а не стандартный ввод, поэтому работает и в конвейере curl | bash.
# Ответ записывается в переменную вызывающей функции, поэтому локальная переменная
# здесь названа иначе — одноимённая заслонила бы её.
ask() { # приглашение, имя переменной для ответа
  local reply=""
  printf '%s' "$1"
  IFS= read -r reply </dev/tty || reply=""
  printf '\n'
  printf -v "$2" '%s' "$reply"
}

# Согласие в диалоге: пустой ответ принимает умолчание (yes | no).
confirm() { # приглашение, умолчание
  local answer
  ask "$1" answer
  if [ -z "$answer" ]; then [ "$2" = "yes" ]; return; fi
  case "$answer" in
    [yY] | [yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

choose_profile() { # профиль по умолчанию
  local answer
  say ""
  say "Профиль поставки:"
  say "  full     — tessera, backlog и mattpocock-skills"
  say "  backlog  — tessera и backlog"
  say "  tessera  — только tessera"
  while :; do
    ask "Профиль [$1]: " answer
    answer="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')"
    case "$answer" in
      "") PROFILE="$1"; return ;;
      full | backlog | tessera) PROFILE="$answer"; return ;;
      *) say "Введите full, backlog или tessera." ;;
    esac
  done
}

# Входит ли слово в перечень через пробел.
list_has() { # перечень, слово
  case " $1 " in *" $2 "*) return 0 ;; esac
  return 1
}

# Найденные харнесы показываются для подтверждения: Enter оставляет все, номера
# или имена через запятую оставляют выбранные.
choose_harnesses() {
  local row answer token number matched picked_names=""
  local picked=()
  if [ "${#SELECTED[@]}" -eq 0 ]; then return 0; fi
  say ""
  say "Найденные харнесы:"
  number=0
  for row in "${SELECTED[@]}"; do
    number=$(( number + 1 ))
    say "  $number. $(field "$row" 1) — $(display "$(harness_target "$row")")"
  done
  while :; do
    ask "Регистрировать: номера или имена через запятую, Enter — все: " answer
    if [ -z "$answer" ]; then return 0; fi
    picked=()
    picked_names=""
    matched=1
    for token in $(printf '%s' "$answer" | tr ',' ' '); do
      row="$(harness_row "$token" || true)"
      case "$token" in
        "" | *[!0-9]*) ;;
        *)
          number="$(printf '%s' "$token" | sed 's/^0*//')"
          if [ -n "$number" ] && [ "$number" -le "${#SELECTED[@]}" ]; then
            row="${SELECTED[$(( number - 1 ))]}"
          fi
          ;;
      esac
      if [ -z "$row" ]; then
        say "  не распознано: $token"
        matched=0
        continue
      fi
      if ! list_has "$picked_names" "$(field "$row" 1)"; then
        picked+=("$row")
        picked_names="$picked_names $(field "$row" 1)"
      fi
    done
    if [ "$matched" -eq 1 ] && [ "${#picked[@]}" -gt 0 ]; then
      SELECTED=("${picked[@]}")
      compute_targets
      return 0
    fi
    say "  укажите номер или имя харнеса из списка."
  done
}

# --- Харнесы и каталоги назначения -----------------------------------------

# Отбор харнесов: найденные по признакам таблицы (found) либо все строки таблицы
# (all — удаление не зависит от того, найдены ли харнесы сейчас), суженные
# параметром --harness.
select_harnesses() { # found | all
  local row want found matched
  SELECTED=()
  for row in "${HARNESSES[@]}"; do
    if [ "$1" = "all" ] || harness_is_found "$row"; then SELECTED+=("$row"); fi
  done
  [ -n "$HARNESS_ARG" ] || return 0
  found=(${SELECTED[@]+"${SELECTED[@]}"})
  SELECTED=()
  for want in $(printf '%s' "$HARNESS_ARG" | tr ',' ' '); do
    harness_row "$want" >/dev/null || usage_error "неизвестный харнес: $want — zcode, codex, gemini, claude, opencode"
    matched=0
    for row in ${found[@]+"${found[@]}"}; do
      if [ "$(field "$row" 1)" = "$want" ]; then SELECTED+=("$row"); matched=1; fi
    done
    if [ "$matched" -eq 0 ]; then say "Харнес $want не найден — пропущен."; fi
  done
}

add_target() { # путь; каталог-цель один на путь
  local existing
  for existing in ${TARGETS[@]+"${TARGETS[@]}"}; do
    if [ "$existing" = "$1" ]; then return 0; fi
  done
  TARGETS+=("$1")
}

# Каталоги назначения: каталоги навыков отобранных харнесов плюс --skills-dir.
compute_targets() {
  local row
  TARGETS=()
  for row in ${SELECTED[@]+"${SELECTED[@]}"}; do add_target "$(harness_target "$row")"; done
  if [ -n "$SKILLS_DIR" ]; then add_target "$SKILLS_DIR"; fi
}

# --- Хранилище -------------------------------------------------------------

# Ссылка создана скриптом, когда её цель лежит в хранилище — целиком или в клоне
# одного компонента.
link_is_ours() { # путь ссылки, предел цели внутри хранилища
  local link="$1" bound="${2:-$STORAGE}" target
  [ -L "$link" ] || return 1
  target="$(readlink "$link")"
  case "$target" in "$bound"/*) return 0 ;; esac
  return 1
}

clone_is_dirty() { # компонент
  [ -n "$(git -C "$STORAGE/$1" status --porcelain </dev/null 2>/dev/null)" ]
}

# Удаляет каталог в хранилище: путь обязан лежать внутри хранилища.
remove_storage_dir() { # путь
  case "$1" in "$STORAGE" | "$STORAGE"/*) ;; *) die "отказ удалять вне хранилища: $1" ;; esac
  rm -rf -- "$1"
}

# Приводит клоны профиля к ветке main: новый клон либо git pull --ff-only.
# Клон с локальными изменениями не обновляется, а называется в отчёте.
ensure_sources() {
  local component url dir output
  SOURCE_STATE=()
  for component in "${WANTED[@]}"; do
    url="$(component_url "$component")"
    dir="$STORAGE/$component"
    if [ ! -d "$dir" ]; then
      mkdir -p "$STORAGE"
      say "Клонирую $component..."
      if ! output="$(git clone --branch main --quiet "$url" "$dir" </dev/null 2>&1)"; then
        die "не удалось клонировать $component: $(last_line "$output")"
      fi
      SOURCE_STATE+=("$component|склонирован")
      continue
    fi
    if [ ! -e "$dir/.git" ]; then
      die "в хранилище лежит не клон: $(display "$dir") — удалите каталог вручную"
    fi
    if clone_is_dirty "$component"; then
      SOURCE_STATE+=("$component|не обновлён: есть локальные изменения")
      continue
    fi
    say "Обновляю $component..."
    if ! output="$(LC_ALL=C git -C "$dir" pull --ff-only </dev/null 2>&1)"; then
      die "не удалось обновить клон $component: $(last_line "$output")"
    fi
    case "$output" in
      *"Already up to date"*) SOURCE_STATE+=("$component|актуален") ;;
      *) SOURCE_STATE+=("$component|обновлён") ;;
    esac
  done
}

# Клоны в хранилище, которых нет в профиле, снимаются: параметры запуска
# переопределяют состав прежней установки. Свои ссылки разыскиваются и во всех
# пользовательских каталогах таблицы — хранилище общее для всех установок.
drop_components() {
  local component target entry removed
  local kept=("${TARGETS[@]}") row
  for row in "${HARNESSES[@]}"; do add_target "$(expand_home "$(field "$row" 4)")"; done
  for component in ${DROPPED[@]+"${DROPPED[@]}"}; do
    removed=0
    for target in "${TARGETS[@]}"; do
      [ -d "$target" ] || continue
      for entry in "$target"/*; do
        if link_is_ours "$entry" "$STORAGE/$component"; then
          rm -- "$entry"
          removed=$(( removed + 1 ))
        fi
      done
    done
    if [ "$component" = "formular" ] && launcher_is_ours; then
      rm -- "$LAUNCHER"
      LAUNCHER_REMOVED=1
    fi
    remove_storage_dir "$STORAGE/$component"
    DROPPED_REPORT+=("$component|$removed")
  done
  TARGETS=("${kept[@]}")
}

# Навыки источников профиля — каталоги с SKILL.md в клонах хранилища.
collect_skills() {
  local component sub dir path names=""
  SKILL_COMPONENT=()
  SKILL_SOURCE=()
  SKILL_NAME=()
  for component in "${WANTED[@]}"; do
    for sub in $(component_skill_dirs "$component"); do
      dir="$STORAGE/$component/$sub"
      if [ ! -d "$dir" ]; then die "в клоне $component нет каталога навыков $sub"; fi
      for path in "$dir"/*/; do
        if [ ! -f "${path}SKILL.md" ]; then continue; fi
        path="${path%/}"
        if list_has "$names" "${path##*/}"; then
          die "имя навыка ${path##*/} встречается в двух источниках профиля"
        fi
        names="$names ${path##*/}"
        SKILL_COMPONENT+=("$component")
        SKILL_SOURCE+=("$path")
        SKILL_NAME+=("${path##*/}")
      done
    done
  done
}

# Снимает в каталоге свою ссылку, цель которой исчезла: навыка нет в источнике.
remove_stale_links() { # каталог
  local entry
  for entry in "$1"/*; do
    if link_is_ours "$entry" && [ ! -e "$entry" ]; then
      rm -- "$entry"
      STALE+=("$entry")
    fi
  done
}

link_skills() {
  local target i entry was_own
  CREATED=0
  RECREATED=0
  for target in "${TARGETS[@]}"; do
    mkdir -p "$target"
    remove_stale_links "$target"
    for i in "${!SKILL_NAME[@]}"; do
      entry="$target/${SKILL_NAME[$i]}"
      was_own=0
      if [ -L "$entry" ]; then
        # Чужой элемент остаётся на месте и называется в отчёте.
        if ! link_is_ours "$entry"; then SKIPPED+=("$entry"); continue; fi
        was_own=1
      elif [ -e "$entry" ]; then
        SKIPPED+=("$entry")
        continue
      fi
      ln -sfn "${SKILL_SOURCE[$i]}" "$entry" || die "не удалось создать ссылку $(display "$entry")"
      if [ "$was_own" -eq 1 ]; then RECREATED=$(( RECREATED + 1 )); else CREATED=$(( CREATED + 1 )); fi
      LINK_DIR+=("$target")
      LINK_NAME+=("${SKILL_NAME[$i]}")
    done
  done
}

# --- Правила проекта --------------------------------------------------------

# Путь правила внутри клона tessera по имени файла без расширения.
rule_rel() { printf '%s' "$(component_rules_dir tessera)/$1.md"; }

# Совпадает ли файл с какой-либо редакцией правила в истории клона tessera:
# совпадает — копия поставлена скриптом (актуальная или устаревшая), нет —
# изменена вручную. Сравнение идёт с текущим состоянием, затем с редакциями git.
copy_is_ours() { # файл копии, путь правила в клоне
  local copy="$1" rel="$2" rev dir="$STORAGE/tessera"
  if cmp -s "$copy" "$dir/$rel"; then return 0; fi
  while IFS= read -r rev; do
    [ -n "$rev" ] || continue
    if git -C "$dir" show "$rev:$rel" 2>/dev/null | cmp -s - "$copy"; then return 0; fi
  done < <(git -C "$dir" log --format=%H -- "$rel" </dev/null 2>/dev/null)
  return 1
}

rule_src_by_name() { # имя правила → файл в клоне
  local i
  for i in ${RULE_NAME[@]+"${!RULE_NAME[@]}"}; do
    if [ "${RULE_NAME[$i]}" = "$1" ]; then printf '%s' "${RULE_SRC[$i]}"; return 0; fi
  done
  return 1
}

rule_stamp() { date +%Y%m%d%H%M%S; }

stamp_human() {
  printf '%s-%s-%s в %s:%s:%s' "${1:0:4}" "${1:4:2}" "${1:6:2}" "${1:8:2}" "${1:10:2}" "${1:12:2}"
}

# Перечень правил источников — имена файлов без расширения через пробел.
all_rules_names() {
  local i out=""
  for i in ${RULE_NAME[@]+"${!RULE_NAME[@]}"}; do out="$out ${RULE_NAME[$i]}"; done
  printf '%s' "${out# }"
}

# Перечень через пробел → «a, b, c» для сообщений.
rules_csv_display() { printf '%s' "$1" | sed -e 's/^ *//' -e 's/  */ /g' | tr ' ' ',' | sed 's/,/, /g'; }

# Инвентарь правил источников: имя, название из заголовка, файл в клоне.
collect_rules() {
  RULE_NAME=()
  RULE_TITLE=()
  RULE_SRC=()
  [ "$PROJECT_MODE" -eq 1 ] || return 0
  local dir path name first title
  dir="$STORAGE/tessera/$(component_rules_dir tessera)"
  if [ ! -d "$dir" ]; then
    die "в клоне tessera нет каталога правил $(component_rules_dir tessera)"
  fi
  for path in "$dir"/*.md; do
    if [ ! -f "$path" ]; then continue; fi
    name="$(basename "$path" .md)"
    first="$(head -n 1 "$path")"
    case "$first" in
      "# "*) title="${first#\# }" ;;
      *) title="$name" ;;
    esac
    RULE_NAME+=("$name")
    RULE_TITLE+=("$title")
    RULE_SRC+=("$path")
  done
}

# Умолчание перечня: имена правил, копии которых лежат в проекте; копий нет — все.
default_rules() {
  local entry name i derived=""
  if [ -d "$RULES_DIR" ]; then
    for entry in "$RULES_DIR"/*.md; do
      if [ ! -f "$entry" ]; then continue; fi
      name="$(basename "$entry" .md)"
      for i in ${RULE_NAME[@]+"${!RULE_NAME[@]}"}; do
        if [ "${RULE_NAME[$i]}" = "$name" ]; then
          if ! list_has "$derived" "$name"; then derived="$derived $name"; fi
        fi
      done
    done
  fi
  derived="${derived# }"
  if [ -n "$derived" ]; then printf '%s' "$derived"; else all_rules_names; fi
}

choose_rules() { # перечень по умолчанию
  local answer token num i name picked known def="$1"
  say ""
  say "Правила tessera: копии в $(display "$RULES_DIR"), секция в $(display "$AGENTS_FILE")"
  for i in ${RULE_NAME[@]+"${!RULE_NAME[@]}"}; do
    say "  $(( i + 1 )). ${RULE_NAME[$i]} — ${RULE_TITLE[$i]}"
  done
  while :; do
    if [ -n "$def" ]; then
      ask "Подключить: all, none, номера или имена через запятую, Enter — прежний перечень ($(rules_csv_display "$def")): " answer
    else
      ask "Подключить: all, none, номера или имена через запятую, Enter — все правила: " answer
    fi
    if [ -z "$answer" ]; then RULES_SEL="$def"; return; fi
    case "$answer" in
      [Aa][Ll][Ll]) RULES_SEL="$(all_rules_names)"; return ;;
      [Nn][Oo][Nn][Ee]) RULES_SEL=""; return ;;
    esac
    picked=""
    known=1
    for token in $(printf '%s' "$answer" | tr ',' ' '); do
      name=""
      case "$token" in
        *[!0-9]*) ;;
        *)
          num="$(printf '%s' "$token" | sed 's/^0*//')"
          if [ -n "$num" ] && [ "$num" -le "${#RULE_NAME[@]}" ]; then
            name="${RULE_NAME[$(( num - 1 ))]}"
          fi
          ;;
      esac
      if [ -z "$name" ]; then
        for i in ${RULE_NAME[@]+"${!RULE_NAME[@]}"}; do
          if [ "${RULE_NAME[$i]}" = "$token" ]; then name="$token"; break; fi
        done
      fi
      if [ -z "$name" ]; then
        say "  не распознано: $token"
        known=0
        continue
      fi
      if ! list_has "$picked" "$name"; then picked="$picked $name"; fi
    done
    if [ "$known" -eq 1 ] && [ -n "$picked" ]; then
      RULES_SEL="${picked# }"
      return
    fi
    say "  укажите all, none, номера или имена правил из списка."
  done
}

# Перечень подключаемых правил: --rules, диалог либо умолчание; неизвестное
# имя останавливает запуск ошибкой параметров, не меняя проект.
resolve_rules() {
  local token i known
  RULES_SEL=""
  [ "$PROJECT_MODE" -eq 1 ] || return 0
  case "$RULES_ARG" in
    "")
      if [ "$INTERACTIVE" -eq 1 ]; then choose_rules "$(default_rules)"; else RULES_SEL="$(default_rules)"; fi
      ;;
    all) RULES_SEL="$(all_rules_names)" ;;
    none) RULES_SEL="" ;;
    *)
      for token in $(printf '%s' "$RULES_ARG" | tr ',' ' '); do
        known=0
        for i in ${RULE_NAME[@]+"${!RULE_NAME[@]}"}; do
          if [ "${RULE_NAME[$i]}" = "$token" ]; then known=1; break; fi
        done
        if [ "$known" -eq 0 ]; then
          printf 'Ошибка: неизвестное правило: %s — доступные: %s\n' "$token" "$(rules_csv_display "$(all_rules_names)")" >&2
          exit 2
        fi
        if ! list_has "$RULES_SEL" "$token"; then RULES_SEL="$RULES_SEL $token"; fi
      done
      RULES_SEL="${RULES_SEL# }"
      ;;
  esac
}

# Классификация элементов каталога правил до любого изменения проекта: копия
# исключаемого правила, изменённая вручную, останавливает запуск; чужие элементы
# остаются на месте и называются в отчёте.
rules_scan() {
  RULE_FOREIGN=()
  [ "$PROJECT_MODE" -eq 1 ] || return 0
  [ -d "$RULES_DIR" ] || return 0
  local entry name rel blockers=0
  for entry in "$RULES_DIR"/*; do
    if [ ! -e "$entry" ]; then continue; fi
    name="$(basename "$entry" .md)"
    if list_has "$RULES_SEL" "$name"; then continue; fi
    rel="$(rule_rel "$name")"
    if [ -f "$STORAGE/tessera/$rel" ] || [ -n "$(git -C "$STORAGE/tessera" log --format=%h -n 1 -- "$rel" </dev/null 2>/dev/null)" ]; then
      if ! copy_is_ours "$entry" "$rel"; then
        say "Копия правила изменена вручную и исключается из перечня: $(display "$entry")"
        blockers=$(( blockers + 1 ))
      fi
    elif [ -f "$entry" ] || [ -d "$entry" ]; then
      RULE_FOREIGN+=("$entry")
      SKIPPED+=("$entry")
    fi
  done
  if [ "$blockers" -gt 0 ]; then
    die "перечень правил не сменён: исключаемые копии изменены вручную — верните их в исходное состояние или подключите названные правила"
  fi
}

# Секция правил: маркеры со штампом, поставщик и время, перечень ссылками
# на копии правил. Названия правил — из заголовков источников.
rules_section_text() { # штамп
  local stamp="$1" i name list=""
  for i in ${RULE_NAME[@]+"${!RULE_NAME[@]}"}; do
    name="${RULE_NAME[$i]}"
    if list_has "$RULES_SEL" "$name"; then
      list="$list
- [${RULE_TITLE[$i]}](./.tessera/rules/$name.md)"
    fi
  done
  cat <<EOF
${SECTION_OPEN}${stamp} -->

## Правила tessera

Секцию ведёт скрипт поставки tessera: правила подключены $(stamp_human "$stamp"). Правки внутри секции не сохраняются — повторная установка перепишет её. Свои инструкции пишите вне секции.

Перед выполнением любой задачи агент обязан полностью прочитать перечисленные правила:
$list

${SECTION_CLOSE}${stamp} -->
EOF
}

# «none | начало конец штамп» для секции правил файла; damaged — маркер без
# парного либо секций больше одной.
find_rules_section() { # файл
  awk '
    $0 ~ /^<!-- delivery-tessera-[0-9]{14} -->$/ {
      nopen++
      if (nopen == 1) { oline = NR; ostamp = substr($0, 23, 14) }
    }
    $0 ~ /^<!-- \/delivery-tessera-[0-9]{14} -->$/ {
      nclose++
      if (nclose == 1) { cline = NR; cstamp = substr($0, 24, 14) }
    }
    END {
      if (nopen == 0 && nclose == 0) { print "none"; exit }
      if (nopen == 1 && nclose == 1 && oline < cline && ostamp == cstamp) {
        print oline, cline, ostamp; exit
      }
      print "damaged"
    }' "$1"
}

# Удаляет диапазон строк, схлопывая пустую строку перед секцией с пустой после
# неё; пустые строки в конце файла убираются, в конце остаётся один перевод
# строки.
remove_line_range() { # файл, начало, конец
  local file="$1"
  awk -v s="$2" -v e="$3" '
    NR == s - 1 { if ($0 !~ /^[[:space:]]*$/) print; else hold = 1; next }
    NR >= s && NR <= e { next }
    hold && $0 ~ /^[[:space:]]*$/ { hold = 0; print; next }
    { hold = 0; print }
  ' "$file" > "$file.tmp"
  printf '%s\n' "$(cat "$file.tmp")" > "$file"
  rm -- "$file.tmp"
}

# Текст созданного скриптом AGENTS.md без секции — по нему файл опознаётся.
created_agents_text() {
  printf '# %s\n\nТочка входа правил для агентов, работающих в проекте.\n' "$(basename "$PROJECT_DIR")"
}

# Секция AGENTS.md: создание файла, запись в конец, замена прежней секции —
# только при изменении текста; пустой перечень снимает секцию.
write_rules_section() {
  local sec start end stamp old_block new_block remainder
  AGENTS_RESULT=""
  RULES_STAMP=""
  if [ ! -n "$RULES_SEL" ]; then
    if [ -f "$AGENTS_FILE" ]; then
      sec="$(find_rules_section "$AGENTS_FILE")"
      if [ "$sec" = "damaged" ]; then
        die "секция правил в $(display "$AGENTS_FILE") повреждена: маркер без парного либо секций больше одной — приведите файл к одной секции правил"
      fi
      if [ "$sec" != "none" ]; then
        read -r start end stamp <<< "$sec"
        remove_line_range "$AGENTS_FILE" "$start" "$end"
        AGENTS_RESULT="снята"
        RULES_STAMP="$stamp"
        if [ "$(cat "$AGENTS_FILE")" = "$(created_agents_text)" ]; then
          rm -- "$AGENTS_FILE"
          AGENTS_RESULT="снята, файл удалён (создан скриптом)"
        fi
      fi
    fi
    if [ -d "$RULES_DIR" ]; then rmdir "$RULES_DIR" 2>/dev/null || true; fi
    if [ -d "${RULES_DIR%/*}" ]; then rmdir "${RULES_DIR%/*}" 2>/dev/null || true; fi
    return
  fi
  RULES_STAMP="$(rule_stamp)"
  new_block="$(rules_section_text "$RULES_STAMP")"
  if [ ! -f "$AGENTS_FILE" ]; then
    { created_agents_text; printf '\n%s\n' "$new_block"; } > "$AGENTS_FILE"
    AGENTS_RESULT="записана (штамп $RULES_STAMP)"
    return
  fi
  sec="$(find_rules_section "$AGENTS_FILE")"
  if [ "$sec" = "damaged" ]; then
    die "секция правил в $(display "$AGENTS_FILE") повреждена: маркер без парного либо секций больше одной — приведите файл к одной секции правил"
  fi
  if [ "$sec" = "none" ]; then
    if [ -n "$(tail -c 1 "$AGENTS_FILE" 2>/dev/null)" ]; then printf '\n' >> "$AGENTS_FILE"; fi
    if [ -n "$(tail -n 1 "$AGENTS_FILE")" ]; then printf '\n' >> "$AGENTS_FILE"; fi
    printf '%s\n' "$new_block" >> "$AGENTS_FILE"
    AGENTS_RESULT="записана (штамп $RULES_STAMP)"
    return
  fi
  read -r start end stamp <<< "$sec"
  old_block="$(sed -n "${start},${end}p" "$AGENTS_FILE")"
  if [ "$old_block" = "$(rules_section_text "$stamp")" ]; then
    AGENTS_RESULT="актуальна (штамп $stamp)"
    return
  fi
  { head -n $(( start - 1 )) "$AGENTS_FILE"; printf '%s\n' "$new_block"; tail -n +$(( end + 1 )) "$AGENTS_FILE"; } > "$AGENTS_FILE.tmp"
  mv -- "$AGENTS_FILE.tmp" "$AGENTS_FILE"
  AGENTS_RESULT="записана (штамп $RULES_STAMP)"
}

# Ссылки подключённых правил на правила вне перечня — только ссылки между
# правилами (./<имя>.md); ссылки на навык плагина и прочие пути не считаются.
rule_cross_links() {
  RULE_LINKS_MISSING=()
  [ -n "$RULES_SEL" ] || return 0
  local name entry target
  for name in $RULES_SEL; do
    entry="$RULES_DIR/$name.md"
    if [ ! -f "$entry" ]; then continue; fi
    for target in $(grep -o '](\.\/[A-Za-z0-9-]*\.md' "$entry" | sed 's/](\.\/\(.*\)\.md/\1/'); do
      if list_has "$RULES_SEL" "$target"; then continue; fi
      if ! list_has "$(all_rules_names)" "$target"; then continue; fi
      if ! list_has "${RULE_LINKS_MISSING[*]-}" "$name|$target"; then
        RULE_LINKS_MISSING+=("$name|$target")
      fi
    done
  done
}

# Подключение правил: копии перечня, снятие исключённых и устаревших копий,
# запись секции, перекрёстные ссылки.
connect_rules() {
  RULE_COPY_STATE=()
  RULE_HAND_EDITED=()
  RULE_REMOVED=()
  RULE_LINKS_MISSING=()
  AGENTS_RESULT=""
  RULES_STAMP=""
  [ "$PROJECT_MODE" -eq 1 ] || return 0
  local i name entry state
  if [ -n "$RULES_SEL" ]; then mkdir -p "$RULES_DIR"; fi
  for i in ${RULE_NAME[@]+"${!RULE_NAME[@]}"}; do
    name="${RULE_NAME[$i]}"
    if ! list_has "$RULES_SEL" "$name"; then continue; fi
    entry="$RULES_DIR/$name.md"
    if [ ! -e "$entry" ]; then
      cp -- "${RULE_SRC[$i]}" "$entry"
      state="создана"
    elif cmp -s "$entry" "${RULE_SRC[$i]}"; then
      state="актуальна"
    elif copy_is_ours "$entry" "$(rule_rel "$name")"; then
      cp -- "${RULE_SRC[$i]}" "$entry"
      state="обновлена"
    else
      state="пропущена (изменена вручную)"
      RULE_HAND_EDITED+=("$entry")
    fi
    RULE_COPY_STATE+=("$name|$state")
  done
  if [ -d "$RULES_DIR" ]; then
    for entry in "$RULES_DIR"/*; do
      if [ ! -e "$entry" ]; then continue; fi
      name="$(basename "$entry" .md)"
      if list_has "$RULES_SEL" "$name"; then continue; fi
      rel="$(rule_rel "$name")"
      if [ -f "$STORAGE/tessera/$rel" ] || [ -n "$(git -C "$STORAGE/tessera" log --format=%h -n 1 -- "$rel" </dev/null 2>/dev/null)" ]; then
        rm -- "$entry"
        RULE_REMOVED+=("$name")
      fi
    done
  fi
  write_rules_section
  rule_cross_links
}

# --- Лаунчер backlog -------------------------------------------------------

launcher_is_ours() { [ -f "$LAUNCHER" ] && grep -qF "$LAUNCHER_MARKER" "$LAUNCHER"; }

# Свободное имя резервной копии: backlog.bak, затем backlog.bak.N.
free_backup_path() {
  local candidate="$LAUNCHER.bak" number=1
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    candidate="$LAUNCHER.bak.$number"
    number=$(( number + 1 ))
  done
  printf '%s' "$candidate"
}

# Лаунчер — обёртка, а не симлинк: bin/backlog берёт корень поставки из $0
# и не разрешает ссылки. Чужой файл по пути сохраняется резервной копией.
install_launcher() {
  mkdir -p "$BIN_DIR"
  if { [ -e "$LAUNCHER" ] || [ -L "$LAUNCHER" ]; } && ! launcher_is_ours; then
    LAUNCHER_BACKUP="$(free_backup_path)"
    mv "$LAUNCHER" "$LAUNCHER_BACKUP"
  fi
  cat >"$LAUNCHER" <<'EOF'
#!/usr/bin/env sh
# Лаунчер backlog — создан скриптом поставки tessera (scripts/install.sh).
export BACKLOG_HOME="${HOME}/.local/share/tessera/formular/plugin/backlog"
exec "${BACKLOG_HOME}/bin/backlog" "$@"
EOF
  chmod +x "$LAUNCHER"
}

bin_dir_on_path() {
  local entry wanted
  wanted="$(canonical "$BIN_DIR")"
  [ -n "${PATH:-}" ] || return 1
  local entries=()
  IFS=: read -r -a entries <<< "$PATH"
  for entry in "${entries[@]}"; do
    if [ "$(canonical "${entry:-.}")" = "$wanted" ]; then return 0; fi
  done
  return 1
}

# --- Реестр поставки --------------------------------------------------------

# Экранирует строку для JSON: обратная косая черта, кавычка, табуляция, перевод
# строки и возврат каретки.
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

json_str() { printf '"%s"' "$(json_escape "$1")"; }

# Абсолютный путь → относительный для реестра: проект — от корня проекта,
# машина — от домашнего каталога. Реестр без имён машины переносим.
registry_path() {
  case "$1" in
    "$PROJECT_DIR"/*) printf '.%s' "${1#"$PROJECT_DIR"}" ;;
    "$HOME_DIR"/*) printf '~%s' "${1#"$HOME_DIR"}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# Профиль реестра: параметр запуска, иначе профиль прежней установки, иначе full.
registry_profile() {
  if [ -n "$PROFILE_ARG" ]; then printf '%s' "$PROFILE_ARG"; return; fi
  local p
  p="$(installed_profile)"
  printf '%s' "${p:-full}"
}

# Раздел компонентов: все компоненты таблицы с признаком вхождения в профиль
# и состоянием клона (есть и редакция / нет).
registry_components() {
  local component out="" first=1 included present rev
  for component in $(component_names); do
    included=false
    present=false
    rev=null
    if profile_has "$PROFILE" "$component"; then included=true; fi
    if [ -d "$STORAGE/$component/.git" ]; then
      present=true
      local r
      r="$(git -C "$STORAGE/$component" log --format=%h -n 1 </dev/null 2>/dev/null)"
      [ -n "$r" ] && rev="$(json_str "$r")"
    fi
    [ "$first" -eq 1 ] || out="$out,"
    first=0
    out="$out
    {\"name\": $(json_str "$component"), \"source\": $(json_str "$(component_url "$component")"), \"storage\": $(json_str "$(registry_path "$STORAGE/$component")"), \"included\": $included, \"present\": $present, \"revision\": $rev}"
  done
  printf '%s' "$out"
}

# Раздел каталогов навыков: харнесы отбора и дополнительный каталог.
registry_skill_dirs() {
  local row out="" first=1
  for row in ${SELECTED[@]+"${SELECTED[@]}"}; do
    [ "$first" -eq 1 ] || out="$out,"
    first=0
    out="$out
    {\"harness\": $(json_str "$(field "$row" 1)"), \"dir\": $(json_str "$(registry_path "$(harness_target "$row")")")}"
  done
  if [ -n "$SKILLS_DIR" ]; then
    [ "$first" -eq 1 ] || out="$out,"
    out="$out
    {\"harness\": \"-\", \"dir\": $(json_str "$(registry_path "$SKILLS_DIR")")}"
  fi
  printf '%s' "$out"
}

# Компоненты профиля, чьих клонов нет в хранилище, — через пробел. Отдельная
# функция: вызывается в родителе, а не в подстановке команды, чтобы результат
# не терялся в под-оболочке.
registry_pending_components() {
  local component sub pending=""
  for component in $(profile_components "$PROFILE"); do
    for sub in $(component_skill_dirs "$component"); do
      if [ ! -d "$STORAGE/$component/$sub" ]; then
        list_has "$pending" "$component" || pending="$pending $component"
      fi
    done
  done
  printf '%s' "${pending# }"
}

# Записи навыков — по одному на навык и каталог назначения. Клоны, которых нет,
# записей не дают: их перечисляет registry_pending_components.
registry_skills_entries() {
  local t component sub dir path out="" first=1
  for t in ${TARGETS[@]+"${TARGETS[@]}"}; do
    for component in $(profile_components "$PROFILE"); do
      for sub in $(component_skill_dirs "$component"); do
        dir="$STORAGE/$component/$sub"
        [ -d "$dir" ] || continue
        for path in "$dir"/*/; do
          if [ ! -f "${path}SKILL.md" ]; then continue; fi
          path="${path%/}"
          [ "$first" -eq 1 ] || out="$out,"
          first=0
          out="$out
    {\"name\": $(json_str "${path##*/}"), \"component\": $(json_str "$component"), \"type\": \"symlink\", \"target\": $(json_str "$(registry_path "$t")/${path##*/}"), \"source\": $(json_str "$(registry_path "$path")")}"
        done
      done
    done
  done
  printf '%s' "$out"
}

# Перечень имён недоступных компонентов в форме JSON-массива; пусто, когда
# все клоны на месте.
registry_pending_json() { # перечень компонентов через пробел
  local c out="" first=1
  for c in $1; do
    [ "$first" -eq 1 ] || out="$out, "
    first=0
    out="$out$(json_str "$c")"
  done
  printf '%s' "$out"
}

# Раздел правил: записи выбранных правил и статус. Клона tessera нет — раздел
# частичный: каркас с пометкой, записи появятся после получения источников.
registry_rules() {
  local out="" first=1 name
  if [ ! -d "$STORAGE/tessera/$(component_rules_dir tessera)" ]; then
    printf '{
    "status": "partial",
    "pending_components": ["tessera"],
    "entries": []
  }'
    return
  fi
  collect_rules
  if [ -z "${RULES_SEL:-}" ]; then
    # Реестр не спрашивает: умолчания как при --yes, диалог не начинается.
    local saved="$INTERACTIVE"
    INTERACTIVE=0
    resolve_rules
    INTERACTIVE="$saved"
  fi
  local status="complete"
  [ -n "$RULES_SEL" ] || status="none"
  for name in $RULES_SEL; do
    [ "$first" -eq 1 ] || out="$out,"
    first=0
    out="$out
    {\"name\": $(json_str "$name"), \"type\": \"copy\", \"target\": $(json_str ".tessera/rules/$name.md"), \"source\": $(json_str "$(registry_path "$STORAGE/tessera/$(rule_rel "$name")")")}"
  done
  printf '{
    "status": "%s",
    "entries": [%s]
  }' "$status" "$out"
}

# Раздел точки входа: только с параметром проекта; штамп — у реестра-факта.
registry_entrypoint() { # штамп или пусто
  [ "$PROJECT_MODE" -eq 1 ] || return 0
  local stamp="$1" stamp_json=""
  [ -n "$stamp" ] && stamp_json=", \"stamp\": $(json_str "$stamp")"
  printf '{"path": "AGENTS.md", "type": "section", "marker_prefix": %s%s}' \
    "$(json_str "$SECTION_OPEN")" "$stamp_json"
}

# Собирает реестр в REGISTRY_TEXT. Аргумент — штамп секции для реестра-факта;
# пустой аргумент означает префлайт: печать без записи на диск.
build_registry() { # штамп или пусто
  local stamp="${1:-}"
  PROFILE="$(registry_profile)"
  read -r -a WANTED <<< "$(profile_components "$PROFILE")"
  local now skills_status="" skills_pending_json="" rules_part="" entrypoint_json=""
  now="$(date +%Y-%m-%dT%H:%M:%S)"
  local comp_json dirs_json skills_json pending
  comp_json="$(registry_components)"
  dirs_json="$(registry_skill_dirs)"
  skills_json="$(registry_skills_entries)"
  pending="$(registry_pending_components)"
  if [ -n "$pending" ]; then
    skills_status="partial"
    skills_pending_json=",
    \"pending_components\": [$(registry_pending_json "$pending")]"
  else
    skills_status="complete"
  fi
  if [ "$PROJECT_MODE" -eq 1 ]; then
    local rules_json entry_json
    rules_json="$(registry_rules)"
    entry_json="$(registry_entrypoint "$stamp")"
    if [ -n "$entry_json" ]; then
      rules_part="
  \"rules\": $rules_json,
  \"entrypoint\": $entry_json,"
    fi
  fi
  local launcher_included=false
  profile_has "$PROFILE" formular && launcher_included=true
  REGISTRY_TEXT="{
  \"registry_version\": \"1.0.0\",
  \"generated_at\": \"$(json_escape "$now")\",
  \"profile\": $(json_str "$PROFILE"),
  \"mode\": \"$([ "$PROJECT_MODE" -eq 1 ] && printf project || printf user)\",
  \"components\": [$comp_json],
  \"skill_dirs\": [$dirs_json],
  \"skills\": {
    \"status\": \"$skills_status\"$skills_pending_json,
    \"entries\": [$skills_json]
  },$rules_part
  \"launcher\": {\"path\": $(json_str "$(registry_path "$LAUNCHER")"), \"type\": \"wrapper\", \"included\": $launcher_included}
}"
}

# Печатает реестр на стандартный вывод — единственный вывод команды.
emit_registry() {
  printf '%s\n' "$REGISTRY_TEXT"
}

# Записывает реестр-факт: в хранилище всегда, в проект — с параметром проекта.
# Вызывается после самопроверки: реестр фиксирует состоявшуюся установку.
write_registry_facts() {
  build_registry "$RULES_STAMP"
  printf '%s\n' "$REGISTRY_TEXT" > "$STORAGE/registry.json"
  REGISTRY_REPORT="$(display "$STORAGE/registry.json")"
  if [ "$PROJECT_MODE" -eq 1 ]; then
    mkdir -p "$PROJECT_DIR/.tessera"
    printf '%s\n' "$REGISTRY_TEXT" > "$PROJECT_DIR/.tessera/registry.json"
    REGISTRY_REPORT="$REGISTRY_REPORT, $(display "$PROJECT_DIR/.tessera/registry.json")"
  fi
}



# --- Отчёт -----------------------------------------------------------------

# Перечень имён навыков с переносом строк.
wrap_names() { printf '%s\n' "$1" | fold -s -w 66 | sed -e 's/^/      /' -e 's/[[:space:]]*$//'; }

skill_counts() {
  local component skill count out=""
  for component in "${WANTED[@]}"; do
    count=0
    for skill in ${SKILL_COMPONENT[@]+"${SKILL_COMPONENT[@]}"}; do
      if [ "$skill" = "$component" ]; then count=$(( count + 1 )); fi
    done
    out="$out, $component $count"
  done
  printf '%s' "${out#, }"
}

run_self_check() {
  local i name line
  BROKEN=()
  for i in ${LINK_NAME[@]+"${!LINK_NAME[@]}"}; do
    if [ ! -f "${LINK_DIR[$i]}/${LINK_NAME[$i]}/SKILL.md" ]; then
      BROKEN+=("${LINK_DIR[$i]}/${LINK_NAME[$i]}")
    fi
  done
  RULE_BROKEN=()
  if [ "$PROJECT_MODE" -eq 1 ] && [ -n "$RULES_SEL" ]; then
    for name in $RULES_SEL; do
      if [ ! -f "$RULES_DIR/$name.md" ]; then
        RULE_BROKEN+=("$RULES_DIR/$name.md — нет файла копии")
      fi
    done
    for line in ${RULE_COPY_STATE[@]+"${RULE_COPY_STATE[@]}"}; do
      case "$line" in
        *"|создана" | *"|обновлена")
          name="${line%%|*}"
          if ! cmp -s "$RULES_DIR/$name.md" "$(rule_src_by_name "$name")"; then
            RULE_BROKEN+=("$RULES_DIR/$name.md — не совпадает с источником")
          fi
          ;;
      esac
    done
  fi
  LAUNCHER_CHECK=""
  if profile_has "$PROFILE" formular; then
    LAUNCHER_CHECK=0
    "$LAUNCHER" --help >/dev/null 2>&1 || LAUNCHER_CHECK=1
  fi
}

print_report() {
  local line target i names count broken_here
  say ""
  say "Отчёт об установке"
  say "  Профиль поставки: $PROFILE — $(profile_summary "$PROFILE")."
  say "  Хранилище $(display "$STORAGE"):"
  for line in "${SOURCE_STATE[@]}"; do
    say "    ${line%%|*} — ${line#*|}"
  done
  say "  Навыков в профиле: ${#SKILL_NAME[@]} ($(skill_counts))."
  say "  Ссылки на навыки: создано $CREATED, пересоздано $RECREATED."
  for target in "${TARGETS[@]}"; do
    names="" count=0 broken_here=0
    for i in ${LINK_NAME[@]+"${!LINK_NAME[@]}"}; do
      if [ "${LINK_DIR[$i]}" != "$target" ]; then continue; fi
      count=$(( count + 1 ))
      names="$names ${LINK_NAME[$i]}"
      if [ ! -f "$target/${LINK_NAME[$i]}/SKILL.md" ]; then broken_here=$(( broken_here + 1 )); fi
    done
    if [ "$count" -eq 0 ]; then
      say "    $(display "$target") — ссылок нет"
    elif [ "$broken_here" -eq 0 ]; then
      say "    $(display "$target") — $count, проверка пройдена"
    else
      say "    $(display "$target") — $count, неисправных $broken_here"
    fi
    [ -z "$names" ] || wrap_names "$names"
  done
  if [ "$PROJECT_MODE" -eq 1 ]; then
    if [ -n "$RULES_SEL" ]; then
      say "  Правила в проекте $(display "$RULES_DIR"):"
      for line in ${RULE_COPY_STATE[@]+"${RULE_COPY_STATE[@]}"}; do
        say "    ${line%%|*} — ${line#*|}"
      done
      for line in ${RULE_REMOVED[@]+"${RULE_REMOVED[@]}"}; do
        say "    $line — копия снята"
      done
      say "  Секция правил $(display "$AGENTS_FILE") — $AGENTS_RESULT."
      if [ "${#RULE_LINKS_MISSING[@]}" -gt 0 ]; then
        say "  Ссылки на неподключённые правила:"
        for line in ${RULE_LINKS_MISSING[@]+"${RULE_LINKS_MISSING[@]}"}; do
          say "    ${line%%|*} → ${line#*|}"
        done
      fi
    else
      say "  Правила не подключаются: перечень пуст."
    fi
  fi
  if [ "${#BROKEN[@]}" -gt 0 ]; then
    say "  Неисправные ссылки:"
    for line in "${BROKEN[@]}"; do say "    $(display "$line") — не разрешается в SKILL.md"; done
  fi
  if [ "${#SKIPPED[@]}" -gt 0 ]; then
    say "  Пропущены чужие элементы (созданы не скриптом):"
    for line in "${SKIPPED[@]}"; do say "    $(display "$line")"; done
  fi
  if [ "${#STALE[@]}" -gt 0 ]; then
    say "  Сняты устаревшие ссылки (навыка нет в источнике):"
    for line in "${STALE[@]}"; do say "    $(display "$line")"; done
  fi
  for line in ${DROPPED_REPORT[@]+"${DROPPED_REPORT[@]}"}; do
    say "  Снято при смене профиля: ${line%%|*} — клон удалён, ссылок снято ${line#*|}."
  done
  if profile_has "$PROFILE" formular; then
    say "  Лаунчер $(display "$LAUNCHER") — backlog --help: код $LAUNCHER_CHECK."
    if [ -n "$LAUNCHER_BACKUP" ]; then
      say "  Прежний лаунчер сохранён: $(display "$LAUNCHER_BACKUP")."
    fi
  elif [ "$LAUNCHER_REMOVED" -eq 1 ]; then
    say "  Лаунчер снят: профиль без backlog."
  else
    say "  Лаунчер не ставится: профиль без backlog."
  fi
  say "  Самопроверка: ссылок ${#LINK_NAME[@]}, неисправных ${#BROKEN[@]}, элементов правил ${#RULE_BROKEN[@]}."
}

describe_plan() {
  local row component
  say ""
  say "Будет сделано:"
  say "  профиль   $PROFILE — $(profile_summary "$PROFILE")"
  if [ "$PROJECT_MODE" -eq 1 ]; then
    say "  каталоги  навыков в проекте $(display "$PROJECT_DIR"):"
  else
    say "  каталоги  пользовательских навыков:"
  fi
  for row in "${SELECTED[@]}"; do
    say "            $(field "$row" 1) — $(display "$(harness_target "$row")")"
  done
  if [ -n "$SKILLS_DIR" ]; then say "            дополнительно $(display "$SKILLS_DIR")"; fi
  for component in ${DROPPED[@]+"${DROPPED[@]}"}; do
    say "  снимается $component (нет в профиле)"
  done
  if [ "$PROJECT_MODE" -eq 1 ]; then
    case "$RULES_ARG" in
      all) say "  правила    все — копии в $(display "$RULES_DIR"), секция в AGENTS.md" ;;
      none) say "  правила    не подключаются (--rules none)" ;;
      "")
        say "  правила    спрошу после загрузки источников; Enter — прежний перечень или все"
        ;;
      *) say "  правила    $(rules_csv_display "$RULES_ARG") — копии в $(display "$RULES_DIR"), секция в AGENTS.md" ;;
    esac
  fi
  if profile_has "$PROFILE" formular; then say "  лаунчер   $(display "$LAUNCHER")"; fi
}

# --- Установка и удаление --------------------------------------------------

install_supply() {
  local installed dropped
  if [ -n "$PROFILE_ARG" ]; then
    PROFILE="$PROFILE_ARG"
  else
    installed="$(installed_profile)"
    if [ "$INTERACTIVE" -eq 1 ]; then choose_profile "${installed:-full}"; else PROFILE="${installed:-full}"; fi
  fi
  read -r -a WANTED <<< "$(profile_components "$PROFILE")"
  DROPPED=()
  for dropped in $(component_names); do
    if [ -d "$STORAGE/$dropped" ] && ! profile_has "$PROFILE" "$dropped"; then DROPPED+=("$dropped"); fi
  done
  # Клон с локальными изменениями не удаляется молча.
  for dropped in ${DROPPED[@]+"${DROPPED[@]}"}; do
    if [ -e "$STORAGE/$dropped/.git" ] && clone_is_dirty "$dropped"; then
      die "профиль не сменён: в клоне $dropped есть локальные изменения — верните клон в исходное состояние или снимите поставку параметром --uninstall"
    fi
  done
  if [ "$INTERACTIVE" -eq 1 ]; then
    choose_harnesses
    if [ "${#TARGETS[@]}" -eq 0 ]; then say "Каталоги навыков не выбраны — ничего не изменено."; exit 0; fi
    describe_plan
    if ! confirm "Продолжить? [Y/n] " yes; then say "Отменено, ничего не изменено."; exit 0; fi
  fi
  DROPPED_REPORT=()
  STALE=()
  SKIPPED=()
  LINK_DIR=()
  LINK_NAME=()
  LAUNCHER_BACKUP=""
  LAUNCHER_REMOVED=0
  ensure_sources
  collect_rules
  resolve_rules
  rules_scan
  drop_components
  collect_skills
  link_skills
  if profile_has "$PROFILE" formular; then install_launcher; fi
  connect_rules
  run_self_check
  print_report
  if [ "${#BROKEN[@]}" -gt 0 ]; then die "самопроверка не пройдена: есть неисправные ссылки"; fi
  if [ "${#RULE_BROKEN[@]}" -gt 0 ]; then
    die "самопроверка не пройдена: есть неисправные элементы поставки правил"
  fi
  write_registry_facts
  say "  Реестр установки: $REGISTRY_REPORT."
  if [ "$LAUNCHER_CHECK" = "1" ]; then
    die "самопроверка не пройдена: backlog --help не отвечает через лаунчер (для CLI backlog нужен python3)"
  fi
  if profile_has "$PROFILE" formular && ! bin_dir_on_path; then
    warn "$(display "$BIN_DIR") вне PATH — добавьте каталог в PATH, чтобы команда backlog была доступна."
  fi
  say ""
  say "Готово. Перезапустите сессию харнеса, чтобы он увидел навыки."
}

# Скан правил проекта перед диалогом удаления: какие копии снимаются молча,
# какие названы как изменённые вручную, какие оставлены как чужие.
rules_uninstall_scan() {
  RULE_UN_HAND=()
  RULE_UN_LEFT=()
  RULE_UN_COUNT=0
  [ "$PROJECT_MODE" -eq 1 ] || return 0
  [ -d "$RULES_DIR" ] || return 0
  local entry name rel
  for entry in "$RULES_DIR"/*; do
    if [ ! -f "$entry" ]; then continue; fi
    name="$(basename "$entry" .md)"
    rel="$(rule_rel "$name")"
    if [ -e "$STORAGE/tessera/.git" ]; then
      if [ -f "$STORAGE/tessera/$rel" ] || [ -n "$(git -C "$STORAGE/tessera" log --format=%h -n 1 -- "$rel" </dev/null 2>/dev/null)" ]; then
        if copy_is_ours "$entry" "$rel"; then
          RULE_UN_COUNT=$(( RULE_UN_COUNT + 1 ))
        else
          RULE_UN_HAND+=("$entry")
        fi
      else
        RULE_UN_LEFT+=("$entry")
      fi
    else
      RULE_UN_LEFT+=("$entry")
    fi
  done
}

# Снятие секции и копий правил проекта; созданный скриптом AGENTS.md без
# инструкций проекта удаляется, опустевшие каталоги снимаются.
rules_uninstall_run() {
  AGENTS_UN_RESULT=""
  [ "$PROJECT_MODE" -eq 1 ] || return 0
  local entry name start end stamp sec removed=0
  if [ -f "$AGENTS_FILE" ]; then
    sec="$(find_rules_section "$AGENTS_FILE")"
    if [ "$sec" != "none" ] && [ "$sec" != "damaged" ]; then
      read -r start end stamp <<< "$sec"
      remove_line_range "$AGENTS_FILE" "$start" "$end"
      AGENTS_UN_RESULT="снята"
      if [ "$(cat "$AGENTS_FILE")" = "$(created_agents_text)" ]; then
        rm -- "$AGENTS_FILE"
        AGENTS_UN_RESULT="снята, файл удалён (создан скриптом)"
      fi
    elif [ "$sec" = "damaged" ]; then
      AGENTS_UN_RESULT="повреждена — не тронута, приведите файл к одной секции правил вручную"
    fi
  fi
  if [ -d "$RULES_DIR" ]; then
    for entry in "$RULES_DIR"/*; do
      if [ ! -f "$entry" ]; then continue; fi
      name="$(basename "$entry" .md)"
      rel="$(rule_rel "$name")"
      if [ -e "$STORAGE/tessera/.git" ] && { [ -f "$STORAGE/tessera/$rel" ] || [ -n "$(git -C "$STORAGE/tessera" log --format=%h -n 1 -- "$rel" </dev/null 2>/dev/null)" ]; }; then
        rm -- "$entry"
        removed=$(( removed + 1 ))
      fi
    done
    rm -f "$PROJECT_DIR/.tessera/registry.json"
    if [ -d "$RULES_DIR" ]; then rmdir "$RULES_DIR" 2>/dev/null || true; fi
    if [ -d "${RULES_DIR%/*}" ]; then rmdir "${RULES_DIR%/*}" 2>/dev/null || true; fi
  fi
  RULE_UN_REMOVED=$removed
}

uninstall_supply() {
  local target entry removed total=0 component dirty=""
  if [ "$INTERACTIVE" -eq 1 ]; then
    say ""
    say "Будет удалено:"
    for target in "${TARGETS[@]}"; do say "  ссылки на навыки tessera в $(display "$target")"; done
    if launcher_is_ours; then say "  лаунчер $(display "$LAUNCHER")"; fi
    if [ "$PROJECT_MODE" -eq 1 ]; then
      if [ -f "$AGENTS_FILE" ] || [ -d "$RULES_DIR" ]; then
        say "  секцию правил в $(display "$AGENTS_FILE") и копии правил в $(display "$RULES_DIR")"
      fi
      for entry in ${RULE_UN_HAND[@]+"${RULE_UN_HAND[@]}"}; do
        say "    $(display "$entry") — копия изменена вручную"
      done
    fi
    if [ -d "$STORAGE" ]; then
      say "  хранилище $(display "$STORAGE")"
      for component in $(component_names); do
        if [ -e "$STORAGE/$component/.git" ] && clone_is_dirty "$component"; then dirty="$dirty $component"; fi
      done
      if [ -n "$dirty" ]; then say "  с локальными изменениями в клонах:$dirty"; fi
    fi
    if ! confirm "Удалить поставку tessera? [y/N] " no; then say "Отменено, ничего не изменено."; exit 0; fi
  fi
  rules_uninstall_run
  UNINSTALL_REPORT=()
  for target in ${TARGETS[@]+"${TARGETS[@]}"}; do
    [ -d "$target" ] || continue
    removed=0
    for entry in "$target"/*; do
      if link_is_ours "$entry"; then
        rm -- "$entry"
        removed=$(( removed + 1 ))
      fi
    done
    total=$(( total + removed ))
    if [ "$removed" -gt 0 ]; then UNINSTALL_REPORT+=("$(display "$target") — $removed"); fi
  done
  say ""
  say "Отчёт об удалении"
  say "  Ссылок снято: $total"
  for entry in ${UNINSTALL_REPORT[@]+"${UNINSTALL_REPORT[@]}"}; do say "    $entry"; done
  if [ "$PROJECT_MODE" -eq 1 ] && [ -n "$AGENTS_UN_RESULT" ]; then
    say "  Секция правил $(display "$AGENTS_FILE") — $AGENTS_UN_RESULT"
  fi
  if [ "$PROJECT_MODE" -eq 1 ] && [ "${RULE_UN_REMOVED:-0}" -gt 0 ]; then
    say "  Копий правил снято: $RULE_UN_REMOVED"
  fi
  for entry in ${RULE_UN_HAND[@]+"${RULE_UN_HAND[@]}"}; do
    say "    $(display "$entry") — копия изменена вручную, снята"
  done
  for entry in ${RULE_UN_LEFT[@]+"${RULE_UN_LEFT[@]}"}; do
    say "    $(display "$entry") — создан не скриптом, оставлен"
  done
  if launcher_is_ours; then
    rm -- "$LAUNCHER"
    say "  Лаунчер снят: $(display "$LAUNCHER")"
  elif [ -e "$LAUNCHER" ] || [ -L "$LAUNCHER" ]; then
    say "  Лаунчер $(display "$LAUNCHER") создан не скриптом — не тронут."
  fi
  if [ -e "$LAUNCHER.bak" ] || [ -L "$LAUNCHER.bak" ]; then
    say "  Резервная копия прежнего лаунчера: $(display "$LAUNCHER.bak") — возвращается вручную."
  fi
  if [ -d "$STORAGE" ]; then
    remove_storage_dir "$STORAGE"
    say "  Хранилище удалено: $(display "$STORAGE")"
  else
    say "  Хранилища не было."
  fi
}

# --- Параметры запуска -----------------------------------------------------

need_value() { # параметр, значение
  [ -n "$2" ] || usage_error "параметру $1 нужно значение"
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --profile) need_value "$1" "${2:-}"; PROFILE_ARG="$2"; shift ;;
      --profile=*) PROFILE_ARG="${1#--profile=}"; need_value --profile "$PROFILE_ARG" ;;
      --harness) need_value "$1" "${2:-}"; HARNESS_ARG="$2"; shift ;;
      --harness=*) HARNESS_ARG="${1#--harness=}"; need_value --harness "$HARNESS_ARG" ;;
      --skills-dir) need_value "$1" "${2:-}"; SKILLS_DIR="$2"; shift ;;
      --skills-dir=*) SKILLS_DIR="${1#--skills-dir=}"; need_value --skills-dir "$SKILLS_DIR" ;;
      --rules) need_value "$1" "${2:-}"; RULES_ARG="$2"; shift ;;
      --rules=*) RULES_ARG="${1#--rules=}"; need_value --rules "$RULES_ARG" ;;
      --registry) REGISTRY=1 ;;
      --project) PROJECT_MODE=1 ;;
      --yes) YES=1 ;;
      --uninstall) UNINSTALL=1 ;;
      -h | --help) usage; exit 0 ;;
      --) shift; break ;;
      -*) usage_error "неизвестный параметр: $1" ;;
      *) usage_error "неизвестный аргумент: $1" ;;
    esac
    shift
  done
  if [ $# -gt 0 ]; then usage_error "неизвестный аргумент: $1"; fi
  case "$PROFILE_ARG" in
    "" | full | backlog | tessera) ;;
    *) usage_error "неизвестный профиль: $PROFILE_ARG — full, backlog или tessera" ;;
  esac
  if [ "$UNINSTALL" -eq 1 ] && [ -n "$PROFILE_ARG" ]; then
    usage_error "--uninstall не сочетается с --profile"
  fi
  if [ -n "$RULES_ARG" ] && [ "$UNINSTALL" -eq 1 ]; then
    usage_error "--uninstall не сочетается с --rules"
  fi
  if [ -n "$RULES_ARG" ] && [ "$PROJECT_MODE" -eq 0 ]; then
    usage_error "--rules подключает правила к проекту и требует --project"
  fi
  if [ "$REGISTRY" -eq 1 ] && [ "$UNINSTALL" -eq 1 ]; then
    usage_error "--registry не сочетается с --uninstall"
  fi
  case "$SKILLS_DIR" in
    "" | /*) ;;
    *) SKILLS_DIR="$PROJECT_DIR/$SKILLS_DIR" ;;
  esac
}

# --- Запуск ----------------------------------------------------------------

parse_args "$@"

[ -n "${HOME:-}" ] || die "не задана переменная HOME"
case "$HOME" in /*) ;; *) die "HOME должен быть абсолютным путём: $HOME" ;; esac
HOME_DIR="$(canonical "$HOME")"
STORAGE="${HOME_DIR}/.local/share/tessera"
BIN_DIR="${HOME_DIR}/.local/bin"
LAUNCHER="${BIN_DIR}/backlog"

# Файлы правил проекта: копии правил и секция в точке входа агентов.
AGENTS_FILE="${PROJECT_DIR}/AGENTS.md"
RULES_DIR="${PROJECT_DIR}/.tessera/rules"
SECTION_OPEN="<!-- delivery-tessera-"
SECTION_CLOSE="<!-- /delivery-tessera-"

# Диалог — только при терминале и без --yes; иначе скрипт ведёт себя как с --yes.
if [ "$YES" -eq 0 ] && { : </dev/tty; } 2>/dev/null; then INTERACTIVE=1; fi

SELECTED=()
TARGETS=()
if [ "$UNINSTALL" -eq 1 ]; then select_harnesses all; else select_harnesses found; fi
compute_targets
if [ "$REGISTRY" -eq 1 ]; then
  if [ "${#TARGETS[@]}" -eq 0 ]; then
    warn "харнесы не найдены и каталог навыков не передан — перечень каталогов навыков в реестре пуст; список харнесов печатает --help"
  fi
  build_registry ""
  emit_registry
  exit 0
fi
if [ "$UNINSTALL" -eq 1 ]; then
  # Хранилище снимается целиком, поэтому свои ссылки разыскиваются и в пользовательских
  # каталогах, когда установка шла в проект.
  for row in "${SELECTED[@]}"; do add_target "$(expand_home "$(field "$row" 4)")"; done
  rules_uninstall_scan
  uninstall_supply
  exit 0
fi

if [ "${#TARGETS[@]}" -eq 0 ]; then
  die "харнесы не найдены и каталог навыков не передан — передайте путь параметром --skills-dir; список харнесов печатает --help"
fi

install_supply
