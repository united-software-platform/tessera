#!/usr/bin/env bash
# Скрипт проверок репозитория tessera — единая точка входа: его запускает и правящий
# репозиторий, и workflow CI (.github/workflows/ci.yml). Проверки исполняются по порядку,
# каждая перед запуском называется; непройденная проверка называет себя и завершает скрипт
# с ненулевым кодом — следующие не запускаются. Перечень проверок живёт только в этом файле.
# Дымовые прогоны ставят tessera из фиксации HEAD репозитория, поэтому прогон видит
# только зафиксированное состояние: правку фиксируют до запуска.
# Запуск: scripts/check.sh — параметров нет.

set -euo pipefail

cd "$(dirname "$0")/.."
REPO="$PWD"

say() { printf '%s\n' "$*"; }

# Обёртка проверки: называет проверку перед запуском, при ошибке называет её
# и завершает скрипт — следующие проверки не запускаются.
check() { # имя проверки, функция проверки
  local name="$1"; shift
  say "— $name"
  if "$@"; then return 0; fi
  say ""
  say "Проверка не пройдена: $name"
  exit 1
}

# --- Временные каталоги ------------------------------------------------------

# Всё, что проверки создают на диске, живёт здесь и снимается на выходе: HOME дымовых
# прогонов, проект установки в проект, зеркало источника tessera.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKE="$TMP/home-full"         # HOME дымовых прогонов полного состава и смены состава
PROJ="$TMP/project"           # проект дымового прогона установки в проект
PROJ_HOME="$TMP/home-project" # HOME дымового прогона установки в проект
MIRROR="$TMP/mirror"          # зеркало фиксации HEAD — источник tessera прогонов
mkdir -p "$FAKE" "$PROJ" "$PROJ_HOME"

say "Проверки репозитория tessera: $REPO"

# --- Проверки ----------------------------------------------------------------

# Каждая проверка — функция без аргументов; её код возврата — результат проверки.
# Порядок: статические проверки, затем три дымовых прогона.

manifest_zcode_json() {
  python3 -m json.tool plugins/tessera-plugin/.zcode-plugin/plugin.json > /dev/null
}

manifests_identical() {
  diff plugins/tessera-plugin/.zcode-plugin/plugin.json \
    plugins/tessera-plugin/.claude-plugin/plugin.json > /dev/null
}

install_script_syntax() {
  bash -n scripts/install.sh
}

install_script_help() {
  HOME="$PROJ_HOME" scripts/install.sh --help > /dev/null
}

registry_json() {
  HOME="$PROJ_HOME" scripts/install.sh --registry | python3 -m json.tool > /dev/null
}

# Реестр состава: перечню --components отвечают признаки входжения, поля профилей
# и режимов в реестре 2.0.0 нет.
registry_composition() {
  HOME="$PROJ_HOME" scripts/install.sh --registry --components tessera,mattpocock-skills \
    > "$TMP/registry-composition.json"
  python3 - "$TMP/registry-composition.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
included = {c["name"]: c["included"] for c in r["components"]}
assert included == {"tessera": True, "formular": False, "mattpocock-skills": True}, included
assert r["registry_version"] == "2.0.0", r["registry_version"]
assert r["scope"] == "user", r["scope"]
assert "profile" not in r and "mode" not in r, sorted(r)
assert r["launcher"]["included"] is False, r["launcher"]
PY
}

# Реестр без параметров: все компоненты включены, лаунчер formular входит.
registry_all_components() {
  HOME="$PROJ_HOME" scripts/install.sh --registry > "$TMP/registry-all.json"
  python3 - "$TMP/registry-all.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
assert all(c["included"] for c in r["components"]), [c["name"] for c in r["components"]]
assert r["launcher"]["included"] is True, r["launcher"]
assert r["scope"] == "user", r["scope"]
PY
}

# Снятые и неверные параметры останавливают запуск кодом 2 с подсказкой замены,
# ничего не меняя на диске.
expect_reject() { # подсказка, параметры запуска...
  local hint="$1"; shift
  local rc=0 out
  out="$(HOME="$PROJ_HOME" scripts/install.sh "$@" 2>&1)" || rc=$?
  if [ "$rc" -ne 2 ]; then
    say "  ожидался код возврата 2, получен $rc: $*"
    return 1
  fi
  if ! printf '%s\n' "$out" | grep -q -- "$hint"; then
    say "  в сообщении нет подсказки «$hint»: $*"
    return 1
  fi
}

rejected_params() {
  expect_reject "--components" --profile backlog
  expect_reject "--scope project" --project
  expect_reject "неизвестный компонент" --components tessera,bogus
  expect_reject "--scope project" --rules all
  expect_reject "--components" --scope project --components formular
  expect_reject "--uninstall" --components tessera --uninstall
  expect_reject "project или user" --scope local
  if [ -d "$PROJ_HOME/.local/share/tessera" ]; then
    say "  хранилище создано при отверженных параметрах"
    return 1
  fi
}

# Отказы навыков называют состав (--components) и не упоминают снятых параметров;
# исторические строки таблиц версий (начинаются с «|») не проверяются.
skills_refusals() {
  local f
  for f in plugins/tessera-plugin/skills/workflow-fast/SKILL.md \
           plugins/tessera-plugin/skills/workflow-grill/SKILL.md \
           plugins/tessera-plugin/skills/tessera-plugin/SKILL.md; do
    if grep -v '^| ' "$f" | grep -q -e '--profile' -e '--project' -e 'профилем'; then
      say "  $f — вне таблицы версий упоминаются снятые параметры"
      return 1
    fi
  done
  grep -q -- '--components' plugins/tessera-plugin/skills/workflow-fast/SKILL.md || return 1
  grep -q -- '--components' plugins/tessera-plugin/skills/workflow-grill/SKILL.md || return 1
}

# Сверка объявления предмета: каждый носитель для агентов открывается канонической строкой
# своего предмета — единственной и сразу после заголовка (PLG-003, PLG-004). Для README
# строкам до объявления разрешено быть блоком бейджей; навыкам — YAML-фронтматтером.
# Перечень носителей живёт только здесь.
subject_check_file() { # файл, предмет
  local file="$1" subject="$2" mark line before stripped
  if [ "$subject" = "продукт" ]; then
    mark='**Предмет:** продукт — уровень предмета: что описывается, поведение компонента.'
  else
    mark='**Предмет:** разработка продукта — уровень работы над предметом: как этот предмет создаётся, правила и процесс.'
  fi
  # Блоки кода не считаются: правило норм цитирует канонические строки как примеры.
  stripped="$(awk '/^```/{in_block = !in_block; next} !in_block' "$file")"
  line="$(printf '%s\n' "$stripped" | grep -n -m1 -x -F "$mark" | cut -d: -f1)"
  if [ -z "$line" ]; then
    say "  $file — нет канонического объявления предмета «$subject»"
    return 1
  fi
  if [ "$(printf '%s\n' "$stripped" | grep -c -x -F "$mark")" -ne 1 ]; then
    say "  $file — объявление предмета «$subject» не единственно"
    return 1
  fi
  before="$(printf '%s\n' "$stripped" | head -n $(( line - 1 )))"
  if printf '%s\n' "$before" | grep -qv -E '^$|^#|^---$|^[a-zA-Z-]+:|^\[!\[|^!\['; then
    say "  $file — объявление предмета стоит не сразу после заголовка"
    return 1
  fi
}

subject_declarations() {
  local f
  for f in plugins/tessera-plugin/rules/*.md \
           plugins/tessera-plugin/skills/*/SKILL.md \
           plugins/tessera-plugin/README.md \
           README.md \
           docs/use-cases.md; do
    subject_check_file "$f" "продукт" || return 1
  done
  for f in AGENTS.md CONTRIBUTING.md GLOSSARY.md; do
    subject_check_file "$f" "разработка" || return 1
  done
}

check "манифест ZCode — валидный JSON" manifest_zcode_json
check "манифесты ZCode и Claude Code — идентичны" manifests_identical
check "скрипт поставки — синтаксис" install_script_syntax
check "скрипт поставки — справка" install_script_help
check "реестр поставки — валидный JSON" registry_json
check "реестр поставки — состав перечнем компонентов" registry_composition
check "реестр поставки — без параметров все компоненты" registry_all_components
check "скрипт поставки — снятые и неверные параметры отвергаются" rejected_params
check "навыки — отказы называют состав, снятых параметров нет" skills_refusals
check "описания для агентов — предмет объявлен канонически" subject_declarations

# --- Скрипт локальной настройки ---------------------------------------------

# Сторож общих блоков локальной настройки: функции, скопированные из scripts/install.sh,
# и таблица харнесов сверяются дословно; строки зависимостей setup.sh — ровно строки
# COMPONENTS скрипта поставки без tessera. Перечень общих функций живёт только здесь.
common_block() { # файл, имя функции
  awk -v fn="$2" '
    index($0, fn"() {") == 1 {
      print
      if (/\}$/) exit
      p = 1
      next
    }
    p { print }
    p && /^}/ { exit }
  ' "$1"
}

setup_shared_blocks() {
  local fn a b
  for fn in canonical display expand_home last_line \
            field harness_row harness_is_found harness_target \
            component_row component_url component_skill_dirs component_names \
            list_has add_target compute_targets select_harnesses \
            clone_is_dirty remove_storage_dir ensure_sources \
            remove_stale_links link_skills free_backup_path launcher_is_ours \
            install_launcher bin_dir_on_path wrap_names; do
    a="$(common_block scripts/install.sh "$fn")"
    if [ -z "$a" ]; then
      say "  в scripts/install.sh нет функции $fn — обновите перечень общих функций"
      return 1
    fi
    b="$(common_block scripts/setup.sh "$fn")"
    if [ "$a" != "$b" ]; then
      say "  общая функция разошлась: $fn"
      return 1
    fi
  done
  a="$(awk '/^HARNESSES=\(/,/^\)/' scripts/install.sh)"
  b="$(awk '/^HARNESSES=\(/,/^\)/' scripts/setup.sh)"
  if [ "$a" != "$b" ]; then
    say "  таблица харнесов разошлась со скриптом поставки"
    return 1
  fi
  a="$(awk '/^COMPONENTS=\(/,/^\)/' scripts/install.sh | grep '^  "' | grep -v '"tessera|')"
  b="$(awk '/^COMPONENTS=\(/,/^\)/' scripts/setup.sh | grep '^  "')" 
  if [ "$a" != "$b" ]; then
    say "  строки компонентов зависимостей не совпадают со скриптом поставки"
    return 1
  fi
}

setup_script_syntax() {
  bash -n scripts/setup.sh
}

setup_script_help() {
  HOME="$PROJ_HOME" scripts/setup.sh --help > /dev/null
}

setup_rejected_params() {
  expect_reject "project или user" --scope local
}

check "скрипт настройки — синтаксис" setup_script_syntax
check "скрипт настройки — справка" setup_script_help
check "скрипт настройки — общие блоки со скриптом поставки идентичны" setup_shared_blocks
check "скрипт настройки — неверные параметры отвергаются" setup_rejected_params

# --- Дымовые прогоны -----------------------------------------------------------

# Скрипт поставки всегда ставит tessera из ветки main репозитория по адресу из таблицы
# COMPONENTS, поэтому прогон правки без перенаправления проверял бы install.sh прогона
# против содержимого main. Зеркало берёт фиксацию HEAD этого репозитория, а перенаправление
# адреса направляет клон tessera в него; зависимости идут в свои репозитории, как всегда.
# Зеркало обязано быть мелким (--depth=1): клон runner'а мелкий, и не мелкое зеркало
# отклоняет его ссылку. Перенаправление — только переменными окружения: конфигурация git
# и сам скрипт поставки не меняются.
prepare_source() {
  git init -q --bare "$MIRROR"
  git -C "$MIRROR" symbolic-ref HEAD refs/heads/main
  git -C "$MIRROR" fetch -q --depth=1 "file://$REPO" HEAD:refs/heads/main
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0="url.file://$MIRROR.insteadOf"
  export GIT_CONFIG_VALUE_0="https://github.com/united-software-platform/tessera.git"
}

smoke_full_composition() {
  prepare_source
  HOME="$FAKE" scripts/install.sh --yes --skills-dir "$FAKE/skills"
}

# Смена состава на клонах первого прогона: сужение снимает formular с лаунчером
# и ссылками backlog, запуск без --components возвращает его, сохраняя mattpocock-skills.
smoke_shrink_and_restore() {
  HOME="$FAKE" scripts/install.sh --yes --skills-dir "$FAKE/skills" \
    --components tessera,mattpocock-skills
  if [ -e "$FAKE/.local/share/tessera/formular" ]; then
    say "  клон formular должен быть снят"; return 1
  fi
  if [ -e "$FAKE/.local/bin/backlog" ]; then
    say "  лаунчер должен быть снят"; return 1
  fi
  if [ -L "$FAKE/skills/backlog-generate" ]; then
    say "  ссылка backlog-generate должна быть снята"; return 1
  fi
  if [ ! -L "$FAKE/skills/grilling" ]; then
    say "  ссылка grilling должна остаться"; return 1
  fi
  HOME="$FAKE" scripts/install.sh --yes --skills-dir "$FAKE/skills"
  if [ ! -d "$FAKE/.local/share/tessera/formular" ]; then
    say "  клон formular должен вернуться"; return 1
  fi
  if [ ! -f "$FAKE/.local/bin/backlog" ]; then
    say "  лаунчер должен вернуться"; return 1
  fi
  if [ ! -L "$FAKE/skills/backlog-generate" ]; then
    say "  ссылка backlog-generate должна вернуться"; return 1
  fi
}

smoke_project_install() {
  (
    cd "$PROJ"
    HOME="$PROJ_HOME" bash "$REPO/scripts/install.sh" --yes --scope project \
      --skills-dir "$PROJ/skills" --rules documentation-rules
    grep -q 'delivery-tessera-' AGENTS.md
  )
}

check "дымовой прогон — полный состав в поддельном домашнем каталоге" smoke_full_composition

# Контроль источника — сразу после первого прогона: клон tessera в хранилище обязан быть
# из HEAD репозитория. Смена адреса tessera в scripts/install.sh уводит клон к ветке main
# GitHub, и перенаправление перестаёт действовать молча; контроль такой откат запрещает.
stored_head="$(git -C "$FAKE/.local/share/tessera/tessera" rev-parse HEAD 2>/dev/null || true)"
repo_head="$(git -C "$REPO" rev-parse HEAD)"
if [ -n "$stored_head" ] && [ "$stored_head" = "$repo_head" ]; then
  say "  контроль источника: клон tessera — из HEAD репозитория"
else
  say ""
  say "Контроль источника не пройден: клон tessera не из HEAD репозитория —"
  say "сверьте адрес tessera в scripts/install.sh и scripts/check.sh."
  exit 1
fi

check "дымовой прогон — смена состава: сужение и возврат" smoke_shrink_and_restore
check "дымовой прогон — установка в проект, секция правил записана" smoke_project_install

# --- Дымовые прогоны локальной настройки --------------------------------------

# Локальная настройка не видит харнесов настоящего HOME: признаков в поддельном
# домашнем каталоге нет, и цель задаёт --skills-dir. Зависимости клонируются
# из своих репозиториев на GitHub, навыки плагина — из рабочего дерева проверок.
SETUP_HOME="$TMP/home-setup"
SETUP2="$TMP/home-setup2"

smoke_setup_full() {
  local before
  mkdir -p "$SETUP_HOME/skills"
  before="$(git -C "$REPO" status --porcelain)"
  HOME="$SETUP_HOME" scripts/setup.sh --skills-dir "$SETUP_HOME/skills" >"$TMP/setup-full.log" 2>&1 ||
    { cat "$TMP/setup-full.log"; return 1; }
  [ ! -e "$SETUP_HOME/.local/share/tessera/tessera" ] || { say "  клон tessera не должен появляться"; return 1; }
  [ -d "$SETUP_HOME/.local/share/tessera/formular" ] || { say "  клона formular нет"; return 1; }
  [ -d "$SETUP_HOME/.local/share/tessera/mattpocock-skills" ] || { say "  клона mattpocock-skills нет"; return 1; }
  [ "$(readlink -f "$SETUP_HOME/skills/project-docs")" = "$REPO/plugins/tessera-plugin/skills/project-docs" ] ||
    { say "  ссылка навыка плагина ведёт не в рабочее дерево"; return 1; }
  HOME="$SETUP_HOME" "$SETUP_HOME/.local/bin/backlog" --help >/dev/null 2>&1 ||
    { say "  лаунчер backlog не отвечает"; return 1; }
  [ ! -e "$REPO/.tessera" ] || { say "  каталог .tessera/ не должен появляться"; return 1; }
  [ "$(git -C "$REPO" status --porcelain)" = "$before" ] || { say "  состояние репозитория изменилось"; return 1; }
}

smoke_setup_variants() {
  mkdir -p "$SETUP2/skills"
  HOME="$SETUP2" scripts/setup.sh --plugin-only --skills-dir "$SETUP2/skills" >"$TMP/setup-plugin-only.log" 2>&1 ||
    { cat "$TMP/setup-plugin-only.log"; return 1; }
  [ ! -e "$SETUP2/.local/share/tessera" ] || { say "  хранилище не должно создаваться с --plugin-only"; return 1; }
  [ ! -e "$SETUP2/.local/bin" ] || { say "  лаунчер не должен ставиться с --plugin-only"; return 1; }
  [ -L "$SETUP2/skills/workflow-fast" ] || { say "  ссылки навыка плагина нет с --plugin-only"; return 1; }
  HOME="$SETUP2" scripts/setup.sh --skills-dir "$SETUP2/skills" >"$TMP/setup-full2.log" 2>&1 ||
    { cat "$TMP/setup-full2.log"; return 1; }
  HOME="$SETUP2" scripts/setup.sh --uninstall --skills-dir "$SETUP2/skills" >"$TMP/setup-uninstall.log" 2>&1 ||
    { cat "$TMP/setup-uninstall.log"; return 1; }
  [ ! -e "$SETUP2/skills/project-docs" ] || { say "  ссылка навыка плагина должна быть снята"; return 1; }
  [ ! -e "$SETUP2/skills/backlog-generate" ] || { say "  ссылка зависимости должна сниматься в области project"; return 1; }
  [ -d "$SETUP2/.local/share/tessera/formular" ] || { say "  хранилище должно остаться после удаления"; return 1; }
  [ -f "$SETUP2/.local/bin/backlog" ] || { say "  лаунчер должен остаться после удаления"; return 1; }
  mkdir -p "$SETUP2/.zcode" "$SETUP2/.claude"
  HOME="$SETUP2" scripts/setup.sh --scope user >"$TMP/setup-user.log" 2>&1 ||
    { cat "$TMP/setup-user.log"; return 1; }
  [ -L "$SETUP2/.agents/skills/project-docs" ] || { say "  нет ссылки навыка плагина в ~/.agents/skills"; return 1; }
  [ -L "$SETUP2/.claude/skills/project-docs" ] || { say "  нет ссылки навыка плагина в ~/.claude/skills"; return 1; }
}

check "дымовой прогон — локальная настройка: полный состав, tessera нет в хранилище" smoke_setup_full
check "дымовой прогон — локальная настройка: --plugin-only, удаление, область user" smoke_setup_variants

say ""
say "Все проверки пройдены: 19 из 19."
