# План реализации: IR-hardening + parity-фаззер

> **Состояние на 2026-08-16:** исполнен, вошло в 3.0.0. Чекбоксы в теле не
> проставлялись — открытым пунктом их читать нельзя.
> **Что это:** план закалки IR и первой версии parity-фаззера.
> **Связанные записи:** `2026-08-04[5]-template-ir-design.md`,
> `2026-08-12[1]-parity-fuzzer-expansion-design.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Закрыть пять точечных находок финального ревью v2 (проба
валидатора в классификаторе, явная ветка `g/G`, запекание
precision-вердикта для static-printf, brace×локаль в матрице) и
добавить seeded parity-фаззер против legacy-оракула.

**Architecture:** Никаких новых механизмов: hardening — локальные
правки `lib/src/template_ir.dart`, покрытие — расширение
существующей дифф-матрицы, фаззер — вынос паритет-харнеса в общий
файл `test/parity_harness.dart` и новый `test/template_ir_fuzz_test.dart`
с фиксированным seed'ом.

**Tech Stack:** Dart ≥3, `package:test`, `dart:math` `Random(seed)`.

Источник требований: раздел «Точечные находки финального ревью
ветки» в HANDOFF.md и ledger v2 (уже удалён — формулировки продублированы
здесь).

## Global Constraints

- `dart analyze lib test example` — ноль замечаний после каждой задачи.
- Seam-импорты в тестах — ТОЛЬКО `package:format/src/engine.dart`.
- Весь suite остаётся зелёным; ПАРИТЕТ С LEGACY ГЛАВЕНСТВУЕТ: все
  правки поведенчески нейтральны, любое расхождение в дифф/фазз-тестах
  означает дефект правки.
- Фаззер детерминирован: фиксированный литеральный seed, никаких
  `Date.now()`/нефиксированного `Random()`; кросс-платформенный
  (никаких int-литералов за 2^53, никаких minInt-литералов).
- Node-прогон обязателен для дифф-теста и фаззера.
- Perf-правки (Task 2) подтверждаются A/B-прогоном: ноль
  `RESULTS DIFFER`, ноль `LEGACY FASTER` (правило «нет GREEN — нет
  коммита»).
- Комментарии в коде — по-английски; HANDOFF.md — по-русски.
- Трейлер каждого коммита:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## Структура файлов

- Modify: `lib/src/template_ir.dart` (Tasks 1-2).
- Create: `test/parity_harness.dart` (Task 4 — вынос из дифф-теста).
- Create: `test/template_ir_fuzz_test.dart` (Task 4).
- Modify: `test/template_ir_compile_test.dart` (Task 1),
  `test/template_ir_diff_test.dart` (Tasks 1, 3, 4).
- Modify: `HANDOFF.md` (Task 5).

---

### Task 1: Hardening классификатора и printf-switch

**Files:**
- Modify: `lib/src/template_ir.dart` (`_rejectsHotDouble` ~:599;
  printf-body-switch `_ => _formatGeneral` ~:1258)
- Test: `test/template_ir_compile_test.dart`,
  `test/template_ir_diff_test.dart`

**Interfaces:**
- Consumes: `_validateDoubleSpec` (number_format.dart),
  `FormattingException`, `const FormatExceptionContext()` — образец
  пробы: `_rejectsDartDoublePrecision` (template_ir.dart:583-594).
- Produces: `_rejectsHotDouble` с пробой валидатора; printf-switch с
  явной веткой `'g' || 'G'` и `_ => throw StateError(...)`.

- [ ] **Step 1: Падающие/пиновые тесты**

Compile-тест (в блок non-hot double пинов):

```dart
  test('oversized double precision stays on fallback', () {
    expect(
      debugCompiledProgramDescription(
        '{:.100001f}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['fallback'],
    );
  });
```

Дифф-кейс (в double-матрицу задачи не входит — отдельный тест):

```dart
  test('oversized double precision keeps the legacy error', () {
    expectBraceParity('{:.100001f}', positional: [2.5]);
    expectBraceParity('{:.100001f}', positional: [2.5],
        engine: compatibleFormat);
  });
```

Оба зелёные уже сейчас (правка поведенчески нейтральна) — они
страхуют Step 2.

- [ ] **Step 2: Реализация**

`_rejectsHotDouble` — правило `precision > 100000` заменяется пробой
(grouping-клаузы остаются: это ограничения возможностей op'а, а не
правила валидатора):

```dart
/// True for specifications the double op cannot write directly: grouping
/// needs `_displayFloatBody`, and anything `_validateDoubleSpec` rejects
/// must keep its legacy per-call error, which the op never raises. The
/// validator is probed instead of copied so its rules cannot drift away
/// from the classifier (same pattern as _rejectsDartDoublePrecision).
bool _rejectsHotDouble(_FormatSpec spec) {
  if (spec.grouping != null || spec.fractionalGrouping != null) {
    return true;
  }
  try {
    _validateDoubleSpec(spec, spec.type, const FormatExceptionContext());
    return false;
  } on FormattingException {
    return true;
  }
}
```

Printf-body-switch в `_PrintfDoubleOp.write` (ветка `_ =>
_formatGeneral(...)` становится явной, default — стоп-кран, как у
`_BraceDoubleOp` ~:500):

```dart
        'g' || 'G' => _formatGeneral(
          Binary64.fromDouble(argument),
          effective == 0 ? 1 : effective,
          alternate,
          type == 'G' ? 'E' : 'e',
        ),
        _ => throw StateError(
          'Unsupported decimal printf conversion: $type',
        ),
```

- [ ] **Step 3: Прогоны**

Run: `dart test test/template_ir_compile_test.dart test/template_ir_diff_test.dart && dart test && dart analyze lib test example && dart test -p node test/template_ir_diff_test.dart`
Expected: всё PASS, analyzer 0.

- [ ] **Step 4: Commit**

```bash
git add lib/src/template_ir.dart test/template_ir_compile_test.dart \
  test/template_ir_diff_test.dart
git commit -m "refactor: probe validators in the double classifier"
```

---

### Task 2: Perf-запекания

**Files:**
- Modify: `lib/src/template_ir.dart`

**Interfaces:**
- Consumes: `_rejectsDartDoublePrecision(String? type, int? precision)`
  (:583), `_PrintfDoubleOp` (:1145, поля `hasPrecision`/
  `staticPrecision`/`precisionArgIndex`), `_validateDartDoublePrecision`.
- Produces: поле `_PrintfDoubleOp.staticPrecisionRejected` (bool);
  `final` вместо `late final _AsciiFloat formatted` (3 места: ~:101,
  ~:464, внутри `_PrintfDoubleOp.write`); поле `uppercase` (bool),
  запечённое конструкторами обоих double-op'ов вместо пересчёта в
  `write()`.

- [ ] **Step 1: Реализация (тесты уже есть — вся дифф-матрица)**

1. `_PrintfDoubleOp`: новое поле `final bool staticPrecisionRejected;`.
   Классификатор: при `precisionArgIndex < 0 && hasPrecision` —
   `staticPrecisionRejected: _rejectsDartDoublePrecision(node.type, staticPrecision)`;
   иначе `staticPrecisionRejected: false` (поле не используется). В
   `write()` dartSdk-ветка:
   `final rejected = precisionArgIndex < 0 ? staticPrecisionRejected : _rejectsDartDoublePrecision(type, precision);`
   — при `rejected` строится контекст и зовётся настоящий
   `_validateDartDoublePrecision` (бросает с тем же сообщением и в той
   же точке потока — до isFinite); иначе валидация пропускается без
   аллокаций. Для динамической отрицательной precision `precision`
   уже `null` → проба возвращает false → пропуск, как у legacy
   (валидатор начинается с `if (precision == null) return;`). Точный
   вид согласовать с существующим паттерном brace-op'а (~:455-461).
2. Три `late final _AsciiFloat formatted;` → `final _AsciiFloat formatted;`
   (каждая if/else-цепочка присваивает на всех путях — definite
   assignment проходит).
3. `uppercase`: в `_BraceDoubleOp` и `_PrintfDoubleOp` добавить
   `final bool uppercase;`, вычислять в `_buildBraceDoubleOp`/
   классификаторе (`type == 'E' || type == 'F' || type == 'G'`),
   строку-пересчёт в `write()` удалить.

- [ ] **Step 2: Прогоны + A/B GREEN**

Run: `dart test && dart analyze lib test example && dart test -p node test/template_ir_diff_test.dart`
Затем `sysctl -n vm.loadavg` (< 5) и
`dart run example/bin/template_ir_benchmark.dart` дважды.
Expected: тесты/analyzer чисто; A/B — ноль `RESULTS DIFFER`, ноль
`LEGACY FASTER`, double-строки не хуже прежних диапазонов (`%.2f`
ожидаемо подрастает). Числа — в отчёт.

- [ ] **Step 3: Commit**

```bash
git add lib/src/template_ir.dart
git commit -m "perf: bake static double op parameters at compile time"
```

---

### Task 3: Расширение дифф-матрицы

**Files:**
- Test: `test/template_ir_diff_test.dart`

**Interfaces:**
- Consumes: `expectBraceParity`/`expectPrintfParity`,
  `_IrTestNumberLocale` (уже в файле), `compatibleFormat`.
- Produces: новые тест-кейсы; финал
  `localeFormat = Format(numberLocale: const _IrTestNumberLocale())`
  и `shortSpellingFormat = Format(doubleSpecialValueSpelling:
  DoubleSpecialValueSpelling.short)` (проверить, что
  `DoubleSpecialValueSpelling` доступен через seam; если нет —
  добавить в engine.dart show-экспорт рядом с `DoubleFormatMode`, с
  комментарием по конвенции).

- [ ] **Step 1: Кейсы (все должны пройти сразу — они пиннят инварианты)**

```dart
  test('brace doubles keep parity under a custom locale', () {
    for (final spec in ['{:.2f}', '{:10.2f}', '{:e}', '{:.3g}', '{:.1%}']) {
      for (final value in <Object?>[2.5, -2.5, double.nan, 1e21]) {
        expectBraceParity(spec, positional: [value], engine: localeFormat);
      }
    }
  });

  test('double edge values keep parity', () {
    // Negative value that rounds to zero: exercises the z-flag
    // suppression through roundedZero, not the trivial -0.0 route.
    expectBraceParity('{:z.1f}', positional: [-0.04]);
    expectBraceParity('{:z.1f}', positional: [-0.04],
        engine: compatibleFormat);
    // BigInt whose toDouble() overflows to infinity: the typed branch
    // must throw like legacy, before any precision validation.
    final huge = BigInt.two.pow(2000);
    expectBraceParity('{:.2f}', positional: [huge]);
    expectBraceParity('{:.2f}', positional: [-huge]);
  });

  test('empty-spec specials keep parity for short spelling', () {
    for (final value in [double.nan, double.infinity,
        double.negativeInfinity]) {
      expectBraceParity('<{}>', positional: [value],
          engine: shortSpellingFormat);
    }
  });

  test('printf doubles keep parity for graphemes and missing args', () {
    expectPrintfParity('%10.2f', [2.5], engine: graphemeFormat);
    expectPrintfParity('%f', const []);
    expectPrintfParity('%*.2f', const []);
  });
```

- [ ] **Step 2: Прогоны и commit**

Run: `dart test test/template_ir_diff_test.dart && dart test && dart analyze lib test example && dart test -p node test/template_ir_diff_test.dart`

```bash
git add test/template_ir_diff_test.dart lib/src/engine.dart
git commit -m "test: pin locale, spelling, and edge-value double parity"
```

(`lib/src/engine.dart` — только если понадобился show-экспорт.)

---

### Task 4: Parity-фаззер

**Files:**
- Create: `test/parity_harness.dart`
- Create: `test/template_ir_fuzz_test.dart`
- Modify: `test/template_ir_diff_test.dart` (импорт харнеса)

**Interfaces:**
- Consumes: содержимое харнеса дифф-теста (:4-146 текущего файла).
- Produces: библиотека `test/parity_harness.dart` БЕЗ `main()` (имя
  без суффикса `_test`, чтобы раннер её не подхватывал), экспортирующая:
  `IrTestNumberLocale` (публичное имя вместо `_IrTestNumberLocale`),
  финалы `graphemeFormat`, `compatibleFormat`, `compatibleGraphemes`,
  и функции `expectBraceParity`, `expectPrintfParity`,
  `expectContextParity` — сигнатуры БЕЗ изменений. Дифф-тест
  импортирует харнес и удаляет свои локальные копии (свои финалы
  `localeFormat`/`shortSpellingFormat` из Task 3 остаются в
  дифф-тесте либо переезжают в харнес — на вкус имплементера, но
  фаззеру нужны `IrTestNumberLocale` и все четыре базовых движка).

- [ ] **Step 1: Вынос харнеса**

Механический перенос без изменения логики; `_IrTestNumberLocale` →
`IrTestNumberLocale` (публичное имя — файл живёт в test/, наружу
пакета не попадает). Прогнать `dart test test/template_ir_diff_test.dart`
— зелёный, ноль изменений поведения.

- [ ] **Step 2: Фаззер**

`test/template_ir_fuzz_test.dart` (кросс-платформенный):

```dart
import 'dart:math';

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

import 'parity_harness.dart';

/// Deterministic seed: the fuzzer must reproduce identically on every
/// platform and every run. Bump deliberately (with a comment) if the
/// corpus needs refreshing.
const _seed = 20260805;
const _casesPerDialect = 400;

final _localeFormat = Format(numberLocale: const IrTestNumberLocale());

late final List<Format> _engines = [
  defaultFormat,
  graphemeFormat,
  compatibleFormat,
  compatibleGraphemes,
  _localeFormat,
];

String _braceSpec(Random random) {
  final buffer = StringBuffer();
  // fill+align (fill may be multi-unit -> exercises fallback parity too)
  if (random.nextInt(4) == 0) {
    buffer.write(const ['*', '0', 'é', 'é', '\u{1F600}'][random.nextInt(5)]);
    buffer.write(const ['<', '>', '^', '='][random.nextInt(4)]);
  } else if (random.nextInt(4) == 0) {
    buffer.write(const ['<', '>', '^', '='][random.nextInt(4)]);
  }
  if (random.nextInt(3) == 0) {
    buffer.write(const ['+', '-', ' '][random.nextInt(3)]);
  }
  if (random.nextInt(5) == 0) buffer.write('z');
  if (random.nextInt(5) == 0) buffer.write('#');
  if (random.nextInt(4) == 0) buffer.write('0');
  if (random.nextInt(2) == 0) buffer.write(random.nextInt(25));
  if (random.nextInt(3) == 0) buffer.write(',');
  if (random.nextInt(2) == 0) {
    buffer.write('.');
    buffer.write(random.nextInt(28));
  }
  if (random.nextInt(4) != 0) {
    buffer.write(
      const ['f', 'F', 'e', 'E', 'g', 'G', '%', 'd', 'x', 's', 'n', 'c']
          [random.nextInt(12)],
    );
  }
  return buffer.toString();
}

String _printfTemplate(Random random) {
  final buffer = StringBuffer('%');
  const flags = ['-', '+', ' ', '#', '0'];
  for (final flag in flags) {
    if (random.nextInt(4) == 0) buffer.write(flag);
  }
  if (random.nextInt(3) == 0) {
    buffer.write(random.nextInt(2) == 0 ? '*' : '${random.nextInt(20)}');
  }
  if (random.nextInt(2) == 0) {
    buffer.write('.');
    buffer.write(random.nextInt(2) == 0 ? '*' : '${random.nextInt(25)}');
  }
  buffer.write(
    const ['f', 'F', 'e', 'E', 'g', 'G', 'd', 'i', 'u', 'x', 's']
        [random.nextInt(11)],
  );
  return buffer.toString();
}

Object? _value(Random random) => switch (random.nextInt(8)) {
  0 => random.nextDouble() * pow(10, random.nextInt(40) - 20),
  1 => -random.nextDouble() * pow(10, random.nextInt(40) - 20),
  2 => random.nextInt(1 << 30) - (1 << 29),
  3 => const <double>[0.0, -0.0, double.nan, double.infinity,
      double.negativeInfinity, 2.5, -2.5][random.nextInt(7)],
  4 => 'str${random.nextInt(1000)}',
  5 => BigInt.from(random.nextInt(1 << 30)).pow(1 + random.nextInt(4)),
  6 => null,
  _ => random.nextBool(),
};

void main() {
  test('brace fuzz: IR matches the legacy oracle', () {
    final random = Random(_seed);
    for (var index = 0; index < _casesPerDialect; index++) {
      final spec = _braceSpec(random);
      final template = '<{:$spec}>';
      final value = _value(random);
      final engine = _engines[random.nextInt(_engines.length)];
      expectBraceParity(template, positional: [value], engine: engine);
    }
  });

  test('printf fuzz: IR matches the legacy oracle', () {
    final random = Random(_seed + 1);
    for (var index = 0; index < _casesPerDialect; index++) {
      final template = 'x=${_printfTemplate(random)}!';
      final stars = '*'.allMatches(template).length;
      final values = <Object?>[
        for (var star = 0; star < stars; star++) random.nextInt(30) - 10,
        _value(random),
      ];
      final engine = _engines[random.nextInt(_engines.length)];
      expectPrintfParity(template, values, engine: engine);
    }
  });
}
```

Примечания к макету:
- `late final List<Format> _engines` можно заменить на обычный
  `final` (все зависимости — топ-левел финалы);
- шаблоны с невалидными спеками легальны и ЖЕЛАННЫ: оба пути обязаны
  бросить одинаково (харнес сравнивает и контексты) — не фильтровать;
- время прогона держать ≤ ~5 c на VM (при необходимости снизить
  `_casesPerDialect`, но не ниже 200).

- [ ] **Step 3: Прогоны**

Run: `dart test test/template_ir_fuzz_test.dart test/template_ir_diff_test.dart && dart test && dart analyze lib test example && dart test -p node test/template_ir_fuzz_test.dart test/template_ir_diff_test.dart`
Expected: всё PASS (ноль расхождений — если фаззер нашёл расхождение,
это НАХОДКА: остановиться, задокументировать репро в отчёте,
статус BLOCKED), analyzer 0.

- [ ] **Step 4: Commit**

```bash
git add test/parity_harness.dart test/template_ir_fuzz_test.dart \
  test/template_ir_diff_test.dart
git commit -m "test: add seeded parity fuzzer against the legacy oracle"
```

---

### Task 5: Верификация и handoff

**Files:**
- Modify: `HANDOFF.md`

- [ ] **Step 1: Полный прогон**

Run: `dart test && (cd example && dart test) && dart test -p node test/char_sink_test.dart test/template_ir_compile_test.dart test/template_ir_diff_test.dart test/template_ir_fuzz_test.dart && dart analyze lib test example`
Expected: всё зелёное, 0 замечаний.

- [ ] **Step 2: HANDOFF.md**

- Раздел «Точечные находки финального ревью ветки»: пункты a-d
  пометить закрытыми (коммиты этой связки), пункт e (фаззер) —
  реализован, с seed'ом и числом кейсов.
- Node-команду в проверках дополнить `template_ir_fuzz_test.dart`.
- Обновить счётчики тестов по фактическим прогонам.
- Git-состояние: HEAD/число коммитов.

- [ ] **Step 3: Commit**

```bash
git add HANDOFF.md
git commit -m "docs: record IR hardening and parity fuzzer"
```

---

## Self-review плана (выполнен)

- Все пять находок покрыты: (a) Task 1 проба; (b) Task 1 явная ветка;
  (c) Task 2 запекание; (d) Task 3 brace×локаль; (e) Task 4 фаззер.
  Плюс отложенные minor'ы: late final/uppercase (Task 2), -0.04 и
  BigInt→∞ и short-spelling и '%f',[] и графемный printf (Task 3).
- Фаззер: seed литеральный, кросс-платформенный, харнес переиспользован
  выносом (имена функций не меняются — дифф-тест правится только в
  импортах/удалении локальных копий).
- Perf-гейт Task 2 — A/B-прогоны (не полная матрица: правки
  микроскопические, A/B чувствительнее и быстрее).
- Известные огрехи макета фаззера перечислены в задаче явно.
