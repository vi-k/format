# Intl `n` Precision Safety Implementation Plan

Статус: исполнен, вошло в 3.0.0. Чекбоксы в теле не проставлялись — открытым пунктом их читать нельзя.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Не допустить искажения числового значения specifier `n` при precision, небезопасной для `intl.NumberFormat`.

**Architecture:** Сохранить `intl` как locale-aware backend и добавить раннюю specifier-specific validation в `_intlNumberFormat`. Публичный regression-тест фиксирует безопасную границу 18 и структурированный typed failure для 19.

**Tech Stack:** Dart 3.7.2+, `intl` 0.20.x, `test`.

## Global Constraints

- `n` использует `intl.NumberFormat`; replacement engine не добавляется.
- Для `double` с `n` допустима precision `1..18`.
- Precision `19+` даёт `InvalidFormatException` до вызова `NumberFormat`.
- `fragment` содержит полный placeholder, `reason` сообщает максимум 18.
- Границы `f`/`e` (`0..20`) и `g`/`G` (`1..21`) не меняются.
- Production change выполняется только после подтверждённого RED-теста.
- Все shell-команды запускаются через `rtk`.

---

### Task 1: Защитить `n` от небезопасной precision

**Files:**
- Modify: `test/format_test.dart`
- Modify: `lib/src/processor.dart`

**Interfaces:**
- Consumes: `format(String, List<Object?>)` и `InvalidFormatException`.
- Produces: безопасный контракт precision `1..18` для `n`.

- [ ] **Step 1: Написать regression-тест через публичный API**

Добавить в группу `bugs:`:

```dart
test('n rejects precision that intl cannot represent safely', () {
  expect(format('{:.18n}', [0.1]), '0.1');
  expect(
    () => format('{:.19n}', [0.1]),
    throwsA(
      isA<InvalidFormatException>()
          .having((error) => error.fragment, 'fragment', '{:.19n}')
          .having((error) => error.reason, 'reason', contains('<= 18')),
    ),
  );
});
```

- [ ] **Step 2: Подтвердить RED**

Run:

```bash
rtk dart test test/format_test.dart --plain-name "n rejects precision that intl cannot represent safely"
```

Expected: FAIL, потому что `.19n` возвращает искажённую строку вместо
`InvalidFormatException`.

- [ ] **Step 3: Реализовать минимальную validation**

В `_intlNumberFormat` заменить верхнюю границу precision 21 на 18 и обновить
структурированную причину:

```dart
if (precision > 18) {
  throw InvalidFormatException(
    fragment: options.all ?? '',
    reason: 'Precision must be <= 18. Passed $precision.',
  );
}
```

Не изменять `NumberFormatter`, `BuiltInFormatters.general` или границы других
specifier.

- [ ] **Step 4: Подтвердить GREEN и отсутствие локальной регрессии**

Run:

```bash
rtk dart test test/format_test.dart --plain-name "n rejects precision that intl cannot represent safely"
rtk dart test test/format_test.dart --plain-name "Format specifier n"
rtk dart analyze
```

Expected: targeted tests pass; analyzer reports no issues.

- [ ] **Step 5: Выполнить полный release verification**

Run:

```bash
rtk dart format --output=none --set-exit-if-changed lib test example example2
rtk dart test --chain-stack-traces
```

Run из `example`:

```bash
rtk dart analyze
rtk dart run bin/benchmark.dart
rtk dart compile exe bin/benchmark.dart -o /private/tmp/format-2-benchmark
rtk /private/tmp/format-2-benchmark
```

Expected: все тесты проходят; JIT/AOT paired ratios для 5/10/50 не выше
`1.02`.

Run из root:

```bash
rtk dart pub publish --dry-run
rtk git diff --check
```

Expected: publish validation имеет 0 warnings; diff check проходит.

- [ ] **Step 6: Commit**

```bash
rtk git add lib/src/processor.dart test/format_test.dart
rtk git commit -m "fix: guard intl number precision"
```
