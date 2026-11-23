# tessera

[![версия tessera-plugin](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Funited-software-platform%2Ftessera%2Fmain%2Fplugins%2Ftessera-plugin%2F.zcode-plugin%2Fplugin.json&query=%24.version&label=tessera-plugin&color=blue)](https://github.com/united-software-platform/tessera/blob/main/plugins/tessera-plugin/.zcode-plugin/plugin.json)
[![версия backlog](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Funited-software-platform%2Fformular%2Fmain%2Fplugin%2Fbacklog%2F.claude-plugin%2Fplugin.json&query=%24.version&label=backlog&color=9cf)](https://github.com/united-software-platform/formular/tree/main/plugin/backlog)
[![версия mattpocock-skills](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fmattpocock%2Fskills%2Fmain%2F.claude-plugin%2Fplugin.json&query=%24.version&label=mattpocock-skills&color=9cf)](https://github.com/mattpocock/skills)
[![openspec](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2Funited-software-platform%2Ftessera%2Fmain%2Fopenspec%2Fconfig.yaml&query=schema&label=openspec&color=blueviolet)](https://github.com/united-software-platform/tessera/tree/main/openspec)
[![лицензия MIT](https://img.shields.io/badge/license-MIT-success)](https://spdx.org/licenses/MIT.html)

Навыки и правила проекта tessera в формате Agent Skills; формат подключается в любой харнес,
читающий каталог навыков. Поставка:

- навык `project-docs` — аудит и правка `README.md`, `CONTRIBUTING.md` и документа кейсов
  по норме DGN;
- навык `workflow-fast` — быстрый рабочий процесс: от требования владельца до ветки изменений
  без прожарки;
- навык `workflow-grill` — рабочий процесс: от требования до ветки изменений через прожарку;
- правила — документация, чтение документов, окружение, чистая архитектура, CQRS, DDD,
  документы проекта, git-процесс.

Что делают навыки на практике и примеры вызовов — [кейсы 4–6](./docs/use-cases.md); установка
обновляемым плагином — кейсы 1–3 там же. Здесь — путь от клона репозитория до первого
работающего навыка. Правящим репозиторий — [`CONTRIBUTING.md`](./CONTRIBUTING.md), агентам,
работающим в репозитории, — [`AGENTS.md`](./AGENTS.md).

---

## Навигация

- [Что нужно](#что-нужно)
- [Шаг 1. Склонировать репозиторий](#шаг-1-склонировать-репозиторий)
- [Шаг 2. Зарегистрировать навыки в своём харнесе](#шаг-2-зарегистрировать-навыки-в-своём-харнесе)
- [Шаг 3. Проверить работу](#шаг-3-проверить-работу)
- [Куда дальше](#куда-дальше)
- [Ограничения](#ограничения)
- [Лицензия](#лицензия)

---

## Что нужно

- `git` и любой харнес, поддерживающий навыки формата Agent Skills — чтение навыков
  из каталога.
- Навыки `workflow-fast` и `workflow-grill` дополнительно требуют навыки плагина backlog;
  `workflow-grill` — ещё и навык `grilling` плагина mattpocock-skills.

---

## Шаг 1. Склонировать репозиторий

```bash
git clone https://github.com/united-software-platform/tessera.git
cd tessera
```

---

## Шаг 2. Зарегистрировать навыки в своём харнесе

```bash
scripts/bootstrap.sh
```

Скрипт создаёт симлинки на `plugins/tessera-plugin/skills/` в каталогах навыков известных
харнесов — единый источник, копий не возникает. Каталоги регистрации находятся вне индекса git:
содержимое каждого определяет разработчик.

Регистрация только выбранных харнесов или в произвольный каталог навыков — целью вызова;
перечень целей печатает `scripts/bootstrap.sh --help`. Навыки появляются после перезапуска
сессии харнеса.

Подробнее — [кейс 3](./docs/use-cases.md#кейс-3-хочу-подключить-навыки-в-другой-проект).

---

## Шаг 3. Проверить работу

Попросите харнес выполнить навык `tessera-plugin`:

```text
Выполни навык tessera-plugin: расскажи, что входит в плагин tessera
и какие у него зависимости.
```

Ответ перечисляет навыки плагина, его правила и зависимость от backlog — навыки подключены.

---

## Куда дальше

- Установка обновляемым плагином — в [документе кейсов](./docs/use-cases.md).
- Устройство плагина, правила и зависимости — в [README плагина](./plugins/tessera-plugin/README.md).
- Если вы хотите править репозиторий — в [`CONTRIBUTING.md`](./CONTRIBUTING.md).

---

## Ограничения

- **Workflow-навыки зависят от внешних навыков.** `workflow-fast` требует backlog,
  `workflow-grill` — backlog и mattpocock-skills (`grilling`); установка —
  в [документе кейсов](./docs/use-cases.md).
- **Правила действуют в репозитории.** Правила читаются агентами по [`AGENTS.md`](./AGENTS.md)
  клона; за его пределами действуют только навыки.
- **Бейджи читают ветку main.** Динамические бейджи версий берут значения из манифестов
  на `main` GitHub: несопровождённая ветка или локальные правки в бейдж не попадают.

---

## Лицензия

tessera распространяется по лицензии MIT; текст лицензии — в файле [`LICENSE`](./LICENSE)
репозитория.
