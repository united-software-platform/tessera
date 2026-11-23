# Tasks

## 1. Каталог и манифесты

- [x] 1.1 Удалить записи `backlog` и `mattpocock-skills` из `.claude-plugin/marketplace.json`;
  проверить: `python3 -m json.tool .claude-plugin/marketplace.json` проходит, в массиве
  `plugins` осталась только запись `tessera-plugin`
- [x] 1.2 Поднять версию поставки до `0.3.0` в `plugins/tessera-plugin/.zcode-plugin/plugin.json`,
  `plugins/tessera-plugin/.claude-plugin/plugin.json` и записи `tessera-plugin` каталога;
  проверить: `grep -rn '"version"' .claude-plugin/marketplace.json plugins/tessera-plugin/.zcode-plugin/plugin.json plugins/tessera-plugin/.claude-plugin/plugin.json` показывает `0.3.0` во всех трёх

## 2. Тексты навыков

- [x] 2.1 В `plugins/tessera-plugin/skills/workflow-fast/SKILL.md` отказ недоступности навыков
  плагина backlog перевести на единственный путь — маркетплейс formular напрямую; вариант
  «запись `backlog` в каталоге маркетплейса `tessera`» убрать; дописать строку в таблицу
  версий навыка; проверить: `grep -n 'каталоге маркетплейса' skills/workflow-fast/SKILL.md`
  не находит упоминаний установки зависимостей через каталог tessera
- [x] 2.2 В `plugins/tessera-plugin/skills/workflow-grill/SKILL.md` то же для зависимостей
  backlog и mattpocock-skills: установка только из маркетплейсов formular и mattpocock
  напрямую; дописать строку в таблицу версий; проверить: текст раздела отказов не называет
  каталог tessera источником зависимостей
- [x] 2.3 В `plugins/tessera-plugin/skills/tessera-plugin/SKILL.md` описание зависимостей
  перевести на самостоятельную установку из маркетплейсов-источников; дописать строку
  в таблицу версий; проверить: навык-каталог не направляет установку зависимостей через
  маркетплейс tessera

## 3. Документы

- [x] 3.1 В `plugins/tessera-plugin/README.md` раздел «Зависимости»: убрать механизм «записи
  в том же маркетплейсе», оставить проверку при запуске и самостоятельную установку
  из маркетплейсов-источников; таблица «зависимость / версия / источник» остаётся; дописать
  строку в таблицу версий; проверить: раздел описывает один механизм закрытия зависимостей
- [x] 3.2 В корневом `README.md` «Что нужно» и «Ограничения»: установка внешних навыков —
  отдельный шаг разработчика из маркетплейсов-источников; проверить: `grep -n 'backlog'
  README.md` показывает формулировки самостоятельной установки, а не установки составом
  маркетплейса tessera
- [x] 3.3 В `docs/use-cases.md` кейсы 1–2: установку зависимостей перевести на маркетплейсы
  formular и mattpocock (Claude Code: `marketplace add` + `install backlog@formular`); версии
  внешних плагинов из каталога tessera не устанавливаются; дописать строку в таблицу версий
  документа; проверить: `grep -n '@tessera' docs/use-cases.md` остаётся только
  на `tessera-plugin@tessera`

## 4. Профили установки

- [x] 4.1 Завести `scripts/install-plugins.sh`: флаги `--all`, `--backlog`,
  `--mattpocock-skills` комбинируются, вызов без флагов печатает справку; для харнеса с CLI
  выполняет команды установки из маркетплейсов-источников, для харнеса без CLI печатает
  пошаговую инструкцию; проверить: `scripts/install-plugins.sh --help` печатает перечень
  флагов, прогон с флагом в окружении без CLI печатает инструкцию и возвращает код `0`
- [x] 4.2 Добавить кейс «Хочу поставить tessera полным набором» за кейсами установки
  в `docs/use-cases.md`: блок команд всех трёх маркетплейсов и упоминание скрипта;
  перенумеровать последующие кейсы и поправить ссылки «Подробнее — кейс N» в корневом
  `README.md` той же правкой (DGN-007); дописать строку в таблицу версий документа;
  проверить: `grep -n 'Подробнее' README.md` ведёт на верные номера кейсов
- [x] 4.3 Дополнить «Устройство репозитория» в `CONTRIBUTING.md` строкой о
  `scripts/install-plugins.sh`; проверить: раздел называет оба скрипта `scripts/`

## 5. Интеграционная проверка

- [x] 5.1 Прогнать строгую валидацию изменения: `openspec validate --strict
  optional-plugin-supply` — код возврата `0`
- [x] 5.2 Сверить отсутствие следов поставки зависимостей через tessera: `grep -rn
  'backlog@tessera\|mattpocock-skills@tessera' README.md docs/ plugins/ scripts/
  .claude-plugin/` не находит совпадений; `.claude-plugin/marketplace.json` несёт только
  `tessera-plugin`

## Workflow follow-up

- Закрыть задачу GitHub [#1 (TSS-012)](https://github.com/united-software-platform/tessera/issues/1)
  после применения изменения.
- Заархивировать изменение `optional-plugin-supply` после ревью владельцем.
- Обратная сторона цикла — отдельное изменение в репозитории formular (снять ссылку на
  маркетплейс tessera из его установки).
