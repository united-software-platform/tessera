#!/usr/bin/env bash
# Скрипт поставки tessera — единый механизм установки для любого харнеса.
# Источники раскладываются клонами ветки main в хранилище ~/.local/share/tessera/,
# навыки связываются симлинками с каталогами навыков найденных харнесов, для backlog
# ставится лаунчер на PATH. Средства харнесов для установки плагинов не используются.
# Запускается из клона (scripts/install.sh) или одной командой (curl ... | bash):
# клон служит только способом получить скрипт, источники всегда берутся из репозиториев.

set -euo pipefail

# Без терминала git не ждёт учётных данных, а сразу сообщает об ошибке.
export GIT_TERMINAL_PROMPT=0

PROJECT_DIR="$PWD"
RAW_URL="https://raw.githubusercontent.com/united-software-platform/tessera/main/scripts/install.sh"
LAUNCHER_MARKER="создан скриптом поставки tessera"

# Компоненты поставки: имя (каталог клона в хранилище) | репозиторий |
# каталоги навыков внутри клона через пробел.
COMPONENTS=(
  "tessera|https://github.com/united-software-platform/tessera.git|plugins/tessera-plugin/skills"
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
  --harness <список>               ограничить харнесы через запятую          все найденные
  --skills-dir <путь>              дополнительный каталог навыков            —
  --yes                            без диалога                               диалог при терминале
  --uninstall                      удалить созданное скриптом                —
  -h, --help                       справка                                   —

Повторный запуск обновляет клоны и пересоздаёт ссылки; профиль прежней установки
сохраняется, пока параметр --profile не задал иной.

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
  local i
  BROKEN=()
  for i in ${LINK_NAME[@]+"${!LINK_NAME[@]}"}; do
    if [ ! -f "${LINK_DIR[$i]}/${LINK_NAME[$i]}/SKILL.md" ]; then
      BROKEN+=("${LINK_DIR[$i]}/${LINK_NAME[$i]}")
    fi
  done
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
  say "  Самопроверка: ссылок ${#LINK_NAME[@]}, неисправных ${#BROKEN[@]}."
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
  drop_components
  collect_skills
  link_skills
  if profile_has "$PROFILE" formular; then install_launcher; fi
  run_self_check
  print_report
  if [ "${#BROKEN[@]}" -gt 0 ]; then die "самопроверка не пройдена: есть неисправные ссылки"; fi
  if [ "$LAUNCHER_CHECK" = "1" ]; then
    die "самопроверка не пройдена: backlog --help не отвечает через лаунчер (для CLI backlog нужен python3)"
  fi
  if profile_has "$PROFILE" formular && ! bin_dir_on_path; then
    warn "$(display "$BIN_DIR") вне PATH — добавьте каталог в PATH, чтобы команда backlog была доступна."
  fi
  say ""
  say "Готово. Перезапустите сессию харнеса, чтобы он увидел навыки."
}

uninstall_supply() {
  local target entry removed total=0 component dirty=""
  if [ "$INTERACTIVE" -eq 1 ]; then
    say ""
    say "Будет удалено:"
    for target in "${TARGETS[@]}"; do say "  ссылки на навыки tessera в $(display "$target")"; done
    if launcher_is_ours; then say "  лаунчер $(display "$LAUNCHER")"; fi
    if [ -d "$STORAGE" ]; then
      say "  хранилище $(display "$STORAGE")"
      for component in $(component_names); do
        if [ -e "$STORAGE/$component/.git" ] && clone_is_dirty "$component"; then dirty="$dirty $component"; fi
      done
      if [ -n "$dirty" ]; then say "  с локальными изменениями в клонах:$dirty"; fi
    fi
    if ! confirm "Удалить поставку tessera? [y/N] " no; then say "Отменено, ничего не изменено."; exit 0; fi
  fi
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

# Диалог — только при терминале и без --yes; иначе скрипт ведёт себя как с --yes.
if [ "$YES" -eq 0 ] && { : </dev/tty; } 2>/dev/null; then INTERACTIVE=1; fi

SELECTED=()
TARGETS=()
if [ "$UNINSTALL" -eq 1 ]; then select_harnesses all; else select_harnesses found; fi
compute_targets
if [ "$UNINSTALL" -eq 1 ]; then
  # Хранилище снимается целиком, поэтому свои ссылки разыскиваются и в пользовательских
  # каталогах, когда установка шла в проект.
  for row in "${SELECTED[@]}"; do add_target "$(expand_home "$(field "$row" 4)")"; done
  uninstall_supply
  exit 0
fi

if [ "${#TARGETS[@]}" -eq 0 ]; then
  die "харнесы не найдены и каталог навыков не передан — передайте путь параметром --skills-dir; список харнесов печатает --help"
fi

install_supply
