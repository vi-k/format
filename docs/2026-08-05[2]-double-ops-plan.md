# План реализации: горячие double-op'ы (IR, итерация 2)

Статус: исполнен, вошло в 3.0.0. Чекбоксы в теле не проставлялись — открытым пунктом их читать нельзя.

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Снять regex, разрезание/пересборку body и конкатенации
паддинга с double-пути обоих диалектов, добавив `_BraceDoubleOp`,
`_PrintfDoubleOp` и double-ветку в `_BraceDynamicValueOp` поверх
существующих генераторов `_AsciiFloat`.

**Architecture:** Генерация цифр не меняется (`_formatDartDouble`,
`_formatFixed`/`_formatScientific`/`_formatGeneral`/`_formatShortest`,
`_formatSpecialDouble`); op'ы читают режим/spelling/локаль из
`frame.engine` в рантайме (кэш программ зависит только от шаблона и
`TextUnit`) и пишут sign/body/суффикс/паддинг напрямую в `CharSink`
через общий писатель `_writeAsciiFloatDirect`.

**Tech Stack:** Dart ≥3, `package:test`, инфраструктура IR v1
(`lib/src/template_ir.dart`, дифф-харнес с паритетом контекстов,
A/B-бенчмарк `example/bin/template_ir_benchmark.dart`).

Спека: `docs/2026-08-05[1]-double-ops-design.md`.

## Global Constraints

- `dart analyze lib test example` — ноль замечаний после каждой
  задачи (info-уровень считается).
- Seam-импорты в тестах — ТОЛЬКО `package:format/src/engine.dart`.
- Тесты кэша/программ зовут `debugClearTemplateCaches()` в `setUp`.
- Весь существующий suite остаётся зелёным; ПАРИТЕТ С LEGACY
  ГЛАВЕНСТВУЕТ над дословным кодом плана: если дифф-тест ловит
  расхождение с текстом плана — прав legacy, правится план-код
  (урок v1, Task 5).
- Порядок ошибок сохраняется: в dartSdk-режиме
  `_validateDartDoublePrecision` зовётся ДО проверки isFinite (как
  в legacy) — невалидная precision на nan обязана кидать.
- Node-прогон дифф-тестов обязателен на каждой op-задаче: SDK-строки
  на JS другие, паритет с legacy — по построению, это и проверяем.
- Комментарии в коде — по-английски; HANDOFF.md — по-русски.
- Правило проекта: нет performance GREEN — нет коммита
  perf-изменения (гейт — Task 5).
- Перед замерами `sysctl -n vm.loadavg` (< 5).
- Трейлер каждого коммита:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## Структура файлов

- Modify: `lib/src/template_ir.dart` — писатель, оба op'а, ветки
  классификаторов, double-ветка `_BraceDynamicValueOp`.
- Test: `test/template_ir_compile_test.dart`,
  `test/template_ir_diff_test.dart`.
- Modify: `example/lib/src/template_ir_benchmark.dart` (+ тест
  `example/test/template_ir_benchmark_test.dart`).
- Modify: `HANDOFF.md` (Task 5).

RED-числа: перед задачей 1 контроллер снимает
`dart run example/bin/benchmark.dart` (quick) в workspace плана;
интерес — сценарии `brace.double.*` и printf `f/e/g`.

---

### Task 1: `_writeAsciiFloatDirect` + `_BraceDoubleOp`

**Files:**
- Modify: `lib/src/template_ir.dart`
- Test: `test/template_ir_compile_test.dart`,
  `test/template_ir_diff_test.dart`

**Interfaces:**
- Consumes: `CharSink` (fill/writeCharCode/writeString),
  `frame._argument`, `formatParsedValue`, `_isIntegerValue`,
  `_formatSpecialDouble`, `_formatDartDouble`,
  `_validateDartDoublePrecision`, `_formatFixed`,
  `_formatScientific`, `_formatGeneral`, `_formatShortest`,
  `_AsciiFloat`, `Binary64`, `DoubleFormatMode`,
  `field.memoizedSpec/memoizeSpec` (гейтинг уже в
  `_classifyBraceField`), харнес `expectBraceParity`.
- Produces:
  - `void _writeAsciiFloatDirect(CharSink sink, String body,
    int signChar, bool percentSuffix, int width, int fillChar,
    int align)` — контент = (signChar==0?0:1) + body.length +
    (percentSuffix?1:0); порядок записи по align: `>` fill→sign→
    body→'%'; `=` sign→fill→body→'%'; `<` sign→body→'%'→fill;
    `^` fill(p~/2)→sign→body→'%'→fill(rest). Переиспользуется
    Task 2-3.
  - `_BraceDoubleOp` с `describe()` вида `double:<type|- >` +
    `:p<n>`/`:w<n>`.
  - Ветки классификатора: `case 'f'||'F'||'e'||'E'||'g'||'G'||'%'`
    и null-тип (непустая спека без типа) — обе с гейтом
    `spec.precision > 100000 → null` (fallback хранит legacy-ошибку
    _validateDoubleSpec).

- [ ] **Step 1: Падающие compile-тесты**

В `test/template_ir_compile_test.dart`:

```dart
  test('static double specs compile to double ops', () {
    expect(
      debugCompiledProgramDescription(
        '{:.2f}|{:e}|{:10.3G}|{:.1%}|{:.3}|{:10}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['double:f:p2', 'literal', 'double:e', 'literal',
          'double:G:w10:p3', 'literal', 'double:%:p1', 'literal',
          'double:-:p3', 'literal', 'double:-:w10'],
    );
  });

  test('non-hot double specs stay on fallback', () {
    for (final spec in ['{:,.2f}', '{:.2n}', '{:é^10.2f}']) {
      expect(
        debugCompiledProgramDescription(
          spec,
          printf: false,
          textUnit: TextUnit.unicodeScalars,
        ),
        ['fallback'],
        reason: spec,
      );
    }
  });
```

(`é` в fallback-пине — составная форма e+U+0301, как в v1;
писать escape'ом `́`.)

- [ ] **Step 2: Падающие дифф-тесты**

В `test/template_ir_diff_test.dart` (compatible-движки добавить
рядом с существующими финалами):

```dart
final compatibleFormat =
    Format(doubleFormatMode: DoubleFormatMode.compatible);
final compatibleGraphemes = Format(
  doubleFormatMode: DoubleFormatMode.compatible,
  textUnit: TextUnit.graphemeClusters,
);

  test('double op matches the legacy path across specs and values', () {
    const specs = [
      '{:f}', '{:.0f}', '{:.2f}', '{:10.2f}', '{:<10.2f}',
      '{:^10.2f}', '{:=10.2f}', '{:010.2f}', '{:+.2f}', '{: .2f}',
      '{:z.1f}', '{:#.0f}', '{:e}', '{:.3e}', '{:E}', '{:g}',
      '{:.3g}', '{:G}', '{:.1%}', '{:.3}', '{:10.3}', '{:>10}',
      '{:F}', '{:.25f}',
    ];
    final values = <Object?>[
      0.0, -0.0, 0.1, 2.5, -2.5, 12345678901234.568, 1e21, 1e-7,
      double.minPositive, double.maxFinite, double.nan,
      double.infinity, double.negativeInfinity,
      42, -7, BigInt.parse('123456789012345678901234567890'),
      'text', true, null,
    ];
    for (final spec in specs) {
      for (final value in values) {
        expectBraceParity(spec, positional: [value]);
        expectBraceParity(spec, positional: [value],
            engine: graphemeFormat);
        expectBraceParity(spec, positional: [value],
            engine: compatibleFormat);
        expectBraceParity(spec, positional: [value],
            engine: compatibleGraphemes);
      }
    }
  });
```

Run: `dart test test/template_ir_compile_test.dart` — FAIL
(fallback вместо double); дифф-тест уже PASS через fallback —
страховка Step 3.

- [ ] **Step 3: Реализация**

Писатель:

```dart
void _writeAsciiFloatDirect(
  CharSink sink,
  String body,
  int signChar,
  bool percentSuffix,
  int width,
  int fillChar,
  int align,
) {
  final content =
      body.length + (signChar == 0 ? 0 : 1) + (percentSuffix ? 1 : 0);
  final padding = width < 0 ? 0 : width - content;
  if (align == 0x3e) {
    sink.fill(fillChar, padding);
  } else if (align == 0x5e) {
    sink.fill(fillChar, padding ~/ 2);
  }
  if (signChar != 0) sink.writeCharCode(signChar);
  if (align == 0x3d) sink.fill(fillChar, padding);
  sink.writeString(body);
  if (percentSuffix) sink.writeCharCode(0x25);
  if (align == 0x3c) {
    sink.fill(fillChar, padding);
  } else if (align == 0x5e) {
    sink.fill(fillChar, padding - padding ~/ 2);
  }
}
```

Op (поля/конструктор полностью; порядок ветвей — это и есть
контракт паритета):

```dart
final class _BraceDoubleOp extends _BraceOp {
  final _FieldNode field;
  final int argumentIndex;
  final String? argumentName;
  final String specifierText;
  final _FormatSpec spec; // delegate branch + generator params
  final String? type; // null = default presentation
  final int? precision;
  final bool alternate;
  final int requestedSign; // 0x2b '+', 0x20 ' ', 0 none
  final bool normalizeNegativeZero;
  final bool percent;
  final int width; // -1 none
  final int fillChar;
  final int align;

  const _BraceDoubleOp({
    required this.field,
    required this.argumentIndex,
    required this.argumentName,
    required this.specifierText,
    required this.spec,
    required this.type,
    required this.precision,
    required this.alternate,
    required this.requestedSign,
    required this.normalizeNegativeZero,
    required this.percent,
    required this.width,
    required this.fillChar,
    required this.align,
  });

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    final value = frame._argument(argumentIndex, argumentName, field);
    final double converted;
    if (value is double) {
      converted = value;
    } else if ((value is int && _isIntegerValue(value)) ||
        value is BigInt) {
      converted = switch (value) {
        final int number => number.toDouble(),
        _ => (value as BigInt).toDouble(),
      };
      if (!converted.isFinite) {
        throw UnsupportedFormatValueException(_context(frame), value);
      }
    } else {
      // The generic path reproduces legacy exactly: text output for
      // strings under a null type, today's errors for everything else.
      sink.writeString(
        formatParsedValue(value, spec, frame.engine, _context(frame)),
      );
      return;
    }

    final engine = frame.engine;
    final uppercase = type == 'E' || type == 'F' || type == 'G';
    final formattingValue = percent ? converted * 100 : converted;
    if (engine.doubleFormatMode == DoubleFormatMode.dartSdk) {
      // Legacy validates before the finiteness check: bad precision on
      // nan must still throw.
      _validateDartDoublePrecision(type, precision, _context(frame));
    }

    late final _AsciiFloat formatted;
    if (!formattingValue.isFinite) {
      formatted = _formatSpecialDouble(formattingValue, uppercase, engine);
    } else if (engine.doubleFormatMode == DoubleFormatMode.dartSdk) {
      formatted = _formatDartDouble(
        formattingValue,
        type,
        precision,
        alternate,
        _context(frame),
      );
    } else if (type == null && precision == null) {
      formatted = _formatShortest(converted, alternate);
    } else {
      final effective = precision ?? 6;
      formatted = switch (type) {
        'f' || 'F' => _formatFixed(converted, effective, alternate),
        'e' || 'E' => _formatScientific(
          Binary64.fromDouble(converted),
          effective,
          alternate,
          type!,
        ),
        'g' || 'G' => _formatGeneral(
          Binary64.fromDouble(converted),
          effective == 0 ? 1 : effective,
          alternate,
          type == 'G' ? 'E' : 'e',
        ),
        '%' => _formatFixed(formattingValue, effective, alternate),
        null => _formatGeneral(
          Binary64.fromDouble(converted),
          effective == 0 ? 1 : effective,
          alternate,
          'e',
          emptyType: true,
        ),
        _ => throw StateError('Unsupported floating presentation: $type'),
      };
    }

    var negative =
        !formattingValue.isNaN && formattingValue.isNegative;
    if (normalizeNegativeZero && formatted.roundedZero) negative = false;
    final signChar = negative ? 0x2d : requestedSign;
    _writeAsciiFloatDirect(
      sink,
      formatted.body,
      signChar,
      percent,
      width,
      fillChar,
      align,
    );
  }

  FormatExceptionContext _context(_BraceProcessor frame) =>
      FormatExceptionContext(
        template: frame.template,
        offset: field.offset,
        fragment: field.fragment,
        specifier: specifierText,
      );

  @override
  String describe() {
    final buffer = StringBuffer('double:${type ?? '-'}');
    if (width >= 0) buffer.write(':w$width');
    if (precision != null) buffer.write(':p$precision');
    return buffer.toString();
  }
}
```

Классификатор — общий строитель, зовётся из двух мест:

```dart
_BraceDoubleOp _buildBraceDoubleOp(
  _FieldNode field,
  int argumentIndex,
  String? argumentName,
  String specText,
  _FormatSpec spec,
) => _BraceDoubleOp(
  field: field,
  argumentIndex: argumentIndex,
  argumentName: argumentName,
  specifierText: specText,
  spec: spec,
  type: spec.type,
  precision: spec.precision,
  alternate: spec.alternate,
  requestedSign: switch (spec.sign) {
    '+' => 0x2b,
    ' ' => 0x20,
    _ => 0,
  },
  normalizeNegativeZero: spec.normalizeNegativeZero,
  percent: spec.type == '%',
  width: spec.width ?? -1,
  fillChar: (spec.fill ?? (spec.zero ? '0' : ' ')).codeUnitAt(0),
  align: (spec.align ?? (spec.zero ? '=' : '>')).codeUnitAt(0),
);
```

В `_classifyBraceField` после существующего гейтинга (customName/
payload/multi-unit fill уже проверены):

- перед `switch (spec.type)`: `if (spec.type == null)` — непустая
  спека без типа (пустая ушла в `_BraceDynamicValueOp` раньше):
  `if (spec.grouping != null || spec.fractionalGrouping != null ||
  (spec.precision != null && spec.precision! > 100000)) return
  null;` иначе `return _buildBraceDoubleOp(...)`;
- в switch новая ветка:

```dart
    case 'f' || 'F' || 'e' || 'E' || 'g' || 'G' || '%':
      if (spec.grouping != null ||
          spec.fractionalGrouping != null ||
          (spec.precision != null && spec.precision! > 100000)) {
        return null;
      }
      return _buildBraceDoubleOp(
        field, argumentIndex, argumentName, specText, spec);
```

(`'n'` в ветку не входит — остаётся default → fallback.)

- [ ] **Step 4: Прогоны**

Run: `dart test test/template_ir_compile_test.dart test/template_ir_diff_test.dart && dart test && dart analyze lib test example && dart test -p node test/template_ir_diff_test.dart`
Expected: всё PASS, analyzer 0.

- [ ] **Step 5: Commit**

```bash
git add lib/src/template_ir.dart test/template_ir_compile_test.dart \
  test/template_ir_diff_test.dart
git commit -m "perf: write static double brace fields directly into the sink"
```

---

### Task 2: double-ветка в `_BraceDynamicValueOp`

**Files:**
- Modify: `lib/src/template_ir.dart`
- Test: `test/template_ir_diff_test.dart`

**Interfaces:**
- Consumes: `_formatSpecialDouble`, `_formatDartDouble`,
  `_formatShortest`, `DoubleFormatMode`.
- Produces: ветка `value is double` в `_BraceDynamicValueOp.write`
  перед медленной веткой.

- [ ] **Step 1: Падающий-по-смыслу дифф-тест**

```dart
  test('empty-spec doubles stay identical across modes', () {
    for (final value in <double>[
      0.0, -0.0, 0.1, 2.5, 3.14159, 1e21, 1e-7, double.nan,
      double.infinity, double.negativeInfinity,
    ]) {
      expectBraceParity('<{}>', positional: [value]);
      expectBraceParity('<{}>', positional: [value],
          engine: compatibleFormat);
    }
  });
```

(Проходит и до реализации — через медленную ветку; страхует Step 2.)

- [ ] **Step 2: Реализация**

В `_BraceDynamicValueOp.write`, после ветки bool/null, перед
generic-веткой:

```dart
    if (value is double) {
      final engine = frame.engine;
      late final _AsciiFloat formatted;
      if (!value.isFinite) {
        formatted = _formatSpecialDouble(value, false, engine);
      } else if (engine.doubleFormatMode == DoubleFormatMode.dartSdk) {
        formatted =
            _formatDartDouble(value, null, null, false, _context(frame));
      } else {
        formatted = _formatShortest(value, false);
      }
      if (!value.isNaN && value.isNegative) sink.writeCharCode(0x2d);
      sink.writeString(formatted.body);
      return;
    }
```

(Сегодня `_BraceDynamicValueOp` строит `FormatExceptionContext`
инлайн в generic-ветке — вынести это построение в приватный метод
`_context(frame)` (specifier: '') и использовать из обеих веток.)

Замечание: чистый `{}` остаётся zero-copy только для строк; для
double первая запись — либо минус (writeCharCode), либо body
(writeString → single-string режим сохраняется для положительных).

- [ ] **Step 3: Прогоны и commit**

Run: как в Task 1 Step 4.

```bash
git add lib/src/template_ir.dart test/template_ir_diff_test.dart
git commit -m "perf: write empty-spec doubles directly into the sink"
```

---

### Task 3: `_PrintfDoubleOp`

**Files:**
- Modify: `lib/src/template_ir.dart`
- Test: `test/template_ir_compile_test.dart`,
  `test/template_ir_diff_test.dart`

**Interfaces:**
- Consumes: `_resolveIrPrintfOption`, `frame._argumentAt`,
  `_writeAsciiFloatDirect` (Task 1), `_formatPrintfDouble` (медленная
  ветка — вызывается с готовым `_ResolvedPrintfConversion`),
  `_PrintfFlags`, `_maximumSafePrintfOption`, `CNumberLocale`,
  `_formatSpecialDouble`, `_formatDartDouble`,
  `_validateDartDoublePrecision`, `_formatFixed`,
  `_formatScientific`, `_formatGeneral`, `Binary64`,
  харнес `expectPrintfParity`.
- Produces: `_PrintfDoubleOp` с describe `double:<type>` +
  `:w<n>/:w*/:p<n>/:p*`; ветка `f/F/e/E/g/G` в
  `_classifyPrintfConversion` (гейтинг статических опций — как у
  `'s'`-ветки v1); `a/A` остаются default → fallback.

- [ ] **Step 1: Падающий compile-тест**

```dart
  test('printf doubles compile to double ops, %a stays fallback', () {
    expect(
      debugCompiledProgramDescription(
        '%f|%.2f|%-10.2f|%010.2f|%e|%.3G|%*.*f|%a',
        printf: true,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['double:f', 'literal', 'double:f:p2', 'literal',
          'double:f:w10:p2', 'literal', 'double:f:w10:p2', 'literal',
          'double:e', 'literal', 'double:G:p3', 'literal',
          'double:f:w*:p*', 'literal', 'fallback'],
    );
  });
```

- [ ] **Step 2: Падающие-по-смыслу дифф-тесты**

```dart
  test('printf double op matches the legacy path', () {
    const templates = [
      '%f', '%.0f', '%.2f', '%10.2f', '%-10.2f', '%010.2f',
      '%+.2f', '% .2f', '%#.0f', '%e', '%.3e', '%E', '%g', '%.3g',
      '%G', '%F',
    ];
    final values = <Object?>[
      0.0, -0.0, 0.1, 2.5, -2.5, 12345678901234.568, 1e21, 1e-7,
      double.maxFinite, double.nan, double.infinity,
      double.negativeInfinity, 42, 'text', null,
    ];
    for (final template in templates) {
      for (final value in values) {
        expectPrintfParity(template, [value]);
        expectPrintfParity(template, [value], engine: compatibleFormat);
      }
    }
    for (final width in [0, 8, -8, 100001]) {
      expectPrintfParity('%*.2f', [width, 2.5]);
    }
    for (final precision in [0, 3, -1, 100001]) {
      expectPrintfParity('%.*f', [precision, 2.5]);
    }
    expectPrintfParity('%*.*f', [12, 3, -2.5]);
  });

  test('printf double op falls back to slow path for custom locales', () {
    final locale = Format(numberLocale: const _IrTestNumberLocale());
    for (final template in ['%.2f', '%10.2f', '%e', '%.3g']) {
      for (final value in [2.5, -2.5, double.nan, 1e21]) {
        expectPrintfParity(template, [value], engine: locale);
      }
    }
  });
```

Локаль: публичной недефолтной в пакете нет (только `CNumberLocale`);
объявить в этом тест-файле `_IrTestNumberLocale` по образцу
`_PrintfNumberLocale` из `test/sprintf_double_test.dart` (тот же
набор членов интерфейса; достаточно отличий вроде
`decimalSeparator: ','` и `minusSign: '−'`, остальное — как у
образца).

- [ ] **Step 3: Реализация**

Поля: `node`, `valueArgIndex`, `type`, `left`, `alternate`,
`signFlag`, `spaceFlag`, `zeroFlag` + тройки
`hasWidth/staticWidth/widthArgIndex` и
`hasPrecision/staticPrecision/precisionArgIndex` (как у
`_PrintfStringOp`). `write()`:

```dart
  @override
  void write(CharSink sink, _PrintfProcessor frame) {
    var effectiveLeft = left;
    int? width;
    if (hasWidth) {
      var resolved =
          widthArgIndex < 0
              ? staticWidth
              : _resolveIrPrintfOption(frame, node, widthArgIndex, 'width');
      if (resolved < 0) {
        effectiveLeft = true;
        resolved = -resolved;
      }
      width = resolved;
    }
    int? precision;
    if (hasPrecision) {
      final resolved =
          precisionArgIndex < 0
              ? staticPrecision
              : _resolveIrPrintfOption(
                frame,
                node,
                precisionArgIndex,
                'precision',
              );
      if (resolved >= 0) precision = resolved;
    }
    final argument = frame._argumentAt(valueArgIndex, node);
    final context = _printfContext(
      frame.template,
      node,
      argumentIndex: valueArgIndex,
    );
    if (argument is! double) {
      throw UnsupportedFormatValueException(context, argument);
    }
    final engine = frame.engine;

    if (!identical(engine.numberLocale, const CNumberLocale())) {
      // Non-default locales localize digits/signs/separators; the legacy
      // tail reproduces that exactly, at legacy cost.
      var flags = node.flags;
      if (effectiveLeft) flags |= _PrintfFlags.left;
      sink.writeString(
        _formatPrintfDouble(
          argument,
          _ResolvedPrintfConversion(
            node: node,
            flags: flags,
            width: width,
            precision: precision,
          ),
          engine,
          context,
        ),
      );
      return;
    }

    final uppercase = type == 'E' || type == 'F' || type == 'G';
    if (engine.doubleFormatMode == DoubleFormatMode.dartSdk) {
      _validateDartDoublePrecision(type, precision, context);
    }
    late final _AsciiFloat formatted;
    if (!argument.isFinite) {
      formatted = _formatSpecialDouble(argument, uppercase, engine);
    } else if (engine.doubleFormatMode == DoubleFormatMode.dartSdk) {
      formatted = _formatDartDouble(
        argument,
        type,
        precision,
        alternate,
        context,
      );
    } else {
      final effective = precision ?? 6;
      formatted = switch (type) {
        'f' || 'F' => _formatFixed(argument, effective, alternate),
        'e' || 'E' => _formatScientific(
          Binary64.fromDouble(argument),
          effective,
          alternate,
          type,
        ),
        _ => _formatGeneral(
          Binary64.fromDouble(argument),
          effective == 0 ? 1 : effective,
          alternate,
          type == 'G' ? 'E' : 'e',
        ),
      };
    }

    final negative = !argument.isNaN && argument.isNegative;
    final signChar =
        negative
            ? 0x2d
            : signFlag
            ? 0x2b
            : spaceFlag
            ? 0x20
            : 0;
    final zero = zeroFlag && !effectiveLeft && !formatted.special;
    _writeAsciiFloatDirect(
      sink,
      formatted.body,
      signChar,
      false,
      width ?? -1,
      zero ? 0x30 : 0x20,
      effectiveLeft
          ? 0x3c
          : zero
          ? 0x3d
          : 0x3e,
    );
  }
```

Ветка классификатора `case 'f' || 'F' || 'e' || 'E' || 'g' || 'G':`
— гейтинг и фолдинг статических опций дословно как в `'s'`-ветке v1
(литералы вне `_maximumSafePrintfOption` → null; отрицательная
статическая ширина → left+abs; отрицательная статическая precision →
`hasPrecision = false`).

- [ ] **Step 4: Прогоны и commit**

Run: как в Task 1 Step 4 (+ compile-тест файла).

```bash
git add lib/src/template_ir.dart test/template_ir_compile_test.dart \
  test/template_ir_diff_test.dart
git commit -m "perf: write printf double conversions directly into the sink"
```

---

### Task 4: A/B-бенчмарк — double-сценарии

**Files:**
- Modify: `example/lib/src/template_ir_benchmark.dart`
- Test: `example/test/template_ir_benchmark_test.dart`

**Interfaces:**
- Consumes: существующие `_IrScenario`, seam'ы, `compatibleFormat`
  придётся объявить в файле бенчмарка
  (`Format(doubleFormatMode: DoubleFormatMode.compatible)`).
- Produces: hot-сценарии `{:.2f}` (dartSdk), `{:.2f}` (compatible),
  `%.2f`, `{:e}`, `{}` c 3.14159; fallback-control `{:.2f}`
  ЗАМЕНЯЕТСЯ на `{:,.2f}` (grouping — честный fallback);
  грапемный контроль остаётся. Итог: 13 hot + 2 fallback-control =
  15 сценариев.

- [ ] **Step 1: Обновить интеграционный тест (падает по счёту)**

В `example/test/template_ir_benchmark_test.dart`: ожидание
вердиктов `10` → `15`; `contains('{:.2f}')` остаётся (теперь hot),
добавить `expect(output, contains('{:,.2f}'))` и
`contains('compatible')` (метка сценария compatible-режима).

- [ ] **Step 2: Реализация сценариев**

По образцу существующих: IR — `formatWith`/`vsprintf` с const-аргументами
(урок v1: никакого variadic-маршаллинга), legacy — seam'ы с теми же
движками. Метки: `{:.2f}`, `{:.2f} compatible`, `%.2f`, `{:e}`,
`{}` (double), `{:,.2f}` (kind: fallback-control).

- [ ] **Step 3: Прогоны и commit**

Run: `cd example && dart test test/template_ir_benchmark_test.dart && dart test`; из корня `dart analyze lib test example`; живой прогон
`dart run example/bin/template_ir_benchmark.dart` — 15 сценариев,
ноль `RESULTS DIFFER`, double-hot ожидаемо `IR FASTER`.

```bash
git add example/lib/src/template_ir_benchmark.dart \
  example/test/template_ir_benchmark_test.dart
git commit -m "bench: cover double ops in the IR A/B benchmark"
```

---

### Task 5: Верификация, гейт, handoff

**Files:**
- Modify: `HANDOFF.md`

- [ ] **Step 1: Полный прогон**

Run: `dart test && (cd example && dart test) && dart test -p node test/char_sink_test.dart test/template_ir_compile_test.dart test/template_ir_diff_test.dart && dart analyze lib test example`
Expected: всё зелёное, 0 замечаний.

- [ ] **Step 2: A/B**

`sysctl -n vm.loadavg` (<5), затем два прогона
`dart run example/bin/template_ir_benchmark.dart`.
GATE: ноль `RESULTS DIFFER`, ноль `LEGACY FASTER`; double-hot
сценарии `IR FASTER`; `{:,.2f}` и грапемный контроль не хуже EQUAL.

- [ ] **Step 3: Полная матрица против RED**

`dart run example/bin/benchmark.dart` (quick). GATE: double-сценарии
(`brace.double.*`, printf `f/e/g`) устойчиво быстрее RED-числ
контроллера; остальные — в пределах existing equivalence threshold;
cold не хуже; ровно один намеренный ERROR; ≤ 60 с.

- [ ] **Step 4: Решение по гейту**

Нет GREEN — не коммитить handoff; профилировать (первые
подозреваемые: лишние ветвления в горячем write, промах
compile-гейтинга — сценарий тихо ушёл в fallback, проверить
`debugCompiledProgramDescription`), чинить, повторять шаги 1-3.

- [ ] **Step 5: HANDOFF.md + commit**

Отразить: double-op'ы (охват, рантайм-чтение режима/локали,
писатель), RED→GREEN обеих матриц, новый состав A/B (15 сценариев),
обновлённые счётчики тестов, оставшиеся резервы (dtoa-in-sink,
пул sink'ов, удаление legacy — по-прежнему конфликтует с
A/B-baseline).

```bash
git add HANDOFF.md
git commit -m "docs: record double op results and refresh handoff"
```

---

## Self-review плана (выполнен)

- Покрытие спеки: писатель+brace-op — Task 1; `{}` — Task 2;
  printf-op с локальным гвардом — Task 3; A/B — Task 4; гейт/handoff
  — Task 5. RED — пре-шаг контроллера. Вне охвата ничего не добавлено.
- Порядок ошибок: dartSdk-валидация precision до isFinite —
  зафиксирована в Global Constraints и в коде обоих op'ов.
- Полиморфизм null-типа: `{:10.3}`/`{:>10}` — hot для double,
  делегирование для остальных типов (текст для String — легально);
  дифф-матрица Task 1 содержит 'text'/42/BigInt/true/null на всех
  спеках, включая null-тип.
- Сигнатуры сведены: `_writeAsciiFloatDirect` (Task 1) используется
  Task 3; тройки опций и резолвер — из v1 без изменений;
  `_formatPrintfDouble` вызывается с готовым
  `_ResolvedPrintfConversion` (медленная ветка) — flags дополняются
  left-фолдом динамической отрицательной ширины.
- Ловушки v1 повторены: паритет главенствует над дословным кодом,
  node-прогон обязателен, variadic-маршаллинг в бенчмарке запрещён,
  составной `é` — escape'ом.
