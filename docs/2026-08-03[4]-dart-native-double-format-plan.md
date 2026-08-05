# Dart-native Double Formatting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Сделать Dart SDK нормативным профилем форматирования `double` по умолчанию, сохранив быстрый Python/C++-совместимый профиль и добавив наглядный пользовательский benchmark обоих режимов.

**Architecture:** Парсеры и общий numeric layout остаются едиными. `Format` выбирает генератор ASCII-тела: новый Dart SDK path делегирует `double.toString*`, а compatible path сохраняет текущие `_formatFixed`, `_formatScientific`, `_formatGeneral`, `Binary64` и fast path. Настройка специальных значений применяется поверх выбранного профиля; `!r`/`!a` используют тот же профиль для вложенных `double`.

**Tech Stack:** Dart SDK 3.12.2, package:test, benchmark_harness, ansi_escape_codes, существующий JIT/AOT/JavaScript benchmark harness.

## Global Constraints

- Mini-language `{...}` и `%...` не меняется.
- Публичные имена: `DoubleFormatMode.dartSdk`, `DoubleFormatMode.compatible`, `DoubleSpecialValueSpelling.dartSdk`, `DoubleSpecialValueSpelling.short`.
- `Format()` и top-level API по умолчанию используют Dart SDK.
- Compatible-профиль сохраняет текущий числовой результат и optimized fixed fast path.
- Dart `f`, `e`, `%` принимают precision `0…20`; Dart `g`, `n` принимают `1…21`.
- В Dart-профиле `f` и `%` без precision используют `6`, `e` без precision вызывает `toStringAsExponential()`, `g`/`n` без precision используют `toString()`.
- Compatible-профиль всегда использует короткую основу `nan`/`inf`; uppercase-типы дают `NAN`/`INF`.
- Пустые `Map` и `Set` в `!r` всегда выводятся одинаково: `{}`.
- Спеки и пользовательский текст пишутся по-русски.
- Замороженные исходники benchmark baseline не изменяются.

---

## File Structure

- Create `lib/src/double_format.dart`: публичные enum профиля и специальных значений.
- Create `lib/src/dart_double_format.dart`: приватная генерация ASCII-тела через Dart SDK и профильная валидация precision.
- Modify `lib/format.dart`, `lib/src/engine.dart`, `lib/src/format.dart`: экспорт и конфигурация `Format`.
- Modify `lib/src/number_format.dart`, `lib/src/printf_formatter.dart`: выбор профиля, special spelling и общий layout.
- Modify `lib/src/representation.dart`: профильное представление вложенного `double` и `{}` для пустого `Set`.
- Create `test/dart_double_format_test.dart`: нормативная матрица Dart SDK обоих диалектов.
- Modify `test/double_format_test.dart`, `test/sprintf_double_test.dart`, compatibility fixture tests: явный compatible-профиль.
- Modify `benchmark/scenarios.dart`, benchmark tests: отдельные Dart/compatible scenario id и сохранение compatible gates.
- Create `example/lib/src/float_modes_benchmark.dart` and `example/bin/float_modes_benchmark.dart`: цветной пользовательский benchmark.
- Modify `example/lib/benchmark.dart`, example tests, `.vscode/launch.json`: экспорт, smoke-test и launch entry.
- Modify `README.md`, `CHANGELOG.md`, `pubspec.yaml`, package/example docs: новый default и миграция.

---

### Task 1: Публичная конфигурация профиля

**Files:**
- Create: `lib/src/double_format.dart`
- Modify: `lib/format.dart`
- Modify: `lib/src/engine.dart`
- Modify: `lib/src/format.dart`
- Test: `test/api_test.dart`

**Interfaces:**
- Produces: `enum DoubleFormatMode { dartSdk, compatible }`.
- Produces: `enum DoubleSpecialValueSpelling { dartSdk, short }`.
- Produces: `Format.doubleFormatMode` and `Format.doubleSpecialValueSpelling`.

- [ ] **Step 1: Написать падающий API-тест**

Добавить в `test/api_test.dart`:

```dart
test('Format exposes immutable double formatting profiles', () {
  final defaults = Format();
  final compatible = Format(
    doubleFormatMode: DoubleFormatMode.compatible,
    doubleSpecialValueSpelling: DoubleSpecialValueSpelling.short,
  );

  expect(defaults.doubleFormatMode, DoubleFormatMode.dartSdk);
  expect(
    defaults.doubleSpecialValueSpelling,
    DoubleSpecialValueSpelling.dartSdk,
  );
  expect(compatible.doubleFormatMode, DoubleFormatMode.compatible);
  expect(
    compatible.doubleSpecialValueSpelling,
    DoubleSpecialValueSpelling.short,
  );
});
```

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/api_test.dart`

Expected: compile failure because the enums and constructor parameters do not exist.

- [ ] **Step 3: Добавить минимальный публичный API**

Создать `lib/src/double_format.dart` с двумя enum, импортировать его в
`engine.dart`, экспортировать из `lib/format.dart`, добавить final-поля и
default-значения в `Format`:

```dart
final DoubleFormatMode doubleFormatMode;
final DoubleSpecialValueSpelling doubleSpecialValueSpelling;

Format({
  // existing parameters
  this.doubleFormatMode = DoubleFormatMode.dartSdk,
  this.doubleSpecialValueSpelling = DoubleSpecialValueSpelling.dartSdk,
});
```

- [ ] **Step 4: Подтвердить GREEN и анализ API**

Run: `rtk dart test test/api_test.dart`

Run: `rtk dart analyze lib test/api_test.dart`

Expected: PASS; no analyzer errors.

- [ ] **Step 5: Commit**

```bash
rtk git add lib/src/double_format.dart lib/format.dart lib/src/engine.dart lib/src/format.dart test/api_test.dart
rtk git commit -m "feat: add double formatting profiles"
```

---

### Task 2: Dart SDK brace-форматирование

**Files:**
- Create: `lib/src/dart_double_format.dart`
- Modify: `lib/src/engine.dart`
- Modify: `lib/src/number_format.dart`
- Create: `test/dart_double_format_test.dart`
- Modify: `test/double_format_test.dart`

**Interfaces:**
- Consumes: `Format.doubleFormatMode`, `Format.doubleSpecialValueSpelling`.
- Produces: `_formatDartDouble(double value, String? type, int? precision, bool alternate, FormatExceptionContext context) -> _AsciiFloat`.
- Produces: `_formatSpecialDouble(double value, bool uppercase, Format settings) -> _AsciiFloat`.

- [ ] **Step 1: Написать Dart SDK regression matrix**

Создать `test/dart_double_format_test.dart` с публичными ожиданиями:

```dart
test('default brace formatting delegates digits to Dart SDK', () {
  expect(format('{}', 1e-7), (1e-7).toString());
  expect(format('{:.0f}', 2.5), (2.5).toStringAsFixed(0));
  expect(format('{:.2f}', 1e21), (1e21).toStringAsFixed(2));
  expect(format('{:e}', 1.0), 1.0.toStringAsExponential());
  expect(format('{:.2e}', 12.5), 12.5.toStringAsExponential(2));
  expect(format('{:g}', 1.0), 1.0.toString());
  expect(format('{:.3g}', 1.0), 1.0.toStringAsPrecision(3));
  expect(format('{:.1%}', 0.125), '12.5%');
});

test('compatible brace formatting preserves exact half-even', () {
  final compatible = Format(
    doubleFormatMode: DoubleFormatMode.compatible,
  );
  expect(compatible.format('{:.0f}', 2.5), '2');
  expect(compatible.format('{:e}', 1.0), '1.000000e+00');
  expect(compatible.format('{:.3g}', 1.0), '1');
  expect(compatible.format('{:.21f}', 0.1), '0.100000000000000005551');
});
```

Добавить проверки `-0.0`, `z`, `#`, `F/E/G`, `n`, grouping и `1e21`.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/dart_double_format_test.dart`

Expected: current default returns compatible results, so half-tie and exponent assertions fail.

- [ ] **Step 3: Реализовать SDK body generator**

Добавить part `dart_double_format.dart`. Для finite `value.abs()` выбрать:

```dart
final body = switch (type) {
  'f' || 'F' => magnitude.toStringAsFixed(precision ?? 6),
  'e' || 'E' => precision == null
      ? magnitude.toStringAsExponential()
      : magnitude.toStringAsExponential(precision),
  'g' || 'G' || 'n' || null => precision == null
      ? magnitude.toString()
      : magnitude.toStringAsPrecision(precision),
  '%' => magnitude.toStringAsFixed(precision ?? 6),
  _ => throw StateError('Unsupported Dart double presentation: $type'),
};
```

До вызова SDK валидировать `0…20` или `1…21` через `_invalidSpecifier`.
Uppercase менять только у exponent marker. `#` при precision `0` добавляет
точку перед exponent. `roundedZero` определять по числовому mantissa тела.

- [ ] **Step 4: Включить profile dispatch в brace path**

В `formatBraceDouble` оставить общий conversion/sign/layout, а body выбирать:

```dart
formatted = settings.doubleFormatMode == DoubleFormatMode.dartSdk
    ? _formatDartDouble(
        formattingValue,
        type,
        spec.precision,
        spec.alternate,
        context,
      )
    : _formatCompatibleBraceDouble(...);
```

Не менять `_formatFixedFast` и не создавать `Binary64` в Dart-ветви.

- [ ] **Step 5: Перевести существующие exact-тесты на compatible**

В `test/double_format_test.dart` создать один настроенный `Format` и заменить
вызовы, нормативно сравнивающие Python spelling/rounding, на его методы.
Общие layout/error тесты оставить на default только там, где результат не
зависит от профиля.

- [ ] **Step 6: Подтвердить GREEN**

Run: `rtk dart test test/dart_double_format_test.dart test/double_format_test.dart`

Expected: PASS for Dart oracle and compatible legacy matrix.

- [ ] **Step 7: Commit**

```bash
rtk git add lib/src/dart_double_format.dart lib/src/engine.dart lib/src/number_format.dart test/dart_double_format_test.dart test/double_format_test.dart
rtk git commit -m "feat: format brace doubles with Dart SDK"
```

---

### Task 3: Dart SDK `sprintf` и special spelling

**Files:**
- Modify: `lib/src/dart_double_format.dart`
- Modify: `lib/src/printf_formatter.dart`
- Modify: `test/dart_double_format_test.dart`
- Modify: `test/sprintf_double_test.dart`

**Interfaces:**
- Consumes: `_formatDartDouble` and `_formatSpecialDouble` from Task 2.
- Produces: identical mode selection for `%f`, `%e`, `%g`; finite `%a` remains the existing hexadecimal algorithm.

- [ ] **Step 1: Добавить падающие printf/special tests**

Добавить:

```dart
test('default sprintf uses Dart SDK decimal conversions', () {
  expect(sprintf('%.0f', 2.5), '3');
  expect(sprintf('%e', 1.0), '1e+0');
  expect(sprintf('%.3g', 1.0), '1.00');
});

test('special value spelling is orthogonal in Dart mode', () {
  final short = Format(
    doubleSpecialValueSpelling: DoubleSpecialValueSpelling.short,
  );
  final compatible = Format(
    doubleFormatMode: DoubleFormatMode.compatible,
  );

  expect(format('{}', double.nan), 'NaN');
  expect(format('{}', double.infinity), 'Infinity');
  expect(short.format('{}', double.nan), 'nan');
  expect(short.sprintf('%F', double.infinity), 'INF');
  expect(compatible.format('{}', double.infinity), 'inf');
  expect(compatible.sprintf('%G', double.nan), 'NAN');
});
```

Проверить также отрицательную бесконечность, `E/G`, `!r` позднее отдельно.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/dart_double_format_test.dart test/sprintf_double_test.dart`

Expected: default printf and long special spellings fail.

- [ ] **Step 3: Подключить Dart path к `_formatPrintfDouble`**

Для decimal типов использовать `_formatDartDouble` при `dartSdk`; для
compatible оставить текущие вызовы. `%a/%A` сохраняет текущий finite algorithm,
но special word получает через общий `_formatSpecialDouble`.

- [ ] **Step 4: Защитить precision типизированными ошибками**

Добавить тесты `.21f`, `.21e`, `.0g`, `.22g` для обоих диалектов. Проверить
`InvalidSpecifierException`, template, fragment и specifier. Не ловить
`RangeError` постфактум: validation выполняется до SDK.

- [ ] **Step 5: Перевести текущие C++ unit tests на compatible**

В `test/sprintf_double_test.dart` использовать configured `Format` для
round-half-even, exponent padding, extended precision и old special spelling.

- [ ] **Step 6: Запустить GREEN**

Run: `rtk dart test test/dart_double_format_test.dart test/sprintf_double_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
rtk git add lib/src/dart_double_format.dart lib/src/printf_formatter.dart test/dart_double_format_test.dart test/sprintf_double_test.dart
rtk git commit -m "feat: apply double profiles to sprintf"
```

---

### Task 4: `!r`, `!a` и пустой `Set`

**Files:**
- Modify: `lib/src/representation.dart`
- Modify: `test/conversion_test.dart`

**Interfaces:**
- Consumes: `Format.doubleFormatMode`, effective special spelling.
- Produces: profile-aware representation of every nested `double`; empty `Set` always `{}`.

- [ ] **Step 1: Написать падающие representation tests**

```dart
test('r conversion uses configured double profile recursively', () {
  final compatible = Format(
    doubleFormatMode: DoubleFormatMode.compatible,
  );
  final short = Format(
    doubleSpecialValueSpelling: DoubleSpecialValueSpelling.short,
  );

  expect(format('{!r}', [1e-7, double.infinity]), '[1e-7, Infinity]');
  expect(short.format('{!r}', [double.nan]), '[nan]');
  expect(
    compatible.format('{!r}', [1e-7, double.infinity]),
    '[1e-07, inf]',
  );
});

test('empty maps and sets intentionally share Dart spelling', () {
  expect(format('{!r}', <Object?, Object?>{}), '{}');
  expect(format('{!r}', <Object?>{}), '{}');
});
```

Добавить `!a` с Unicode-строкой и вложенным special double.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/conversion_test.dart`

Expected: default double spelling and empty Set assertions fail.

- [ ] **Step 3: Передать `Format` в double representation**

Заменить прямой `_pythonShortestDouble(value)` на профильный helper:

```dart
case double():
  output.write(_representDouble(value, engine));
```

Finite Dart mode использует `value.toString()`, compatible — текущий
`_pythonShortestDouble`. Special spelling следует эффективной настройке.
В `_writeSet` заменить `set()` на `{}` без профильной ветви.

- [ ] **Step 4: Подтвердить GREEN**

Run: `rtk dart test test/conversion_test.dart`

Expected: PASS, включая recursion и custom Representation tests.

- [ ] **Step 5: Commit**

```bash
rtk git add lib/src/representation.dart test/conversion_test.dart
rtk git commit -m "feat: align representations with double profiles"
```

---

### Task 5: Перевод compatibility fixtures и locale integration

**Files:**
- Modify: `test/python_compatibility_test.dart`
- Modify: `test/sprintf_compatibility_test.dart`
- Modify: `packages/format_intl/test/format_integration_test.dart`
- Modify: `packages/format_intl/test/intl_number_locale_test.dart`

**Interfaces:**
- Consumes: public profile API.
- Produces: explicit normative separation between Dart default and frozen Python/C++ fixtures.

- [ ] **Step 1: Сделать fixture runners явными**

Создать в каждом compatibility test один экземпляр:

```dart
final compatibleFormat = Format(
  doubleFormatMode: DoubleFormatMode.compatible,
);
```

Brace fixtures вызывают `compatibleFormat.formatWith`, printf fixtures —
`compatibleFormat.vsprintf`. Не менять fixture JSON и frozen generators.

- [ ] **Step 2: Добавить locale matrix обоих профилей**

В `format_intl` создать два `Format` с одним `IntlNumberLocale`, проверить
локализацию Dart body и прежний compatible body для `n`, `%`, exponent и
special values.

- [ ] **Step 3: Запустить targeted suites**

Run: `rtk dart test test/python_compatibility_test.dart test/sprintf_compatibility_test.dart`

Run: `rtk dart test` in `packages/format_intl`.

Expected: all frozen fixtures pass through compatible; locale tests pass.

- [ ] **Step 4: Commit**

```bash
rtk git add test/python_compatibility_test.dart test/sprintf_compatibility_test.dart packages/format_intl/test
rtk git commit -m "test: separate Dart and compatible double contracts"
```

---

### Task 6: Release benchmark matrix двух профилей

**Files:**
- Modify: `benchmark/scenarios.dart`
- Modify: `test/benchmark_scenarios_test.dart`
- Modify: `test/benchmark_gates_test.dart`

**Interfaces:**
- Produces: explicit `brace.double.fixed.dart.hot`, `brace.double.fixed.compatible.hot`, large variants and Dart correctness scenarios.
- Preserves: compatible key threshold `candidate / Format2 <= 1.05`.

- [ ] **Step 1: Написать падающий scenario contract test**

Проверить наличие четырёх fixed scenario id, `keyScenario == true` у двух
compatible вариантов, ожидаемые `3`/`2` для half-tie и явный configured engine.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/benchmark_scenarios_test.dart`

Expected: new scenario ids are absent.

- [ ] **Step 3: Разделить benchmark candidates**

Добавить `_dartBenchmarkFormat = Format()` и `_compatibleBenchmarkFormat`.
Расширить scenario helper параметром `Format engine`. Compatible fixed и
large fixed сравнивать с Format 2 и оставить key. Dart half-tie/e/g/special
сценарии сделать correctness-only либо informational с явным rationale, если
старый baseline не совпадает по контракту.

- [ ] **Step 4: Обновить gate expectations**

Проверить, что compatible key ids присутствуют во всех JIT/AOT отчётах и
порог `1.05` применяется к ним. Dart-only различия не должны сравниваться с
несовместимым baseline.

- [ ] **Step 5: Запустить benchmark tests**

Run: `rtk dart test test/benchmark_scenarios_test.dart test/benchmark_gates_test.dart`

Expected: PASS, включая compiled JavaScript/AOT provenance tests.

- [ ] **Step 6: Commit**

```bash
rtk git add benchmark/scenarios.dart test/benchmark_scenarios_test.dart test/benchmark_gates_test.dart
rtk git commit -m "bench: cover Dart and compatible double modes"
```

---

### Task 7: Цветной пользовательский benchmark

**Files:**
- Create: `example/lib/src/float_modes_benchmark.dart`
- Create: `example/bin/float_modes_benchmark.dart`
- Modify: `example/lib/benchmark.dart`
- Modify: `example/test/restored_benchmark_test.dart`
- Modify: `.vscode/launch.json`

**Interfaces:**
- Produces: `runFloatModesBenchmark()` and executable `bin/float_modes_benchmark.dart`.
- Uses: existing `h1`, `h2`, `accent`, `ok`, `warning`, `error`, `defaultFg`.

- [ ] **Step 1: Написать падающий output test**

В example test вызвать benchmark с малыми test-only round/iteration counts и
инъецированным `StringSink`. Проверить наличие template, value, обоих mode
names, обоих formatted results, `µs/op`, percentage и differing-results note.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/restored_benchmark_test.dart` in `example/`.

Expected: missing import/API compile failure.

- [ ] **Step 3: Реализовать измеритель и матрицу**

Создать immutable scenario с brace/printf templates, value и двумя closures.
Прогреть оба режима, чередовать порядок, собрать нечётное число samples и
печатать median `Stopwatch` nanoseconds / operations. Обновлять checksum длиной
результата и проверять, что timed output совпал с напечатанным result.

- [ ] **Step 4: Применить существующий ANSI UI**

Executable оборачивает запуск:

```dart
ansi.runZonedPrinter(
  defaultStyle: const ansi.Style(foreground: defaultFg),
  runFloatModesBenchmark,
);
```

Не добавлять raw escape sequences. Заголовки, значения, names, winner и
intentional differences оформлять существующими helpers.

- [ ] **Step 5: Настроить VS Code**

Добавить configuration `Benchmark: float modes` с cwd `example` и program
`bin/float_modes_benchmark.dart`. Если compound запуска всех benchmark уже
существует, добавить имя; иначе создать `compounds` с original, Format 2 gate,
release smoke, parser strategy и float modes.

- [ ] **Step 6: Проверить тест и ручной вывод**

Run: `rtk dart test` in `example/`.

Run: `rtk dart run bin/float_modes_benchmark.dart` in `example/`.

Expected: тест PASS; терминал показывает цветные результаты и время всех
brace/printf сценариев.

- [ ] **Step 7: Commit**

```bash
rtk git add example/lib/src/float_modes_benchmark.dart example/bin/float_modes_benchmark.dart example/lib/benchmark.dart example/test/restored_benchmark_test.dart .vscode/launch.json
rtk git commit -m "bench: compare double modes interactively"
```

---

### Task 8: Публичная документация и миграция

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `pubspec.yaml`
- Modify: `example/README.md`
- Modify: `packages/format_intl/README.md`

**Interfaces:**
- Documents: Dart default, compatible opt-in, special spelling, precision limits, empty Map/Set ambiguity and benchmark command.

- [ ] **Step 1: Обновить позиционирование**

Заменить безусловное “Python-compatible formatting” на “Dart formatting with
Python/C-style mini-languages”. Не обещать C++ numeric output для default.

- [ ] **Step 2: Добавить migration examples**

Показать `Format()`, `DoubleFormatMode.compatible`,
`DoubleSpecialValueSpelling.short`, различия `2.5`, `e`, `g`, precision и
специальных значений. Явно написать, что пустые Map/Set дают `{}` в `!r`.

- [ ] **Step 3: Документировать benchmark**

Добавить команду `cd example && dart run bin/float_modes_benchmark.dart` и
описать result/time/ANSI output.

- [ ] **Step 4: Проверить документацию**

Run: `rtk rg -n "Python-compatible|C\+\+23-compatible" README.md CHANGELOG.md pubspec.yaml example packages/format_intl`

Expected: remaining occurrences only describe explicit compatible mode.

- [ ] **Step 5: Commit**

```bash
rtk git add README.md CHANGELOG.md pubspec.yaml example/README.md packages/format_intl/README.md
rtk git commit -m "docs: describe Dart-native double formatting"
```

---

### Task 9: Полная корректность, performance и release verification

**Files:**
- Verify: all modified files
- Verify: `/private/tmp/format-double-*.json`

**Interfaces:**
- Consumes: clean final 40-character Git revision.
- Produces: verified JIT/AOT reports and a release-ready clean worktree.

- [ ] **Step 1: Запустить все тесты и анализаторы**

Run: `rtk dart test` and `rtk dart analyze` in root.

Run: `rtk dart test` and `rtk dart analyze` in `example/`.

Run: `rtk dart test` and `rtk dart analyze` in `packages/format_intl/`.

Expected: all tests PASS; analyzers have no errors.

- [ ] **Step 2: Проверить package archives**

Run: `rtk dart pub publish --dry-run` in root and `packages/format_intl/`.

Expected: zero warnings; the known non-incremental-version hint is allowed.

- [ ] **Step 3: Зафиксировать verification revision**

Commit any final test/doc corrections, require clean `rtk git status --short`,
then capture `rtk git rev-parse HEAD`. Не использовать dirty revision в reports.

- [ ] **Step 4: Снять два JIT compatible reports**

Run `benchmark/runner.dart` twice with exact
`-Dformat.benchmark.sourceRevision=<40hex>`, `--runtime=jit`, brace hot filter,
run 1/2 and separate `/private/tmp/format-double-jit-*.json` outputs.

- [ ] **Step 5: Снять два AOT compatible reports**

Compile one executable with the same revision, then run 1/2 into
`/private/tmp/format-double-aot-*.json`.

- [ ] **Step 6: Проверить provenance и ratios**

Через `jq` проверить для всех четырёх reports:

```text
gateable == true
sourceRevision == final HEAD
operations == 1000
compatible fixed ratio <= 1.05
compatible fixed_large ratio <= 1.05
```

- [ ] **Step 7: Проверить пользовательский benchmark**

Run: `rtk dart run bin/float_modes_benchmark.dart` in `example/`.

Expected: оба режима печатают formatted result и median time; ANSI style
совпадает с original benchmark; compatible ordinary/large fixed не показывает
необъяснимой регрессии.

- [ ] **Step 8: Финальная hygiene-проверка**

Run: `rtk git diff --check`

Run: `rtk git status --short --branch`

Expected: no whitespace errors and clean worktree.

