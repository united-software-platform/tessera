# CONTRIBUTING

Как устроен репозиторий tessera, как проверяется правка и какие нормы действуют. Читатель —
правящий плагин; применяющему систему — [`README.md`](./README.md), агентам, работающим
в репозитории, — [`AGENTS.md`](./AGENTS.md).

---

## Навигация

- [Устройство репозитория](#устройство-репозитория)
- [Локальная настройка](#локальная-настройка)
- [Блок бейджей](#блок-бейджей)
- [Проверки](#проверки)
- [Правила и процесс](#правила-и-процесс)
- [Версионирование](#версионирование)

---

## Устройство репозитория

| Путь | Назначение |
|------|------------|
| `AGENTS.md` | Точка входа правил для агентов, работающих в репозитории |
| `plugins/tessera-plugin/` | Плагин-носитель: навыки, правила, Python-инструменты |
| `plugins/tessera-plugin/.zcode-plugin/plugin.json` | Манифест плагина для ZCode |
| `plugins/tessera-plugin/.claude-plugin/plugin.json` | Зеркальный манифест для Claude Code |
| `plugins/tessera-plugin/skills/` | Навыки формата Agent Skills |
| `plugins/tessera-plugin/rules/` | Правила оформления и процесса |
| `plugins/.claude-plugin/marketplace.json` | Каталог маркетплейса `tessera` (владелец `usp`) |
| `scripts/bootstrap.sh` | Локальная регистрация навыков плагина в харнесах |
| `openspec/` | Спецификации OpenSpec — схема spec-driven |
| `.zcode/`, `.claude/`, `.agents/` | Локальная регистрация харнесов; вне индекса git |

## Локальная настройка

Регистрация харнесов локальна и в индекс git не входит: `scripts/bootstrap.sh` создаёт симлинки
навыков в каталогах харнесов — известные цели `zcode`, `claude`, `agents` или произвольный путь
(перечень печатает `--help`); OpenSpec устанавливается командой `openspec init` с набором
инструментов по выбору разработчика. Подробности — в
[`AGENTS.md`](./AGENTS.md#локальная-настройка).

## Блок бейджей

| Бейдж | Источник значения | Режим | Цель ссылки |
|-------|-------------------|-------|-------------|
| Версия tessera-plugin | Манифест `plugins/tessera-plugin/.zcode-plugin/plugin.json` (raw-файл на `main`) | Динамический — shields `dynamic/json`, запрос `$.version` | blob-страница манифеста в этом репозитории |
| Версия backlog | Манифест `plugin/backlog/.claude-plugin/plugin.json` репозитория formular (raw-файл на `main`) | Динамический — shields `dynamic/json`, запрос `$.version` | каталог `plugin/backlog` в репозитории formular |
| Версия mattpocock-skills | Манифест `.claude-plugin/plugin.json` репозитория mattpocock/skills (raw-файл на `main`) | Динамический — shields `dynamic/json`, запрос `$.version` | репозиторий mattpocock/skills |
| OpenSpec-схема | `openspec/config.yaml`, поле `schema` (raw-файл на `main`) | Динамический — shields `dynamic/yaml`, запрос `schema` | каталог `openspec` этого репозитория |
| Лицензия MIT | Неизменная характеристика | Статический | `https://spdx.org/licenses/MIT.html` |

Переименование манифеста или смена пути сломает динамический бейдж — носители значений
перечислены в таблице. Значения читаются с ветки `main` GitHub.

## Проверки

```bash
python3 -m json.tool plugins/tessera-plugin/.zcode-plugin/plugin.json > /dev/null   # манифест ZCode — валидный JSON
diff plugins/tessera-plugin/.zcode-plugin/plugin.json plugins/tessera-plugin/.claude-plugin/plugin.json  # манифесты идентичны
bash scripts/bootstrap.sh                                                            # локальная регистрация навыков
```

## Правила и процесс

- Формат сообщения коммита — [GIT-009](./plugins/tessera-plugin/rules/git-rules.md#формат-сообщения-коммита).
- Запрет служебных подписей агентов в коммитах и PR — [GIT-012](./plugins/tessera-plugin/rules/git-rules.md#запрет-служебных-подписей).
- Оформление документов — [DOC-014](./plugins/tessera-plugin/rules/documentation-rules.md#структура-файла).
- Какой материал в каком документе — [DGN-001](./plugins/tessera-plugin/rules/project-docs-rules.md#роли-читателей-dgn-001).

---

## Версионирование

| Версия | Дата | Задача | Агент | Модель | Описание изменений |
|--------|------|--------|-------|--------|--------------------|
| 1.0.0 | 2026-11-23 | Запрос пользователя: привести документы проекта в порядок (навык project-docs) | ZCode | GLM-5.3 | Начальное создание по каркасу DGN-008: устройство репозитория, локальная настройка, карта бейджей, проверки, правила и процесс |
| 1.0.1 | 2026-11-23 | Запрос пользователя: сделать установку универсальной | ZCode | GLM-5.3 | Устройство дополнено `.claude/`; локальная настройка переписана под цели `scripts/bootstrap.sh` (`zcode`, `claude`, `agents`, произвольный путь) |
| 1.0.2 | 2026-11-23 | Запрос пользователя: убрать python tool | ZCode | GLM-5.3 | Из устройства и проверок удалены Python-инструменты плагина (`scripts/tessera_tools.py` удалён вместе с каталогом `scripts/` плагина) |
| 1.0.3 | 2026-11-23 | Запрос пользователя: нужны версия и бейджи для formular и плагина | ZCode | GLM-5.3 | Добавлены динамические бейджи версий tessera-plugin (из манифеста этого репозитория) и backlog (из манифеста formular) через shields `dynamic/json`; карта бейджей дополнена носителями значений |
| 1.0.4 | 2026-11-23 | Запрос пользователя: добавить зависимость mattpocock-skills | ZCode | GLM-5.3 | Добавлены бейдж версии mattpocock-skills и строка в карту бейджей; зависимости в README дополнены mattpocock-skills (навык `grilling` для workflow-grill) |
| 1.0.5 | 2026-11-23 | Запрос пользователя: бейджи openspec и mattpocock-skills | ZCode | GLM-5.3 | Добавлен бейдж openspec-схемы (`dynamic/yaml`, поле `schema` из `openspec/config.yaml`) и строка в карту бейджей; бейдж mattpocock-skills добавлен предыдущей правкой (1.0.4) |
