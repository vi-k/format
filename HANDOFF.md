# Handoff для новой сессии

Дата: 2026-08-04  
Рабочий каталог: `/Users/user/development/my/format`

Все shell-команды запускать с префиксом `rtk`. Спецификации и планы писать
по-русски.

## Git-состояние

Работа ведётся в ветке `main`. Текущий `HEAD` и `origin/main`:

```text
841bbb9 bench: rename float modes benchmark to double
```

Рабочее дерево содержит незакоммиченные изменения. Их нельзя сбрасывать или
перезаписывать.

Изменения пользовательского benchmark:

```text
M  example/bin/benchmark.dart
M  example/lib/benchmark.dart
D  example/lib/src/format2_benchmark.dart
D  example/lib/src/format3_benchmark.dart
D  example/lib/src/sprintf_benchmark.dart
M  example/test/restored_benchmark_test.dart
?? example/lib/src/benchmark_format2_format.dart
?? example/lib/src/benchmark_format3_format.dart
?? example/lib/src/benchmark_format3_sprintf.dart
?? example/lib/src/benchmark_sprintf7.dart
```

Отдельные незакоммиченные исправления производительности:

```text
M lib/src/printf_formatter.dart
M lib/src/format_spec.dart
M test/format_spec_fast_path_test.dart
```

Текущие изменения ещё не закоммичены и не отправлены.

## Реализованное исправление `%d`

В `_formatPrintfInteger` удалено безусловное преобразование обычного `int` в
`BigInt`.

Теперь используются два независимых пути:

```text
int    → прямой _formatIntMagnitude()
BigInt → прежний BigInt-путь
```

Поддержка настоящего `BigInt` сохранена. Также сохранена обработка:

- минимального и максимального `int`;
- двойного минуса;
- `%d`, `%i`, `%u`, `%o`, `%x`, `%X`;
- precision;
- alternate prefixes;
- width и zero padding;
- JavaScript integral-double dispatch.

Изменённый файл: `lib/src/printf_formatter.dart`, функция
`_formatPrintfInteger`.

### Производительность `%d`

До исправления на большом `int`:

```text
{:d}: ≈ 0,596 мкс
%d:   ≈ 0,764 мкс
```

После исправления, два прогона:

```text
{:d}: 0,608–0,613 мкс
%d:   0,490–0,494 мкс
```

### Выполненные проверки

```text
dart test: 329 тестов прошли
Node sprintf_api_test: 14/14 прошли
dart analyze lib/src/printf_formatter.dart: No issues found
git diff --check: чисто
```

Полный analyzer выдаёт 16 ранее существовавших `info` в benchmark-коде.

VM-only `sprintf_integer_test.dart` нельзя запускать через Node: файл содержит
литерал `9223372036854775807`, который dart2js не может представить точно. Это
ожидаемое ограничение теста.

## Исследование `{:10d}` и `%10d`

Production-код brace-форматирования для этого случая ещё не менялся.

Результаты прогретого benchmark:

```text
unicodeScalars
{:10d}, 1:   0,831 мкс
%10d, 1:     0,462 мкс
{:10d}, max: 0,995 мкс
%10d, max:   0,604 мкс

graphemeClusters
{:10d}, 1:   0,837 мкс
%10d, 1:     0,460 мкс
{:10d}, max: 1,003 мкс
%10d, max:   0,622 мкс
```

Корневая причина подтверждена: brace разбирает спецификацию фактически дважды.

```text
"{:10d}"
 → brace parser создаёт AST спецификации
 → _resolveSpecification собирает "10d" через StringBuffer
 → parseFormatSpec снова разбирает "10d"
```

`{:d}` попадает в `_simpleBuiltinFormatSpec`, а `{:10d}` — нет. Поэтому для
`10d` выполняются:

- `textUnit.split('10d')`;
- создание списка text units;
- полный проход по mini-language;
- отдельный `StringBuffer` для width;
- `int.tryParse`;
- создание `_FormatSpec`.

Один `textUnit.split('10d')` занимает около `0,226 мкс`.

Printf `%10d` получает width и type за один проход по ASCII code units. Сам
numeric padding общий для обоих синтаксисов через `applyNumericWidth` и не
является причиной. На максимальном `int` padding отсутствует, но разница
сохраняется.

## Реализованный brace fast path (сессия 2026-08-04, Claude)

Минимальный вариант реализован. В `lib/src/format_spec.dart`:

- `parseFormatSpec` разделён: общий parser вынесен в `_parseFormatSpecGeneral`;
- `_simpleBuiltinFormatSpec` расширен новым ASCII fast path
  `_simpleAsciiFlagWidthSpec` для спецификаций вида
  `sign? z? #? 0? width? type?` (width ≤ 6 цифр, type — встроенный);
- fill/align, grouping, precision-с-width, custom и Unicode остаются на общем
  parser;
- добавлен test seam `debugSimpleBuiltinFormatSpecMatchesGeneralParser`:
  true только если fast path распознал спецификацию и результат пополево
  совпал с общим parser для обоих `TextUnit`.

Тесты: `test/format_spec_fast_path_test.dart` — корпус эквивалентности
(RED наблюдался до реализации), негативный корпус, пиннинг вывода `format()`.

### Производительность (format 3.0 → format, до → после)

```text
{:10d}, 1:    0,897 → 0,566–0,597 мкс   (%10d: ≈ 0,47)
{:10d}, max:  1,071 → 0,745 мкс          (%10d: ≈ 0,64)
{:010d}, 1:   1,035 → 0,664 мкс          (%010d: ≈ 0,69)
{:10d} ×10:   9,33  → 5,99 мкс
```

### Проверки

```text
dart test: 332 теста прошли (было 329, +3 новых)
dart test -p node (format_spec_fast_path, format): 9/9
dart analyze lib test: только 3 pre-existing info в benchmark_scenarios_test
benchmark: без новых ERROR (остался только известный баг пакета sprintf 7.0
на минимальном int)
git diff --check: чисто
```

`integer_format_test.dart` не компилируется под Node из-за литерала
`9223372036854775807` — то же VM-only ограничение, что и у
`sprintf_integer_test.dart`.

## Возможный дальнейший шаг

Более глубокий вариант: не превращать статическую brace-спецификацию из AST
обратно в строку, а хранить уже разобранный `_FormatSpec`. При этом необходимо
отдельно учитывать динамические вложенные поля. Остаток разницы с `%10d`
(≈ 0,1 мкс) — в основном resolve/AST-обвязка, а не парсинг спецификации.

## Диагностические скрипты

Скрипты находятся вне репозитория:

```text
/private/tmp/format_integer_diagnosis.dart
/private/tmp/format_pipeline_diagnosis.dart
/private/tmp/format_width_diagnosis.dart
```
