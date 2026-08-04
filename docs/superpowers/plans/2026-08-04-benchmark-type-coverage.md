# План: покрытие типов и ускорение сравнительного бенчмарка

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Расширить `example/bin/benchmark.dart` на все распространённые сценарии форматирования (включая fill/align), убрать избыточные строки и сократить прогон с ~2.8 мин до ~33 с (флаг `--full` — точный режим).

**Architecture:** Логика прогона переезжает из `bin/benchmark.dart` в `example/lib/src/comparison_benchmark.dart` (по образцу `runDoubleModesBenchmark` — testable через `writeLine`). `MyBenchmarkBase.measure()` переопределяется с настраиваемыми длительностями. Матрица сценариев переписывается на класс `BenchmarkScenario` с nullable-шаблонами.

**Tech Stack:** Dart, `benchmark_harness` 2.3.1 (остаётся), `package:test`.

**Спека:** `docs/superpowers/specs/2026-08-04-benchmark-type-coverage-design.md`.

## Global Constraints

- Все четыре раннера сохраняются: `sprintf 7.0 → sprintf`, `format 2.0 → format`, `format 3.0 → format`, `format 3.0 → sprintf`.
- `benchmark_harness` остаётся основой измерений (переопределяем только `measure()`; `BenchmarkBase.measureFor` — публичный статический).
- Никаких timing-ассертов в unit-тестах (правило проекта). Тесты проверяют конфигурацию и вывод, не время.
- Производственный код `lib/` не трогать. `double_modes_benchmark`, `format2_gate`, корневой `test/` — не трогать.
- Analyzer: не добавлять новых замечаний (строки ≤ 80 символов).
- Все команды запускать из `/Users/user/development/my/format/example`, кроме отдельно указанных.
- Коммиты с префиксом `bench:`; трейлер `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

Известные факты об окружении (проверены):

- `BenchmarkBase.measure()` в harness 2.3.1: `setup(); measureForImpl(warmup, 100); result = measureForImpl(exercise, minimumMeasureDurationMillis /* топ-уровневая const = 2000 */); teardown();` — метод переопределяем, константа нет.
- printf-движок format 3.0 поддерживает типы `c s d i u o x X a A e E f F g G %` — `%b` НЕ поддерживается.
- Движки раннеров: format 3.0 brace — `Format(textUnit: TextUnit.graphemeClusters).formatWith(t, positional: v)`; format 3.0 printf — тот же экземпляр, `.vsprintf(t, v)`; format 2.0 — `legacyFormat(t, v)` из `package:example/src/legacy_format_baseline.dart`; sprintf 7.0 — `sprintf7.sprintf(t, v)` из `package:sprintf7_baseline/sprintf.dart`.
- Известный баг sprintf 7.0: минимальный int печатается с двойным минусом — минимальный int в матрице не используется.

---

### Task 1: Настраиваемые длительности измерения

**Files:**
- Modify: `example/lib/src/my_benchmark_base.dart`
- Test: `example/test/restored_benchmark_test.dart`

**Interfaces:**
- Consumes: `BenchmarkBase.measureFor(void Function(), int)` из `package:benchmark_harness`.
- Produces: `final class BenchmarkDurations { final int warmupMillis; final int measureMillis; const BenchmarkDurations({required this.warmupMillis, required this.measureMillis}); static const quick; static const full; }` и мутабельное поле `MyBenchmarkBase.durations` (дефолт `quick`). Задачи 2–4 используют оба имени как есть.

- [ ] **Step 1: Написать падающий тест**

В `example/test/restored_benchmark_test.dart` добавить:

```dart
  test('benchmark durations default to quick and switch to full', () {
    expect(BenchmarkDurations.quick.warmupMillis, 60);
    expect(BenchmarkDurations.quick.measureMillis, 250);
    expect(BenchmarkDurations.full.warmupMillis, 100);
    expect(BenchmarkDurations.full.measureMillis, 2000);

    final benchmark = BenchmarkFormat3Format();
    expect(benchmark.durations, BenchmarkDurations.quick);
    benchmark.durations = BenchmarkDurations.full;
    expect(benchmark.durations, BenchmarkDurations.full);
  });
```

- [ ] **Step 2: Убедиться, что тест падает**

Run: `dart test test/restored_benchmark_test.dart`
Expected: ошибка компиляции — `BenchmarkDurations` не определён. Это ожидаемый RED для статического языка.

- [ ] **Step 3: Минимальная реализация**

Заменить содержимое `example/lib/src/my_benchmark_base.dart` на:

```dart
import 'package:benchmark_harness/benchmark_harness.dart';

final class BenchmarkDurations {
  final int warmupMillis;
  final int measureMillis;

  const BenchmarkDurations({
    required this.warmupMillis,
    required this.measureMillis,
  });

  static const quick = BenchmarkDurations(warmupMillis: 60, measureMillis: 250);
  static const full = BenchmarkDurations(
    warmupMillis: 100,
    measureMillis: 2000,
  );
}

abstract base class MyBenchmarkBase extends BenchmarkBase {
  late String template;
  late List<Object?> values;
  late String output;
  BenchmarkDurations durations = BenchmarkDurations.quick;

  MyBenchmarkBase({required String name}) : super(name);

  bool get isSprintf;

  @override
  double measure() {
    setup();
    BenchmarkBase.measureFor(warmup, durations.warmupMillis);
    final result = BenchmarkBase.measureFor(
      exercise,
      durations.measureMillis,
    );
    teardown();
    return result;
  }

  double go(String template, List<Object?> values) {
    this.template = template;
    this.values = values;

    return measure() / 100;
  }
}
```

`measure()` повторяет структуру оригинала из harness 2.3.1, меняя только минимальные длительности.

- [ ] **Step 4: Убедиться, что тесты проходят**

Run: `dart test test/restored_benchmark_test.dart`
Expected: PASS, включая существующие тесты (go() продолжает работать; дефолт quick уже ускоряет их).

- [ ] **Step 5: Commit**

```bash
git add lib/src/my_benchmark_base.dart test/restored_benchmark_test.dart
git commit -m "bench: make measurement durations configurable

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Разбор аргументов quick/full

**Files:**
- Create: `example/lib/src/comparison_benchmark.dart`
- Modify: `example/lib/benchmark.dart`
- Test: `example/test/restored_benchmark_test.dart`

**Interfaces:**
- Consumes: `BenchmarkDurations` из Task 1.
- Produces: `BenchmarkDurations parseBenchmarkArgs(List<String> args)` — `[]` → quick, `['--full']` → full, иначе `FormatException`. Task 3 вызывает её из `runComparisonBenchmark`.

- [ ] **Step 1: Написать падающий тест**

```dart
  test('benchmark arguments select measurement durations', () {
    expect(parseBenchmarkArgs([]), BenchmarkDurations.quick);
    expect(parseBenchmarkArgs(['--full']), BenchmarkDurations.full);
    expect(() => parseBenchmarkArgs(['--fast']), throwsFormatException);
    expect(() => parseBenchmarkArgs(['--full', 'x']), throwsFormatException);
  });
```

- [ ] **Step 2: Убедиться, что тест падает**

Run: `dart test test/restored_benchmark_test.dart`
Expected: ошибка компиляции — `parseBenchmarkArgs` не определён.

- [ ] **Step 3: Минимальная реализация**

Создать `example/lib/src/comparison_benchmark.dart`:

```dart
import 'my_benchmark_base.dart';

/// Parses benchmark CLI arguments: no flags select the quick mode, `--full`
/// selects the precise benchmark_harness defaults.
BenchmarkDurations parseBenchmarkArgs(List<String> args) => switch (args) {
  [] => BenchmarkDurations.quick,
  ['--full'] => BenchmarkDurations.full,
  _ => throw FormatException(
    'Unknown arguments: ${args.join(' ')}. Usage: benchmark.dart [--full]',
  ),
};
```

В `example/lib/benchmark.dart` добавить экспорт (по алфавиту):

```dart
export 'src/comparison_benchmark.dart';
```

- [ ] **Step 4: Убедиться, что тесты проходят**

Run: `dart test test/restored_benchmark_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/comparison_benchmark.dart lib/benchmark.dart test/restored_benchmark_test.dart
git commit -m "bench: parse quick and full benchmark modes

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Извлечь runComparisonBenchmark из bin

Чистое извлечение при СТАРОЙ матрице `testData`: bin становится тонкой обёрткой, логика — testable-функцией. Поведение вывода не меняется, добавляется только итоговая строка Mode/Total.

**Files:**
- Modify: `example/lib/src/comparison_benchmark.dart`
- Modify: `example/bin/benchmark.dart`
- Test: `example/test/restored_benchmark_test.dart`

**Interfaces:**
- Consumes: `parseBenchmarkArgs`, `BenchmarkDurations` (Tasks 1–2); `testData` из `tests/tests.dart`; типы раннеров; `BenchmarkLineWriter` из `double_modes_benchmark.dart`; хелперы `h1/h2/ok/error/accent/accentError` из `utils/output.dart`.
- Produces: `void runComparisonBenchmark({List<String> args = const [], BenchmarkLineWriter? writeLine, BenchmarkDurations? durations})` — Task 4 меняет только тело цикла, сигнатура остаётся.

- [ ] **Step 1: Написать падающий тест**

```dart
  test('comparison benchmark reports scores and total time', () {
    final lines = <String>[];

    runComparisonBenchmark(
      writeLine: lines.add,
      durations: const BenchmarkDurations(warmupMillis: 1, measureMillis: 1),
    );

    final output = lines.join('\n');
    expect(output, contains('Format template:'));
    expect(output, contains('OK'));
    expect(output, contains('Mode: quick'));
    expect(output, contains('Total:'));
  });
```

Замечание: при старой матрице в выводе есть ERROR от sprintf 7.0 на минимальном int — на этом шаге его отсутствие НЕ проверяем (это Task 4).

- [ ] **Step 2: Убедиться, что тест падает**

Run: `dart test test/restored_benchmark_test.dart`
Expected: ошибка компиляции — у `runComparisonBenchmark` нет такой сигнатуры (функция не определена).

- [ ] **Step 3: Реализация**

`example/lib/src/comparison_benchmark.dart` — добавить (перенос текущего `_run` и `diff` из bin; `emit` вместо `print`):

```dart
import 'dart:math';

import 'package:format/format.dart';

import 'benchmark_format2_format.dart';
import 'benchmark_format3_format.dart';
import 'benchmark_format3_sprintf.dart';
import 'benchmark_sprintf7.dart';
import 'double_modes_benchmark.dart' show BenchmarkLineWriter;
import 'my_benchmark_base.dart';
import 'tests/tests.dart';
import 'utils/output.dart';

// ... parseBenchmarkArgs из Task 2 ...

void runComparisonBenchmark({
  List<String> args = const [],
  BenchmarkLineWriter? writeLine,
  BenchmarkDurations? durations,
}) {
  final resolved = durations ?? parseBenchmarkArgs(args);
  final emit = writeLine ?? print;
  final benchmarks = [
    BenchmarkSprintf7(),
    BenchmarkFormat2Format(),
    BenchmarkFormat3Format(),
    BenchmarkFormat3Sprintf(),
  ];
  for (final benchmark in benchmarks) {
    benchmark.durations = resolved;
  }

  final stopwatch = Stopwatch()..start();
  for (final template in testData) {
    final formatTemplate = template.$1;
    final sprintfTemplate = template.$2;

    emit('');
    emit(h1('----------------------------------------'));
    emit('Format template: ${h1(formatTemplate)}');
    emit('Sprintf template: ${h1(sprintfTemplate)}');

    for (final test in template.$3) {
      final values = test.$1;
      final result = test.$2;

      emit('');
      emit('Values: ${h2(values.join(', '))}');

      for (final benchmark in benchmarks) {
        try {
          final score = benchmark.go(
            benchmark.isSprintf ? sprintfTemplate : formatTemplate,
            values,
          );

          String message;
          if (benchmark.output == result) {
            message = ok('OK');
          } else {
            final difference = _diff(result, benchmark.output);
            message =
                '${accentError('ERROR')}'
                '\n  expected: ${difference.$1}'
                '\n  actual:   ${difference.$2}';
          }
          emit(
            '${accent(benchmark.name)}:'
            ' ${format('{:.3f}', score)} µs'
            ' <- $message',
          );
        } on Object catch (errorValue) {
          emit(
            '${accent(benchmark.name)}:'
            ' <- ${accentError('ERROR')}'
            '\n${error(errorValue.toString())}',
          );
        }
      }
    }
  }

  emit('');
  emit(h1('----------------------------------------'));
  final mode = identical(resolved, BenchmarkDurations.full) ? 'full' : 'quick';
  final seconds = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);
  emit('Mode: $mode. Total: $seconds s');
}

(String, String) _diff(String expected, String actual) {
  final minLength = min(expected.length, actual.length);
  final maxLength = max(expected.length, actual.length);
  final expectedReturn = expected.padRight(maxLength);

  var end = 0;
  while (end < minLength && expected[end] == actual[end]) {
    end++;
  }

  final absent =
      actual.length >= expected.length
          ? ''
          : '•' * (expected.length - actual.length);

  final rest = actual.substring(end);
  return (
    expectedReturn,
    '${actual.substring(0, end)}'
        '${error(rest)}'
        '${error(absent)}',
  );
}
```

`example/bin/benchmark.dart` заменить целиком на:

```dart
import 'package:ansi_escape_codes/ansi_escape_codes.dart' as ansi;
import 'package:example/benchmark.dart';

void main(List<String> arguments) {
  ansi.runZonedPrinter(
    defaultStyle: const ansi.Style(foreground: defaultFg),
    () => runComparisonBenchmark(args: arguments),
  );
}
```

- [ ] **Step 4: Убедиться, что тесты проходят**

Run: `dart test test/restored_benchmark_test.dart && dart analyze .`
Expected: PASS; analyzer без новых замечаний.

- [ ] **Step 5: Smoke-прогон бинарника**

Run: `dart run bin/benchmark.dart | tail -3`
Expected: последняя строка вида `Mode: quick. Total: NN.N s` (~40–60 с на старой матрице из 19 строк; ERROR sprintf 7.0 на минимальном int пока остаётся — известный баг).

- [ ] **Step 6: Commit**

```bash
git add lib/src/comparison_benchmark.dart bin/benchmark.dart test/restored_benchmark_test.dart
git commit -m "bench: extract comparison benchmark runner

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Матрица сценариев с покрытием типов и пропусками

**Files:**
- Modify: `example/lib/src/tests/tests.dart` (полная замена)
- Modify: `example/lib/src/comparison_benchmark.dart` (тело цикла)
- Modify: `example/lib/src/my_benchmark_base.dart` (+`isLegacy`)
- Modify: `example/lib/src/benchmark_format2_format.dart` (+override)
- Test: `example/test/restored_benchmark_test.dart`

**Interfaces:**
- Consumes: всё из Tasks 1–3.
- Produces:
  - `final class BenchmarkScenario { final String? brace; final String? sprintf; final bool skipLegacy; final List<(List<Object?>, String)> cases; const BenchmarkScenario({required this.brace, required this.sprintf, this.skipLegacy = false, required this.cases}); }`
  - `final benchmarkScenarios = <BenchmarkScenario>[...]` (заменяет `testData`; `ListMultiplyExt` удаляется).
  - `bool get isLegacy` на `MyBenchmarkBase` (база — `false`, `BenchmarkFormat2Format` — `true`).

- [ ] **Step 1: Оракул — сверить движки на черновой матрице**

Создать НЕ в репозитории, в scratchpad-каталоге сессии, файл `oracle.dart`:

```dart
import 'package:example/src/legacy_format_baseline.dart';
import 'package:format/format.dart';
import 'package:sprintf7_baseline/sprintf.dart' as sprintf7;

final _format3 = Format(textUnit: TextUnit.graphemeClusters);

void main() {
  final rows = <(String?, String?, List<List<Object?>>)>[
    ('{}', '%d', [[0], [9223372036854775807]]),
    ('{:d}', '%d', [[9223372036854775807], [-12345]]),
    ('{:10d}', '%10d', [[1], [9223372036854775807]]),
    ('{:010d}', '%010d', [[1]]),
    ('{:+d}', '%+d', [[42]]),
    ('{:x}', '%x', [[3735928559]]),
    ('{:X}', '%X', [[3735928559]]),
    ('{:#x}', '%#x', [[255]]),
    ('{:o}', '%o', [[493]]),
    ('{:b}', null, [[170]]),
    ('{:,d}', null, [[1234567]]),
    ('{:c}', '%c', [[65]]),
    ('{:.2f}', '%.2f', [[0.1], [12345678901234.568]]),
    ('{:f}', '%f', [[3.141592653589793]]),
    ('{:e}', '%e', [[12345.6789]]),
    ('{:g}', '%g', [[0.00012345]]),
    ('{:.3g}', '%.3g', [[1234.5678]]),
    ('{:%}', null, [[0.756]]),
    ('{}', '%s', [['hello world']]),
    ('{:s}', '%s', [['hello world']]),
    ('{:>10s}', '%10s', [['dart']]),
    ('{:<10s}', '%-10s', [['dart']]),
    ('{:^10s}', null, [['dart']]),
    ('{:*^10s}', null, [['dart']]),
    ('{:é^10s}', null, [['dart']]),
    ('{:d} ' * 10, '%d ' * 10, [
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    ]),
  ];
  for (final (brace, sprintf, valueSets) in rows) {
    for (final values in valueSets) {
      print('--- $brace | $sprintf | $values');
      if (brace != null) {
        _tryPrint('format3 ', () => _format3.formatWith(
              brace,
              positional: values,
            ));
        _tryPrint('legacy2 ', () => legacyFormat(brace, values));
      }
      if (sprintf != null) {
        _tryPrint('printf3 ', () => _format3.vsprintf(sprintf, values));
        _tryPrint('sprintf7', () => sprintf7.sprintf(sprintf, values));
      }
    }
  }
}

void _tryPrint(String engine, String Function() run) {
  try {
    print('  $engine: "${run()}"');
  } on Object catch (errorValue) {
    print('  $engine: ERROR $errorValue');
  }
}
```

Run (из `example/`): `dart run <scratchpad>/oracle.dart`

По каждой строке применить правила спеки:
- все участвующие движки совпали → их вывод становится ожидаемой строкой;
- расходится только legacy 2.0 → `skipLegacy: true` у строки;
- расходятся printf-движки между собой или с brace → заменить значение
  либо обнулить sprintf-шаблон (`sprintf: null`);
- зафиксировать фактические решения в сообщении коммита этой задачи.

- [ ] **Step 2: Написать падающие пин-тесты**

В `example/test/restored_benchmark_test.dart` ЗАМЕНИТЬ тест `'restored matrix keeps separate brace and printf templates'` на:

```dart
  test('comparison matrix covers common builtin scenarios', () {
    expect(benchmarkScenarios, hasLength(26));

    final braces = benchmarkScenarios.map((s) => s.brace).toList();
    expect(braces, contains('{:b}'));
    expect(braces, contains('{:,d}'));
    expect(braces, contains('{:é^10s}'));
    expect(braces, contains('{:d} ' * 10));
    expect(braces, isNot(contains('{:10d} ' * 10)));

    final binary = benchmarkScenarios.singleWhere((s) => s.brace == '{:b}');
    expect(binary.sprintf, isNull);

    final first = benchmarkScenarios.first;
    expect(first.brace, '{}');
    expect(first.sprintf, '%d');
    expect(first.cases.first.$2, '0');
  });
```

И ЗАМЕНИТЬ тест Task 3 `'comparison benchmark reports scores and total time'` на усиленный:

```dart
  test('comparison benchmark skips missing runners and stays clean', () {
    final lines = <String>[];

    runComparisonBenchmark(
      writeLine: lines.add,
      durations: const BenchmarkDurations(warmupMillis: 1, measureMillis: 1),
    );

    final output = lines.join('\n');
    expect(output, contains('{:b}'));
    expect(output, contains(': —'));
    expect(output, contains('OK'));
    expect(output, isNot(contains('ERROR')));
    expect(output, contains('Mode: quick'));
    expect(output, contains('Total:'));
  });
```

- [ ] **Step 3: Убедиться, что тесты падают**

Run: `dart test test/restored_benchmark_test.dart`
Expected: ошибка компиляции — `benchmarkScenarios` не определён.

- [ ] **Step 4: Реализация — модель и матрица**

`example/lib/src/tests/tests.dart` заменить целиком (ожидаемые строки ниже — расчётные; если оракул из Step 1 дал другие — использовать вывод оракула и решения по правилам спеки):

```dart
final class BenchmarkScenario {
  final String? brace;
  final String? sprintf;
  final bool skipLegacy;
  final List<(List<Object?>, String)> cases;

  const BenchmarkScenario({
    required this.brace,
    required this.sprintf,
    this.skipLegacy = false,
    required this.cases,
  });
}

final benchmarkScenarios = <BenchmarkScenario>[
  BenchmarkScenario(
    brace: '{}',
    sprintf: '%d',
    cases: [
      ([0], '0'),
      ([9223372036854775807], '9223372036854775807'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:d}',
    sprintf: '%d',
    cases: [
      ([9223372036854775807], '9223372036854775807'),
      ([-12345], '-12345'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:10d}',
    sprintf: '%10d',
    cases: [
      ([1], '         1'),
      ([9223372036854775807], '9223372036854775807'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:010d}',
    sprintf: '%010d',
    cases: [
      ([1], '0000000001'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:+d}',
    sprintf: '%+d',
    cases: [
      ([42], '+42'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:x}',
    sprintf: '%x',
    cases: [
      ([3735928559], 'deadbeef'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:X}',
    sprintf: '%X',
    cases: [
      ([3735928559], 'DEADBEEF'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:#x}',
    sprintf: '%#x',
    cases: [
      ([255], '0xff'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:o}',
    sprintf: '%o',
    cases: [
      ([493], '755'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:b}',
    sprintf: null,
    cases: [
      ([170], '10101010'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:,d}',
    sprintf: null,
    cases: [
      ([1234567], '1,234,567'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:c}',
    sprintf: '%c',
    cases: [
      ([65], 'A'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:.2f}',
    sprintf: '%.2f',
    cases: [
      ([0.1], '0.10'),
      ([12345678901234.56789], '12345678901234.57'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:f}',
    sprintf: '%f',
    cases: [
      ([3.141592653589793], '3.141593'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:e}',
    sprintf: '%e',
    cases: [
      ([12345.6789], '1.234568e+04'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:g}',
    sprintf: '%g',
    cases: [
      ([0.00012345], '0.00012345'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:.3g}',
    sprintf: '%.3g',
    cases: [
      ([1234.5678], '1.23e+03'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:%}',
    sprintf: null,
    cases: [
      ([0.756], '75.600000%'),
    ],
  ),
  BenchmarkScenario(
    brace: '{}',
    sprintf: '%s',
    cases: [
      (['hello world'], 'hello world'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:s}',
    sprintf: '%s',
    cases: [
      (['hello world'], 'hello world'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:>10s}',
    sprintf: '%10s',
    cases: [
      (['dart'], '      dart'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:<10s}',
    sprintf: '%-10s',
    cases: [
      (['dart'], 'dart      '),
    ],
  ),
  BenchmarkScenario(
    brace: '{:^10s}',
    sprintf: null,
    cases: [
      (['dart'], '   dart   '),
    ],
  ),
  BenchmarkScenario(
    brace: '{:*^10s}',
    sprintf: null,
    cases: [
      (['dart'], '***dart***'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:é^10s}',
    sprintf: null,
    cases: [
      (['dart'], 'ééédartééé'),
    ],
  ),
  BenchmarkScenario(
    brace: '{:d} ' * 10,
    sprintf: '%d ' * 10,
    cases: [
      (
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        '1 2 3 4 5 6 7 8 9 10 ',
      ),
    ],
  ),
];
```

(`testData` и `ListMultiplyExt` удалены.)

- [ ] **Step 5: Реализация — isLegacy и пропуски**

`example/lib/src/my_benchmark_base.dart` — в `MyBenchmarkBase` после `bool get isSprintf;` добавить:

```dart
  bool get isLegacy => false;
```

`example/lib/src/benchmark_format2_format.dart` — в класс добавить:

```dart
  @override
  bool get isLegacy => true;
```

`example/lib/src/comparison_benchmark.dart` — заменить тело внешнего цикла (`for (final template in testData) { ... }`) на:

```dart
  for (final scenario in benchmarkScenarios) {
    emit('');
    emit(h1('----------------------------------------'));
    emit('Format template: ${h1(scenario.brace ?? '—')}');
    emit('Sprintf template: ${h1(scenario.sprintf ?? '—')}');

    for (final (values, expected) in scenario.cases) {
      emit('');
      emit('Values: ${h2(values.join(', '))}');

      for (final benchmark in benchmarks) {
        final template =
            benchmark.isSprintf ? scenario.sprintf : scenario.brace;
        if (template == null ||
            (benchmark.isLegacy && scenario.skipLegacy)) {
          emit('${accent(benchmark.name)}: —');
          continue;
        }
        try {
          final score = benchmark.go(template, values);

          String message;
          if (benchmark.output == expected) {
            message = ok('OK');
          } else {
            final difference = _diff(expected, benchmark.output);
            message =
                '${accentError('ERROR')}'
                '\n  expected: ${difference.$1}'
                '\n  actual:   ${difference.$2}';
          }
          emit(
            '${accent(benchmark.name)}:'
            ' ${format('{:.3f}', score)} µs'
            ' <- $message',
          );
        } on Object catch (errorValue) {
          emit(
            '${accent(benchmark.name)}:'
            ' <- ${accentError('ERROR')}'
            '\n${error(errorValue.toString())}',
          );
        }
      }
    }
  }
```

- [ ] **Step 6: Убедиться, что тесты проходят**

Run: `dart test test/restored_benchmark_test.dart && dart analyze .`
Expected: PASS (в т.ч. `isNot(contains('ERROR'))` — если падает, вернуться к решениям Step 1: значение/`sprintf: null`/`skipLegacy`); analyzer чист.

- [ ] **Step 7: Commit**

```bash
git add lib/src/tests/tests.dart lib/src/comparison_benchmark.dart lib/src/my_benchmark_base.dart lib/src/benchmark_format2_format.dart test/restored_benchmark_test.dart
git commit -m "bench: cover builtin types and alignment scenarios

<решения по оракулу: какие значения заменены, где sprintf обнулён,
где skipLegacy>

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Документация и полная проверка

**Files:**
- Modify: `example/README.md`

**Interfaces:**
- Consumes: `dart run bin/benchmark.dart [--full]` из Tasks 1–4.
- Produces: ничего нового — финальная верификация.

- [ ] **Step 1: Обновить README**

В `example/README.md` заменить блок про `bin/benchmark.dart`:

```markdown
Run the restored original user benchmark (quick mode, ~35 s):

```console
dart run bin/benchmark.dart
```

Precise measurements with the benchmark_harness defaults (~4 min):

```console
dart run bin/benchmark.dart --full
```
```

- [ ] **Step 2: Полные тесты example**

Run: `dart test`
Expected: все тесты example проходят.

- [ ] **Step 3: Корневые тесты и analyzer**

Run (из корня репозитория): `dart test && dart analyze lib test example`
Expected: корневые тесты зелёные; analyzer — без новых замечаний (3 pre-existing info в `test/benchmark_scenarios_test.dart` допустимы).

- [ ] **Step 4: Реальный quick-прогон**

Run (из `example/`): `dart run bin/benchmark.dart 2>&1 | tail -2`
Expected: `Mode: quick. Total: NN.N s`, где NN.N в диапазоне ~25–45; в полном выводе нет ERROR (проверить `... | grep -c ERROR` → 0).

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "bench: document quick and full benchmark modes

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
