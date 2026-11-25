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

check "манифест ZCode — валидный JSON" manifest_zcode_json
check "манифесты ZCode и Claude Code — идентичны" manifests_identical
check "скрипт поставки — синтаксис" install_script_syntax
check "скрипт поставки — справка" install_script_help
check "реестр поставки — валидный JSON" registry_json
check "реестр поставки — состав перечнем компонентов" registry_composition
check "реестр поставки — без параметров все компоненты" registry_all_components
check "скрипт поставки — снятые и неверные параметры отвергаются" rejected_params
check "навыки — отказы называют состав, снятых параметров нет" skills_refusals

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

say ""
say "Все проверки пройдены: 12 из 12."
