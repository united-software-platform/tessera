#!/usr/bin/env bash
# Локальная настройка репозитория tessera: регистрация навыков плагина в харнесах.
# Создаёт симлинки <каталог-навыков>/<имя> -> plugins/tessera-plugin/skills/<имя>; копий не возникает.
# Повторный запуск идемпотентен: существующие ссылки пересоздаются.

set -euo pipefail
cd "$(dirname "$0")/.."

SKILLS_DIR="plugins/tessera-plugin/skills"
KNOWN_TARGETS="zcode claude agents"

usage() {
  cat <<EOF
Использование: scripts/bootstrap.sh [цель ...]

цель — zcode | claude | agents | произвольный путь к каталогу навыков харнеса.
Без аргументов регистрируются все известные цели: $KNOWN_TARGETS.
EOF
}

resolve_target() {
  case "$1" in
    zcode) echo ".zcode/skills" ;;
    claude) echo ".claude/skills" ;;
    agents) echo ".agents/skills" ;;
    *) echo "$1" ;;
  esac
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

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
