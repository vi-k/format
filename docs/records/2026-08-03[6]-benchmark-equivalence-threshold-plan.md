# План реализации порога равной производительности benchmark

Статус: исполнен, вошло в 3.0.0. Чекбоксы в теле не проставлялись — открытым пунктом их читать нельзя.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить в пользовательский benchmark настраиваемый порог 5%, ниже которого производительность Dart SDK и Compatible считается равной.

**Architecture:** Существующее измерение median и формула относительной разницы не меняются. `runFloatModesBenchmark` принимает порог, валидирует его до прогрева и выбирает между сообщениями `PERFORMANCE EQUAL` и `<режим> FASTER`; различие форматированных строк остаётся независимым.

**Tech Stack:** Dart SDK, package:test, ansi_escape_codes, существующий example benchmark.

## Global Constraints

- Порог по умолчанию равен `5.0` процента.
- Граница включительная: разница `<= threshold` считается равной.
- Порог должен быть конечным и неотрицательным.
- Существующие пользовательские незакоммиченные изменения ANSI-вывода в `example/lib/src/float_modes_benchmark.dart` сохраняются.
- Raw ANSI escape sequences в production benchmark не добавляются.

---

### Task 1: Порог равной производительности

**Files:**
- Modify: `example/lib/src/float_modes_benchmark.dart`
- Modify: `example/test/restored_benchmark_test.dart`
- Modify: `example/README.md`

**Interfaces:**
- Consumes: существующие median `dartMicros` и `compatibleMicros`.
- Produces: `runFloatModesBenchmark({..., double equivalenceThresholdPercent = 5.0})`.
- Produces: строки `PERFORMANCE EQUAL: difference N% <= T%` либо `<режим> FASTER: N%`.

- [ ] **Step 1: Согласовать текущий тест с сохранённым ANSI-выводом пользователя**

В существующем тесте заменить устаревшие ожидания `Result: 3` и `Result: 2`
на проверку фактических цветных значений через экспортированный helper:

```dart
expect(output, contains(h2('3')));
expect(output, contains(h2('2')));
```

Run: `rtk dart test test/restored_benchmark_test.dart` in `example/`.

Expected: текущий suite снова PASS без отката пользовательских изменений.

- [ ] **Step 2: Написать падающие тесты порога и валидации**

Добавить тест равной ветки:

```dart
test('float modes benchmark treats differences inside threshold as equal', () {
  final lines = <String>[];

  runFloatModesBenchmark(
    writeLine: lines.add,
    warmupOperations: 1,
    operations: 2,
    samples: 1,
    equivalenceThresholdPercent: 1e9,
  );

  final output = lines.join('\n');
  expect(output, contains('PERFORMANCE EQUAL'));
  expect(output, contains('<= 1000000000.0%'));
});
```

Добавить тест нулевого порога и некорректных значений:

```dart
test('float modes benchmark reports a winner outside threshold', () {
  final lines = <String>[];

  runFloatModesBenchmark(
    writeLine: lines.add,
    warmupOperations: 1,
    operations: 2,
    samples: 3,
    equivalenceThresholdPercent: 0,
  );

  expect(lines.join('\n'), contains('FASTER:'));
});

for (final threshold in [-1.0, double.nan, double.infinity]) {
  test('float modes benchmark rejects threshold $threshold', () {
    expect(
      () => runFloatModesBenchmark(equivalenceThresholdPercent: threshold),
      throwsArgumentError,
    );
  });
}
```

- [ ] **Step 3: Подтвердить RED**

Run: `rtk dart test test/restored_benchmark_test.dart` in `example/`.

Expected: compile failure because `equivalenceThresholdPercent` отсутствует.

- [ ] **Step 4: Реализовать минимальную валидацию и выбор сообщения**

Расширить сигнатуру:

```dart
void runFloatModesBenchmark({
  BenchmarkLineWriter? writeLine,
  int warmupOperations = 1000,
  int operations = 10000,
  int samples = 7,
  double equivalenceThresholdPercent = 5.0,
}) {
```

До создания `emit` добавить:

```dart
if (!equivalenceThresholdPercent.isFinite ||
    equivalenceThresholdPercent < 0) {
  throw ArgumentError.value(
    equivalenceThresholdPercent,
    'equivalenceThresholdPercent',
    'must be finite and non-negative',
  );
}
```

После вычисления `difference` заменить безусловный winner output:

```dart
if (difference <= equivalenceThresholdPercent) {
  emit(
    ok(
      'PERFORMANCE EQUAL: difference '
      '${difference.toStringAsFixed(1)}% <= '
      '${equivalenceThresholdPercent.toStringAsFixed(1)}%',
    ),
  );
} else {
  emit(ok('$fastest FASTER: ${difference.toStringAsFixed(1)}%'));
}
```

- [ ] **Step 5: Подтвердить GREEN и анализ**

Run: `rtk dart test` in `example/`.

Run: `rtk dart analyze` in `example/`.

Expected: all tests PASS; analyzer reports no issues.

- [ ] **Step 6: Обновить пользовательскую документацию**

В `example/README.md` указать, что разница до 5% по умолчанию помечается как
равная, а при вызове `runFloatModesBenchmark` порог можно изменить параметром
`equivalenceThresholdPercent`.

- [ ] **Step 7: Проверить реальный ANSI-вывод**

Run: `rtk dart run bin/float_modes_benchmark.dart` in `example/`.

Expected: близкие результаты получают `PERFORMANCE EQUAL`, различия больше 5%
по-прежнему получают `<режим> FASTER`, а `RESULTS DIFFER` выводится независимо.

- [ ] **Step 8: Commit**

```bash
rtk git add example/lib/src/float_modes_benchmark.dart example/test/restored_benchmark_test.dart example/README.md
rtk git commit -m "bench: treat small timing differences as equal"
```
