# tessera

[![версия tessera-plugin](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Funited-software-platform%2Ftessera%2Fmain%2Fplugins%2Ftessera-plugin%2F.zcode-plugin%2Fplugin.json&query=%24.version&label=tessera-plugin&color=blue)](https://github.com/united-software-platform/tessera/blob/main/plugins/tessera-plugin/.zcode-plugin/plugin.json)
[![версия backlog](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Funited-software-platform%2Fformular%2Fmain%2Fplugin%2Fbacklog%2F.claude-plugin%2Fplugin.json&query=%24.version&label=backlog&color=9cf)](https://github.com/united-software-platform/formular/tree/main/plugin/backlog)
[![версия mattpocock-skills](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fmattpocock%2Fskills%2Fmain%2F.claude-plugin%2Fplugin.json&query=%24.version&label=mattpocock-skills&color=9cf)](https://github.com/mattpocock/skills)
[![лицензия MIT](https://img.shields.io/badge/license-MIT-success)](https://spdx.org/licenses/MIT.html)

tessera — минимальный инженерный фреймворк: правила работы с репозиториями, процессами
и построения ПО вместе с навыками, которые их применяют. Гибкий пересмотр
[sdd-developer-kit](https://github.com/united-software-platform/sdd-developer-kit) — та же
методология без его привязки к Claude и песочнице. Имя — мозаичный элемент: набор, собранный
из частей.

Поставка — скрипт установки: одна команда ставит навыки, правила и шаблоны операций
в любой харнес, читающий навыки из каталога.

- навык `project-docs` — аудит и правка `README.md`, `CONTRIBUTING.md` и документа кейсов
  по норме DGN;
- навык `workflow-fast` — быстрый рабочий процесс: от требования владельца до ветки изменений
  без прожарки;
- навык `workflow-grill` — рабочий процесс: от требования до ветки изменений через прожарку;
- правила — документация, чтение документов, окружение, чистая архитектура, CQRS, DDD,
  документы проекта, git-процесс; после установки применяются навыками: точка входа —
  `tessera-plugin`, профильные навыки ссылаются на свои правила сами;
- шаблоны операций — `workflow-fast` и `workflow`: из них навыки workflow порождают беклоги.

Разработка самого tessera ведётся через OpenSpec (каталог `openspec/`); в поставку он
не входит.
Что делают навыки на практике и примеры вызовов — [кейсы 3–5](./docs/use-cases.md),
установка только в один проект и обновление кнопкой — кейсы 1–2 там же. Здесь — путь
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
с каталогами навыков ваших харнесов и ставит команду `backlog`; в конце проверяет каждую
ссылку и печатает отчёт. Харнесы скрипт находит сам.

Из клона репозитория результат тот же:

```bash
git clone https://github.com/united-software-platform/tessera.git
cd tessera
scripts/install.sh
```

Состав профилей и каталоги навыков харнесов печатает `scripts/install.sh --help`.
Обновление — повторный запуск, удаление — запуск с параметром `--uninstall`.

Подробнее — [кейс 1](./docs/use-cases.md#кейс-1-хочу-поставить-tessera-только-в-один-проект)
и [кейс 2](./docs/use-cases.md#кейс-2-хочу-обновлять-tessera-кнопкой).

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

- Применение навыков с примерами вызовов, установка только в один проект и обновление
  кнопкой — в [документе кейсов](./docs/use-cases.md).
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
- **Правила действуют в репозитории.** Правила читаются агентами по [`AGENTS.md`](./AGENTS.md)
  клона; за его пределами действуют только навыки.
- **Бейджи читают ветку main.** Динамические бейджи версий берут значения из манифестов
  на `main` GitHub: несопровождённая ветка или локальные правки в бейдж не попадают.

---

## Лицензия

tessera распространяется по лицензии MIT; текст лицензии — в файле [`LICENSE`](./LICENSE)
репозитория.
