#!/usr/bin/env bash
# Профили установки tessera: базовый плагин и опциональные зависимости из маркетплейсов-источников.
# Каталог маркетплейса tessera несёт только tessera-plugin; backlog ставится из formular,
# mattpocock-skills — из mattpocock. Зависимости — выбор разработчика, цикл поставки не замыкается.

set -euo pipefail
cd "$(dirname "$0")/.."

TESSERA_MARKETPLACE="united-software-platform/tessera"
FORMULAR_MARKETPLACE="united-software-platform/formular"
MATTSKILLS_MARKETPLACE="mattpocock/skills"

usage() {
  cat <<EOF
Использование: scripts/install-plugins.sh [--all | --backlog] [--mattpocock-skills]

tessera-plugin ставится всегда. Зависимости — опционально, из маркетплейсов-источников:
  --all                 полный набор: backlog и mattpocock-skills
  --backlog             только backlog (нужен workflow-fast и workflow-grill)
  --mattpocock-skills   только mattpocock-skills (прожарка в workflow-grill)

Флаги комбинируются; без флагов печатается эта справка.
Харнес с CLI (claude) получает команды установки; без CLI печатается пошаговая инструкция.
EOF
}

WANT_BACKLOG=0
WANT_MATTSKILLS=0
for arg in "$@"; do
  case "$arg" in
    --all) WANT_BACKLOG=1; WANT_MATTSKILLS=1 ;;
    --backlog) WANT_BACKLOG=1 ;;
    --mattpocock-skills) WANT_MATTSKILLS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Неизвестный флаг: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [ $((WANT_BACKLOG + WANT_MATTSKILLS)) -eq 0 ]; then
  usage
  exit 0
fi

print_instructions() {
  cat <<EOF
CLI установки плагинов в этом окружении недоступен — пошаговая инструкция.

Claude Code (REPL):
  /plugin marketplace add $TESSERA_MARKETPLACE
  /plugin install tessera-plugin@tessera
EOF
  if [ "$WANT_BACKLOG" -eq 1 ]; then
    cat <<EOF
  /plugin marketplace add $FORMULAR_MARKETPLACE
  /plugin install backlog@formular
EOF
  fi
  if [ "$WANT_MATTSKILLS" -eq 1 ]; then
    cat <<EOF
  /plugin marketplace add $MATTSKILLS_MARKETPLACE
  /plugin install mattpocock-skills@mattpocock
EOF
  fi
  cat <<EOF

ZCode (интерфейс):
  Plugin Marketplace → Add → Add Plugin Marketplace — адреса репозиториев:
    https://github.com/$TESSERA_MARKETPLACE.git
EOF
  if [ "$WANT_BACKLOG" -eq 1 ]; then
    echo "    https://github.com/$FORMULAR_MARKETPLACE.git"
  fi
  if [ "$WANT_MATTSKILLS" -eq 1 ]; then
    echo "    https://github.com/$MATTSKILLS_MARKETPLACE.git"
  fi
  cat <<'EOF'
  затем Personal → <маркетплейс> → установка плагина кнопкой.
EOF
}

if command -v claude >/dev/null 2>&1; then
  claude plugin marketplace add "$TESSERA_MARKETPLACE"
  claude plugin install "tessera-plugin@tessera"
  if [ "$WANT_BACKLOG" -eq 1 ]; then
    claude plugin marketplace add "$FORMULAR_MARKETPLACE"
    claude plugin install "backlog@formular"
  fi
  if [ "$WANT_MATTSKILLS" -eq 1 ]; then
    claude plugin marketplace add "$MATTSKILLS_MARKETPLACE"
    claude plugin install "mattpocock-skills@mattpocock"
  fi
else
  print_instructions
fi
