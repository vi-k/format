# План реализации переименования benchmark режимов `double`

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Полностью переименовать активный пользовательский benchmark с `float` на `double` и разместить его проверенный результат рядом с документацией compatible-профиля.

**Architecture:** До выпуска старые имена удаляются без alias. Сначала публичная example-функция и unit-тест переходят на `double`, затем переименовываются executable/configuration и актуальная документация; исторические specs/plans остаются неизменными.

**Tech Stack:** Dart SDK, package:test, ansi_escape_codes, VS Code launch configuration, Markdown.

## Global Constraints

- Новая функция называется `runDoubleModesBenchmark`.
- Новые файлы называются `double_modes_benchmark.dart`.
- Активные пользовательские тексты используют `double modes` и `double-mode`.
- Старые alias не сохраняются.
- README утверждает преимущество или равенство только для конечных `double` в протестированных сценариях.
- Исторические файлы в `docs/` (бывшие `docs/superpowers/specs` и `docs/superpowers/plans`) не переписываются.

---

### Task 1: Переименование library API benchmark

**Files:**
- Move: `example/lib/src/float_modes_benchmark.dart` → `example/lib/src/double_modes_benchmark.dart`
- Modify: `example/lib/benchmark.dart`
- Modify: `example/test/restored_benchmark_test.dart`

**Interfaces:**
- Replaces: top-level function `runFloatModesBenchmark`.
- Produces: `runDoubleModesBenchmark({BenchmarkLineWriter? writeLine, int warmupOperations = 1000, int operations = 10000, int samples = 7, double equivalenceThresholdPercent = 5.0})`.

- [ ] **Step 1: Написать падающий API-тест нового имени**

В `example/test/restored_benchmark_test.dart` заменить все вызовы
`runFloatModesBenchmark` на `runDoubleModesBenchmark`, а названия тестов
`float modes benchmark` на `double modes benchmark`.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/restored_benchmark_test.dart` in `example/`.

Expected: compile failure `Method not found: 'runDoubleModesBenchmark'`.

- [ ] **Step 3: Переименовать source и API**

Переместить source в `example/lib/src/double_modes_benchmark.dart`. Внутри
переименовать top-level функцию `runFloatModesBenchmark` в
`runDoubleModesBenchmark`, класс `_FloatModeScenario` в `_DoubleModeScenario`,
а список `_floatModeScenarios` в `_doubleModeScenarios`. Остальные параметры
и алгоритм измерения не менять.

В `example/lib/benchmark.dart` заменить export на:

```dart
export 'src/double_modes_benchmark.dart';
```

- [ ] **Step 4: Подтвердить GREEN**

Run: `rtk dart test test/restored_benchmark_test.dart` in `example/`.

Expected: all tests PASS.

---

### Task 2: Executable, VS Code и документация

**Files:**
- Move: `example/bin/float_modes_benchmark.dart` → `example/bin/double_modes_benchmark.dart`
- Modify: `.vscode/launch.json`
- Modify: `README.md`
- Modify: `example/README.md`

**Interfaces:**
- Produces: command `dart run bin/double_modes_benchmark.dart`.
- Produces: VS Code configuration `Benchmark: double modes` included in `Benchmark: all`.

- [ ] **Step 1: Переименовать executable и launch configuration**

Переместить bin-файл, заменить его callback на:

```dart
runDoubleModesBenchmark,
```

В `.vscode/launch.json` заменить configuration name, program и compound item:

```json
"name": "Benchmark: double modes",
"program": "bin/double_modes_benchmark.dart"
```

- [ ] **Step 2: Перенести benchmark к compatible-разделу README**

Сразу после примера `DoubleFormatMode.compatible` добавить команду:

```console
cd example
dart run bin/double_modes_benchmark.dart
```

И проверенный результат:

```text
For finite doubles in the benchmark scenarios, DoubleFormatMode.dartSdk is
faster than compatible mode or within the default 5% equivalence threshold.
```

Удалить команду и описание benchmark из конца раздела `Format 3.0 migration`.
Не распространять вывод на `NaN` и `Infinity`.

- [ ] **Step 3: Обновить example README**

Заменить команду, `float-mode report` на `double-mode report` и
`runFloatModesBenchmark` на `runDoubleModesBenchmark`.

- [ ] **Step 4: Проверить отсутствие активных старых имён**

Run:

```bash
rtk rg -n "float_modes|FloatModes|float modes|float-mode|runFloat" README.md example .vscode CHANGELOG.md packages/format_intl/README.md
```

Expected: no matches.

- [ ] **Step 5: Полная проверка example**

Run: `rtk dart test` in `example/`.

Run: `rtk dart analyze` in `example/`.

Expected: all tests PASS; analyzer reports no issues.

- [ ] **Step 6: Ручной запуск нового executable**

Run: `rtk dart run bin/double_modes_benchmark.dart` in `example/`.

Expected: ANSI report contains formatted results, `PERFORMANCE EQUAL`,
`RESULTS DIFFER` and winner messages. Старого bin-файла в списке файлов нет.

- [ ] **Step 7: Hygiene и commit**

Run: `rtk git diff --check`.

Run: `rtk git status --short`.

Commit:

```bash
rtk git add .vscode/launch.json README.md example
rtk git commit -m "bench: rename float modes benchmark to double"
```
