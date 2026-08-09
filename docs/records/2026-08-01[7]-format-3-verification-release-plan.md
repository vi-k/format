# Format 3 Verification and Release Readiness Implementation Plan

Статус: исполнен, вошло в 3.0.0. Чекбоксы в теле не проставлялись — открытым пунктом их читать нельзя.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Доказать корректность и производительность Format 3 на целевых runtimes, документировать переход с 1.6/2.0 и сделать Linux/macOS проверки обязательными перед release.

**Architecture:** Замороженные baseline implementations исполняются внутри единого benchmark harness, который сначала проверяет равенство результатов, затем создаёт JSON с interleaved samples и применяет утверждённые gates. GitHub Actions независимо воспроизводит C++ fixtures, тесты и измерения на Ubuntu/macOS и сохраняет versioned reports.

**Tech Stack:** Dart SDK `^3.7.2`, Dart JIT/AOT/JavaScript, Node.js `24.8.0`, Python fixtures committed from CPython 3.14, C++23 (`g++`/glibc, `clang++`/libSystem), GitHub Actions `checkout@v6`, `setup-dart@v1`, `setup-node@v6`, `upload-artifact@v7`.

## Global Constraints

- Format 2 baseline — commit `86febb4`; sprintf competitor — package 7.0.0 commit `f1e74f2`; оба доступны только benchmark code.
- Сравниваются только scenarios с одинаковыми inputs и outputs; каждый scenario проверяет output до timing.
- `{...}` gates: geometric mean hot ratio `<=1.02`; every key scenario `<=1.05`; отдельно JIT и AOT; превышение подтверждается двумя runs.
- `%...` gates: cold geometric mean `<=0.90`, hot `<=0.80`, every key scenario `<=1.02`; отдельно JIT, AOT и JavaScript; cache исключён из cold.
- На scenario выполняется не менее 7 interleaved samples; весь suite запускается дважды.
- Cold templates уникальны и создаются до timing; hot templates повторяются.
- Linux workflow использует `ubuntu-24.04`, `g++ -std=c++23`, glibc и `LC_ALL=C`; macOS workflow использует pinned image, `clang++`, libSystem и `LC_ALL=C`.
- Reports сохраняют raw samples, medians, ratios, gate status, Dart/Node/compiler/C library/OS versions и AOT size.
- README содержит самостоятельные migration routes с Format 1.6 и Format 2.0.
- Публикация на pub.dev не выполняется этим планом; только `--dry-run`.
- Перед заявлением о завершении обязательно используется `superpowers:verification-before-completion`, а перед интеграцией — `superpowers:requesting-code-review`.
- Все локальные shell-команды агента запускаются через `rtk`; команды внутри GitHub-hosted runner используют установленные runner tools напрямую.
- Работа идёт в текущем дереве без worktree и без отката существующих изменений.

---

## Структура файлов

- `benchmark/baselines/format2/` — namespaced frozen Format 2 code и provenance.
- `benchmark/baselines/sprintf7/` — competitor из sprintf plan.
- `benchmark/model.dart` — scenario/sample/report value objects и JSON codec.
- `benchmark/scenarios.dart` — `{...}` и `%...` matrices с expected outputs.
- `benchmark/runner.dart` — JIT/AOT/JS entrypoint, interleaving, medians и geometric means.
- `benchmark/gates.dart` — exact acceptance thresholds и exit status.
- `benchmark/results/README.md` — schema, команды и ссылки на CI artifacts.
- `tool/generate_std_format_fixtures.cpp` — вторичный `std::format` reference.
- `test/fixtures/std_format_common.json` — пересечение `{...}` с C++.
- `test/std_format_compatibility_test.dart` — объяснимые Python/C++ differences.
- `.github/workflows/format3-linux.yml` — mandatory Ubuntu correctness/performance job.
- `.github/workflows/format3-macos.yml` — mandatory macOS correctness/performance job.
- `README.md`, `CHANGELOG.md`, `example/` — public contract, migrations и runnable examples.
- `pubspec.yaml`, `packages/format_intl/pubspec.yaml` — final release metadata.

---

### Task 1: Заморозить Format 2 baseline без публичного экспорта

**Files:**
- Create: `benchmark/baselines/format2/README.md`
- Create: `benchmark/baselines/format2/LICENSE`
- Create: `benchmark/baselines/format2/format2.dart`
- Create: `benchmark/baselines/format2/src/`
- Create: `test/benchmark_isolation_test.dart`

**Interfaces:**
- Produces: `legacyFormat(String template, List<Object?> values)` внутри benchmark library.
- Consumes: exact source behavior commit `86febb4`; не импортируется production или public tests.

- [ ] **Step 1: Написать RED isolation test**

```dart
test('benchmark baselines are absent from package:format public API', () {
  final exports = File('lib/format.dart').readAsStringSync();
  expect(exports, isNot(contains('benchmark/')));
  expect(exports, isNot(contains('legacyFormat')));
  expect(exports, isNot(contains('sprintf7')));
});
```

- [ ] **Step 2: Получить source read-only и перенести через patch**

Просмотреть каждый baseline file командой вида:

Run: `rtk git show 86febb4:lib/src/processor.dart`

Создать copies через `apply_patch`, переименовать library/private collisions и
оставить только API, нужный scenarios. Не выполнять checkout/reset и не создавать
worktree. `README.md` фиксирует commit, команды воспроизведения и список purely
namespacing edits. LICENSE копируется из root.

- [ ] **Step 3: Добавить equivalence smoke cases**

```dart
test('frozen Format 2 preserves the selected baseline behavior', () {
  expect(legacyFormat('{}', [1.23456789]), '1.23457');
  expect(legacyFormat('{:#X}', [42]), '0x2A');
  expect(legacyFormat('{:e}', [1.0]), '1.000000e+0');
});
```

- [ ] **Step 4: Подтвердить isolation GREEN**

Run: `rtk dart test test/benchmark_isolation_test.dart`

Expected: PASS.

Run: `rtk dart analyze`

Expected: no production import references benchmark baseline.

- [ ] **Step 5: Commit**

```bash
rtk git add benchmark/baselines/format2 test/benchmark_isolation_test.dart
rtk git commit -m "bench: freeze Format 2 baseline"
```

---

### Task 2: Создать scenario model и correctness-first harness

**Files:**
- Create: `benchmark/model.dart`
- Create: `benchmark/scenarios.dart`
- Create: `benchmark/runner.dart`
- Create: `benchmark/results/README.md`
- Create: `test/benchmark_scenarios_test.dart`

**Interfaces:**
- Consumes: Format 3, Format 2 baseline, sprintf7 baseline.
- Produces: immutable `BenchmarkScenario`, `BenchmarkSample`, `BenchmarkReport`; CLI `--dialect`, `--phase`, `--run`, `--output`.

- [ ] **Step 1: Написать RED scenario completeness test**

```dart
test('benchmark matrix covers every required dimension', () {
  final ids = benchmarkScenarios.map((scenario) => scenario.id).toSet();
  for (final required in [
    'brace.literal.cold',
    'brace.mixed_named.hot.10',
    'brace.graphemes.hot',
    'brace.nested_precision.hot',
    'printf.literal.cold',
    'printf.dynamic.hot.10',
    'printf.hex_float.hot',
    'printf.invalid.hot',
  ]) {
    expect(ids, contains(required));
  }
});
```

- [ ] **Step 2: Определить exact model**

```dart
enum BenchmarkDialect { braces, printf }
enum BenchmarkPhase { cold, hot }

sealed class BenchmarkOutcome {
  const BenchmarkOutcome();
}

final class TextOutcome extends BenchmarkOutcome {
  final String value;
  const TextOutcome(this.value);
}

final class ErrorOutcome extends BenchmarkOutcome {
  final String category;
  const ErrorOutcome(this.category);
}

final class BenchmarkScenario {
  final String id;
  final BenchmarkDialect dialect;
  final BenchmarkPhase phase;
  final bool keyScenario;
  final BenchmarkOutcome expected;
  final BenchmarkOutcome Function(int iteration) candidate;
  final BenchmarkOutcome Function(int iteration) baseline;
}

final class BenchmarkSample {
  final String scenarioId;
  final String engine;
  final int elapsedNanoseconds;
  final int operations;
}
```

Report stores runtime, run number, versions, raw samples, per-scenario medians,
ratios and no gate result yet.

- [ ] **Step 3: Реализовать complete scenarios**

Brace matrix включает literal/parser-heavy, top-level/with/tear-off, auto/manual,
named/mixed, 1/5/10/50 fields, both TextUnit, int/BigInt/double default and
f/e/g/%, grouping/sign/=/alternate/specials, nested width/precision, lookup,
conversions, custom extensions, C `n` и `format_intl` comparable output.

Printf matrix включает sprintf/vsprintf/tear-off, 1/5/10/50 conversions,
literal/dynamic width+precision, text/c/signed+unsigned, f/e/g/a uppercase,
flags/specials/Unicode/locale и error detection.

Каждый comparison вызывает candidate и baseline один раз до stopwatch и
проверяет exact output. Непересекающиеся new features имеют informational
scenario без ratio и не влияют на gates.

- [ ] **Step 4: Реализовать cold/hot inputs и interleaving**

Cold scenario заранее создаёт не менее 200 уникальных valid templates и
передаёт iteration index; создание strings выполняется до stopwatch. Hot
scenario использует один template. Для sample order чередовать
candidate→baseline и baseline→candidate; сделать 3 warmup rounds и минимум 7
recorded rounds.

- [ ] **Step 5: Подтвердить harness correctness**

Run: `rtk dart test test/benchmark_scenarios_test.dart`

Expected: PASS и каждый comparable scenario имеет равный output.

Run: `rtk dart run benchmark/runner.dart --dialect=braces --phase=hot --run=1 --output=/private/tmp/brace-smoke.json --samples=1`

Expected: valid JSON smoke report; `--samples=1` разрешён только при explicit
smoke flag и не используется gates.

- [ ] **Step 6: Commit**

```bash
rtk git add benchmark/model.dart benchmark/scenarios.dart benchmark/runner.dart benchmark/results/README.md test/benchmark_scenarios_test.dart
rtk git commit -m "bench: add Format 3 scenario harness"
```

---

### Task 3: Реализовать gates для JIT, AOT и JavaScript

**Files:**
- Create: `benchmark/gates.dart`
- Modify: `benchmark/runner.dart`
- Create: `test/benchmark_gates_test.dart`

**Interfaces:**
- Consumes: two independent reports одного runtime/dialect.
- Produces: merged JSON с gate status и process exit code 0/1.

- [ ] **Step 1: Написать RED tests exact thresholds**

```dart
test('brace gates enforce geometric mean and key maximum', () {
  final result = evaluateBraceGates(
    ratios: const {'a': 1.01, 'b': 1.03},
    keyScenarios: const {'a', 'b'},
    reproducedRatios: const {'a': 1.01, 'b': 1.03},
  );
  expect(result.geometricMeanPassed, isTrue);
  expect(result.keyScenariosPassed, isTrue);
});

test('printf gates distinguish cold and hot', () {
  expect(evaluatePrintfMean(BenchmarkPhase.cold, 0.90), isTrue);
  expect(evaluatePrintfMean(BenchmarkPhase.cold, 0.901), isFalse);
  expect(evaluatePrintfMean(BenchmarkPhase.hot, 0.80), isTrue);
  expect(evaluatePrintfMean(BenchmarkPhase.hot, 0.801), isFalse);
});
```

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/benchmark_gates_test.dart`

Expected: compile failure — gates отсутствуют.

- [ ] **Step 3: Реализовать deterministic statistics**

Median сортирует integer nanoseconds; geometric mean вычисляется как
`exp(sum(log(ratio))/count)`. Brace failure считается reproduced, если один и
тот же threshold превышен в run 1 и run 2. Printf thresholds применяются к
каждому runtime/phase; every key scenario ratio >1.02 в обоих runs даёт failure.

- [ ] **Step 4: Добавить exact execution commands**

JIT:

Run: `rtk dart run benchmark/runner.dart --runtime=jit --run=1 --output=/private/tmp/format3-jit-1.json`

Run: `rtk dart run benchmark/runner.dart --runtime=jit --run=2 --output=/private/tmp/format3-jit-2.json`

AOT:

Run: `rtk dart compile exe benchmark/runner.dart -o /private/tmp/format3-benchmark`

Run: `rtk /private/tmp/format3-benchmark --runtime=aot --run=1 --output=/private/tmp/format3-aot-1.json`

Run: `rtk /private/tmp/format3-benchmark --runtime=aot --run=2 --output=/private/tmp/format3-aot-2.json`

JavaScript `%...`:

Run: `rtk dart compile js benchmark/runner.dart -O4 -o /private/tmp/format3-benchmark.js`

Run: `rtk node /private/tmp/format3-benchmark.js --runtime=js --dialect=printf --run=1 --output=/private/tmp/format3-js-1.json`

Run: `rtk node /private/tmp/format3-benchmark.js --runtime=js --dialect=printf --run=2 --output=/private/tmp/format3-js-2.json`

- [ ] **Step 5: Добавить merge/gate command**

Run: `rtk dart run benchmark/gates.dart --reports=/private/tmp/format3-jit-1.json,/private/tmp/format3-jit-2.json,/private/tmp/format3-aot-1.json,/private/tmp/format3-aot-2.json,/private/tmp/format3-js-1.json,/private/tmp/format3-js-2.json --output=/private/tmp/format3-gates.json`

Expected: exit 0 only if every applicable gate passes; output includes absolute
times, ratios, geometric means, two-run reproduction and AOT executable size.

- [ ] **Step 6: Если gate падает, оптимизировать только доказанный bottleneck**

Сначала использовать per-scenario report, затем добавить узкий benchmark test,
затем изменить только соответствующий hot path. Допустимые evidence-driven
изменения: `StringBuffer`, уменьшение allocations AST/options, selected parser,
или bounded parsed-template cache. Cache обязан иметь фиксированный limit,
включать dialect в key и не участвовать в cold scenarios. После каждой правки
повторить correctness suite и все шесть benchmark reports; threshold не
ослаблять.

- [ ] **Step 7: Commit**

```bash
rtk git add benchmark/gates.dart benchmark/runner.dart test/benchmark_gates_test.dart lib/src/brace_parser.dart lib/src/printf_parser.dart lib/src/brace_processor.dart lib/src/printf_processor.dart lib/src/format.dart
rtk git commit -m "perf: enforce Format 3 performance gates"
```

---

### Task 4: Добавить вторичный `std::format` reference

**Files:**
- Create: `tool/generate_std_format_fixtures.cpp`
- Create: `tool/verify_fixtures.dart`
- Create: `test/fixtures/std_format_common.json`
- Create: `test/std_format_compatibility_test.dart`

**Interfaces:**
- Consumes: пересечение Python `{...}` и C++23 `std::format`.
- Produces: secondary comparison, который не переопределяет Python result.

- [ ] **Step 1: Написать RED fixture runner**

```dart
test('explains every std::format difference in the common domain', () async {
  final suite = await StdFormatFixtureSuite.load('test/fixtures/std_format_common.json');
  for (final fixture in suite.cases) {
    final actual = formatWith(
      fixture.pythonTemplate,
      positional: fixture.arguments,
    );
    expect(actual, fixture.pythonOrDocumentedDivergence, reason: fixture.id);
  }
});
```

- [ ] **Step 2: Реализовать statically typed C++23 generator**

Generator покрывает common integer, float, string, width/alignment, alternate,
grouping-free and special cases. Header записывает compiler и standard library.
Cases, где Python нормативно отличается, помечаются stable divergence id вместо
изменения expected Dart output.

Linux CI:

Run: `rtk g++ -std=c++23 -O2 tool/generate_std_format_fixtures.cpp -o /private/tmp/generate-std-format-fixtures`

Run: `rtk env LC_ALL=C /private/tmp/generate-std-format-fixtures /private/tmp/std-format-linux.json`

macOS:

Run: `rtk clang++ -std=c++23 -O2 tool/generate_std_format_fixtures.cpp -o /private/tmp/generate-std-format-fixtures`

Run: `rtk env LC_ALL=C /private/tmp/generate-std-format-fixtures /private/tmp/std-format-macos.json`

`std_format_common.json` хранит exact/allowed reference, а platform JSON
создаётся заново и сохраняется как CI artifact.

Run: `rtk dart run tool/verify_fixtures.dart --reference=test/fixtures/std_format_common.json --actual=/private/tmp/std-format-macos.json`

- [ ] **Step 3: Подтвердить GREEN**

Run: `rtk dart test test/std_format_compatibility_test.dart`

Expected: PASS; every difference points to Python fixture or approved Dart
divergence.

- [ ] **Step 4: Commit**

```bash
rtk git add tool/generate_std_format_fixtures.cpp tool/verify_fixtures.dart test/fixtures/std_format_common.json test/std_format_compatibility_test.dart
rtk git commit -m "test: compare Format 3 with std format"
```

---

### Task 5: Переписать README, migrations, examples и changelog

**Files:**
- Replace: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `pubspec.yaml`
- Create: `example/format_example.dart`
- Delete: `example2/format_example.dart`
- Delete: `example/analysis_options.yaml`
- Delete: `example/pubspec.yaml`
- Delete: `example/README.md`
- Delete: `example/CHANGELOG.md`
- Delete: `example/bin/benchmark.dart`
- Delete: `example/bin/benchmark.exe`
- Delete: `example/lib/benchmark.dart`
- Delete: `example/lib/src/format_benchmark.dart`
- Delete: `example/lib/src/legacy_format_baseline.dart`
- Delete: `example/lib/src/legacy_format_benchmark.dart`
- Delete: `example/lib/src/my_benchmark_base.dart`
- Delete: `example/lib/src/tests/tests.dart`
- Delete: `example/lib/src/utils/output.dart`

**Interfaces:**
- Consumes: final public API and verified command set.
- Produces: user-facing Format 3 documentation and independent 1.6/2.0 migration paths.

- [ ] **Step 1: Добавить executable README examples test**

Создать test, который извлекает fenced Dart snippets с marker `// example` в
temporary file, добавляет import и запускает analyzer. Минимальный expected
example:

```dart
format('{} {}', 'hello', 'world');
formatWith(
  '{0} {name}',
  positional: ['hello'],
  named: {'name': 'world'},
);
sprintf('%+08.2f', 12.5);
vsprintf('%s=%d', ['answer', 42]);
```

- [ ] **Step 2: Написать основной README contract**

Разделы в порядке: overview; Python 3.14/C++23 contracts; four APIs and custom
Format; brace grammar/spec table; lookup/conversions; sprintf conversion/flag
table; Unicode TextUnit; custom formatter payload; `n` core and `format_intl`;
typed errors; intentional divergences; performance commands/results.

Отдельно объяснить, что C++ API byte-oriented, `%n/%p` и modifiers rejected,
а compatibility с Dart package sprintf отсутствует.

- [ ] **Step 3: Добавить самостоятельный переход с 1.6**

Таблица обязана показать separate positional call, 10-value limit,
`formatWith` unlimited list/named, no List/Map expansion, no extensions/print/
Symbol Map, mixed numbering error, restored dynamic width/precision, changed
f/e/g/#b/#o/#X/%/=/n/c/nan/inf, typed errors и external `format_intl`.

Включить оба разных examples:

```dart
format('{}', values); // форматирует один List
formatWith('{} {}', positional: values); // раскрывает список как аргументы
```

- [ ] **Step 4: Добавить самостоятельный переход с 2.0**

Таблица показывает `format(template, values)` → `formatWith(positional:)`,
`formatNamed` → `formatWith(named:)`, immutable Format constructor registry,
lookup/representation/payload, nested width/precision, strict grammar, numeric
edge changes, CNumberLocale, separate intl, Unicode-scalar default и errors.

- [ ] **Step 5: Обновить metadata/examples и удалить binary artifact**

Root description упоминает Python-style и C++ sprintf. CHANGELOG 3.0.0 содержит
breaking API, semantics, intl split, sprintf and performance verification.
Старый отдельный benchmark package `example/` полностью заменяется обычным
`example/format_example.dart`, использующим только `package:format/format.dart`.
Его benchmark code уже перенесён в корневой `benchmark/`. Удалить tracked
compiled `example/bin/benchmark.exe`; executable создаётся только в
`/private/tmp`. Удалить дублирующий `example2/format_example.dart`; locale
example живёт в `packages/format_intl/example/`.

- [ ] **Step 6: Проверить docs**

Run: `rtk dart test test/readme_examples_test.dart`

Expected: all marked snippets compile.

Run: `rtk dart pub publish --dry-run`

Expected: 0 warnings for root package.

- [ ] **Step 7: Commit**

```bash
rtk git add README.md CHANGELOG.md pubspec.yaml example example2/format_example.dart test/readme_examples_test.dart
rtk git commit -m "docs: document Format 3 migration"
```

---

### Task 6: Обязательные Linux и macOS GitHub Actions

**Files:**
- Create: `.github/workflows/format3-linux.yml`
- Create: `.github/workflows/format3-macos.yml`
- Create: `tool/collect_environment.dart`
- Modify: `tool/verify_fixtures.dart`
- Create: `test/workflow_contract_test.dart`

**Interfaces:**
- Consumes: fixture generators, full tests, benchmark runner/gates.
- Produces: mandatory platform jobs and JSON artifacts.

- [ ] **Step 1: Написать RED workflow contract test**

```dart
test('workflows pin required platforms and runtimes', () {
  final linux = File('.github/workflows/format3-linux.yml').readAsStringSync();
  final macos = File('.github/workflows/format3-macos.yml').readAsStringSync();
  expect(linux, contains('ubuntu-24.04'));
  expect(linux, contains('g++ -std=c++23'));
  expect(macos, contains('macos-15'));
  expect(macos, contains('clang++ -std=c++23'));
  for (final yaml in [linux, macos]) {
    expect(yaml, contains('actions/checkout@v6'));
    expect(yaml, contains('dart-lang/setup-dart@v1'));
    expect(yaml, contains('actions/setup-node@v6'));
    expect(yaml, contains("node-version: '24.8.0'"));
    expect(yaml, contains('actions/upload-artifact@v7'));
  }
});
```

- [ ] **Step 2: Реализовать Linux workflow**

Workflow permissions `contents: read`, triggers pull_request/push main,
`runs-on: ubuntu-24.04`. Steps: checkout v6; setup Dart stable; setup Node v6
with exact 24.8.0 and package-manager-cache false; pub get; format check;
analyze; tests; compile/run both C++ generators with `LC_ALL=C`; compare generated
fixtures to committed via `tool/verify_fixtures.dart`; run two JIT/AOT/JS reports;
apply gates; collect environment; upload all JSON as `format3-linux-reports` with
`if-no-files-found: error`.

- [ ] **Step 3: Реализовать macOS workflow**

Workflow повторяет correctness и performance steps на `macos-15`, использует
`clang++ -std=c++23`, `LC_ALL=C`, записывает `sw_vers`, clang version и linked
libSystem. Artifact name — `format3-macos-reports`. Platform fixtures могут
отличаться только разрешённым set, который проверяет merge tool.

- [ ] **Step 4: Реализовать environment/fixture tools**

`collect_environment.dart` запускает version commands через `Process.run`,
проверяет exit codes и создаёт JSON keys `os`, `dart`, `node`, `compiler`,
`cLibrary`, `timestampUtc`. `verify_fixtures.dart` сравнивает semantic decoded
JSON без зависимости от whitespace и завершается 1 при unexplained difference.

- [ ] **Step 5: Подтвердить локальный workflow contract**

Run: `rtk dart test test/workflow_contract_test.dart`

Expected: PASS.

Run: `rtk dart analyze`

Expected: no issues.

- [ ] **Step 6: Commit**

```bash
rtk git add .github/workflows tool/collect_environment.dart tool/verify_fixtures.dart test/workflow_contract_test.dart
rtk git commit -m "ci: verify Format 3 on Linux and macOS"
```

---

### Task 7: Итоговая проверка и передача на review

**Files:**
- Modify only if verification exposes a defect; changes must include a reproducing test.

**Interfaces:**
- Consumes: all previous tasks and required CI results.
- Produces: evidence package proving release readiness; no pub.dev mutation.

- [ ] **Step 1: Использовать обязательный verification skill**

Invoke: `superpowers:verification-before-completion`.

Не делать утверждений о готовности до выполнения остальных steps этой task.

- [ ] **Step 2: Выполнить fresh local correctness verification**

Run: `rtk dart pub get`

Run: `rtk dart format --output=none --set-exit-if-changed lib test tool benchmark packages example`

Run: `rtk dart analyze`

Run: `rtk dart test --chain-stack-traces`

Expected: every command exits 0.

- [ ] **Step 3: Выполнить fresh performance verification**

Повторить exact six report commands Task 3 и gate merge с новыми output paths.

Expected: all `{...}` JIT/AOT and `%...` JIT/AOT/JavaScript gates PASS twice.

- [ ] **Step 4: Проверить publication shape обоих packages**

Run из root: `rtk dart pub publish --dry-run`

Run из `packages/format_intl`: `rtk dart pub publish --dry-run`

Expected: оба dry-run дают 0 warnings; actual publish не выполняется.

- [ ] **Step 5: Проверить git diff и commits**

Run: `rtk git diff --check`

Run: `rtk git status --short`

Expected: no whitespace errors; status содержит только намеренные изменения или
пуст.

- [ ] **Step 6: Использовать обязательный code review skill**

Invoke: `superpowers:requesting-code-review`.

Исправлять только подтверждённые findings через отдельный RED-test и повторять
затронутые verification commands.

- [ ] **Step 7: Подтвердить GitHub Actions**

После push проверить обязательные `Format 3 Linux` и `Format 3 macOS` jobs.
Оба должны пройти, а JSON artifacts — содержать versions, fixture reports,
samples и gate status. До этого Format 3 не называется завершённым.

- [ ] **Step 8: Зафиксировать verification findings в исходной task**

Если fixes потребовались, вернуться к task, владеющей затронутым файлом,
добавить reproducing RED-test и использовать её точный список `git add` и
commit message с префиксом `fix:`. После этого заново выполнить Steps 2–7.
Если fixes не потребовались, пустой commit не создавать.
