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
FAKE="$TMP/home-full"         # HOME дымового прогона полного профиля
PROJ="$TMP/project"           # проект дымового прогона установки в проект
PROJ_HOME="$TMP/home-project" # HOME дымового прогона установки в проект
MIRROR="$TMP/mirror"          # зеркало фиксации HEAD — источник tessera прогонов
mkdir -p "$FAKE" "$PROJ" "$PROJ_HOME"

say "Проверки репозитория tessera: $REPO"

# --- Проверки ----------------------------------------------------------------

# Каждая проверка — функция без аргументов; её код возврата — результат проверки.
# Порядок: статические проверки, затем два дымовых прогона.

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

check "манифест ZCode — валидный JSON" manifest_zcode_json
check "манифесты ZCode и Claude Code — идентичны" manifests_identical
check "скрипт поставки — синтаксис" install_script_syntax
check "скрипт поставки — справка" install_script_help
check "реестр поставки — валидный JSON" registry_json

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

smoke_full_profile() {
  prepare_source
  HOME="$FAKE" scripts/install.sh --yes --skills-dir "$FAKE/skills"
}

smoke_project_install() {
  (
    cd "$PROJ"
    HOME="$PROJ_HOME" bash "$REPO/scripts/install.sh" --yes --project \
      --skills-dir "$PROJ/skills" --rules documentation-rules
    grep -q 'delivery-tessera-' AGENTS.md
  )
}

check "дымовой прогон — полный профиль в поддельном домашнем каталоге" smoke_full_profile

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

check "дымовой прогон — установка в проект, секция правил записана" smoke_project_install

say ""
say "Все проверки пройдены: 7 из 7."
