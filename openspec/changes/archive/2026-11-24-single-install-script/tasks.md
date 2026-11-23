# Tasks

## 1. Скрипт поставки

- [x] 1.1 Завести `scripts/install.sh`: хранилище `~/.local/share/tessera/` с клонами ветки `main`,
  профили `full|backlog|tessera`, определение харнесов по таблице решения 3 design.md,
  регистрация симлинками, диалог через `/dev/tty` и режим `--yes`, параметры `--project`,
  `--harness`, `--skills-dir`; проверить: `bash -n scripts/install.sh` без ошибок,
  `scripts/install.sh --help` печатает таблицу параметров с кодом `0`
- [x] 1.2 Лаунчер `backlog` с `BACKLOG_HOME` и маркерной строкой (решение 4), предупреждение,
  если `~/.local/bin` вне PATH, самопроверка ссылок и `backlog --help` в конце с отчётом;
  проверить в новом поддельном домашнем каталоге `$FAKE` (`FAKE=$(mktemp -d)`):
  `HOME="$FAKE" scripts/install.sh --yes --profile backlog --skills-dir "$FAKE/skills"` даёт
  код `0`, файл `$FAKE/.local/bin/backlog` содержит строку `BACKLOG_HOME`, а его вызов с `--help`
  даёт код `0`
- [x] 1.3 Изолированная установка трёх профилей в новом поддельном домашнем каталоге `$FAKE2`
  с `--yes --skills-dir "$FAKE2/skills"`: `tessera`, затем `backlog`, затем `full`; проверить
  по отчёту: число ссылок равно числу навыков источников (на момент планирования 4, 7 и 34),
  самопроверка без неисправных ссылок, лаунчер появляется начиная с профиля `backlog`,
  в хранилище нет клонов невостребованных зависимостей
- [x] 1.4 Изолированные особые случаи в новом поддельном домашнем каталоге: чужой одноимённый
  навык в каталоге назначения, чужой файл по пути лаунчера, установка `--project` во временный
  репозиторий, харнесы не найдены; проверить: чужой навык остался и назван в отчёте, прежний
  лаунчер лежит в `backlog.bak` с прежним содержимым, при `--project` ссылки лежат
  в `.agents/skills/` и `.claude/skills/` проекта, без найденных харнесов и без `--skills-dir`
  скрипт завершается с ненулевым кодом и не создаёт хранилище
- [x] 1.5 Повторный запуск (`git pull --ff-only` в каждом клоне, клон с локальными изменениями
  пропускается с сообщением, ссылки пересоздаются, состав и цели прежние) и `--uninstall` (свои
  ссылки, свой лаунчер по маркеру, хранилище; `backlog.bak` остаётся); проверить в `$FAKE2`
  после задачи 1.3: повторный запуск с тем же `--skills-dir` даёт код `0` и прежнее число
  ссылок, после `--uninstall` хранилище и ссылки отсутствуют
- [x] 1.6 Удалить `scripts/install-plugins.sh`; проверить: `ls scripts/` выводит `bootstrap.sh`
  и `install.sh`

## 2. Шаблоны операций и навыки

- [x] 2.1 Перенести `templates/workflow-fast.md` и `templates/workflow.md`
  в `plugins/tessera-plugin/templates/` командой `git mv`, корневой `templates/` удалить;
  проверить: `ls plugins/tessera-plugin/templates/` выводит оба файла, каталога `templates/`
  в корне репозитория нет
- [x] 2.2 В `plugins/tessera-plugin/skills/workflow-fast/SKILL.md`: шаг порождения передаёт
  `--templates` по правилу приоритета (решение 7), зависимость зовётся по короткому имени
  и признаётся с префиксом плагина, отказ называет одну команду установки; дописать строку
  в таблицу версий; проверить: `grep -n 'маркетплейс'` по файлу находит только исторические
  строки таблицы версий; в `$FAKE2` после задачи 1.3 команда
  `HOME="$FAKE2" "$FAKE2/.local/bin/backlog" generate --operation workflow-fast --subject test
  --value target=o/r --value requirement=x --templates "$(realpath
  "$FAKE2/skills/workflow-fast/../../templates")" --root "$FAKE2/run"` создаёт
  `$FAKE2/run/workflow-fast/test/tasks.md`
- [x] 2.3 То же в `plugins/tessera-plugin/skills/workflow-grill/SKILL.md` для зависимостей
  backlog и mattpocock-skills; дописать строку в таблицу версий; проверить: как в задаче 2.2,
  с операцией `workflow`
- [x] 2.4 В `plugins/tessera-plugin/skills/tessera-plugin/SKILL.md` разделы «Зависимости»
  и «Подключение» перевести на скрипт поставки; дописать строку в таблицу версий; проверить:
  `grep -n 'bootstrap\|маркетплейс'` по файлу находит только исторические строки таблицы версий

## 3. Регистрация для разработки

- [x] 3.1 `scripts/bootstrap.sh`: цели `agents` и `claude`, произвольный путь, цель `zcode`
  снята, при запуске снимаются свои прежние ссылки из `.zcode/skills/` (решение 9); проверить:
  `scripts/bootstrap.sh --help` не называет `zcode`, после прогона в клоне `ls .zcode/skills/`
  не содержит навыков tessera, а `.agents/skills/` и `.claude/skills/` содержат все четыре

## 4. Документы и язык

- [x] 4.1 `README.md`: назначение называет поставку скриптом; шаги «Установить tessera» (одна
  команда, строка про запуск из клона, «Подробнее — кейсы 1 и 2») и «Проверить работу»;
  «Что нужно» — bash, git, curl; «Ограничения» пополняются нативной Windows; проверить:
  `grep -c '^## Шаг' README.md` выводит `2`, `grep -n 'bootstrap' README.md` пусто
- [x] 4.2 `docs/use-cases.md`: пять кейсов — «поставить только в один проект», «обновлять
  кнопкой» с оговоркой про workflow-навыки, три кейса применения навыков; назначение, навигация
  и таблица версий обновлены; проверить: `grep -c '^## Кейс' docs/use-cases.md` выводит `5`,
  каждый кейс несёт метки «Когда», «Что делаю», «Что получаю»
- [x] 4.3 `plugins/tessera-plugin/README.md`: «Структура» с `templates/`, «Зависимости»,
  «Совместимость с харнесами» и «Проверка» без `zcode plugins validate .`; проверить:
  `grep -n 'install-plugins\|zcode plugins validate' plugins/tessera-plugin/README.md` пусто
- [x] 4.4 `CONTRIBUTING.md`: устройство (`scripts/install.sh`, `plugins/tessera-plugin/templates/`,
  без корневого `templates/` и `install-plugins.sh`), локальная настройка, проверки (справка
  скрипта, дымовой прогон в поддельном домашнем каталоге, `bootstrap.sh`); дописать строку
  в таблицу версий; проверить: `grep -n 'install-plugins' CONTRIBUTING.md | grep -v -E ':[0-9]+:\| '`
  пусто
- [x] 4.5 `AGENTS.md`, раздел «Локальная настройка»: цели `bootstrap.sh` — `agents`, `claude`,
  произвольный путь; дописать строку в таблицу версий; проверить: раздел не называет цель `zcode`
- [x] 4.6 `GLOSSARY.md`: понятия по решению 11 design.md; дописать строку в таблицу версий;
  проверить: есть статьи «Установка», «Профиль поставки», «Хранилище», «Лаунчер», статья
  «Зависимость» не упоминает запись маркетплейса
- [x] 4.7 Версия 0.4.0 в `plugins/tessera-plugin/.zcode-plugin/plugin.json`,
  `plugins/tessera-plugin/.claude-plugin/plugin.json` и `.claude-plugin/marketplace.json`;
  проверить: `grep -rn '"version"'` по трём файлам выводит `0.4.0`, `diff` манифестов пуст

## 5. Интеграционная проверка

- [x] 5.1 Прогнать строгую валидацию: `openspec validate --strict single-install-script` —
  код `0`
- [x] 5.2 Сверить отсутствие прежних маршрутов установки:
  `grep -rn 'install-plugins\|backlog@tessera\|mattpocock-skills@tessera' README.md docs/
  plugins/ scripts/ CONTRIBUTING.md AGENTS.md GLOSSARY.md .claude-plugin/ | grep -v -E ':[0-9]+:\| '`
  пусто

## Workflow follow-up

- Правки аудита в `CONTRIBUTING.md` и `docs/use-cases.md` коммитятся до задач группы 4 (GIT-020);
  коммит и push — по явному запросу владельца (GIT-015).
- Слить PR #2 и заархивировать `optional-plugin-supply` до архивации этого изменения.
- Настоящая установка на хосте владельца и снятие из ZCode плагинов `backlog`
  и `mattpocock-skills` — по отдельному слову владельца после задач 1.3 и 1.4.
- Владелец проходит установку плагином через интерфейс ZCode один раз — проверка кейса 2.
- Задача в formular на дефекты лаунчера `backlog` — по отдельному запросу владельца.
