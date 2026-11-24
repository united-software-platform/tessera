# tessera

[![версия tessera-plugin](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Funited-software-platform%2Ftessera%2Fmain%2Fplugins%2Ftessera-plugin%2F.zcode-plugin%2Fplugin.json&query=%24.version&label=tessera-plugin&color=blue)](https://github.com/united-software-platform/tessera/blob/main/plugins/tessera-plugin/.zcode-plugin/plugin.json)
[![версия backlog](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Funited-software-platform%2Fformular%2Fmain%2Fplugin%2Fbacklog%2F.claude-plugin%2Fplugin.json&query=%24.version&label=backlog&color=9cf)](https://github.com/united-software-platform/formular/tree/main/plugin/backlog)
[![версия mattpocock-skills](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fmattpocock%2Fskills%2Fmain%2F.claude-plugin%2Fplugin.json&query=%24.version&label=mattpocock-skills&color=9cf)](https://github.com/mattpocock/skills)
[![лицензия MIT](https://img.shields.io/badge/license-MIT-success)](https://spdx.org/licenses/MIT.html)
![ZCode](https://img.shields.io/badge/ZCode-blueviolet)
[![Codex](https://img.shields.io/badge/Codex-blueviolet)](https://github.com/openai/codex)
[![Gemini CLI](https://img.shields.io/badge/Gemini%20CLI-blueviolet)](https://github.com/google-gemini/gemini-cli)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-blueviolet)](https://claude.com/claude-code)
[![OpenCode](https://img.shields.io/badge/OpenCode-blueviolet)](https://opencode.ai)

tessera — минимальный инженерный фреймворк: правила работы с репозиториями, процессами
и построения ПО вместе с навыками, которые их применяют. Гибкий пересмотр
[sdd-developer-kit](https://github.com/united-software-platform/sdd-developer-kit) — та же
методология без его привязки к Claude и песочнице. Имя — мозаичный элемент: набор, собранный
из частей.

Поставка — скрипт установки: одна команда ставит в любой харнес, читающий навыки
из каталога, навыки и правила, а профилями с зависимостями — ещё и плагины-зависимости.
Состав поставки открыт — ниже всё, что оказывается на машине после установки.
Инструментов в поставке нет: ни хуков, ни команд, ни MCP-серверов; из инструментов
ставится только команда `backlog` — лаунчер CLI зависимости, профилем с backlog
([Шаг 1](#шаг-1-установить-tessera)).

Навыки и правила — несёт плагин tessera-plugin:

- навык `project-docs` — аудит и правка `README.md`, `CONTRIBUTING.md` и документа кейсов
  по норме DGN;
- навык `workflow-fast` — быстрый рабочий процесс: от требования владельца до ветки изменений
  без прожарки;
- навык `workflow-grill` — рабочий процесс: от требования до ветки изменений через прожарку;
- правила — документация, чтение документов, окружение, чистая архитектура, CQRS, DDD,
  документы проекта, git-процесс; при установке с `--project` скрипт копирует выбранные
  правила в `.tessera/rules/` проекта и подключает секцией в его `AGENTS.md`, а после
  установки они применяются навыками: точка входа — `tessera-plugin`, профильные навыки
  ссылаются на свои правила сами;
- шаблоны операций — `workflow-fast` и `workflow`: из них навыки workflow порождают беклоги.

Плагины-зависимости — приносят профили `backlog` и полный, клонируя репозитории-источники:

- [backlog](https://github.com/united-software-platform/formular/tree/main/plugin/backlog)
  из formular — навыки `backlog-generate`, `backlog-run` и `backlog-template`: порождение
  и исполнение беклогов операций;
- [mattpocock-skills](https://github.com/mattpocock/skills) — навыки инжиниринга из каталогов
  `engineering` и `productivity`: код-ревью, TDD, доменное моделирование и другие.

Ничего сверх перечня не ставится: отчёт установки называет каждую созданную ссылку,
а профиль «только tessera» обходится одними навыками и правилами.

**Реестр поставки** — всё, что скрипт создаёт, по уровням:

| Уровень | Путь | Что появляется |
|---------|------|----------------|
| Машина | `~/.local/share/tessera/` | Клоны источников: `tessera`, `formular`, `mattpocock-skills` — по профилю; в клоне tessera лежат навыки, правила и шаблоны операций |
| Машина | `~/.local/bin/backlog` | Лаунчер CLI backlog — профили с backlog; чужой файл по пути сохраняется `backlog.bak` |
| Харнес | `~/.agents/skills/` (ZCode, Codex, Gemini CLI), `~/.claude/skills/` (Claude Code), `~/.config/opencode/skills/` (OpenCode) | Симлинки на навыки — перечень имён ниже; полную таблицу харнесов и каталогов печатает `scripts/install.sh --help` |
| Проект | `.agents/skills/`, `.claude/skills/` и другие по той же таблице | Те же симлинки — при `--project`; пользовательские каталоги не меняются |
| Проект | `.tessera/rules/` | Копии подключённых правил — имена ниже; состав выбирают параметром `--rules` или диалогом |
| Проект | `AGENTS.md` | Секция правил `delivery-tessera-<штамп>` между комментариями-маркерами; остальной текст файла не меняется |

Навыки — 34 симлинка в каталогах навыков харнесов:

- tessera (4): `project-docs`, `tessera-plugin`, `workflow-fast`, `workflow-grill`;
- backlog (3): `backlog-generate`, `backlog-run`, `backlog-template`;
- mattpocock-skills (27): `ask-matt`, `codebase-design`, `code-review`, `diagnosing-bugs`,
  `domain-modeling`, `grill-with-docs`, `grilling`, `grill-me`, `handoff`, `implement`,
  `implement-spec`, `improve-codebase-architecture`, `pr`, `prototype`, `research`, `retro`,
  `setup-matt-pocock-skills`, `tdd`, `teach`, `to-questionnaire`, `to-spec`, `to-tickets`,
  `triage`, `wayfinder`, `wait-what`, `wizard`, `writing-for-agents`.

Правила — 8 копий в `.tessera/rules/` при `--project`: `clean-architecture.md`, `cqrs.md`,
`ddd.md`, `documentation-rules.md`, `environment.md`, `git-rules.md`, `project-docs-rules.md`,
`reading-rules.md`.

Совпадения с уже установленным: чужой одноимённый элемент каталога навыков скрипт не
перезаписывает и называет в отчёте, чужой лаунчер сохраняет резервной копией, чужие файлы
`.tessera/rules/` не трогает; свои элементы обновляет. Перечень навыков зависимостей — снимок
источников на 2026-11-24; фактический состав каждой установки называет её отчёт.

Разработка самого tessera ведётся через OpenSpec (каталог `openspec/`); в поставку он
не входит.
Что делают навыки на практике и примеры вызовов — [кейсы 4–6](./docs/use-cases.md),
установка только в один проект, подключение части правил и обновление кнопкой — кейсы 1–3
там же. Здесь — путь
от одной команды до первого работающего навыка. Правящим репозиторий —
[`CONTRIBUTING.md`](./CONTRIBUTING.md), агентам, работающим в репозитории, —
[`AGENTS.md`](./AGENTS.md).

---

## Навигация

- [Что нужно](#что-нужно)
- [Шаг 1. Установить tessera](#шаг-1-установить-tessera)
- [Шаг 2. Проверить работу](#шаг-2-проверить-работу)
- [Куда дальше](#куда-дальше)
- [Ограничения](#ограничения)
- [Лицензия](#лицензия)

---

## Что нужно

- `bash`, `git` и `curl` — скрипт установки скачивает источники из GitHub.
- `python3` — для команды `backlog`, которая ставится профилем с backlog.
- Любой харнес, поддерживающий навыки формата Agent Skills — чтение навыков из каталога.
- Навыки `workflow-fast` и `workflow-grill` дополнительно требуют плагин backlog;
  `workflow-grill` — ещё и навык `grilling` плагина mattpocock-skills. Обе зависимости
  ставит тот же скрипт установки профилем `backlog` или полным.

---

## Шаг 1. Установить tessera

```bash
curl -fsSL https://raw.githubusercontent.com/united-software-platform/tessera/main/scripts/install.sh | bash
```

Скрипт спросит профиль поставки и покажет найденные харнесы — подтвердите нажатием Enter.
Он раскладывает источники в хранилище `~/.local/share/tessera/`, связывает навыки симлинками
с каталогами навыков ваших харнесов и ставит команду `backlog`; с параметром `--project` —
ещё и подключает правила к текущему проекту: копии в `.tessera/rules/` и секцию в `AGENTS.md`
(какие правила — параметр `--rules` или диалог). В конце скрипт проверяет каждую ссылку
и копию правила и печатает отчёт. Харнесы скрипт находит сам.

Из клона репозитория результат тот же:

```bash
git clone https://github.com/united-software-platform/tessera.git
cd tessera
scripts/install.sh
```

Состав профилей и каталоги навыков харнесов печатает `scripts/install.sh --help`.
Обновление — повторный запуск, удаление — запуск с параметром `--uninstall`.

Подробнее — [кейс 1](./docs/use-cases.md#кейс-1-хочу-поставить-tessera-только-в-один-проект),
[кейс 2](./docs/use-cases.md#кейс-2-хочу-подключить-к-проекту-только-часть-правил)
и [кейс 3](./docs/use-cases.md#кейс-3-хочу-обновлять-tessera-кнопкой).

---

## Шаг 2. Проверить работу

Перезапустите сессию харнеса и попросите его выполнить навык `tessera-plugin`:

```text
Выполни навык tessera-plugin: расскажи, что входит в плагин tessera
и какие у него зависимости.
```

Ответ перечисляет навыки плагина, его правила и зависимости — навыки подключены.
Для профиля с backlog команда `backlog --help` в новом окне терминала отвечает справкой.

---

## Куда дальше

- Применение навыков с примерами вызовов, установка только в один проект, подключение
  части правил и обновление кнопкой — в [документе кейсов](./docs/use-cases.md).
- Устройство плагина, правила и зависимости — в [README плагина](./plugins/tessera-plugin/README.md).
- Параметры скрипта установки и каталоги навыков харнесов печатает `scripts/install.sh --help`.
- Если вы хотите править репозиторий — в [`CONTRIBUTING.md`](./CONTRIBUTING.md).

---

## Ограничения

- **Язык — русский.** Артефакты фреймворка на русском; англоязычная адаптация — будущая
  работа, до неё ориентир — команда usp.
- **Workflow-навыки зависят от внешних навыков.** `workflow-fast` требует backlog,
  `workflow-grill` — backlog и mattpocock-skills (`grilling`). Профиль «только tessera»
  обходится без них, а без зависимостей навык останавливается отказом с командой установки.
- **Версии зависимостей не закреплены.** Скрипт ставит ветку `main` репозиториев tessera,
  formular и mattpocock/skills на момент запуска; повторный запуск обновляет её
  до актуального состояния.
- **Нативная Windows не поддерживается.** Скрипту установки нужны bash, git и curl.
- **Подключение правил — в проект и через `AGENTS.md`.** Правила подключаются к проекту
  только параметром `--project`, секцией в его `AGENTS.md`; другой точки входа у скрипта нет.
  Правила самого репозитория tessera читаются агентами по его [`AGENTS.md`](./AGENTS.md).
- **Бейджи читают ветку main.** Динамические бейджи версий берут значения из манифестов
  на `main` GitHub: несопровождённая ветка или локальные правки в бейдж не попадают.

---

## Лицензия

tessera распространяется по лицензии MIT; текст лицензии — в файле [`LICENSE`](./LICENSE)
репозитория.
