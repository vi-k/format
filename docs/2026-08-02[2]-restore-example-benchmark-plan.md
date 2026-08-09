# План восстановления пользовательского example benchmark

Статус: исполнен, вошло в 3.0.0. Чекбоксы в теле не проставлялись — открытым пунктом их читать нельзя.

> **Для agentic workers:** ОБЯЗАТЕЛЬНЫЙ SUB-SKILL: выполнять план через `superpowers:subagent-driven-development` (рекомендуется) или `superpowers:executing-plans`. Шаги используют checkbox (`- [ ]`) для отслеживания выполнения.

**Цель:** Вернуть пользовательский `example/bin/benchmark.dart` с тремя исходными движками, сохранить заменивший его gate-benchmark отдельно и добавить VS Code-конфигурации для всех benchmark entrypoint.

**Архитектура:** Исторический driver и матрица восстанавливаются из коммита `d865cd21056754a2815b23a74f48799756f5ebb9`, но старые движки подключаются только через benchmark-local adapters. Текущий Legacy/Current gate изолируется в собственном namespace и entrypoint. Production API `lib/format.dart` не получает `format2`, `sprintf7` или benchmark exports.

**Технологии:** Dart 3.12.2, `benchmark_harness`, immutable Format 3 API, frozen Format 2/sprintf7 sources, VS Code Dart launch configurations.

## Общие ограничения

- Все локальные shell-команды начинаются с `rtk`.
- Все изменения файлов выполняются через `apply_patch`; исторические файлы читаются через `rtk git show`, без checkout/reset.
- Пользовательские `.vscode/c_cpp_properties.json` и `.vscode/settings.json` не изменяются.
- `.vscode/launch.json` находится в области задачи: существующие конфигурации сохраняются, новые только добавляются или уточняются.
- Старый `format2()` не возвращается в production или публичный API.
- Frozen implementations доступны только example/benchmark-коду.
- Performance-benchmark не запускаются параллельно.
- Каждый кодовый task проходит RED → GREEN и заканчивается отдельным коммитом.

---

### Task 1: Изолировать текущий Legacy/Current gate и исправить grapheme-сценарий

**Files:**
- Create: `example/lib/format2_gate_benchmark.dart`
- Create: `example/lib/src/format2_gate/benchmark_base.dart`
- Create: `example/lib/src/format2_gate/format_benchmark.dart`
- Create: `example/lib/src/format2_gate/legacy_format_benchmark.dart`
- Create: `example/lib/src/format2_gate/scenarios.dart`
- Create: `example/bin/format2_gate_benchmark.dart`
- Test: `example/test/format2_gate_benchmark_test.dart`
- Preserve: `example/lib/src/legacy_format_baseline.dart`

**Interfaces:**
- Produces: `gateBenchmarkScenarios`, `gateBenchmarkFormat`, `GateFormatBenchmark`, `GateLegacyFormatBenchmark`.
- Consumes: текущий код Legacy/Current из `example/bin/benchmark.dart` и `example/lib/src/`.

- [ ] **Step 1: Написать RED-тест grapheme semantics**

```dart
import 'package:example/format2_gate_benchmark.dart';
import 'package:test/test.dart';

void main() {
  test('gate unicode scenario treats the family emoji as one fill grapheme', () {
    final scenario = gateBenchmarkScenarios.singleWhere(
      (value) => value.name == 'unicode',
    );
    final benchmark = GateFormatBenchmark(scenario);

    expect(benchmark.execute(), scenario.expected);
  });
}
```

- [ ] **Step 2: Подтвердить RED**

Run from `example/`:

```bash
rtk dart test test/format2_gate_benchmark_test.dart
```

Expected: compile failure — `package:example/format2_gate_benchmark.dart` и gate-типы ещё отсутствуют.

- [ ] **Step 3: Перенести gate-код в изолированный namespace**

Создать `example/lib/format2_gate_benchmark.dart`:

```dart
export 'src/format2_gate/format_benchmark.dart';
export 'src/format2_gate/legacy_format_benchmark.dart';
export 'src/format2_gate/scenarios.dart';
```

Перенести текущие `BenchmarkScenario`, `BenchmarkValue`, benchmark base и оба
движка в `example/lib/src/format2_gate/`, добавив префикс `Gate` публичным
типам. `GateBenchmarkBase.execute()` возвращает один проверяемый output, а
`run()` присваивает его полю `output`.

Создать format instance:

```dart
final gateBenchmarkFormat = Format(
  textUnit: TextUnit.graphemeClusters,
  formatters: const [GateBenchmarkValueFormatter()],
);
```

Это сохраняет family emoji как один fill и не меняет глобальный `defaultFormat`.

- [ ] **Step 4: Перенести текущий driver под отдельное имя**

`example/bin/format2_gate_benchmark.dart` содержит текущий цикл из трёх
измерений Legacy/Current, но импортирует
`package:example/format2_gate_benchmark.dart` и использует gate-типы.

- [ ] **Step 5: Подтвердить GREEN**

```bash
rtk dart test test/format2_gate_benchmark_test.dart
rtk dart run bin/format2_gate_benchmark.dart
```

Expected: test PASS; entrypoint завершается без `InvalidSpecifierException` и
печатает строку `unicode`.

- [ ] **Step 6: Commit**

```bash
rtk git add example/lib/format2_gate_benchmark.dart example/lib/src/format2_gate example/bin/format2_gate_benchmark.dart example/test/format2_gate_benchmark_test.dart
rtk git commit -m "fix: isolate the Format 2 gate benchmark"
```

---

### Task 2: Восстановить исходный benchmark с тремя движками

**Files:**
- Modify: `example/bin/benchmark.dart`
- Modify: `example/lib/benchmark.dart`
- Modify: `example/lib/src/my_benchmark_base.dart`
- Modify: `example/lib/src/format_benchmark.dart`
- Create: `example/lib/src/format2_benchmark.dart`
- Create: `example/lib/src/sprintf_benchmark.dart`
- Modify: `example/lib/src/tests/tests.dart`
- Test: `example/test/restored_benchmark_test.dart`

**Interfaces:**
- Produces: `FormatBenchmark`, `Format2Benchmark`, `SprintfBenchmark`, `testData`.
- Consumes: `legacyFormat(String, Object)` из benchmark-local Format 2 baseline и `sprintf7.sprintf(String, List<Object?>)` из frozen sprintf7.

- [ ] **Step 1: Написать RED-тест трёх движков**

```dart
import 'package:example/benchmark.dart';
import 'package:test/test.dart';

void main() {
  test('restored benchmark exposes Format 3, Format 2 and sprintf engines', () {
    final format3 = FormatBenchmark();
    final format2 = Format2Benchmark();
    final printf = SprintfBenchmark();

    format3.go('{:d}', [42]);
    format2.go('{:d}', [42]);
    printf.go('%d', [42]);

    expect(format3.output, '42');
    expect(format2.output, '42');
    expect(printf.output, '42');
  });

  test('restored matrix keeps separate brace and printf templates', () {
    final scenario = testData.first;
    expect(scenario.$1, '{}');
    expect(scenario.$2, '%d');
    expect(scenario.$3.first.$2, '0');
  });
}
```

Mutation caught: удаление любого движка, подмена обоих синтаксисов одним
шаблоном или неправильное подключение baseline ломает наблюдаемый output.

- [ ] **Step 2: Подтвердить RED**

```bash
rtk dart test test/restored_benchmark_test.dart
```

Expected: compile failure — `Format2Benchmark`, `SprintfBenchmark` и `testData`
отсутствуют в текущем barrel.

- [ ] **Step 3: Восстановить driver и матрицу только через read-only history**

Прочитать исторические версии:

```bash
rtk git show d865cd21056754a2815b23a74f48799756f5ebb9:example/bin/benchmark.dart
rtk git show d865cd21056754a2815b23a74f48799756f5ebb9:example/lib/src/tests/tests.dart
rtk git show d865cd21056754a2815b23a74f48799756f5ebb9:example/lib/src/utils/output.dart
```

Восстановить их через `apply_patch`. Сохранить исходные brace/printf templates,
порядок сценариев, colored diff и per-engine exception handling. Не возвращать
диагностические `list`, `v` и `v2` prints в начало `run()` — они не являются
benchmark-сценариями и искажают запуск.

- [ ] **Step 4: Восстановить benchmark base и Format 3 adapter**

`MyBenchmarkBase` сохраняет поля `template`, `values`, `output`, `isSprintf` и
метод `go()`. `run()` каждого движка выполняет форматирование десять раз, как в
историческом benchmark, чтобы `measure() / 100` оставалось сопоставимым.

Format 3 adapter использует отдельный instance:

```dart
final _format3Benchmark = Format(textUnit: TextUnit.graphemeClusters);

String _formatCurrent(String template, List<Object?> values) =>
    _format3Benchmark.formatWith(template, positional: values);
```

Вызвать `_formatCurrent` десять раз; последний результат записать в `output`.

- [ ] **Step 5: Подключить benchmark-local Format 2 и frozen sprintf7**

`Format2Benchmark` импортирует `legacy_format_baseline.dart` и десять раз
вызывает `legacyFormat(template, values)`.

`SprintfBenchmark` импортирует frozen source только из benchmark-кода:

```dart
// ignore: avoid_relative_lib_imports
import '../../../benchmark/baselines/sprintf7/lib/sprintf.dart' as sprintf7;
```

Он десять раз вызывает `sprintf7.sprintf(template, values)`. Если analyzer не
разрешает traversal, создать тонкий adapter в
`example/lib/src/baselines/sprintf7_adapter.dart`; production `lib/` корневого
пакета не изменять.

- [ ] **Step 6: Обновить barrel и подтвердить GREEN**

`example/lib/benchmark.dart` экспортирует три benchmark-класса, base, `testData`
и output helpers. Gate-типы остаются в отдельном barrel.

```bash
rtk dart test test/restored_benchmark_test.dart
rtk dart run bin/benchmark.dart
```

Expected: tests PASS; driver печатает результаты `sprintf::sprintf`,
`format::format` и `format::format2` и доходит до конца матрицы.

- [ ] **Step 7: Проверить production isolation**

```bash
rtk rg -n "legacyFormat|sprintf7|format2_benchmark" lib test --glob '!benchmark_isolation_test.dart'
```

Expected: нет новых production imports/exports.

- [ ] **Step 8: Commit**

```bash
rtk git add example/bin/benchmark.dart example/lib/benchmark.dart example/lib/src/my_benchmark_base.dart example/lib/src/format_benchmark.dart example/lib/src/format2_benchmark.dart example/lib/src/sprintf_benchmark.dart example/lib/src/tests/tests.dart example/test/restored_benchmark_test.dart
rtk git commit -m "feat: restore the original example benchmark"
```

---

### Task 3: Добавить launch-конфигурации всех benchmark entrypoint

**Files:**
- Modify: `.vscode/launch.json`

**Interfaces:**
- Consumes: оба example entrypoint из Tasks 1–2 и существующие root benchmark entrypoint.
- Produces: четыре независимо запускаемые VS Code Dart configurations.

- [ ] **Step 1: Сохранить существующие конфигурации**

Не изменять `format`, `test` и `C/C++ Runner: Debug Session`. Существующий
`benchmark` переименовать в `Benchmark: original example`, сохранив program
`example/bin/benchmark.dart`.

- [ ] **Step 2: Добавить отдельные конфигурации**

Добавить в `configurations`:

```json
{
  "name": "Benchmark: Format 2 gate",
  "request": "launch",
  "type": "dart",
  "program": "example/bin/format2_gate_benchmark.dart",
  "cwd": "${workspaceFolder}/example",
  "args": []
},
{
  "name": "Benchmark: release harness smoke",
  "request": "launch",
  "type": "dart",
  "program": "benchmark/runner.dart",
  "cwd": "${workspaceFolder}",
  "args": [
    "--runtime=jit",
    "--run=1",
    "--samples=1",
    "--smoke",
    "--output=/private/tmp/format3-vscode-smoke.json"
  ]
},
{
  "name": "Benchmark: parser strategy JIT",
  "request": "launch",
  "type": "dart",
  "program": "benchmark/parser_strategy.dart",
  "cwd": "${workspaceFolder}",
  "args": [
    "--runtime=jit",
    "--output=/private/tmp/parser-strategy-vscode-jit.json"
  ]
}
```

Для `Benchmark: original example` также задать
`"cwd": "${workspaceFolder}/example"`. Не добавлять parallel compound.

- [ ] **Step 3: Проверить JSON и каждый эквивалентный CLI launch**

```bash
rtk dart run bin/benchmark.dart
rtk dart run bin/format2_gate_benchmark.dart
rtk dart run benchmark/runner.dart --runtime=jit --run=1 --samples=1 --smoke --output=/private/tmp/format3-vscode-smoke.json
rtk dart run benchmark/parser_strategy.dart --runtime=jit --output=/private/tmp/parser-strategy-vscode-jit.json
```

Первые две команды запускать из `example/`, последние две — из корня. Expected:
все exit 0 и оба JSON-файла созданы. Команды выполняются последовательно.

- [ ] **Step 4: Commit**

```bash
rtk git add .vscode/launch.json
rtk git commit -m "chore: add benchmark launch configurations"
```

---

### Task 4: Финальная проверка восстановления

**Files:**
- Verify only: `example/`, `.vscode/launch.json`, production isolation.

**Interfaces:**
- Consumes: результаты Tasks 1–3.
- Produces: проверенное восстановление без release/API regressions.

- [ ] **Step 1: Проверить example package**

```bash
rtk dart analyze
rtk dart test
```

Run from `example/`. Expected: analyzer exit 0; все tests PASS.

- [ ] **Step 2: Проверить root package**

```bash
rtk dart analyze
rtk dart test
rtk git diff --check
```

Expected: analyzer без новых ошибок; полный suite PASS; whitespace clean.

- [ ] **Step 3: Проверить scope**

```bash
rtk git status --short
rtk git log -4 --oneline
```

Expected: пользовательские `.vscode/c_cpp_properties.json` и
`.vscode/settings.json` остаются нетронутыми; `launch.json` изменён только в
запрошенной области; старые baseline не экспортируются production-кодом.

- [ ] **Step 4: Запросить независимое code review**

Review должен отдельно проверить восстановление исторической матрицы, честность
трёх adapters, grapheme semantics, отсутствие production exports и корректность
всех launch paths.
