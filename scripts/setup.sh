#!/usr/bin/env bash
# Локальная настройка tessera — подготовка харнесов контрибьютора к работе над репозиторием.
# Навыки плагина связываются с каталогами навыков найденных харнесов прямо из рабочего дерева
# этого репозитория; зависимости приносятся компонентами — клонами ветки main в хранилище
# ~/.local/share/tessera/ — и лаунчер backlog ставится, когда приносится formular. tessera
# для самой себя не ставится: клона tessera в хранилище нет, правила не подключаются, реестр
# поставки не пишется. Область задаёт --scope project|user (умолчание project); --plugin-only
# ограничивает настройку навыками плагина из рабочего дерева.
#
# Механика — копия scripts/install.sh; общие блоки скриптов сверяет scripts/check.sh.

set -euo pipefail

# Без терминала git не ждёт учётных данных, а сразу сообщает об ошибке.
export GIT_TERMINAL_PROMPT=0

# Корень репозитория — физический: запуск возможен из любого каталога.
cd "$(dirname "$0")/.."
PROJECT_DIR="$PWD"
LAUNCHER_MARKER="создан скриптом поставки tessera"

# Компоненты зависимостей локальной настройки: те же строки, что в таблице
# scripts/install.sh, без tessera — настройка не ставит tessera для самой себя.
COMPONENTS=(
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

SCOPE_ARG=""
SCOPE="project"
PROJECT_MODE=0
HARNESS_ARG=""
SKILLS_DIR=""
PLUGIN_ONLY=0
UNINSTALL=0

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
Использование: scripts/setup.sh [параметры]
Задача mise: mise run setup [-- <параметры>]

Локальная настройка tessera для контрибьютора: навыки плагина связываются
с каталогами навыков найденных харнесов из рабочего дерева этого репозитория,
а зависимости приносятся в хранилище ~/.local/share/tessera/. tessera для самой
себя не ставится. Запускается из клонов и worktree репозитория tessera.

Параметры:

  Параметр                Действие                                     Умолчание
  --scope project|user    область установки: каталоги навыков          project
                          текущего репозитория или пользовательские
                          каталоги харнесов
  --plugin-only           только навыки плагина из рабочего дерева:    —
                          без зависимостей, хранилища и лаунчера
  --harness <список>      ограничить харнесы через запятую            все найденные
  --skills-dir <путь>     дополнительный каталог навыков              —
  --uninstall             снять ссылки локальной настройки            —
  -h, --help              справка                                      —

Повторный запуск идемпотентен: клоны зависимостей доводятся до ветки main,
ссылки пересоздаются. Диалога нет. Харнесы и их каталоги — та же таблица,
что у scripts/install.sh; перечень печатает его --help.

Коды возврата:
  0   настройка выполнена и прошла самопроверку, либо ничего не требовалось
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

# Входит ли слово в перечень через пробел.
list_has() { # перечень, слово
  case " $1 " in *" $2 "*) return 0 ;; esac
  return 1
}

# --- Харнессы и каталоги назначения -----------------------------------------

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

# --- Хранилище и навыки ------------------------------------------------------

# Вхождение компонента в состав запуска.
wanted_has() { # компонент
  list_has "${WANTED[*]-}" "$1"
}

clone_is_dirty() { # компонент
  [ -n "$(git -C "$STORAGE/$1" status --porcelain </dev/null 2>/dev/null)" ]
}

# Удаляет каталог в хранилище: путь обязан лежать внутри хранилища.
remove_storage_dir() { # путь
  case "$1" in "$STORAGE" | "$STORAGE"/*) ;; *) die "отказ удалять вне хранилища: $1" ;; esac
  rm -rf -- "$1"
}

# Приводит клоны состава к ветке main: новый клон либо git pull --ff-only.
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

# Навыки настройки — каталоги с SKILL.md: зависимости дают клоны хранилища,
# плагин — рабочее дерево репозитория. tessera для самой себя не ставится.
collect_skills() {
  local component sub dir path names=""
  SKILL_COMPONENT=()
  SKILL_SOURCE=()
  SKILL_NAME=()
  for path in "$PLUGIN_SKILLS"/*/; do
    if [ ! -f "${path}SKILL.md" ]; then continue; fi
    path="${path%/}"
    if list_has "$names" "${path##*/}"; then
      die "имя навыка ${path##*/} встречается в двух источниках настройки"
    fi
    names="$names ${path##*/}"
    SKILL_COMPONENT+=("tessera")
    SKILL_SOURCE+=("$path")
    SKILL_NAME+=("${path##*/}")
  done
  for component in ${WANTED[@]+"${WANTED[@]}"}; do
    for sub in $(component_skill_dirs "$component"); do
      dir="$STORAGE/$component/$sub"
      if [ ! -d "$dir" ]; then die "в клоне $component нет каталога навыков $sub"; fi
      for path in "$dir"/*/; do
        if [ ! -f "${path}SKILL.md" ]; then continue; fi
        path="${path%/}"
        if list_has "$names" "${path##*/}"; then
          die "имя навыка ${path##*/} встречается в двух источниках настройки"
        fi
        names="$names ${path##*/}"
        SKILL_COMPONENT+=("$component")
        SKILL_SOURCE+=("$path")
        SKILL_NAME+=("${path##*/}")
      done
    done
  done
}

# Ссылка создана локальной настройкой, когда её разрешённая цель лежит в хранилище
# (навыки зависимостей) или в навыках плагина рабочего дерева. Разрешение цели
# покрывает и относительные ссылки прежнего scripts/bootstrap.sh — они пересоздаются.
link_is_ours() { # путь ссылки
  local link="$1" target
  [ -L "$link" ] || return 1
  target="$(canonical "$link")" || return 1
  case "$target" in
    "$STORAGE" | "$STORAGE"/* | "$PLUGIN_SKILLS"/*) return 0 ;;
    *) return 1 ;;
  esac
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

# Лаунчер — обёртка, а не симлинк: bin/backlogберёт корень поставки из $0
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

# --- Навыки OpenSpec --------------------------------------------------------

# Регистрирует навыки OpenSpec в области установки: инициализация с перечнем отобранных
# харнесов (область project — проектная, user — пользовательская). Существующий
# openspec/config.yaml не перезаписывается — язык задаёт конфигурация репозитория,
# а служебные секции, дописываемые инициализацией, снимаются и возвращаются;
# повторный запуск идемпотентен. CLI закреплён в mise.toml и ставится через mise;
# без mise используется openspec из PATH, без обоих — предупреждение.
register_openspec_skills() {
  OPENSPEC_RESULT=""
  if [ "$PLUGIN_ONLY" -eq 1 ]; then
    OPENSPEC_RESULT="пропущено (--plugin-only)"
    return 0
  fi
  local row tools="" scope_arg conf_save="" conf="$PROJECT_DIR/openspec/config.yaml"
  if [ "${#SELECTED[@]}" -eq 0 ]; then
    OPENSPEC_RESULT="пропущено: харнесы не отобраны"
    return 0
  fi
  for row in ${SELECTED[@]+"${SELECTED[@]}"}; do tools="$tools,$(field "$row" 1)"; done
  tools="${tools#,}"
  if [ "$SCOPE" = "user" ]; then scope_arg="global"; else scope_arg="project"; fi
  if [ -f "$conf" ]; then
    conf_save="$(mktemp)"
    cp -- "$conf" "$conf_save"
  fi
  if command -v mise >/dev/null 2>&1; then
    mise install
    if ! mise exec -- openspec init --tools "$tools" --scope "$scope_arg" --no-animation --no-copilot-cloud >/dev/null; then
      restore_openspec_config
      die "не удалось зарегистрировать навыки OpenSpec"
    fi
  elif command -v openspec >/dev/null 2>&1; then
    if ! openspec init --tools "$tools" --scope "$scope_arg" --no-animation --no-copilot-cloud >/dev/null; then
      restore_openspec_config
      die "не удалось зарегистрировать навыки OpenSpec"
    fi
  else
    restore_openspec_config
    warn "mise и openspec не найдены — навыки OpenSpec не зарегистрированы; CLI закреплён в mise.toml"
    OPENSPEC_RESULT="пропущено: нет mise и openspec"
    return 0
  fi
  restore_openspec_config
  OPENSPEC_RESULT="зарегистрированы: $tools (область $scope_arg)"
}

# Возвращает снятую конфигурацию OpenSpec на место — при любом исходе инициализации.
restore_openspec_config() {
  [ -n "$conf_save" ] || return 0
  cp -- "$conf_save" "$conf"
  rm -f -- "$conf_save"
  conf_save=""
}

# --- Отчёт -----------------------------------------------------------------

# Перечень имён навыков с переносом строк.
wrap_names() { printf '%s\n' "$1" | fold -s -w 66 | sed -e 's/^/      /' -e 's/[[:space:]]*$//'; }

run_self_check() {
  local i
  BROKEN=()
  for i in ${LINK_NAME[@]+"${!LINK_NAME[@]}"}; do
    if [ ! -f "${LINK_DIR[$i]}/${LINK_NAME[$i]}/SKILL.md" ]; then
      BROKEN+=("${LINK_DIR[$i]}/${LINK_NAME[$i]}")
    fi
  done
  LAUNCHER_CHECK=""
  if wanted_has formular; then
    LAUNCHER_CHECK=0
    "$LAUNCHER" --help >/dev/null 2>&1 || LAUNCHER_CHECK=1
  fi
}

print_report() {
  local target i names count broken_here line
  say ""
  say "Отчёт локальной настройки"
  say "  Навыки плагина — из $(display "$PLUGIN_SKILLS") рабочего дерева."
  if [ "$(printf '%s' "${WANTED[*]-}" | wc -w)" -gt 0 ]; then
    say "  Зависимости в хранилище $(display "$STORAGE"):"
    for line in ${SOURCE_STATE[@]+"${SOURCE_STATE[@]}"}; do
      say "    ${line%%|*} — ${line#*|}"
    done
  else
    say "  Зависимости не приносятся (--plugin-only)."
  fi
  say "  Навыков в настройке: ${#SKILL_NAME[@]}."
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
  if [ "${#SKIPPED[@]}" -gt 0 ]; then
    say "  Пропущены чужие элементы (созданы не локальной настройкой):"
    for line in ${SKIPPED[@]+"${SKIPPED[@]}"}; do say "    $(display "$line")"; done
  fi
  if [ "${#STALE[@]}" -gt 0 ]; then
    say "  Сняты устаревшие ссылки (навыка нет в источнике):"
    for line in ${STALE[@]+"${STALE[@]}"}; do say "    $(display "$line")"; done
  fi
  if wanted_has formular; then
    say "  Лаунчер $(display "$LAUNCHER") — backlog --help: код $LAUNCHER_CHECK."
    if [ -n "${LAUNCHER_BACKUP:-}" ]; then
      say "  Прежний лаунчер сохранён: $(display "$LAUNCHER_BACKUP")."
    fi
  fi
  say "  Навыки OpenSpec — ${OPENSPEC_RESULT:-не регистрировались}."
  say "  Самопроверка: ссылок ${#LINK_NAME[@]}, неисправных ${#BROKEN[@]}."
}

# --- Настройка и удаление ---------------------------------------------------

setup_run() {
  SKIPPED=()
  STALE=()
  LINK_DIR=()
  LINK_NAME=()
  LAUNCHER_BACKUP=""
  ensure_sources
  collect_skills
  link_skills
  if wanted_has formular; then install_launcher; fi
  register_openspec_skills
  run_self_check
  print_report
  if [ "${#BROKEN[@]}" -gt 0 ]; then die "самопроверка не пройдена: есть неисправные ссылки"; fi
  if [ "$LAUNCHER_CHECK" = "1" ]; then
    die "самопроверка не пройдена: backlog --help не отвечает через лаунчер (для CLI backlog нужен python3)"
  fi
  if wanted_has formular && ! bin_dir_on_path; then
    warn "$(display "$BIN_DIR") вне PATH — добавьте каталог в PATH, чтобы команда backlog была доступна."
  fi
  say ""
  say "Готово. Перезапустите сессию харнеса, чтобы он увидел навыки."
}

# Снятие ссылок локальной настройки в каталогах выбранной области. Хранилище
# и лаунчер принадлежат поставке: их снимает scripts/install.sh --uninstall.
# В пользовательской области ссылки зависимостей принадлежат поставке и остаются;
# с --plugin-only снимаются только ссылки навыков плагина.
uninstall_run() {
  local target entry target_path removed total=0
  say ""
  say "Отчёт удаления локальной настройки"
  for target in ${TARGETS[@]+"${TARGETS[@]}"}; do
    [ -d "$target" ] || continue
    removed=0
    for entry in "$target"/*; do
      [ -L "$entry" ] || continue
      target_path="$(canonical "$entry")" || continue
      case "$target_path" in
        "$PLUGIN_SKILLS"/*)
          rm -- "$entry"
          removed=$(( removed + 1 ))
          ;;
        "$STORAGE" | "$STORAGE"/*)
          if [ "$SCOPE" = "project" ] && [ "$PLUGIN_ONLY" -eq 0 ]; then
            rm -- "$entry"
            removed=$(( removed + 1 ))
          else
            say "  $(display "$entry") — ссылка зависимости поставки, оставлена"
          fi
          ;;
      esac
    done
    total=$(( total + removed ))
  done
  say "  Ссылок снято: $total"
  say "  Хранилище и лаунчер не тронуты — их снимает scripts/install.sh --uninstall."
}

# --- Параметры запуска -----------------------------------------------------

need_value() { # параметр, значение
  [ -n "$2" ] || usage_error "параметру $1 нужно значение"
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --scope) need_value "$1" "${2:-}"; SCOPE_ARG="$2"; shift ;;
      --scope=*) SCOPE_ARG="${1#--scope=}"; need_value --scope "$SCOPE_ARG" ;;
      --harness) need_value "$1" "${2:-}"; HARNESS_ARG="$2"; shift ;;
      --harness=*) HARNESS_ARG="${1#--harness=}"; need_value --harness "$HARNESS_ARG" ;;
      --skills-dir) need_value "$1" "${2:-}"; SKILLS_DIR="$2"; shift ;;
      --skills-dir=*) SKILLS_DIR="${1#--skills-dir=}"; need_value --skills-dir "$SKILLS_DIR" ;;
      --plugin-only) PLUGIN_ONLY=1 ;;
      --uninstall) UNINSTALL=1 ;;
      -h | --help) usage; exit 0 ;;
      --) shift; break ;;
      -*) usage_error "неизвестный параметр: $1" ;;
      *) usage_error "неизвестный аргумент: $1" ;;
    esac
    shift
  done
  if [ $# -gt 0 ]; then usage_error "неизвестный аргумент: $1"; fi
  case "$SCOPE_ARG" in
    "" | project | user) ;;
    *) usage_error "неизвестная область: $SCOPE_ARG — project или user" ;;
  esac
  SCOPE="${SCOPE_ARG:-project}"
  if [ "$SCOPE" = "project" ]; then PROJECT_MODE=1; fi
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
PLUGIN_SKILLS="$(canonical "$PROJECT_DIR/plugins/tessera-plugin/skills")"
if [ ! -d "$PLUGIN_SKILLS" ]; then
  die "нет каталога навыков плагина: $PROJECT_DIR/plugins/tessera-plugin/skills — запускайте из клона tessera"
fi

# Состав запуска: все компоненты зависимостей либо, с --plugin-only, пустой.
WANTED=()
if [ "$PLUGIN_ONLY" -eq 0 ]; then
  for component in $(component_names); do WANTED+=("$component"); done
fi

SELECTED=()
TARGETS=()
select_harnesses found
compute_targets

if [ "${#TARGETS[@]}" -eq 0 ]; then
  die "харнесы не найдены и каталог навыков не передан — передайте путь параметром --skills-dir; список харнесов печатает scripts/install.sh --help"
fi

if [ "$UNINSTALL" -eq 1 ]; then
  uninstall_run
  exit 0
fi

setup_run
