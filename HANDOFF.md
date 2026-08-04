# Handoff для новой сессии

Дата: 2026-08-05
Рабочий каталог: `/Users/user/development/my/format`

Все shell-команды запускать с префиксом `rtk` (hook подменяет
прозрачно). Спецификации, планы и handoff писать по-русски.

## Git-состояние

Ветка `main`, синхронна с `origin/main` на момент старта сессии
(пуш не выполнялся). Рабочее дерево чистое. `HEAD` продвинулся на два
коммита за сессию:

```text
<новый>  docs: record template IR results and refresh handoff   (этот коммит)
d2bb6aa  perf: return single-string sink output without copying
c96d2f6  bench: add IR vs legacy A/B benchmark runner            (конец Task 10)
```

Оба новых коммита содержат trailer `Co-Authored-By: Claude Fable 5
<noreply@anthropic.com>`. Всё, что описано ниже, закоммичено; пуш в
`origin` не делался — следующей сессии решать, когда пушить.

## Template IR: спека завершена (Tasks 1–11)

Редизайн форматтеров под IR (компиляция шаблона в программу op'ов,
прямая запись в общий буфер без промежуточных строк) полностью
реализован и провалидирован. Основные файлы:

- `lib/src/char_sink.dart` — `CharSink`: growable UTF-16 sink
  (`Uint16List`) с прямыми методами `writeCharCode`/`writeString`/
  `writeCodeUnits`/`fill`/`writeMagnitude`. **Новое в Task 11**: lazy
  single-string режим — поле `String? _single`; первый `writeString`
  на пустом sink'е просто запоминает строку по ссылке; любая
  последующая запись (второй `writeString`, `writeCharCode`, `fill`,
  `writeMagnitude`) сначала «материализует» отложенную строку в
  `_buffer` через тот же `setRange`-путь (метод `_materialize()`), а
  дальше работает как раньше. `toString()` для чисто-однострочного
  вывода возвращает `_single` НАПРЯМУЮ — ноль копий (быстрее даже
  legacy-пути с его одной копией через `StringBuffer`). `length`
  считает по `_single?.length ?? _length` (UTF-16 code units в обоих
  случаях). Инвариант: `_single != null` ⇒ `_length == 0`.
- `lib/src/template_ir.dart` — `_BraceOp`/`_PrintfOp` (sealed) и их
  компиляция:
  - Brace-op'ы: `_BraceLiteralOp` (статический текст), `_BraceFallbackOp`
    (всё, что не попало под классификацию — старый резолвер + одна
    строка), `_BraceDynamicValueOp` (`{}`/`{0}` без спецификации),
    `_BraceIntOp` (`d/b/o/x/X` без grouping/precision — пишет цифры
    сразу в sink через `writeMagnitude`), `_BraceTextOp` (`:s` с
    опциональными width/align/precision).
  - Printf-op'ы: `_PrintfLiteralOp`, `_PrintfFallbackOp` (та же роль,
    что и brace-fallback: сохраняет `_staticResolved`/`_staticContext`
    мемоизацию), `_PrintfStringOp` (`%s`), `_PrintfIntOp`
    (`d/i/u/o/x/X`).
  - Компиляция тотальна и не бросает: неклассифицируемое поле всегда
    попадает в fallback-op, а не в ошибку компиляции.
  - Программа кэшируется по два слота на шаблон — `programFor(TextUnit)`
    в `_BraceTemplate`/`_PrintfTemplate` (`lib/src/brace_ast.dart`,
    `lib/src/printf_ast.dart`): один слот на `TextUnit.unicodeScalars`,
    один на `TextUnit.graphemeClusters`, лениво, максимум одна
    компиляция на комбинацию шаблон×юнит.
- `lib/src/brace_processor.dart` / `lib/src/printf_processor.dart` —
  `format()` прогоняет `program.ops` по общему `CharSink` и один раз
  зовёт `toString()`; `formatWithoutIr()` — сохранённый legacy-путь
  (сборка через `StringBuffer`), используется дифф-тестами и
  A/B-бенчмарком как baseline, публично не экспортируется.
- Seam'ы (не экспортируются `format.dart`, доступны только через
  `package:format/src/engine.dart`):
  - `debugCompiledProgramDescription(template, {printf, textUnit})` —
    список `op.describe()` скомпилированной программы, для
    компиляционных тестов.
  - `debugFormatBraceWithoutIr` / `debugFormatPrintfWithoutIr` — прямой
    вызов legacy-пути с теми же аргументами, что и публичный API, для
    дифф-тестов и A/B-бенчмарка.

## Замеры: RED → GREEN

### A/B (IR против legacy на идентичных вызовах)

Команда: `dart run example/bin/template_ir_benchmark.dart`
(`example/lib/src/template_ir_benchmark.dart`,
`example/bin/template_ir_benchmark.dart`).

Task 10 (после фикса маршалинг-перекоса, до Task 11) — RED для этой
матрицы: статические целочисленные hot-сценарии (`{:10d}`, `{:x}`,
`%10d`, `%0*d`) уже `IR FASTER` (89–166%); текстовые сценарии `{:s}`/
`%s` — `LEGACY FASTER` 11–16%; grapheme fallback-control (`{:é^10s}`)
— `LEGACY FASTER` 50–52%. Корневая причина (установлена в Task 10):
чисто-однострочный вывод в IR платил две копии (`CharSink.writeString`
`setRange` + финальный `String.fromCharCodes`) против rope-семантики
VM-овского `StringBuffer` в legacy-пути — хуже всего именно там, где
результат — ровно одна строка.

GREEN (Task 11, после single-string sink, три живых прогона,
`vm.loadavg` в диапазоне `2.6–2.7`, без `RESULTS DIFFER` и без единого
`LEGACY FASTER` во всех трёх):

| Сценарий | IR | Legacy | Вердикт (прогон 1 / прогон 2) |
|---|---|---|---|
| `{:10d}` (hot) | 0.075–0.085 µs | 0.226–0.253 µs | IR FASTER 202.3% / 196.6% |
| `{:x}` (hot) | 0.048–0.050 µs | 0.162–0.171 µs | IR FASTER 235.4% / 245.2% |
| `{:s}` (hot) | 0.029–0.030 µs | 0.062 µs | IR FASTER 115.8% / 108.6% |
| `{:<10s}` (hot) | 0.128–0.130 µs | 0.131–0.134 µs | EQUAL 2.8% / 2.1% |
| `{}` (hot) | 0.030–0.031 µs | 0.059–0.060 µs | IR FASTER 91.2% / 97.7% |
| `%s` (hot) | 0.059–0.063 µs | 0.090–0.095 µs | IR FASTER 62.4% / 43.4% |
| `%10d` (hot) | 0.121–0.124 µs | 0.257–0.263 µs | IR FASTER 112.1% / 111.9% |
| `%0*d` (hot) | 0.119–0.132 µs | 0.337–0.364 µs | IR FASTER 183.8% / 175.7% |
| `{:.2f}` (fallback-control) | 0.528–0.558 µs | 0.535–0.564 µs | EQUAL 1.3% / 1.2% |
| `{:é^10s}` (fallback-control, grapheme) | 0.194–0.197 µs | 0.192–0.196 µs | EQUAL 2.5% / 1.0% |

Оба закрытых до этого проблемных сценария (`{:s}`/`%s`) перешли в
`IR FASTER`; grapheme fallback-control перешёл в `PERFORMANCE EQUAL`
(было `LEGACY FASTER` 50–52%). Целочисленные hot-сценарии остались
`IR FASTER` с ещё бо́льшим отрывом. Третий прогон (не в таблице,
для верификации стабильности) дал тот же качественный паттерн: ноль
`RESULTS DIFFER`, ноль `LEGACY FASTER`.

### Полная матрица (`example/bin/benchmark.dart`)

Команда: `dart run example/bin/benchmark.dart` (quick-режим).
RED-файл: `.superpowers/sdd/2026-08-04-template-ir/red-benchmark.txt`
(захвачен на HEAD `c96d2f6`, т.е. после Task 10, до single-string
sink).

Горячие сценарии, `format 3.0 → format` / `format 3.0 → sprintf`,
RED → GREEN (значение с маленькой магнитудой; два независимых
прогона GREEN, числа стабильны):

| Сценарий | RED | GREEN (прогон 1 / 2) |
|---|---|---|
| `{:10d}` (значение `1`) | 0.237 µs | 0.090 / 0.091 µs |
| `{:s}` | 0.066 µs | 0.029 / 0.030 µs |
| `{:<10s}` | 0.152 µs | 0.138 / 0.139 µs |
| `%s` (через `{:s}`→`%s`) | 0.096 µs | 0.063 / 0.063 µs |
| `%10d` (значение `1`, через `{:10d}`→`%10d`) | 0.236 µs | 0.126 / 0.126 µs |

Cold-секция (два раннера с уникальным шаблоном на вызов):
`format (cold)` RED 0.752 µs → GREEN 0.650 / 0.644 µs;
`format → sprintf (cold)` RED 0.555 µs → GREEN 0.493 / 0.488 µs —
заметно **лучше** RED, не хуже (порог тревоги был `>25% хуже`).

ERROR ровно один в каждом прогоне — намеренный (`sprintf 7.0` на
минимальном int). Quick-режим: 38.7 с / 39.4 с (порог 60 с).

**Важная деталь, установленная в Task 11**: строки для 19-значных
значений (максимум/минимум `int64`) в `{:d}`/`{:10d}`/`%10d` в
сегодняшнем прогоне выглядят на 10–23% медленнее, чем в
`red-benchmark.txt` (например `{:10d}` на макс. int: RED 0.392 µs →
GREEN ~0.435 µs). Это **не регрессия от single-string sink** —
подтверждено прямым сравнением на одной и той же машине в одну и ту
же сессию: временный откат `char_sink.dart` к состоянию до Task 11 и
повторный прогон дали те же ~0.43 µs для этих строк (0.430–0.433 µs),
т.е. дрейф целиком объясняется разницей условий между сессией, когда
был захвачен RED-файл, и сегодняшней (фон, JIT-прогрев и т.п.), а не
кодом. `_BraceIntOp`/`_PrintfIntOp` вообще не проходят через
single-string путь (они не вызывают `writeString` для самого числа),
так что затронуть их эта оптимизация и не могла. Единственная
проверяемая стоимость single-string режима на не-single-string
путях — один `null`-чек в начале `_materialize()` на каждый
`writeCharCode`/`writeCodeUnits`/`fill`/`writeMagnitude`; замеры
показывают, что она в пределах шума.

## Проверки на HEAD

```text
dart test (корень): 376 прошли
dart test (example): 15 прошли
dart test -p node test/char_sink_test.dart test/template_ir_compile_test.dart
  test/template_ir_diff_test.dart: 33 прошли (12 char_sink + 12
  template_ir_compile + 9 template_ir_diff)
dart analyze lib test example: No issues found!
A/B (template_ir_benchmark.dart): 3 живых прогона, 0 RESULTS DIFFER, 0
  LEGACY FASTER
Полная матрица (benchmark.dart) quick: 2 живых прогона, ~39 с каждый,
  ERROR ровно 1 в каждом (намеренный)
```

## Ловушки и знания (важно)

- Двойная библиотека: смешение `package:format/...` и относительного
  `../lib/src/...` в одном файле создаёт ДВЕ копии библиотеки
  (разные канонические URI) с независимыми статиками и несовместимыми
  типами. Seam-тесты импортируют движок ТОЛЬКО через
  `package:format/src/engine.dart` (тот же URI, что у публичного
  экспорта). Не возвращать относительные импорты.
- Тесты кэша обязаны звать `debugClearTemplateCaches` в `setUp`.
- Замеры чувствительны к фону: перед замером проверять
  `sysctl -n vm.loadavg` (порог < 5). Абсолютные цифры между сессиями
  плавают (см. кейс с 19-значными int выше) — для решений о
  регрессии/улучшении надёжнее сравнение «до/после» на одной машине в
  одну сессию, а не только сверка с числами из старого RED-файла.
- `CharSink` single-string инвариант: `_single != null ⇒ _length == 0`.
  Любой новый метод записи, который может быть добавлен в `CharSink` в
  будущем, обязан либо звать `_materialize()` первым, либо явно
  документировать, почему он безопасен без неё (иначе строка,
  ожидающая в `_single`, будет молча потеряна).
- VM-only тесты (литерал max int не компилируется dart2js):
  `integer_format_test.dart`, `sprintf_integer_test.dart`.
- «%d дожат»: мемоизация внутреннего `_FormatSpec` целочисленного
  форматтера дала ноль в A/B (аллокация мелких объектов бесплатна) —
  изменение откачено. Правило проекта: нет performance GREEN — нет
  коммита. Это же правило применено в Task 11: если бы A/B-повтор
  после single-string sink не показал восстановления `{:s}`/`%s`/
  grapheme-сценария, handoff и коммит результатов не делались бы.

## Возможные следующие шаги (незакрытые резервы)

- **Double-op'ы**: `{:.2f}`/`{:f}`/`{:e}`/`{:g}` и `%` эквиваленты
  по-прежнему идут через `_BraceFallbackOp`/`_PrintfFallbackOp` (общий
  резолвер + одна строка). Task 11 показал их `PERFORMANCE EQUAL`, то
  есть выделенный hot-op для double не обязателен прямо сейчас, но
  остаётся кандидатом, если double-сценарии станут узким местом.
- **Пул sink'ов**: `CharSink` сейчас создаётся заново на каждый вызов
  `format()`/`vsprintf()` с ёмкостью `program.estimatedCapacity`.
  Пулинг/переиспользование буфера между вызовами не исследовался —
  потенциальный резерв для очень горячих циклов форматирования
  (нужен профиль, прежде чем браться).
- **Удаление legacy-процессоров** — отдельная задача на будущее:
  `formatWithoutIr()` в `_BraceProcessor`/`_PrintfProcessor` сейчас
  живёт исключительно как baseline для дифф-тестов и A/B-бенчмарка;
  если IR-путь остаётся единственным производственным путём
  достаточно долго без регрессий, legacy-код и связанный с ним
  `_FieldResolver`-путь для форматирования (не путать с резолвером
  значений, который используется и в fallback-op'ах) можно вынести в
  отдельный PR на удаление — вне охвата этой сессии.
- Мелочи из предыдущего handoff (декларативный timeout JS-теста,
  3 analyzer-info в `benchmark_scenarios_test.dart`) уже закрыты
  коммитами `0299a79` и `c759228` до начала работы над IR.
