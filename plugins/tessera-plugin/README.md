# tessera-plugin

Базовый каркас-шаблон плагина для проекта tessera: навык-заготовка и Python-инструменты,
которые наполняются реальным поведением. Отправная точка для собственных расширений агента.

---

## Навигация

- [Структура](#структура)
- [Python-инструменты](#python-инструменты)
- [Как расширять](#как-расширять)
- [Совместимость с Claude Code](#совместимость-с-claude-code)
- [Проверка](#проверка)

---

## Структура

| Путь | Назначение |
|------|------------|
| `.zcode-plugin/plugin.json` | Манифест плагина для ZCode: имя, версия, объявленные компоненты |
| `.claude-plugin/plugin.json` | Зеркальный манифест для Claude Code; синхронизируется с ним |
| `skills/tessera-plugin/SKILL.md` | Навык-заготовка: порядок работы при обращении к плагину |
| `scripts/tessera_tools.py` | Python-инструменты каркаса: подкоманды, вызываемые из навыка |

## Python-инструменты

Инструмент вызывается из корня плагина:

```bash
python3 scripts/tessera_tools.py hello --name "мир"
python3 scripts/tessera_tools.py info
```

Коды возврата:

| Код | Что значит | Что делаю |
|-----|------------|-----------|
| `0` | Подкоманда выполнена | Использую вывод |
| `2` | Ошибка разбора аргументов | Проверяю состав аргументов команды |

## Как расширять

1. Реальную возможность оформляйте новой подкомандой в `scripts/tessera_tools.py`: функция `cmd_<имя>`, регистрация в `build_parser`.
2. Порядок вызова подкоманд из навыка описывайте в `skills/tessera-plugin/SKILL.md`.
3. При изменении поведения повышайте `version` в `.zcode-plugin/plugin.json` **и** в `.claude-plugin/plugin.json` по семантическому версионированию.

## Совместимость с Claude Code

Плагин собирается из общих для обоих хостов компонентов: навык `skills/tessera-plugin/SKILL.md`,
Python-инструменты `scripts/tessera_tools.py` и токен `${CLAUDE_PLUGIN_ROOT}` — их формат совпадает.

Различаются две точки, и обе закрыты зеркальными файлами:

- манифест: ZCode читает `.zcode-plugin/plugin.json`, Claude Code — `.claude-plugin/plugin.json`;
  содержимое идентично и правится совместно;
- каталог рынка: `plugins/.claude-plugin/marketplace.json` — расположение, которое требует
  Claude Code и которое ZCode тоже поддерживает; имя рынка `dev-tessera-edf3c6d1` общее.

Установка в Claude Code (в REPL):

```text
/plugin marketplace add /home/llm-station/Workspace/open-source/usp/toolkit/workspace/projects/software-engineering/ai-agent-engineering/tessera/plugins
/plugin install tessera-plugin@dev-tessera-edf3c6d1
```

## Проверка

В окружении разработки доступна проверка манифеста перед установкой:

```bash
zcode plugins validate .
```

Команда выполняется из корня плагина; в обычной установке ZCode Desktop недоступна — там плагин
проверяется установкой из локального маркетплейса.
