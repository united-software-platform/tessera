#!/usr/bin/env python3
"""Инструменты каркаса плагина tessera-plugin.

Заготовка для собственных подкоманд: каждая новая возможность плагина — отдельная
подкоманда argparse, вызываемая из навыка skills/tessera-plugin.
"""

import argparse
import json
import sys
from pathlib import Path

# Корень плагина: scripts/ лежит на уровень ниже манифеста
PLUGIN_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = PLUGIN_ROOT / ".zcode-plugin" / "plugin.json"

# Объявленные зависимости плагина: имя, рынок, git-источник, минимальная версия
DEPENDENCIES = [
    {
        "name": "backlog",
        "marketplace": "formular",
        "url": "https://github.com/united-software-platform/formular.git",
        "path": "plugin/backlog",
        "ref": "main",
        "min_version": "1.4.0",
    },
]


def read_manifest() -> dict:
    """Читает манифест плагина .zcode-plugin/plugin.json."""
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def cmd_hello(args: argparse.Namespace) -> int:
    """Приветствие: демонстрация передачи аргументов в подкоманду."""
    print(f"Привет, {args.name}! Каркас tessera-plugin работает.")
    return 0


def cmd_info(args: argparse.Namespace) -> int:
    """Печатает имя и версию плагина из манифеста."""
    manifest = read_manifest()
    print(f"Плагин: {manifest['name']}")
    print(f"Версия: {manifest['version']}")
    return 0


def cmd_deps(args: argparse.Namespace) -> int:
    """Печатает объявленные зависимости плагина и их источники."""
    for dep in DEPENDENCIES:
        print(f"Зависимость: {dep['name']} >= {dep['min_version']} (рынок {dep['marketplace']})")
        print(f"Источник: {dep['url']}, путь {dep['path']}, ветка {dep['ref']}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    """Собирает парсер подкоманд; новые возможности регистрируются здесь."""
    parser = argparse.ArgumentParser(
        prog="tessera_tools",
        description="Инструменты каркаса плагина tessera-plugin",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    hello = subparsers.add_parser("hello", help="приветствие-проверка каркаса")
    hello.add_argument("--name", default="мир", help="имя для приветствия")
    hello.set_defaults(handler=cmd_hello)

    info = subparsers.add_parser("info", help="имя и версия плагина из манифеста")
    info.set_defaults(handler=cmd_info)

    deps = subparsers.add_parser("deps", help="зависимости плагина и их источники")
    deps.set_defaults(handler=cmd_deps)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.handler(args)


if __name__ == "__main__":
    sys.exit(main())
