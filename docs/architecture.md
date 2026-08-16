# Архитектура `format`

Статус: живой документ; сверено с кодом 2026-08-15. Здесь хранится устойчивое
устройство проекта. Текущее состояние работы, результаты проверок и следующие
действия находятся в `docs/handoff.md`, история решений — в `docs/records/`.

## Назначение и границы

`format` — Dart-пакет с двумя строковыми мини-языками поверх одного
конфигурируемого движка:

- Python-подобные поля `{...}` через `format` и `formatWith`;
- printf-подобные преобразования `%...` через `sprintf` и `vsprintf`.

Поддерживаемая публичная поверхность собрана только в `lib/format.dart`.
`lib/src/engine.dart` — внутренняя библиотека-контейнер и тестовый seam, а не
второй публичный API. Производственный пакет не зависит от `intl`: адаптер к
его локалям вынесен в отдельный workspace-пакет `packages/format_intl`.

## Поток форматирования

```text
format / formatWith                 sprintf / vsprintf
        │                                  │
        ▼                                  ▼
  _BraceProcessor                    _PrintfProcessor
        │                                  │
        ├─ template cache ─ parser ─ AST ──┤
        │                                  │
        └──── programFor(TextUnit) → typed IR ops
                                      │
                  field resolution / argument cursor
                                      │
             conversions, extensions, value/number formatting
                                      │
                                  CharSink
                                      │
                                    String
```

`Format` — неизменяемая конфигурация одного движка. Она хранит единицу длины
текста, профиль `double`, локаль чисел и снимки реестров расширений. Публичные
методы также снимают копии переданных списков и карт, поэтому пользовательский
`toString` не может изменить данные уже идущего вызова.

На cache miss шаблон разбирается в AST и компилируется в программу
специализированных op'ов. Программа строится отдельно для нужного `TextUnit` и
пишет результат прямо в `CharSink`. Редкие, динамические и расширяемые случаи
остаются на общем fallback-пути. Рядом сохранена legacy-сборка через AST и
`StringBuffer`: она доступна только внутренним debug-seams и служит oracle для
дифференциальных тестов и A/B-замеров IR.

## Компоненты

| Область | Основные файлы | Ответственность |
|---|---|---|
| Публичный facade | `lib/format.dart` | Экспорты поддерживаемого API |
| Конфигурация и входы | `lib/src/api.dart`, `lib/src/format.dart` | Top-level функции, `defaultFormat`, экземпляры `Format`, снимки аргументов |
| Brace syntax | `brace_parser.dart`, `brace_ast.dart`, `format_spec.dart` | Поля, пути, вложенные спецификации и Python-подобный format spec |
| Printf syntax | `printf_parser.dart`, `printf_ast.dart`, `printf_formatter.dart` | Flags, width/precision, consumption order и conversion types |
| Исполнение | `template_ir.dart`, `brace_processor.dart`, `printf_processor.dart` | Компиляция и выполнение op'ов, fallback на общий путь |
| Значения и числа | `value_formatter.dart`, `number_format.dart`, `dart_double_format.dart`, `binary64.dart` | Dispatch встроенных типов, целые и профили `double` |
| Разрешение и расширения | `field_resolver.dart`, `extensions.dart`, `representation.dart` | Positional/named/item/attribute lookup, custom formatter и `!r`/`!a` |
| Локаль и текст | `number_locale.dart`, `text_unit.dart`, `python_identifier.dart` | Числовые символы, grouping, единицы ширины и таблицы Python Unicode |
| Вывод и кэш | `char_sink.dart`, `template_cache.dart` | Сборка строки и ограниченный cache шаблонов на isolate |
| Ошибки | `errors.dart` | Отдельная sealed-иерархия `FormattingException` с контекстом шаблона |

Большинство файлов `lib/src/` объявлены как `part` библиотеки
`engine.dart`, чтобы внутренние типы оставались приватными во всём движке.
Самостоятельные библиотеки — `binary64.dart`, `double_format.dart`,
`errors.dart`, `extensions.dart`, `number_locale.dart` и `text_unit.dart`.

## Расширение и локализация

Пользователь не меняет глобальное состояние: он создаёт `Format` с нужными
`Formatter`, `AttributeLookup`, `Representation`, `NumberLocale`, `TextUnit`
и профилем `DoubleFormatMode`. Движок сначала сохраняет приоритет встроенных
типов, затем обращается к типизированным пользовательским расширениям. Ошибка
в callback оборачивается в `FormatExtensionException` с причиной, stack trace
и контекстом места в шаблоне.

`NumberLocale` задаёт символы, цифры и схему grouping. Корневой пакет содержит
только C locale и интерфейс; `format_intl` реализует `IntlNumberLocale` поверх
данных `package:intl`, не добавляя эту зависимость пользователям базового
пакета.

## Кэш и производительность

Brace- и printf-шаблоны имеют отдельные cache на isolate. Ёмкость и модельный
лимит памяти публично настраиваются; cache может временно перестать опрашивать
поток промахов и вернуться к нему позднее. Скомпилированная программа не
принадлежит конкретному экземпляру `Format`, поэтому зависящие от конфигурации
случаи либо читают движок во время выполнения, либо уходят в fallback.

Hot path намеренно специализирован и местами дублирует короткие операции для
разных платформ. Такие решения защищают differential-тесты против legacy
oracle и benchmark gate; архитектурное упрощение не должно молча менять их.

## Ошибки и платформы

Ошибки форматирования не являются `dart:core FormatException`. Все публичные
отказы входят в sealed-иерархию `FormattingException` и несут
`FormatExceptionContext`: шаблон, смещение, фрагмент и, где применимо,
specifier, conversion и индекс аргумента.

Один и тот же контракт проверяется на Dart VM, dart2js/Node и
dart2wasm/Node. Различия числовой модели web-targets изолированы в ветках с
compile-time/runtime проверками; поддерживаемые различия результата закреплены
отдельными тестами, а не списками исключённых файлов.

## Репозиторий и проверки

- `test/` проверяет публичный контракт, парсеры, IR/legacy parity, Unicode,
  память, cache и совместимость с Python/C++ fixtures.
- `tool/` генерирует и сверяет fixtures, проверяет coverage и собирает
  автономную копию pub-архива. Производственный `lib/` от него не зависит.
- `benchmark/` содержит performance gate и замороженные сравниваемые версии;
  `benchmark/suite/` — отдельный пакет с VM/JS/Wasm-матрицей.
- `packages/format_intl/` — отдельный публикуемый пакет-адаптер.
- `.github/workflows/` повторяет основные проверки на минимальном SDK и
  stable; локальный полный список перед коммитом нормативно хранится в
  `docs/conventions.md`.

Сгенерированные файлы коммитятся, но сверяются повторной генерацией во
временной директории без записи в checkout. `tool/verify_package_archive.dart`
отдельно реконструирует содержимое публикации и требует, чтобы оно само
проходило analyze и tests: локально доступный, но исключённый `.pubignore`
файл не должен стать скрытой зависимостью пакета.

## Документация и владение состоянием

- `AGENTS.md` — единая автоматически читаемая инструкция для агентов;
  `CLAUDE.md` содержит только `@AGENTS.md`.
- `docs/handoff.md` — состояние проекта и точка восстановления сессии;
  только то, что верно на сейчас.
- `docs/conventions.md` — правила работы, полный список проверок перед
  коммитом и накопленные ловушки.
- `docs/architecture.md` — эта живая карта устойчивого устройства.
- `docs/backlog.md` пишет владелец; агент только предлагает работу и удаляет
  исполненный пункт вместе с соответствующим коммитом.
- Спеки, планы, отчёты и ревью лежат плоско в
  `docs/records/YYYY-MM-DD[N]-name-kind.md` и несут под заголовком шапку из
  трёх строк: состояние на дату, что это, связанные записи.
