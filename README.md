# tessera

[![версия tessera-plugin](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Funited-software-platform%2Ftessera%2Fmain%2Fplugins%2Ftessera-plugin%2F.zcode-plugin%2Fplugin.json&query=%24.version&label=tessera-plugin&color=blue)](https://github.com/united-software-platform/tessera/blob/main/plugins/tessera-plugin/.zcode-plugin/plugin.json)
[![версия backlog](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Funited-software-platform%2Fformular%2Fmain%2Fplugin%2Fbacklog%2F.claude-plugin%2Fplugin.json&query=%24.version&label=backlog&color=9cf)](https://github.com/united-software-platform/formular/tree/main/plugin/backlog)
[![версия mattpocock-skills](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fmattpocock%2Fskills%2Fmain%2F.claude-plugin%2Fplugin.json&query=%24.version&label=mattpocock-skills&color=9cf)](https://github.com/mattpocock/skills)
[![лицензия MIT](https://img.shields.io/badge/license-MIT-success)](https://spdx.org/licenses/MIT.html)
![ZCode](https://img.shields.io/badge/ZCode-000000)
[![Codex](https://img.shields.io/badge/Codex-10A37F)](https://github.com/openai/codex)
[![Gemini CLI](https://img.shields.io/badge/Gemini%20CLI-4285F4)](https://github.com/google-gemini/gemini-cli)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-D97757)](https://claude.com/claude-code)
[![OpenCode](https://img.shields.io/badge/OpenCode-201D1D)](https://opencode.ai)
[![CI](https://github.com/united-software-platform/tessera/actions/workflows/ci.yml/badge.svg)](https://github.com/united-software-platform/tessera/actions/workflows/ci.yml)

**Предмет:** продукт — уровень предмета: что описывается, поведение компонента.

tessera — минимальный инженерный фреймворк: правила работы с репозиториями, процессами
и построения ПО вместе с навыками, которые их применяют. Гибкий пересмотр
[sdd-developer-kit](https://github.com/united-software-platform/sdd-developer-kit) — та же
методология без его привязки к Claude и песочнице. Имя — мозаичный элемент: набор, собранный
из частей.

Поставка — скрипт установки: одна команда ставит в любой харнес, читающий навыки
из каталога, навыки, правила и плагины-зависимости в заданном составе. Состав задаёт
`--components`, область установки — `--scope`, правила к проекту — `--rules`; без параметров
ставится полный состав в пользовательской области
([Шаг 1](#шаг-1-установить-tessera)).
Состав поставки открыт — ниже всё, что оказывается на машине после установки.
Инструментов в поставке нет: ни хуков, ни команд, ни MCP-серверов.

Состав плагина — несёт плагин tessera-plugin:

- навык `project-docs` — аудит и правка `README.md`, `CONTRIBUTING.md` и документа кейсов
  по норме DGN;
- навык `workflow-fast` — быстрый рабочий процесс: от требования владельца до ветки изменений
  без прожарки;
- навык `workflow-grill` — рабочий процесс: от требования до ветки изменений через прожарку;
- правила — документация, чтение документов, окружение, чистая архитектура, CQRS, DDD,
  документы проекта, git-процесс, нормы классов ПО; в области `--scope project` скрипт копирует выбранные
  правила в `.tessera/rules/` проекта и подключает секцией в его `AGENTS.md`, а после
  установки они применяются навыками: точка входа — `tessera-plugin`, профильные навыки
  ссылаются на свои правила сами;
- шаблоны операций — `workflow-fast` и `workflow`: из них навыки workflow порождают беклоги.

Зависимости плагина — приносятся компонентами состава, клонируя репозитории-источники:

- [backlog](https://github.com/united-software-platform/formular/tree/main/plugin/backlog)
  из formular — навыки `backlog-generate`, `backlog-run` и `backlog-template`: порождение
  и исполнение беклогов операций; с ним скрипт ставит команду `backlog` — лаунчер CLI
  зависимости;
- [mattpocock-skills](https://github.com/mattpocock/skills) — навыки инжиниринга из каталогов
  `engineering` и `productivity`: код-ревью, TDD, доменное моделирование и другие.

Ничего сверх перечня не ставится: отчёт установки называет каждую созданную ссылку,
а состав из одного tessera обходится одними навыками и правилами.

**Реестр поставки** печатает `scripts/install.sh --registry` — JSON со всеми записями
поставки: компоненты с источниками и путями хранилища, навыки, правила, секцию `AGENTS.md`
и лаунчер; каждая запись — имя, тип (`symlink`, `copy`, `section`, `wrapper`), целевой путь
и источник. Реестр отражает параметры запуска — `--components`, `--scope`, `--rules` и другие —
и ничего не меняет на диске, поэтому состав можно сверить с репозиторием до установки:
состав читается по признаку входжения компонентов, область установки — по полю `scope`.
Та же поставка деревом:

```text
tessera — все компоненты, область «user»
├── ~/.local/share/tessera/              хранилище: клоны источников
│   ├── tessera/                         навыки, правила, шаблоны операций
│   ├── formular/                        backlog
│   └── mattpocock-skills/
├── ~/.local/bin/backlog                 лаунчер CLI зависимости
├── навыки → каталоги харнесов           34 симлинка
│   ├── ~/.agents/skills/                (ZCode, Codex, Gemini CLI)
│   └── ~/.claude/skills/                (Claude Code)
│       ├── tessera (4)      project-docs · tessera-plugin · workflow-fast · workflow-grill
│       ├── formular (3)     backlog-generate · backlog-run · backlog-template
│       └── mattpocock (27)  ask-matt · code-review · codebase-design · diagnosing-bugs
│                          domain-modeling · grill-me · grill-with-docs · grilling
│                          handoff · implement · implement-spec · improve-codebase-…
│                          pr · prototype · research · retro · setup-matt-pocock-…
│                          tdd · teach · to-questionnaire · to-spec · to-tickets
│                          triage · wait-what · wayfinder · wizard · writing-for-agents
└── в области project добавляется в проект:
    ├── .tessera/rules/                  копии правил: все 9 или выбранные
    └── AGENTS.md                        секция delivery-tessera-<штамп>
```

JSON для разбора программой:

```bash
scripts/install.sh --registry | python3 -m json.tool
```

До первой установки хранилища нет, и реестр печатается частичным: уровни поставки описаны,
а перечни навыков и правил помечены как недоступные до получения источников.

Совпадения с уже установленным: чужой одноимённый элемент каталога навыков скрипт не
перезаписывает и называет в отчёте, чужой лаунчер сохраняет резервной копией, чужие файлы
`.tessera/rules/` не трогает; свои элементы обновляет. Факт каждой установки лежит тем же
реестром в `registry.json` рядом с хранилищем, а в области project — ещё и в `.tessera/`
проекта.

Разработка самого tessera ведётся через OpenSpec; каталог `openspec/` — процесс разработки
репозитория и в поставку не входит. Порядок работы над репозиторием описывает
[`CONTRIBUTING.md`](./CONTRIBUTING.md).
Что делают навыки на практике и примеры вызовов — [кейсы 7–9](./docs/use-cases.md),
установка только в один проект, состав поставки до установки, подключение части правил,
поставка без зависимостей, смена состава и обновление кнопкой — кейсы 1–6
там же. Здесь — путь
от одной команды до первого работающего навыка. Контрибьюторам —
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
- `python3` — для команды `backlog`, которая ставится вместе с компонентом formular.
- Любой харнес, поддерживающий навыки формата Agent Skills — чтение навыков из каталога.
- Навыки `workflow-fast` и `workflow-grill` дополнительно требуют плагин backlog;
  `workflow-grill` — ещё и навык `grilling` плагина mattpocock-skills. Обе зависимости
  приносит тот же скрипт установки — компонентами formular и mattpocock-skills
  в перечне `--components`.

---

## Шаг 1. Установить tessera

```bash
curl -fsSL https://raw.githubusercontent.com/united-software-platform/tessera/main/scripts/install.sh | bash
```

Скрипт покажет найденные харнесы и план установки — подтвердите нажатием Enter.
Он раскладывает источники в хранилище `~/.local/share/tessera/`, связывает навыки симлинками
с каталогами навыков ваших харнесов и ставит команду `backlog`; в области `--scope project` —
ещё и подключает правила к текущему проекту: копии в `.tessera/rules/` и секцию в `AGENTS.md`
(какие правила — параметр `--rules` или диалог). В конце скрипт проверяет каждую ссылку
и копию правила и печатает отчёт. Харнесы скрипт находит сам.

Состав задаётся параметром `--components` — имена компонентов через запятую; поставленное
вне перечня снимается, без перечня ставятся все компоненты:

```bash
scripts/install.sh --components tessera
```

Из клона репозитория результат тот же:

```bash
git clone https://github.com/united-software-platform/tessera.git
cd tessera
scripts/install.sh
```

Параметры, компоненты и каталоги навыков харнесов печатает `scripts/install.sh --help`.
Обновление — повторный запуск, удаление — запуск с параметром `--uninstall`.

Подробнее — [кейс 1](./docs/use-cases.md#кейс-1-хочу-поставить-tessera-только-в-один-проект),
[кейс 2](./docs/use-cases.md#кейс-2-хочу-узнать-состав-поставки-до-установки)
и [кейс 4](./docs/use-cases.md#кейс-4-хочу-поставить-tessera-без-зависимостей).

---

## Шаг 2. Проверить работу

Перезапустите сессию харнеса и попросите его выполнить навык `tessera-plugin`:

```text
Выполни навык tessera-plugin: расскажи, что входит в плагин tessera
и какие у него зависимости.
```

Ответ перечисляет навыки плагина, его правила и зависимости — навыки подключены.
Когда в составе есть formular, команда `backlog --help` в новом окне терминала отвечает
справкой.

---

## Куда дальше

- Применение навыков с примерами вызовов, установка только в один проект, состав поставки
  до установки, подключение части правил, поставка без зависимостей, смена состава
  и обновление кнопкой — в [документе кейсов](./docs/use-cases.md).
- Устройство плагина, правила и зависимости — в [README плагина](./plugins/tessera-plugin/README.md).
- Параметры, компоненты и каталоги навыков харнесов печатает `scripts/install.sh --help`.
- Если вы хотите править репозиторий — в [`CONTRIBUTING.md`](./CONTRIBUTING.md).

---

## Ограничения

- **Язык — русский.** Артефакты фреймворка на русском; англоязычная адаптация — будущая
  работа, до неё ориентир — команда usp.
- **Workflow-навыки зависят от внешних навыков.** `workflow-fast` требует backlog,
  `workflow-grill` — backlog и mattpocock-skills (`grilling`). Состав из одного tessera
  обходится без них, а без зависимостей навык останавливается отказом с командой
  установки состава.
- **Версии зависимостей не закреплены.** Скрипт ставит ветку `main` репозиториев tessera,
  formular и mattpocock/skills на момент запуска; повторный запуск обновляет её
  до актуального состояния.
- **Нативная Windows не поддерживается.** Скрипту установки нужны bash, git и curl.
- **Подключение правил — в проект и через `AGENTS.md`.** Правила подключаются к проекту
  только в области `--scope project`, секцией в его `AGENTS.md`; другой точки входа у скрипта
  нет. Правила самого репозитория tessera читаются агентами по его [`AGENTS.md`](./AGENTS.md).
- **Бейджи читают ветку main.** Динамические бейджи версий берут значения из манифестов
  на `main` GitHub: несопровождённая ветка или локальные правки в бейдж не попадают. Бейдж
  прогонов CI показывает последний прогон на `main` — прогон pull request в него не попадает.

---

## Лицензия

tessera распространяется по лицензии MIT; текст лицензии — в файле [`LICENSE`](./LICENSE)
репозитория.
