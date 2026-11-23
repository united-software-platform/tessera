#!/usr/bin/env bash
# Локальная настройка репозитория tessera: регистрация навыков плагина в харнесах.
# Создаёт симлинки <каталог-навыков>/<имя> -> plugins/tessera-plugin/skills/<имя>; копий не возникает.
# Повторный запуск идемпотентен: существующие ссылки пересоздаются.

set -euo pipefail
cd "$(dirname "$0")/.."

SKILLS_DIR="plugins/tessera-plugin/skills"
KNOWN_TARGETS="agents claude"
LEGACY_TARGET=".zcode/skills"

usage() {
  cat <<EOF
Использование: scripts/bootstrap.sh [цель ...]

цель — agents | claude | произвольный путь к каталогу навыков харнеса.
Без аргументов регистрируются все известные цели: $KNOWN_TARGETS.
ZCode читает навыки из .agents/skills/ и отдельной цели не имеет; прежние ссылки навыков
плагина из прежнего каталога регистрации ZCode снимаются при каждом запуске.
EOF
}

resolve_target() {
  case "$1" in
    claude) echo ".claude/skills" ;;
    agents) echo ".agents/skills" ;;
    zcode)
      echo "Цель zcode снята: ZCode читает .agents/skills/ — передайте agents." >&2
      exit 2
      ;;
    *) echo "$1" ;;
  esac
}

# ZCode читает .agents/skills/, поэтому прежние ссылки навыков плагина из .zcode/skills
# снимаются: оставленные, они двоили бы навыки. Чужие элементы каталога не трогаются.
remove_legacy_links() {
  local link name
  [ -d "$LEGACY_TARGET" ] || return 0
  for link in "$LEGACY_TARGET"/*; do
    [ -L "$link" ] || continue
    name="${link##*/}"
    if [ "$(readlink -f "$link")" = "$(readlink -f "$SKILLS_DIR/$name")" ]; then
      rm "$link"
      echo "Снята прежняя ссылка: $link"
    fi
  done
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

remove_legacy_links

# Без аргументов — все известные цели
if [ "$#" -eq 0 ]; then
  # shellcheck disable=SC2086
  set -- $KNOWN_TARGETS
fi

for target_name in "$@"; do
  target_dir="$(resolve_target "$target_name")"
  mkdir -p "$target_dir"
  for skill_path in "$SKILLS_DIR"/*/; do
    name="$(basename "$skill_path")"
    link_target="$(realpath --relative-to="$target_dir" "${skill_path%/}")"
    ln -sfn "$link_target" "$target_dir/$name"
  done
  echo "Готово: $target_name -> $target_dir ($SKILLS_DIR)"
done
