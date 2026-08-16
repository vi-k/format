# План оптимизации больших десятичных целых чисел

> **Состояние на 2026-08-16:** исполнен, вошло в 3.0.0. Чекбоксы в теле не
> проставлялись — открытым пунктом их читать нельзя.
> **Что это:** план ускорения больших десятичных целых.
> **Связанные записи:**
> `2026-08-02[3]-large-decimal-integer-performance-design.md`.

> **Для agentic workers:** ОБЯЗАТЕЛЬНЫЙ SUB-SKILL: выполнять план через `superpowers:subagent-driven-development` (рекомендуется) или `superpowers:executing-plans`. Шаги используют checkbox (`- [ ]`) для отслеживания выполнения.

**Цель:** Устранить подтверждённое 2,7–3,8-кратное замедление Format 3 на больших десятичных `int` без изменения результата и публичного API.

**Архитектура:** Существующая benchmark-матрица получает отдельный ключевой large-decimal сценарий с frozen Format 2 baseline. Сначала radix 10 переводится с `BigInt.toRadixString(10)` на `BigInt.toString()`; прямой `int` fast path добавляется отдельным условным task только если минимальное изменение не проходит существующий key gate 1,05.

**Технологии:** Dart 3.12.2, `package:test`, существующие `benchmark/runner.dart` и frozen Format 2 baseline.

## Общие ограничения

- Все shell-команды начинаются с `rtk`, все изменения файлов выполняются через `apply_patch`.
- Не менять публичный API и parser.
- Не менять пользовательские незакоммиченные `.vscode/launch.json`, `.vscode/c_cpp_properties.json`, `.vscode/settings.json`.
- Task 0 завершает явно включённый пользователем rename `FormatBenchmark` → `Format3Benchmark`; после его коммита остальные tasks не меняют `example/`.
- Timing-порог не добавляется в обычный unit-test suite; performance RED/GREEN фиксируется существующим benchmark harness.
- Недесятичные пути `b`, `o`, `x`, `X` сохраняют `toRadixString(radix)`.
- Benchmark-матрица использует JS-safe `9007199254740991`; VM correctness-тесты отдельно покрывают полные 64-битные границы.
- Каждый кодовый task проходит RED → GREEN и заканчивается отдельным коммитом.

---

### Task 0: Завершить rename benchmark-класса Format 3

**Files:**
- Modify: `example/bin/benchmark.dart`
- Modify: `example/lib/benchmark.dart`
- Delete: `example/lib/src/format_benchmark.dart`
- Create: `example/lib/src/format3_benchmark.dart`
- Modify: `example/test/restored_benchmark_test.dart`

**Interfaces:**
- Produces: экспортируемый `Format3Benchmark` с прежним benchmark-поведением и именем `format::format`.
- Consumes: существующие пользовательские rename-правки и `MyBenchmarkBase`.

- [ ] **Step 1: Подтвердить существующий RED**

```bash
rtk dart test test/restored_benchmark_test.dart
rtk dart analyze
```

Run from `example/`. Expected: compile/analyzer errors — barrel экспортирует
удалённый `src/format_benchmark.dart`, поэтому `Format3Benchmark` не виден
driver и тесту.

- [ ] **Step 2: Завершить barrel rename минимальной правкой**

В `example/lib/benchmark.dart` заменить:

```dart
export 'src/format_benchmark.dart';
```

на:

```dart
export 'src/format3_benchmark.dart';
```

Не менять тело пользовательского `Format3Benchmark` и порядок движков в
driver.

- [ ] **Step 3: Подтвердить GREEN**

```bash
rtk dart test test/restored_benchmark_test.dart
rtk dart analyze
```

Run from `example/`. Expected: 2 restored tests PASS вместе с gate tests;
analyzer — `No issues found!`.

- [ ] **Step 4: Проверить rename scope**

```bash
rtk git diff --check
rtk git status --short
```

Expected: rename включает только пять перечисленных example-файлов;
`.vscode/` остаётся незатронутым.

- [ ] **Step 5: Commit**

```bash
rtk git add example/bin/benchmark.dart example/lib/benchmark.dart example/lib/src/format_benchmark.dart example/lib/src/format3_benchmark.dart example/test/restored_benchmark_test.dart
rtk git commit -m "refactor: name the Format 3 benchmark explicitly"
```

---

### Task 1: Добавить воспроизводимый large-decimal benchmark

**Files:**
- Modify: `test/benchmark_scenarios_test.dart`
- Modify: `benchmark/scenarios.dart`

**Interfaces:**
- Produces: scenario `brace.int.large_decimal.hot` с key gate 1,05.
- Consumes: `_braceComparable(...)`, `legacyFormat(...)`, `BenchmarkScenario`.

- [ ] **Step 1: Написать RED-тест наличия ключевого сценария**

В список обязательных идентификаторов теста `benchmark matrix covers every required dimension` добавить:

```dart
'brace.int.large_decimal.hot',
```

Затем добавить отдельную проверку контракта:

```dart
test('large decimal integer is a key Format 2 comparison', () {
  final scenario = benchmarkScenarios.singleWhere(
    (value) => value.id == 'brace.int.large_decimal.hot',
  );

  expect(scenario.keyScenario, isTrue);
  expect(scenario.comparisonKind, BenchmarkComparisonKind.performance);
  expect(
    scenario.expected,
    isA<TextOutcome>().having(
      (outcome) => outcome.value,
      'value',
      '9007199254740991',
    ),
  );
  expect(outcomesEqual(scenario.candidate(0), scenario.expected), isTrue);
  expect(outcomesEqual(scenario.baseline!(0), scenario.expected), isTrue);
});
```

- [ ] **Step 2: Подтвердить RED**

```bash
rtk dart test test/benchmark_scenarios_test.dart --name "large decimal integer"
```

Expected: FAIL из-за отсутствия `brace.int.large_decimal.hot`.

- [ ] **Step 3: Добавить минимальный benchmark-сценарий**

Сразу после `brace.int.default` в `benchmark/scenarios.dart` добавить:

```dart
_braceComparable(
  'brace.int.large_decimal',
  template: '{:d}',
  values: const [9007199254740991],
  expected: '9007199254740991',
  key: true,
),
```

- [ ] **Step 4: Подтвердить GREEN контракта**

```bash
rtk dart test test/benchmark_scenarios_test.dart --name "large decimal integer"
```

Expected: PASS.

- [ ] **Step 5: Зафиксировать performance RED**

```bash
rtk dart run benchmark/runner.dart --dialect=braces --phase=hot --run=1 --samples=1 --smoke --output=/private/tmp/large-int-before.json
rtk jq '.scenarios[] | select(.scenarioId == "brace.int.large_decimal.hot") | {candidateMedianNanoseconds, baselineMedianNanoseconds, ratio}' /private/tmp/large-int-before.json
```

Expected: output корректен, ratio существенно выше key threshold `1.05`.

- [ ] **Step 6: Commit**

```bash
rtk git add benchmark/scenarios.dart test/benchmark_scenarios_test.dart
rtk git commit -m "test: benchmark large decimal integers"
```

---

### Task 2: Ускорить десятичный BigInt magnitude path

**Files:**
- Modify: `test/integer_format_test.dart`
- Modify: `lib/src/number_format.dart`

**Interfaces:**
- Produces: `formatMagnitude(BigInt magnitude, int radix, {bool uppercase = false})` с отдельным radix-10 путём.
- Consumes: существующие brace/printf integer formatters.

- [ ] **Step 1: Добавить characterization-тест крайних десятичных значений**

В `test/integer_format_test.dart` добавить:

```dart
test('preserves decimal int boundaries and out-of-range BigInt values', () {
  final aboveInt = BigInt.parse('9223372036854775808');
  final belowInt = BigInt.parse('-9223372036854775809');

  expect(format('{:d}', 9223372036854775807), '9223372036854775807');
  expect(format('{:d}', -9223372036854775808), '-9223372036854775808');
  expect(format('{:d}', aboveInt), '9223372036854775808');
  expect(format('{:d}', belowInt), '-9223372036854775809');
  expect(format('{:+,d}', 9223372036854775807), '+9,223,372,036,854,775,807');
});
```

- [ ] **Step 2: Подтвердить characterization GREEN и сохранить performance RED**

```bash
rtk dart test test/integer_format_test.dart --name "preserves decimal int boundaries"
rtk jq -e '.scenarios[] | select(.scenarioId == "brace.int.large_decimal.hot" and .ratio > 1.05)' /private/tmp/large-int-before.json
```

Expected: correctness PASS; jq exit 0 подтверждает отдельный performance RED.

- [ ] **Step 3: Реализовать минимальный radix-10 fast path**

Заменить тело `formatMagnitude`:

```dart
String formatMagnitude(BigInt magnitude, int radix, {bool uppercase = false}) {
  final digits =
      radix == 10 ? magnitude.toString() : magnitude.toRadixString(radix);
  return uppercase ? digits.toUpperCase() : digits;
}
```

- [ ] **Step 4: Подтвердить correctness GREEN**

```bash
rtk dart test test/integer_format_test.dart test/sprintf_api_test.dart
rtk dart analyze
```

Expected: tests PASS; analyzer без новых ошибок и предупреждений.

- [ ] **Step 5: Измерить performance GREEN дважды**

```bash
rtk dart run benchmark/runner.dart --dialect=braces --phase=hot --run=1 --samples=1 --smoke --output=/private/tmp/large-int-after-1.json
rtk dart run benchmark/runner.dart --dialect=braces --phase=hot --run=2 --samples=1 --smoke --output=/private/tmp/large-int-after-2.json
rtk jq '.scenarios[] | select(.scenarioId == "brace.int.large_decimal.hot") | {candidateMedianNanoseconds, baselineMedianNanoseconds, ratio}' /private/tmp/large-int-after-1.json /private/tmp/large-int-after-2.json
```

Decision: если оба ratio `<= 1.05`, Task 3 пропустить. Если хотя бы один ratio `> 1.05`, выполнить Task 3.

- [ ] **Step 6: Commit**

```bash
rtk git add lib/src/number_format.dart test/integer_format_test.dart
rtk git commit -m "perf: optimize decimal magnitude formatting"
```

---

### Task 3: Добавить прямой int fast path, только если требуется gate

**Files:**
- Modify: `lib/src/number_format.dart`
- Test: `test/integer_format_test.dart`

**Interfaces:**
- Produces: прямое форматирование `int` без промежуточного `BigInt`; `BigInt` сохраняет Task 2 path.
- Consumes: `_FormatSpec`, `applyNumericWidth`, существующую integer validation/layout логику.

- [ ] **Step 1: Подтвердить условный RED**

```bash
rtk jq -s -e '[.[].scenarios[] | select(.scenarioId == "brace.int.large_decimal.hot" and .ratio > 1.05)] | length > 0' /private/tmp/large-int-after-1.json /private/tmp/large-int-after-2.json
```

Expected: exit 0 хотя бы для одного after-report. Если команда не находит ratio, Task 3 не выполняется.

- [ ] **Step 2: Сохранить исходный тип до вычисления digits**

В `formatBraceInteger` удалить безусловный `int() => BigInt.from(value)`.
После вычисления `type` и `radix` получить знак и digits через исходный тип так,
чтобы отрицательный `int`, включая `-9223372036854775808`, не требовал
арифметического `-value`:

```dart
final negative = switch (value) {
  int() => value.isNegative,
  BigInt() => value.isNegative,
  _ => throw UnsupportedFormatValueException(context, value),
};

final digits = switch (value) {
  int() => _formatIntMagnitude(value, radix, uppercase: type == 'X'),
  BigInt() => formatMagnitude(
    value.isNegative ? -value : value,
    radix,
    uppercase: type == 'X',
  ),
  _ => throw UnsupportedFormatValueException(context, value),
};
```

Добавить рядом с `formatMagnitude`:

```dart
String _formatIntMagnitude(int value, int radix, {bool uppercase = false}) {
  final raw = radix == 10 ? value.toString() : value.toRadixString(radix);
  final digits = value.isNegative ? raw.substring(1) : raw;
  return uppercase ? digits.toUpperCase() : digits;
}
```

Остальные sign/prefix/grouping/width ветви не менять.

- [ ] **Step 3: Проверить все integer bases и границы**

```bash
rtk dart test test/integer_format_test.dart
rtk dart test test/printf_parser_test.dart test/sprintf_api_test.dart
rtk dart analyze lib/src/number_format.dart
```

Expected: все tests PASS; analyzer без новых ошибок и предупреждений.

- [ ] **Step 4: Выполнить smoke только как диагностический sanity-check**

```bash
rtk dart run benchmark/runner.dart --dialect=braces --phase=hot --run=1 --samples=1 --smoke --output=/private/tmp/large-int-direct-1.json
rtk dart run benchmark/runner.dart --dialect=braces --phase=hot --run=2 --samples=1 --smoke --output=/private/tmp/large-int-direct-2.json
rtk jq '.scenarios[] | select(.scenarioId == "brace.int.large_decimal.hot") | {candidateMedianNanoseconds, baselineMedianNanoseconds, ratio}' /private/tmp/large-int-direct-1.json /private/tmp/large-int-direct-2.json
```

Expected: оба сценария корректны. Smoke выполняет одну операцию на round и не
используется для threshold-решения: при наносекундных операциях его ratio
доминируется overhead harness.

- [ ] **Step 5: Commit**

```bash
rtk git add lib/src/number_format.dart
rtk git commit -m "perf: avoid BigInt conversion for decimal int"
```

- [ ] **Step 6: Подтвердить gate двумя non-smoke JIT-прогонами**

Получить новый commit revision:

```bash
rtk git rev-parse HEAD
```

Подставить его вместо `<40hex>`:

```bash
rtk dart run -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart --runtime=jit --dialect=braces --phase=hot --run=1 --output=/private/tmp/large-int-direct-gate-1.json
rtk dart run -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart --runtime=jit --dialect=braces --phase=hot --run=2 --output=/private/tmp/large-int-direct-gate-2.json
rtk jq -s -e '[.[].scenarios[] | select(.scenarioId == "brace.int.large_decimal.hot") | .ratio] | length == 2 and all(.[]; . <= 1.05)' /private/tmp/large-int-direct-gate-1.json /private/tmp/large-int-direct-gate-2.json
```

Expected: два gateable 7-round/100-operation отчёта с matching provenance;
jq exit 0. Если gate не проходит, не добавлять новую оптимизацию в этот task —
вернуть `BLOCKED` с абсолютными медианами и ratio.

---

### Task 4: Финальная проверка производительности и области изменений

**Files:**
- Verify: `lib/src/number_format.dart`, `benchmark/scenarios.dart`, tests и пользовательские незакоммиченные файлы.

**Interfaces:**
- Consumes: результаты Tasks 1–3.
- Produces: проверенный performance fix без API/correctness regressions.

- [ ] **Step 1: Полная correctness-проверка**

```bash
rtk dart analyze
rtk dart test
rtk git diff --check
```

Expected: analyzer exit 0 без новых warning/error; 303+ tests PASS; diff-check clean.

- [ ] **Step 2: JIT и AOT large-decimal измерения**

Получить commit revision после кодовых коммитов:

```bash
rtk git rev-parse HEAD
```

Подставить его вместо `<40hex>`:

```bash
rtk dart run -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart --runtime=jit --dialect=braces --phase=hot --run=1 --output=/private/tmp/large-int-jit-1.json
rtk dart run -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart --runtime=jit --dialect=braces --phase=hot --run=2 --output=/private/tmp/large-int-jit-2.json
rtk dart compile exe -Dformat.benchmark.sourceRevision=<40hex> benchmark/runner.dart -o /private/tmp/format3-large-int-aot
rtk /private/tmp/format3-large-int-aot --runtime=aot --dialect=braces --phase=hot --run=1 --output=/private/tmp/large-int-aot-1.json
rtk /private/tmp/format3-large-int-aot --runtime=aot --dialect=braces --phase=hot --run=2 --output=/private/tmp/large-int-aot-2.json
```

Извлечь четыре результата:

```bash
rtk jq '.scenarios[] | select(.scenarioId == "brace.int.large_decimal.hot") | {runtime: input_filename, candidateMedianNanoseconds, baselineMedianNanoseconds, ratio}' /private/tmp/large-int-jit-1.json /private/tmp/large-int-jit-2.json /private/tmp/large-int-aot-1.json /private/tmp/large-int-aot-2.json
```

Expected: output совпадает с expected; улучшение воспроизводится в обоих JIT и обоих AOT отчётах. Если абсолютный key threshold зависит от общего overhead harness, отдельно сообщить четыре ratio без сокрытия результата.

- [ ] **Step 3: JS correctness/smoke и production isolation**

```bash
rtk dart compile js -O4 -Dformat.benchmark.dartCompilerVersion=3.12.2 benchmark/runner.dart -o /private/tmp/format3-large-int.js
rtk node /private/tmp/format3-large-int.js --runtime=js --dialect=printf --phase=hot --run=1 --samples=1 --smoke --output=/private/tmp/large-int-js-smoke.json
rtk jq -e 'type == "object" and .runtime == "js" and .smoke == true' /private/tmp/large-int-js-smoke.json
rtk rg -n "legacyFormat|sprintf7|format2" lib --glob '*.dart'
```

Expected: JS compile/run в поддерживаемой printf-конфигурации exit 0; production
`lib/` не импортирует benchmark baselines. Large-int performance сравнивается
в JIT/AOT, где `int` сохраняет требуемый 64-битный диапазон.

- [ ] **Step 4: Проверить пользовательские изменения и запросить независимое ревью**

```bash
rtk git status --short
rtk git diff -- example .vscode
rtk git log -5 --oneline
```

Expected: пользовательские незакоммиченные rename/VS Code изменения сохранены и не включены в performance-коммиты. Review отдельно проверяет large-int semantics, benchmark fairness, JIT/AOT/JS evidence и отсутствие production API изменений.
