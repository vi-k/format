# Handoff для новой сессии

Дата: 2026-08-04 (вечер)  
Рабочий каталог: `/Users/user/development/my/format`

Все shell-команды запускать с префиксом `rtk` (hook подменяет
прозрачно). Спецификации, планы и handoff писать по-русски.

## Git-состояние

Ветка `main`, синхронна с `origin/main`, рабочее дерево чистое.
`HEAD` = `4f8c112 perf: memoize static printf conversions`.
Всё, что описано ниже, закоммичено и запушено.

## Что сделано за день

### Производительность lib/ (обе стороны)

- `perf: extend brace spec ASCII fast path to flags and width` и
  `perf: extend brace fast path to fill and align` — `parseFormatSpec`
  разбирает `fill? align? sign? z? #? 0? width? type?` по code units
  без `textUnit.split`. Seam
  `debugSimpleBuiltinFormatSpecMatchesGeneralParser` сверяет fast path
  с общим парсером пополево для обоих `TextUnit`.
- `perf: replace printf flag sets with a bitmask` — флаги printf
  ходят одним int; четыре set-аллокации на вызов устранены.
- `perf: skip AST defensive copies outside asserts` —
  `List.unmodifiable` в конструкторах AST только под asserts
  (`_sealedInDebug`); `dart test` контракт immutability сохраняет.
- `perf: cache parsed templates` — per-isolate кэш AST по строке
  шаблона, ёмкость 512, полная очистка при переполнении, ошибки не
  кэшируются. Seam'ы: `debugBraceTemplateCacheSize` и др. в
  `lib/src/template_cache.dart`.
- `perf: memoize static brace specifications` — в `_FieldNode` два
  ленивых слота `_FormatSpec` (по `TextUnit`); динамические `{:{}d}`
  и ошибки — по-прежнему на каждый вызов. `formatValue` разделён на
  обёртку и `formatParsedValue`.
- `perf: memoize static printf conversions` — `_staticResolved` и
  `_staticContext` на узле для конверсий без `*`-опций; отрицательная
  динамическая ширина не «залипает» (закрыто тестом).

Цифры (тихая машина, утро → вечер, горячий путь):
`{:10d}` 0.90 → 0.27; `{:s}` 0.40 → 0.08; `{:<10s}` 0.81 → 0.17;
`%s` 0.28 → 0.11; `%10d` ~0.51 → 0.29; `%-10s` 0.52 → 0.20 мкс.

### Бенчмарк (example/)

- Матрица из 26 сценариев (`BenchmarkScenario`: nullable brace/sprintf,
  `skipLegacy`, `skipSprintf7`), все распространённые типы + fill/align.
- Режимы: quick (дефолт, `BenchmarkDurations.quick` 45/165 мс,
  фактически ~42 с) и `--full` (100/2000, ~4 мин). Пользователь
  разрешил quick до 60 с. Неизвестный флаг — сообщение + exit 64.
- Логика прогона — `runComparisonBenchmark` в
  `example/lib/src/comparison_benchmark.dart` (testable через
  `writeLine`), bin — тонкая обёртка.
- Намеренный ERROR: sprintf 7.0 печатает `--…` на минимальном int —
  оставлен видимым по требованию пользователя, интеграционный тест
  фиксирует ровно один ERROR.
- Cold-секция: два раннера format 3.0 с уникальным шаблоном на вызов —
  парсер под наблюдением после появления кэша (0.85/0.61 мкс).

### Спеки и планы

`docs/superpowers/specs/` и `plans/`: benchmark-type-coverage и
template-cache — актуальны реализации.

## Проверки на HEAD

```text
dart test (корень): 342 прошли
dart test (example): 13 прошли
dart test -p node (fast path, format, template_cache): 16 прошли
dart analyze lib test example: 3 pre-existing info в
  test/benchmark_scenarios_test.dart, больше ничего
Бенчмарк quick: 42.5 с, ERROR ровно 1 (намеренный)
```

## Ловушки и знания (важно)

- Двойная библиотека: смешение `package:format/...` и относительного
  `../lib/src/...` в одном файле создаёт ДВЕ копии библиотеки
  (разные канонические URI) с независимыми статиками и несовместимыми
  типами. Seam-тесты импортируют движок ТОЛЬКО через
  `package:format/src/engine.dart` (тот же URI, что у публичного
  экспорта). Не возвращать относительные импорты.
- Тесты кэша обязаны звать `debugClearTemplateCaches` в `setUp`.
- Замеры чувствительны к фону: Android-эмулятор пользователя давал
  load 24–44 и 5–10× шум. Перед замером проверять
  `sysctl -n vm.loadavg`. Тест
  `benchmark_scenarios_test.dart: compiled JavaScript runner...`
  (dart2js внутри, лимит 30 с) под нагрузкой таймаутится — это не
  поломка; проверять `--timeout 4x` или на тихой машине.
- «%d дожат»: мемоизация внутреннего `_FormatSpec` целочисленного
  форматтера дала ноль в A/B (аллокация мелких объектов бесплатна) —
  изменение откачено. Правило проекта: нет performance GREEN — нет
  коммита.
- VM-only тесты (литерал max int не компилируется dart2js):
  `integer_format_test.dart`, `sprintf_integer_test.dart`.
- Диагностические скрипты сессии (string_diagnosis, printf_flag_cost,
  printf_left_diagnosis, oracle) жили в session-scratchpad вне репо —
  одноразовые, при нужде пересоздать; запуск:
  `dart --packages=example/.dart_tool/package_config.json <скрипт>`.

## Возможные следующие шаги

- Единственный крупный оставшийся резерв производительности —
  «компиляция» шаблонов в IR с прямой записью цифр в общий выходной
  буфер (без промежуточных строк). Сознательно вынесено за рамки
  кэша; это редизайн форматтеров — начинать с brainstorming.
- Мелочь: поднять декларативный timeout JS-теста в
  `benchmark_scenarios_test.dart`, чтобы не фолзил под нагрузкой.
- 3 давних analyzer-info в `test/benchmark_scenarios_test.dart` можно
  причесать отдельным test-коммитом.
