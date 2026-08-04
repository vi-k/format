# План реализации: IR-компиляция шаблонов

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Компилировать кэшированные AST обоих диалектов в программы
из sealed op'ов, пишущих напрямую в общий буфер code units, и убрать
промежуточные строки с горячего пути.

**Architecture:** Новый `CharSink` (растущий `Uint16List`) и
sealed-иерархии `_BraceOp`/`_PrintfOp` с компиляторами из AST;
программа мемоизируется на кэшированном шаблоне двумя слотами по
`TextUnit`. Публичные пути переключаются на IR; старые процессоры
остаются под seam'ами `debugFormat*WithoutIr` как baseline
дифф-тестов и A/B-бенчмарка.

**Tech Stack:** Dart ≥3, `package:test`, benchmark-инфраструктура
`example/` (образец — `double_modes_benchmark.dart`).

Спека: `docs/superpowers/specs/2026-08-04-template-ir-design.md`.

## Global Constraints

- Документы, комментарии план/handoff — по-русски; комментарии в
  коде — по-английски (стиль проекта).
- Seam-тесты импортируют движок ТОЛЬКО через
  `package:format/src/engine.dart` — никаких относительных
  `../lib/...` (ловушка двойной библиотеки).
- Тесты, зовущие кэш/программы, выполняют
  `debugClearTemplateCaches()` в `setUp`.
- Литерал минимального int не компилируется dart2js: такие кейсы —
  только в VM-only файле `test/template_ir_vm_test.dart`.
- `dart analyze lib test example` — ноль замечаний после каждой
  задачи.
- Правило проекта: нет performance GREEN — нет коммита
  perf-изменения. Поведенческие задачи гейтятся полным тестовым
  прогоном.
- Перед любым замером: `sysctl -n vm.loadavg` — load < 5.
- Публичный API пакета не меняется; всё новое не экспортируется из
  `format.dart`.

## Структура файлов

- Create: `lib/src/char_sink.dart` — `CharSink` (part of engine).
- Create: `lib/src/template_ir.dart` — op'ы, компиляторы,
  интерпретаторные врезки, seam'ы (part of engine).
- Modify: `lib/src/engine.dart` — `import 'dart:typed_data';` и два
  новых `part`.
- Modify: `lib/src/brace_ast.dart` — слоты программы на
  `_BraceTemplate`.
- Modify: `lib/src/printf_ast.dart` — слоты программы на
  `_PrintfTemplate`.
- Modify: `lib/src/brace_processor.dart` — IR-`format()`, старый путь
  → `formatWithoutIr()`, хелперы аргументов/контекстов.
- Modify: `lib/src/printf_processor.dart` — IR-`format()`, старый
  путь → `formatWithoutIr()`.
- Test: `test/char_sink_test.dart`,
  `test/template_ir_compile_test.dart`,
  `test/template_ir_diff_test.dart`, `test/template_ir_vm_test.dart`.
- Create: `example/lib/src/template_ir_benchmark.dart`,
  `example/bin/template_ir_benchmark.dart`.
- Test: `example/test/template_ir_benchmark_test.dart`.

RED-числа: перед задачей 1 снять `dart run example/bin/benchmark.dart`
(quick) в scratchpad сессии; итоговые числа попадут в handoff.

---

### Task 1: `CharSink`

**Files:**
- Create: `lib/src/char_sink.dart`
- Modify: `lib/src/engine.dart` (import + part)
- Test: `test/char_sink_test.dart`

**Interfaces:**
- Consumes: ничего нового.
- Produces (для задач 2–8):
  `CharSink(int initialCapacity)`, `int get length`,
  `void writeCharCode(int codeUnit)`, `void writeString(String text)`,
  `void fill(int codeUnit, int count)`,
  `void writeMagnitude(int value, int radix, {bool uppercase})`,
  `static int digitCount(int value, int radix)`,
  `String toString()`.

- [ ] **Step 1: Написать падающий тест**

```dart
// test/char_sink_test.dart
import 'package:format/src/engine.dart';
import 'package:test/test.dart';

void main() {
  test('writes strings, chars and fill with growth', () {
    final sink = CharSink(1);
    sink
      ..writeString('ab')
      ..writeCharCode(0x2d)
      ..fill(0x30, 3)
      ..writeString('');
    expect(sink.length, 6);
    expect(sink.toString(), 'ab-000');
  });

  test('fill ignores non-positive counts', () {
    final sink = CharSink(4)..fill(0x30, 0)..fill(0x30, -2);
    expect(sink.toString(), isEmpty);
  });

  test('digitCount matches toString length across radixes', () {
    for (final value in [0, 1, 7, 9, 10, 99, 12345, -1, -12345]) {
      for (final radix in [2, 8, 10, 16]) {
        expect(
          CharSink.digitCount(value, radix),
          value.abs().toRadixString(radix).length,
          reason: '$value radix $radix',
        );
      }
    }
  });

  test('writeMagnitude writes |value| digits in place', () {
    final sink = CharSink(4);
    sink.writeMagnitude(-48879, 16, uppercase: true);
    sink.writeCharCode(0x7c);
    sink.writeMagnitude(255, 16);
    sink.writeMagnitude(0, 10);
    expect(sink.toString(), 'BEEF|ff0');
  });

  test('surrogate pairs survive as code units', () {
    final sink = CharSink(2)..writeString('a\u{1F600}b');
    expect(sink.toString(), 'a\u{1F600}b');
  });
}
```

- [ ] **Step 2: Прогнать тест — убедиться, что падает**

Run: `dart test test/char_sink_test.dart`
Expected: FAIL — `CharSink` не определён.

- [ ] **Step 3: Минимальная реализация**

```dart
// lib/src/char_sink.dart
part of 'engine.dart';

/// Growable UTF-16 code-unit sink for the template IR. Deliberately not
/// exported by `format.dart`; tests import it through
/// `package:format/src/engine.dart`.
final class CharSink {
  static const _lowerDigits = '0123456789abcdef';
  static const _upperDigits = '0123456789ABCDEF';

  Uint16List _buffer;
  int _length = 0;

  CharSink(int initialCapacity)
    : _buffer = Uint16List(initialCapacity < 16 ? 16 : initialCapacity);

  int get length => _length;

  void _ensure(int extra) {
    final required = _length + extra;
    if (required <= _buffer.length) return;
    var capacity = _buffer.length * 2;
    while (capacity < required) {
      capacity *= 2;
    }
    _buffer = Uint16List(capacity)..setRange(0, _length, _buffer);
  }

  void writeCharCode(int codeUnit) {
    _ensure(1);
    _buffer[_length++] = codeUnit;
  }

  void writeString(String text) {
    final units = text.codeUnits;
    _ensure(units.length);
    _buffer.setRange(_length, _length + units.length, units);
    _length += units.length;
  }

  void fill(int codeUnit, int count) {
    if (count <= 0) return;
    _ensure(count);
    _buffer.fillRange(_length, _length + count, codeUnit);
    _length += count;
  }

  /// Counts the digits of |value| in [radix]. Runs in negative space, so
  /// the minimum int does not overflow, and uses division only, which is
  /// also exact on dart2js within the web-safe integer range.
  static int digitCount(int value, int radix) {
    var negative = value <= 0 ? value : -value;
    var count = 1;
    while (negative <= -radix) {
      negative = negative ~/ radix;
      count++;
    }
    return count;
  }

  /// Writes the digits of |value| in [radix] without allocating.
  void writeMagnitude(int value, int radix, {bool uppercase = false}) {
    var negative = value <= 0 ? value : -value;
    final count = digitCount(value, radix);
    _ensure(count);
    final digits = uppercase ? _upperDigits : _lowerDigits;
    var index = _length + count;
    _length = index;
    var remaining = count;
    while (remaining-- > 0) {
      _buffer[--index] = digits.codeUnitAt(-negative.remainder(radix));
      negative = negative ~/ radix;
    }
  }

  @override
  String toString() => String.fromCharCodes(_buffer, 0, _length);
}
```

В `lib/src/engine.dart` добавить `import 'dart:typed_data';` первой
строкой импортов и `part 'char_sink.dart';` рядом с
`part 'template_cache.dart';`.

- [ ] **Step 4: Прогнать тесты**

Run: `dart test test/char_sink_test.dart && dart analyze lib test`
Expected: PASS, 0 замечаний.

- [ ] **Step 5: Прогнать на node (кросс-платформенность)**

Run: `dart test -p node test/char_sink_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/char_sink.dart lib/src/engine.dart test/char_sink_test.dart
git commit -m "feat: add CharSink code-unit sink for template IR"
```

---

### Task 2: Каркас brace-IR — literal + fallback, переключение пути

**Files:**
- Create: `lib/src/template_ir.dart`
- Modify: `lib/src/engine.dart` (part)
- Modify: `lib/src/brace_ast.dart` (слоты программы)
- Modify: `lib/src/brace_processor.dart` (IR-путь, хелперы)
- Test: `test/template_ir_compile_test.dart`

**Interfaces:**
- Consumes: `CharSink` (Task 1); существующие
  `_cachedBraceTemplate`, `_FieldNode`, `_FieldResolver`,
  `_BraceProcessor._formatField`.
- Produces:
  - `sealed class _BraceOp { void write(CharSink sink,
    _BraceProcessor frame); String describe(); }`
  - `final class _BraceProgram { final List<_BraceOp> ops; final int
    estimatedCapacity; final bool needsResolver; }`
  - `_BraceProgram _compileBraceProgram(_BraceTemplate template,
    TextUnit textUnit)`
  - на `_BraceTemplate`: `_BraceProgram programFor(TextUnit textUnit)`
  - на `_BraceProcessor`: `_FieldResolver get resolver` (ленивый),
    `Object? _argument(int index, String? name, _FieldNode field)`,
    `String formatWithoutIr()`
  - seam'ы: `List<String> debugCompiledProgramDescription(String
    template, {required bool printf, required TextUnit textUnit})`
    (printf-ветка до Task 3 кидает `UnimplementedError`),
    `String debugFormatBraceWithoutIr(String template, Format engine,
    {List<Object?> positional, Map<String, Object?> named})`
  - `int _automaticFieldCount(_FieldNode field)`,
    `String? _staticBraceSpecification(_FieldNode field)`
  - классификатор `_BraceOp? _classifyBraceField(_FieldNode field,
    int argumentIndex, String? argumentName, TextUnit textUnit)` — в
    этой задаче всегда возвращает `null` (всё в fallback), горячие
    op'ы добавляют задачи 4–6.

- [ ] **Step 1: Написать падающий seam-тест**

```dart
// test/template_ir_compile_test.dart
import 'package:format/src/engine.dart';
import 'package:test/test.dart';

void main() {
  setUp(debugClearTemplateCaches);

  test('literal-only template compiles to a single literal op', () {
    expect(
      debugCompiledProgramDescription(
        'plain text',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['literal'],
    );
  });

  test('fields compile to fallback ops in the skeleton', () {
    // Both fields stay on fallback even after Tasks 4-8: a floating spec
    // and a dynamic nested spec are outside the v1 hot core.
    expect(
      debugCompiledProgramDescription(
        'a{:.2f}b{:{}d}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['literal', 'fallback', 'literal', 'fallback'],
    );
  });

  test('IR path and legacy path agree on a mixed template', () {
    const template = '{} + {} = {answer:>6}';
    final ir = formatWith(
      template,
      positional: [2, 3],
      named: {'answer': 5},
    );
    final legacy = debugFormatBraceWithoutIr(
      template,
      defaultFormat,
      positional: [2, 3],
      named: {'answer': 5},
    );
    expect(ir, legacy);
  });
}
```

- [ ] **Step 2: Прогнать тест — убедиться, что падает**

Run: `dart test test/template_ir_compile_test.dart`
Expected: FAIL — `debugCompiledProgramDescription` не определён.

- [ ] **Step 3: Реализация каркаса**

`lib/src/template_ir.dart` (и `part 'template_ir.dart';` в
`engine.dart`):

```dart
part of 'engine.dart';

sealed class _BraceOp {
  const _BraceOp();

  void write(CharSink sink, _BraceProcessor frame);

  String describe();
}

final class _BraceProgram {
  final List<_BraceOp> ops;
  final int estimatedCapacity;
  final bool needsResolver;

  const _BraceProgram(this.ops, this.estimatedCapacity, this.needsResolver);
}

final class _BraceLiteralOp extends _BraceOp {
  final Uint16List units;

  _BraceLiteralOp(String text) : units = Uint16List.fromList(text.codeUnits);

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    sink.writeCodeUnits(units);
  }

  @override
  String describe() => 'literal';
}

final class _BraceFallbackOp extends _BraceOp {
  final _FieldNode field;
  final int automaticBase;

  const _BraceFallbackOp(this.field, this.automaticBase);

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    final resolver = frame.resolver.._automaticIndex = automaticBase;
    final value = resolver.resolveField(field);
    sink.writeString(frame._formatField(resolver, field, value));
  }

  @override
  String describe() => 'fallback';
}

int _automaticFieldCount(_FieldNode field) {
  var count = field.root is _AutomaticRoot ? 1 : 0;
  for (final node in field.specification) {
    if (node is _FieldNode) count += _automaticFieldCount(node);
  }
  return count;
}

String? _staticBraceSpecification(_FieldNode field) {
  final specification = field.specification;
  if (specification.isEmpty) return '';
  if (specification case [_LiteralNode(:final text)]) return text;
  return null;
}

// Hot classification lands in Tasks 4-6; the skeleton sends every field
// through the legacy string path.
_BraceOp? _classifyBraceField(
  _FieldNode field,
  int argumentIndex,
  String? argumentName,
  TextUnit textUnit,
) => null;

_BraceProgram _compileBraceProgram(_BraceTemplate template, TextUnit textUnit) {
  final ops = <_BraceOp>[];
  var automatic = 0;
  var capacity = 0;
  var needsResolver = false;
  for (final node in template.nodes) {
    if (node case _LiteralNode(:final text)) {
      ops.add(_BraceLiteralOp(text));
      capacity += text.length;
      continue;
    }
    final field = node as _FieldNode;
    final automaticBase = automatic;
    automatic += _automaticFieldCount(field);
    capacity += 16;
    final (argumentIndex, argumentName) = switch (field.root) {
      _AutomaticRoot() => (automaticBase, null),
      _PositionalRoot(:final index) => (index, null),
      _NamedRoot(:final name) => (-1, name),
    };
    final op =
        field.conversion == null && field.accesses.isEmpty
            ? _classifyBraceField(field, argumentIndex, argumentName, textUnit)
            : null;
    if (op == null) {
      ops.add(_BraceFallbackOp(field, automaticBase));
      needsResolver = true;
    } else {
      ops.add(op);
    }
  }
  return _BraceProgram(ops, capacity, needsResolver);
}

/// Test seams. Deliberately not exported by `format.dart`.
List<String> debugCompiledProgramDescription(
  String template, {
  required bool printf,
  required TextUnit textUnit,
}) =>
    printf
        ? throw UnimplementedError('printf IR lands in Task 3')
        : [
          for (final op in _cachedBraceTemplate(template)
              .programFor(textUnit)
              .ops)
            op.describe(),
        ];

String debugFormatBraceWithoutIr(
  String template,
  Format engine, {
  List<Object?> positional = const [],
  Map<String, Object?> named = const {},
}) =>
    _BraceProcessor(
      template,
      positional: positional,
      named: named,
      engine: engine,
    ).formatWithoutIr();
```

`CharSink` дополняется методом (в `char_sink.dart`):

```dart
  void writeCodeUnits(Uint16List units) {
    _ensure(units.length);
    _buffer.setRange(_length, _length + units.length, units);
    _length += units.length;
  }
```

и тестом в `test/char_sink_test.dart`:

```dart
  test('writeCodeUnits copies a prepared literal', () {
    final units = Uint16List.fromList('lit'.codeUnits);
    final sink = CharSink(1)..writeCodeUnits(units)..writeCodeUnits(units);
    expect(sink.toString(), 'litlit');
  });
```

(в тест-файл добавить `import 'dart:typed_data';`).

`lib/src/brace_ast.dart`, внутри `_BraceTemplate` (по образцу
мемо-слотов `_FieldNode`):

```dart
  // Lazily memoized IR programs, one slot per TextUnit. Shared through the
  // template cache; compilation is total and never throws, so a slot is
  // written at most once per unit.
  _BraceProgram? _scalarProgram;
  _BraceProgram? _graphemeProgram;

  _BraceProgram programFor(TextUnit textUnit) => switch (textUnit) {
    TextUnit.unicodeScalars =>
      _scalarProgram ??= _compileBraceProgram(this, textUnit),
    TextUnit.graphemeClusters =>
      _graphemeProgram ??= _compileBraceProgram(this, textUnit),
  };
```

`lib/src/brace_processor.dart` — `format()` заменяется, старое тело
переименовывается, добавляются ленивый resolver и хелперы:

```dart
  String format() {
    final program = _cachedBraceTemplate(template).programFor(engine.textUnit);
    final output = CharSink(program.estimatedCapacity);
    for (final op in program.ops) {
      op.write(output, this);
    }
    return output.toString();
  }

  /// Legacy string-assembly path. Kept as the baseline for differential
  /// tests and the IR A/B benchmark; reachable via debugFormatBraceWithoutIr.
  String formatWithoutIr() {
    // ...прежнее тело format() без изменений...
  }

  _FieldResolver? _lazyResolver;

  _FieldResolver get resolver =>
      _lazyResolver ??= _FieldResolver(
        template: template,
        positional: positional,
        named: named,
        engine: engine,
      );

  Object? _argument(int index, String? name, _FieldNode field) {
    if (name != null) {
      if (!named.containsKey(name)) {
        throw MissingFormatArgumentException(_resolveContext(field), name);
      }
      return named[name];
    }
    if (index >= positional.length) {
      throw MissingFormatArgumentException(_resolveContext(field), index);
    }
    return positional[index];
  }

  FormatExceptionContext _resolveContext(_FieldNode field) =>
      FormatExceptionContext(
        template: template,
        offset: field.offset,
        fragment: field.fragment,
      );
```

`_FieldResolver._automaticIndex` уже доступен внутри библиотеки —
права менять модификаторы не требуется.

- [ ] **Step 4: Прогнать тесты и полный suite**

Run: `dart test test/template_ir_compile_test.dart && dart test && dart analyze lib test example`
Expected: новый файл PASS; полный suite зелёный (паритет: все поля
идут через fallback = старую логику); analyzer чист.

- [ ] **Step 5: Прогнать на node**

Run: `dart test -p node test/char_sink_test.dart test/template_ir_compile_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/template_ir.dart lib/src/engine.dart lib/src/brace_ast.dart \
  lib/src/brace_processor.dart lib/src/char_sink.dart \
  test/template_ir_compile_test.dart test/char_sink_test.dart
git commit -m "feat: compile brace templates to IR with fallback ops"
```

---

### Task 3: Каркас printf-IR — literal + fallback со статическими индексами

**Files:**
- Modify: `lib/src/template_ir.dart`
- Modify: `lib/src/printf_ast.dart` (слоты программы)
- Modify: `lib/src/printf_processor.dart` (IR-путь)
- Test: `test/template_ir_compile_test.dart`

**Interfaces:**
- Consumes: `CharSink`, `_cachedPrintfTemplate`,
  `_PrintfConversionNode`, `_formatPrintfValue`,
  `_ResolvedPrintfConversion`, `_printfContext`, `_PrintfFlags`.
- Produces:
  - `sealed class _PrintfOp { void write(CharSink sink,
    _PrintfProcessor frame); String describe(); }`
  - `final class _PrintfProgram { final List<_PrintfOp> ops; final
    int estimatedCapacity; }`
  - на `_PrintfTemplate`: `_PrintfProgram programFor(TextUnit
    textUnit)` (слоты `_scalarProgram`/`_graphemeProgram`)
  - на `_PrintfProcessor`: `String formatWithoutIr()` (старое тело),
    `Object? _argumentAt(int index, _PrintfConversionNode node,
    {String? specifier})`
  - `int? _resolveIrPrintfOption(_PrintfProcessor frame,
    _PrintfConversionNode node, int staticValue, int argumentIndex,
    String role)` — общий резолвер width/precision для задач 7–8
    (сентинели: staticValue -1 «нет», argumentIndex -1 «статический»)
  - `_PrintfFallbackOp` с полями `widthArgIndex`, `precisionArgIndex`,
    `valueArgIndex` (int, -1 = нет)
  - классификатор `_PrintfOp? _classifyPrintfConversion(
    _PrintfConversionNode node, int widthArgIndex,
    int precisionArgIndex, int valueArgIndex, TextUnit textUnit)` —
    в этой задаче всегда `null`; printf-ветка
    `debugCompiledProgramDescription` начинает работать;
  - `String debugFormatPrintfWithoutIr(String template, Format
    engine, List<Object?> values)`.

- [ ] **Step 1: Написать падающий seam-тест**

Дописать в `test/template_ir_compile_test.dart`:

```dart
  test('printf skeleton: literals merge, %% folds into literal', () {
    // %f stays on fallback even after Tasks 7-8 (doubles are out of the
    // v1 hot core), so this expectation survives the whole plan.
    expect(
      debugCompiledProgramDescription(
        'x=%f, done 100%%',
        printf: true,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['literal', 'fallback', 'literal'],
    );
  });

  test('printf IR path agrees with the legacy path', () {
    const template = '%s scored %05.1f%%';
    final ir = sprintf(template, 'Ann', 97.5);
    final legacy = debugFormatPrintfWithoutIr(
      template,
      defaultFormat,
      ['Ann', 97.5],
    );
    expect(ir, legacy);
  });
```

- [ ] **Step 2: Прогнать тест — убедиться, что падает**

Run: `dart test test/template_ir_compile_test.dart`
Expected: FAIL — printf-ветка кидает `UnimplementedError`.

- [ ] **Step 3: Реализация**

В `template_ir.dart`:

```dart
sealed class _PrintfOp {
  const _PrintfOp();

  void write(CharSink sink, _PrintfProcessor frame);

  String describe();
}

final class _PrintfProgram {
  final List<_PrintfOp> ops;
  final int estimatedCapacity;

  const _PrintfProgram(this.ops, this.estimatedCapacity);
}

final class _PrintfLiteralOp extends _PrintfOp {
  final Uint16List units;

  _PrintfLiteralOp(String text) : units = Uint16List.fromList(text.codeUnits);

  @override
  void write(CharSink sink, _PrintfProcessor frame) {
    sink.writeCodeUnits(units);
  }

  @override
  String describe() => 'literal';
}

final class _PrintfFallbackOp extends _PrintfOp {
  final _PrintfConversionNode node;
  final int widthArgIndex;
  final int precisionArgIndex;
  final int valueArgIndex;

  const _PrintfFallbackOp(
    this.node,
    this.widthArgIndex,
    this.precisionArgIndex,
    this.valueArgIndex,
  );

  @override
  void write(CharSink sink, _PrintfProcessor frame) {
    // Same consumption order as the legacy cursor (width, precision,
    // value) and the same _staticResolved/_staticContext memoization, so
    // static fallback conversions (e.g. %f) keep today's performance.
    var resolved = node._staticResolved;
    if (resolved == null) {
      var flags = node.flags;
      var width = _fallbackOption(frame, node.width, widthArgIndex, 'width');
      var precision = _fallbackOption(
        frame,
        node.precision,
        precisionArgIndex,
        'precision',
      );
      if (width case final value? when value < 0) {
        flags |= _PrintfFlags.left;
        width = -value;
      }
      if (precision case final value? when value < 0) precision = null;
      resolved = _ResolvedPrintfConversion(
        node: node,
        flags: flags,
        width: width,
        precision: precision,
      );
      if (!node.hasDynamicOptions) node._staticResolved = resolved;
    }
    if (node.type == '%') {
      sink.writeCharCode(0x25);
      return;
    }
    final argument = frame._argumentAt(valueArgIndex, node);
    var context = node._staticContext;
    if (context == null) {
      context = _printfContext(
        frame.template,
        node,
        argumentIndex: valueArgIndex,
      );
      if (!node.hasDynamicOptions) node._staticContext = context;
    }
    sink.writeString(
      _formatPrintfValue(argument, resolved, frame.engine, context),
    );
  }

  int? _fallbackOption(
    _PrintfProcessor frame,
    _PrintfOption? option,
    int argumentIndex,
    String role,
  ) {
    if (option == null) return null;
    if (option case _LiteralPrintfOption(:final value)) {
      return frame._validateOption(node, value, role);
    }
    final argument = frame._argumentAt(argumentIndex, node, specifier: role);
    if (argument is! int || !_isIntegerValue(argument)) {
      throw UnsupportedFormatValueException(
        _printfContext(
          frame.template,
          node,
          specifier: role,
          argumentIndex: argumentIndex,
        ),
        argument,
      );
    }
    return frame._validateOption(
      node,
      argument,
      role,
      argumentIndex: argumentIndex,
    );
  }

  @override
  String describe() => 'fallback';
}

_PrintfOp? _classifyPrintfConversion(
  _PrintfConversionNode node,
  int widthArgIndex,
  int precisionArgIndex,
  int valueArgIndex,
  TextUnit textUnit,
) => null;

_PrintfProgram _compilePrintfProgram(
  _PrintfTemplate template,
  TextUnit textUnit,
) {
  final ops = <_PrintfOp>[];
  final literal = StringBuffer();
  var argument = 0;
  var capacity = 0;

  void flushLiteral() {
    if (literal.isEmpty) return;
    final text = literal.toString();
    ops.add(_PrintfLiteralOp(text));
    capacity += text.length;
    literal.clear();
  }

  for (final node in template.nodes) {
    if (node case _PrintfLiteralNode(:final text)) {
      literal.write(text);
      continue;
    }
    final conversion = node as _PrintfConversionNode;
    final widthArgIndex =
        conversion.width is _DynamicPrintfOption ? argument++ : -1;
    final precisionArgIndex =
        conversion.precision is _DynamicPrintfOption ? argument++ : -1;
    final valueArgIndex = conversion.type == '%' ? -1 : argument++;
    if (conversion.type == '%' && !conversion.hasDynamicOptions) {
      literal.write('%');
      continue;
    }
    flushLiteral();
    capacity += 16;
    final op = _classifyPrintfConversion(
      conversion,
      widthArgIndex,
      precisionArgIndex,
      valueArgIndex,
      textUnit,
    );
    ops.add(
      op ??
          _PrintfFallbackOp(
            conversion,
            widthArgIndex,
            precisionArgIndex,
            valueArgIndex,
          ),
    );
  }
  flushLiteral();
  return _PrintfProgram(ops, capacity);
}

String debugFormatPrintfWithoutIr(
  String template,
  Format engine,
  List<Object?> values,
) =>
    _PrintfProcessor(
      template,
      List<Object?>.unmodifiable(values),
      engine,
    ).formatWithoutIr();
```

printf-ветка `debugCompiledProgramDescription` меняется на

```dart
        ? [
          for (final op in _cachedPrintfTemplate(template)
              .programFor(textUnit)
              .ops)
            op.describe(),
        ]
```

`lib/src/printf_ast.dart`, внутри `_PrintfTemplate` — слоты по
образцу `_BraceTemplate` (тот же комментарий):

```dart
  _PrintfProgram? _scalarProgram;
  _PrintfProgram? _graphemeProgram;

  _PrintfProgram programFor(TextUnit textUnit) => switch (textUnit) {
    TextUnit.unicodeScalars =>
      _scalarProgram ??= _compilePrintfProgram(this, textUnit),
    TextUnit.graphemeClusters =>
      _graphemeProgram ??= _compilePrintfProgram(this, textUnit),
  };
```

`lib/src/printf_processor.dart`: `format()` → IR-цикл (аналог
brace), старое тело → `formatWithoutIr()`; `_validateOption`
становится доступным op'ам как есть (он уже метод процессора);
добавляется:

```dart
  Object? _argumentAt(
    int index,
    _PrintfConversionNode node, {
    String? specifier,
  }) {
    if (index >= values.length) {
      throw MissingFormatArgumentException(
        _printfContext(
          template,
          node,
          specifier: specifier,
          argumentIndex: index,
        ),
        index,
      );
    }
    return values[index];
  }
```

Семантика `%%` с динамическими опциями (`%*.*%` — если парсер такое
пропускает) сохраняется fallback-op'ом: он потребляет аргументы
width/precision и пишет `%`, как сегодняшний
`_PrintfProcessor.format`.

- [ ] **Step 4: Прогнать тесты и полный suite**

Run: `dart test test/template_ir_compile_test.dart && dart test && dart analyze lib test example`
Expected: всё зелёное (паритет через fallback), analyzer чист.

- [ ] **Step 5: Commit**

```bash
git add lib/src/template_ir.dart lib/src/printf_ast.dart \
  lib/src/printf_processor.dart test/template_ir_compile_test.dart
git commit -m "feat: compile printf templates to IR with static argument indices"
```

---

### Task 4: `_BraceDynamicValueOp` — горячий `{}`

**Files:**
- Modify: `lib/src/template_ir.dart`
- Test: `test/template_ir_compile_test.dart`,
  `test/template_ir_diff_test.dart` (создать)

**Interfaces:**
- Consumes: `_argument`, `_resolveContext` (Task 2), `CharSink`,
  `formatParsedValue`, `_isIntegerValue`, `_FormatSpec`.
- Produces: `_BraceDynamicValueOp` c `describe() == 'dynamic'`;
  первая горячая ветка в `_classifyBraceField`.

- [ ] **Step 1: Написать падающие тесты**

В `test/template_ir_compile_test.dart`:

```dart
  test('empty spec compiles to the dynamic value op', () {
    expect(
      debugCompiledProgramDescription(
        '{} {name}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['dynamic', 'literal', 'dynamic'],
    );
  });
```

Новый `test/template_ir_diff_test.dart`:

```dart
import 'package:format/src/engine.dart';
import 'package:test/test.dart';

final graphemeFormat = Format(textUnit: TextUnit.graphemeClusters);

void expectBraceParity(
  String template, {
  List<Object?> positional = const [],
  Map<String, Object?> named = const {},
  Format? engine,
}) {
  final format = engine ?? defaultFormat;
  Object? irError;
  String? ir;
  try {
    ir = format.formatWith(template, positional: positional, named: named);
  } on FormattingException catch (error) {
    irError = error;
  }
  Object? legacyError;
  String? legacy;
  try {
    legacy = debugFormatBraceWithoutIr(
      template,
      format,
      positional: positional,
      named: named,
    );
  } on FormattingException catch (error) {
    legacyError = error;
  }
  expect(ir, legacy, reason: template);
  expect(
    irError.runtimeType,
    legacyError.runtimeType,
    reason: '$template errors',
  );
  if (irError is FormattingException &&
      legacyError is FormattingException) {
    expect(irError.toString(), legacyError.toString(), reason: template);
  }
}

void main() {
  setUp(debugClearTemplateCaches);

  test('dynamic value op matches the legacy path per runtime type', () {
    for (final value in <Object?>[
      'text',
      '',
      'é',
      42,
      -42,
      0,
      9007199254740991,
      BigInt.parse('123456789012345678901234567890'),
      true,
      false,
      null,
      3.5,
      -0.0,
      double.nan,
      const Duration(seconds: 1),
    ]) {
      expectBraceParity('<{}>', positional: [value]);
      expectBraceParity('<{}>', positional: [value], engine: graphemeFormat);
    }
  });

  test('dynamic value op keeps missing-argument errors', () {
    expectBraceParity('{} {}', positional: ['only one']);
    expectBraceParity('{name}', named: {});
  });
}
```

- [ ] **Step 2: Прогнать — compile-тест падает**

Run: `dart test test/template_ir_compile_test.dart test/template_ir_diff_test.dart`
Expected: compile-тест FAIL (`fallback` вместо `dynamic`); дифф-тест
уже PASS (fallback ведёт себя идентично) — это нормально, он
страхует шаг 3.

- [ ] **Step 3: Реализация op'а и ветки классификатора**

```dart
final class _BraceDynamicValueOp extends _BraceOp {
  final _FieldNode field;
  final int argumentIndex;
  final String? argumentName;

  const _BraceDynamicValueOp(this.field, this.argumentIndex, this.argumentName);

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    final value = frame._argument(argumentIndex, argumentName, field);
    if (value is String) {
      sink.writeString(value);
      return;
    }
    if (value is int && _isIntegerValue(value)) {
      if (value.isNegative) sink.writeCharCode(0x2d);
      sink.writeMagnitude(value, 10);
      return;
    }
    if (value is bool || value == null) {
      sink.writeString(value.toString());
      return;
    }
    // BigInt, double, custom formatters, unsupported values: the generic
    // dispatch reproduces today's behavior and errors exactly.
    sink.writeString(
      formatParsedValue(
        value,
        const _FormatSpec(),
        frame.engine,
        FormatExceptionContext(
          template: frame.template,
          offset: field.offset,
          fragment: field.fragment,
          specifier: '',
          conversion: null,
        ),
      ),
    );
  }

  @override
  String describe() => 'dynamic';
}
```

В `_classifyBraceField` (заменяя тело-заглушку из Task 2):

```dart
_BraceOp? _classifyBraceField(
  _FieldNode field,
  int argumentIndex,
  String? argumentName,
  TextUnit textUnit,
) {
  final specText = _staticBraceSpecification(field);
  if (specText == null) return null;
  if (specText.isEmpty) {
    return _BraceDynamicValueOp(field, argumentIndex, argumentName);
  }
  return null; // Typed hot ops land in Tasks 5-6.
}
```

Проверка контекста: сегодняшний `_BraceProcessor._formatField`
строит контекст с `specifier: ''` и `conversion: null` для пустой
спеки — op повторяет это дословно.

- [ ] **Step 4: Прогнать тесты, полный suite, node**

Run: `dart test test/template_ir_compile_test.dart test/template_ir_diff_test.dart && dart test && dart analyze lib test example && dart test -p node test/template_ir_compile_test.dart test/template_ir_diff_test.dart`
Expected: всё PASS, analyzer чист.

- [ ] **Step 5: Commit**

```bash
git add lib/src/template_ir.dart test/template_ir_compile_test.dart \
  test/template_ir_diff_test.dart
git commit -m "perf: write empty-spec brace fields directly into the sink"
```

---

### Task 5: `_BraceIntOp` — горячие `d/x/X/o/b`

**Files:**
- Modify: `lib/src/template_ir.dart`
- Test: `test/template_ir_compile_test.dart`,
  `test/template_ir_diff_test.dart`, `test/template_ir_vm_test.dart`
  (создать)

**Interfaces:**
- Consumes: `CharSink.digitCount`, `CharSink.writeMagnitude`,
  `formatMagnitude`, `_integerPrefix`, `field.memoizedSpec` /
  `memoizeSpec`, `parseFormatSpec`.
- Produces: `_BraceIntOp` с `describe()` вида `'int:<type>'` или
  `'int:<type>:w<width>'`; ветка `d/b/o/x/X` в `_classifyBraceField`;
  вспомогательные приватные хелперы выравнивания, переиспользуемые
  Task 6: у op'а методы `_writeLeading(CharSink sink, int padding,
  int signChar)` и `_writeTrailing(CharSink sink, int padding)`.

- [ ] **Step 1: Написать падающие тесты**

Compile-тест:

```dart
  test('static integer specs compile to int ops', () {
    expect(
      debugCompiledProgramDescription(
        '{:10d}|{:x}|{:<5b}|{:#o}|{:+03d}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['int:d:w10', 'literal', 'int:x', 'literal', 'int:b:w5', 'literal',
          'int:o', 'literal', 'int:d:w3'],
    );
  });

  test('non-hot integer specs stay on fallback', () {
    // NB: single-code-unit fills (including precomposed 'é') compile hot;
    // only multi-unit fills fall back — that case is covered in Task 6.
    for (final spec in ['{:,d}', '{:n}', '{:.2d}', '{:{}d}']) {
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

Дифф-тест (значения × спеки, оба TextUnit):

```dart
  test('int op matches the legacy path across specs and values', () {
    const specs = [
      '{:d}', '{:10d}', '{:<10d}', '{:>10d}', '{:^10d}', '{:=10d}',
      '{:010d}', '{:+d}', '{: d}', '{:-d}', '{:*<8d}', '{:x}', '{:X}',
      '{:#x}', '{:#X}', '{:o}', '{:#o}', '{:b}', '{:#b}', '{:#010x}',
      '{:1d}',
    ];
    final values = <Object?>[
      0, 1, -1, 42, -42, 9007199254740991, -9007199254740991,
      BigInt.parse('-340282366920938463463374607431768211456'),
      BigInt.zero,
      'not a number', 3.5, null,
    ];
    for (final spec in specs) {
      for (final value in values) {
        expectBraceParity(spec, positional: [value]);
        expectBraceParity(spec, positional: [value], engine: graphemeFormat);
      }
    }
  });
```

Новый VM-only `test/template_ir_vm_test.dart` (литерал minInt не
компилируется dart2js — файл только для VM, по прецеденту
`integer_format_test.dart`):

```dart
@TestOn('vm')
library;

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

void main() {
  setUp(debugClearTemplateCaches);

  const minInt = -9223372036854775808;

  test('int op handles the minimum int like the legacy path', () {
    for (final spec in ['{:d}', '{:30d}', '{:x}', '{:b}', '{:#o}', '{}']) {
      expect(
        formatWith(spec, positional: [minInt]),
        debugFormatBraceWithoutIr(
          spec,
          defaultFormat,
          positional: [minInt],
        ),
        reason: spec,
      );
    }
    expect(sprintf('%d|%x|%o', minInt, minInt, minInt),
        debugFormatPrintfWithoutIr(
          '%d|%x|%o', defaultFormat, [minInt, minInt, minInt]));
  });
}
```

(printf-строка заработает после Task 8 — до тех пор printf-кейс
идёт через fallback и уже обязан совпадать.)

- [ ] **Step 2: Прогнать — compile-тест падает**

Run: `dart test test/template_ir_compile_test.dart`
Expected: FAIL (`fallback` вместо `int:*`).

- [ ] **Step 3: Реализация**

```dart
final class _BraceIntOp extends _BraceOp {
  final _FieldNode field;
  final int argumentIndex;
  final String? argumentName;
  final String specifierText;
  final int radix;
  final bool uppercase;
  final String prefix; // '', '0b', '0o', '0x', '0X'
  final int requestedSign; // 0x2b '+', 0x20 ' ', 0 none
  final int width; // -1 none
  final int fillChar;
  final int align; // code unit of '<' '>' '^' '='
  final String type;

  const _BraceIntOp({
    required this.field,
    required this.argumentIndex,
    required this.argumentName,
    required this.specifierText,
    required this.radix,
    required this.uppercase,
    required this.prefix,
    required this.requestedSign,
    required this.width,
    required this.fillChar,
    required this.align,
    required this.type,
  });

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    final value = frame._argument(argumentIndex, argumentName, field);
    if (value is int && _isIntegerValue(value)) {
      final signChar = value.isNegative ? 0x2d : requestedSign;
      final digits = CharSink.digitCount(value, radix);
      final padding =
          width < 0
              ? 0
              : width - digits - prefix.length - (signChar == 0 ? 0 : 1);
      _writeLeading(sink, padding, signChar);
      sink.writeMagnitude(value, radix, uppercase: uppercase);
      _writeTrailing(sink, padding);
      return;
    }
    if (value is BigInt) {
      final magnitude = formatMagnitude(
        value.isNegative ? -value : value,
        radix,
        uppercase: uppercase,
      );
      final signChar = value.isNegative ? 0x2d : requestedSign;
      final padding =
          width < 0
              ? 0
              : width -
                  magnitude.length -
                  prefix.length -
                  (signChar == 0 ? 0 : 1);
      _writeLeading(sink, padding, signChar);
      sink.writeString(magnitude);
      _writeTrailing(sink, padding);
      return;
    }
    throw UnsupportedFormatValueException(_context(frame), value);
  }

  void _writeLeading(CharSink sink, int padding, int signChar) {
    if (align == 0x3e) {
      sink.fill(fillChar, padding);
    } else if (align == 0x5e) {
      sink.fill(fillChar, padding ~/ 2);
    }
    if (signChar != 0) sink.writeCharCode(signChar);
    if (prefix.isNotEmpty) sink.writeString(prefix);
    if (align == 0x3d) sink.fill(fillChar, padding);
  }

  void _writeTrailing(CharSink sink, int padding) {
    if (align == 0x3c) {
      sink.fill(fillChar, padding);
    } else if (align == 0x5e) {
      sink.fill(fillChar, padding - padding ~/ 2);
    }
  }

  FormatExceptionContext _context(_BraceProcessor frame) =>
      FormatExceptionContext(
        template: frame.template,
        offset: field.offset,
        fragment: field.fragment,
        specifier: specifierText,
        conversion: null,
      );

  @override
  String describe() => width < 0 ? 'int:$type' : 'int:$type:w$width';
}
```

Ветка в `_classifyBraceField` после ветки пустой спеки — спека
парсится один раз и мемоизируется в существующие слоты узла:

```dart
  var spec = field.memoizedSpec(textUnit);
  if (spec == null) {
    try {
      spec = parseFormatSpec(specText, textUnit, const FormatExceptionContext());
    } on FormattingException {
      return null; // Invalid static specs keep today's per-call errors.
    }
    field.memoizeSpec(textUnit, spec);
  }
  if (spec.customName != null || spec.payload != null) return null;
  final fill = spec.fill;
  if (fill != null && fill.length != 1) return null; // multi-unit fill
  switch (spec.type) {
    case 'd' || 'b' || 'o' || 'x' || 'X':
      if (spec.grouping != null ||
          spec.precision != null ||
          spec.fractionalGrouping != null ||
          spec.normalizeNegativeZero) {
        return null;
      }
      final type = spec.type!;
      return _BraceIntOp(
        field: field,
        argumentIndex: argumentIndex,
        argumentName: argumentName,
        specifierText: specText,
        radix: switch (type) {
          'b' => 2,
          'o' => 8,
          'd' => 10,
          _ => 16,
        },
        uppercase: type == 'X',
        prefix: _integerPrefix(type, spec.alternate),
        requestedSign: switch (spec.sign) {
          '+' => 0x2b,
          ' ' => 0x20,
          _ => 0,
        },
        width: spec.width ?? -1,
        fillChar: (spec.fill ?? (spec.zero ? '0' : ' ')).codeUnitAt(0),
        align: (spec.align ?? (spec.zero ? '=' : '>')).codeUnitAt(0),
        type: type,
      );
    default:
      return null;
  }
```

Запечённые дефолты повторяют `applyNumericWidth`:
`fill = spec.fill ?? (zero ? '0' : ' ')`,
`align = spec.align ?? (zero ? '=' : '>')`, `'^'`-паддинг слева —
`padding ~/ 2`.

- [ ] **Step 4: Прогнать тесты, полный suite, node**

Run: `dart test test/template_ir_compile_test.dart test/template_ir_diff_test.dart test/template_ir_vm_test.dart && dart test && dart analyze lib test example && dart test -p node test/template_ir_diff_test.dart`
Expected: всё PASS, analyzer чист.

- [ ] **Step 5: Commit**

```bash
git add lib/src/template_ir.dart test/template_ir_compile_test.dart \
  test/template_ir_diff_test.dart test/template_ir_vm_test.dart
git commit -m "perf: write static integer brace fields directly into the sink"
```

---

### Task 6: `_BraceTextOp` — горячий `s`

**Files:**
- Modify: `lib/src/template_ir.dart`
- Test: `test/template_ir_compile_test.dart`,
  `test/template_ir_diff_test.dart`

**Interfaces:**
- Consumes: `TextUnitOperations.length/take`, `formatParsedValue`
  (медленная ветка), хелперы выравнивания — те же формулы, что в
  `_BraceIntOp` (методы дублируются на op'е: у текста нет sign и
  prefix, `_writeLeading` вырождается в fill-до, `=` недостижим).
- Produces: `_BraceTextOp` с `describe()` вида
  `'text:s'`/`'text:s:w10'`/`'text:s:w10:p3'`; ветка `'s'` в
  `_classifyBraceField`.

- [ ] **Step 1: Написать падающие тесты**

Compile-тест:

```dart
  test('static text specs compile to text ops', () {
    expect(
      debugCompiledProgramDescription(
        '{:s}|{:<10s}|{:^7.3s}',
        printf: false,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['text:s', 'literal', 'text:s:w10', 'literal', 'text:s:w7:p3'],
    );
  });

  test('text specs with numeric options stay on fallback', () {
    for (final spec in [
      '{:=10s}', '{:+s}', '{:#s}', '{:,s}', '{:é^10s}',
    ]) {
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

Замечание: fill из `é` уходит в fallback, только если записан
двумя code units. Чтобы тест не зависел от нормализации редактора,
в коде использовать явный escape: `'{:e\u0301^10s}'` (e + U+0301).
Прекомпозированный `é` — один code unit и компилируется в text-op.

Дифф-тест:

```dart
  test('text op matches the legacy path across specs and values', () {
    const specs = [
      '{:s}', '{:10s}', '{:<10s}', '{:>10s}', '{:^10s}', '{:.3s}',
      '{:10.3s}', '{:*^10s}', '{:.0s}', '{:2s}',
    ];
    final values = <Object?>[
      'hello', '', 'ab', 'ééé', '\u{1F600}\u{1F600}',
      'exactly10!', 42, null,
    ];
    for (final spec in specs) {
      for (final value in values) {
        expectBraceParity(spec, positional: [value]);
        expectBraceParity(spec, positional: [value], engine: graphemeFormat);
      }
    }
  });
```

- [ ] **Step 2: Прогнать — compile-тест падает**

Run: `dart test test/template_ir_compile_test.dart`
Expected: FAIL.

- [ ] **Step 3: Реализация**

```dart
final class _BraceTextOp extends _BraceOp {
  final _FieldNode field;
  final int argumentIndex;
  final String? argumentName;
  final String specifierText;
  final _FormatSpec spec; // for the slow non-String branch
  final int width; // -1 none
  final int fillChar;
  final int align; // '<' '>' '^'
  final int precision; // -1 none
  final TextUnit textUnit;

  const _BraceTextOp({
    required this.field,
    required this.argumentIndex,
    required this.argumentName,
    required this.specifierText,
    required this.spec,
    required this.width,
    required this.fillChar,
    required this.align,
    required this.precision,
    required this.textUnit,
  });

  @override
  void write(CharSink sink, _BraceProcessor frame) {
    final value = frame._argument(argumentIndex, argumentName, field);
    if (value is! String) {
      // The generic path throws exactly today's errors for non-strings.
      sink.writeString(
        formatParsedValue(value, spec, frame.engine, _context(frame)),
      );
      return;
    }
    final text = precision < 0 ? value : textUnit.take(value, precision);
    if (width < 0) {
      sink.writeString(text);
      return;
    }
    final padding = width - textUnit.length(text);
    if (align == 0x3e) {
      sink.fill(fillChar, padding);
    } else if (align == 0x5e) {
      sink.fill(fillChar, padding ~/ 2);
    }
    sink.writeString(text);
    if (align == 0x3c) {
      sink.fill(fillChar, padding);
    } else if (align == 0x5e) {
      sink.fill(fillChar, padding - padding ~/ 2);
    }
  }

  FormatExceptionContext _context(_BraceProcessor frame) =>
      FormatExceptionContext(
        template: frame.template,
        offset: field.offset,
        fragment: field.fragment,
        specifier: specifierText,
        conversion: null,
      );

  @override
  String describe() {
    final buffer = StringBuffer('text:s');
    if (width >= 0) buffer.write(':w$width');
    if (precision >= 0) buffer.write(':p$precision');
    return buffer.toString();
  }
}
```

Ветка классификатора (в `switch (spec.type)` из Task 5):

```dart
    case 's':
      if (spec.sign != null ||
          spec.normalizeNegativeZero ||
          spec.alternate ||
          spec.zero ||
          spec.grouping != null ||
          spec.fractionalGrouping != null ||
          spec.align == '=') {
        return null; // Invalid-for-text specs keep today's errors.
      }
      return _BraceTextOp(
        field: field,
        argumentIndex: argumentIndex,
        argumentName: argumentName,
        specifierText: specText,
        spec: spec,
        width: spec.width ?? -1,
        fillChar: (spec.fill ?? ' ').codeUnitAt(0),
        align: (spec.align ?? '<').codeUnitAt(0),
        precision: spec.precision ?? -1,
        textUnit: textUnit,
      );
```

`_validateTextSpec` для горячего op'а не нужен: перечисленные
условия — в точности его проверки; всё непроходящее уходит в
fallback и кидает сегодняшнюю ошибку.

Паддинг по графемам: `textUnit.length(text)` уже считает графемы, а
запись — code units; ширина совпадает с `applyFieldWidth`.

- [ ] **Step 4: Прогнать тесты, полный suite, node**

Run: `dart test test/template_ir_compile_test.dart test/template_ir_diff_test.dart && dart test && dart analyze lib test example && dart test -p node test/template_ir_diff_test.dart`
Expected: всё PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/template_ir.dart test/template_ir_compile_test.dart \
  test/template_ir_diff_test.dart
git commit -m "perf: write static text brace fields directly into the sink"
```

---

### Task 7: `_PrintfStringOp` — горячий `%s`

**Files:**
- Modify: `lib/src/template_ir.dart`
- Test: `test/template_ir_compile_test.dart`,
  `test/template_ir_diff_test.dart`

**Interfaces:**
- Consumes: `_argumentAt` (Task 3), `_validateOption`,
  `UnsupportedConversionException`, `TextUnitOperations`.
- Produces: `_PrintfStringOp` с `describe()` вида
  `'str'`/`'str:w10'`/`'str:w*'`/`'str:w*:p*'`; общий резолвер
  `int? _resolveIrPrintfOption(_PrintfProcessor frame,
  _PrintfConversionNode node, int staticValue, int argumentIndex,
  String role)` (описан в Task 3, реализуется здесь; Task 8 его
  переиспользует); ветка `'s'` в `_classifyPrintfConversion`.

- [ ] **Step 1: Написать падающие тесты**

Compile-тест:

```dart
  test('%s compiles to the string op, static and dynamic', () {
    expect(
      debugCompiledProgramDescription(
        '%s|%10s|%-10s|%.3s|%*s|%.*s',
        printf: true,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['str', 'literal', 'str:w10', 'literal', 'str:w10', 'literal',
          'str:p3', 'literal', 'str:w*', 'literal', 'str:p*'],
    );
  });
```

(`%-10s` описывается как `str:w10` — флаг left не входит в
describe; проверяется дифф-тестом.)

Дифф-тест — printf-паритет через новый хелпер:

```dart
void expectPrintfParity(
  String template,
  List<Object?> values, {
  Format? engine,
}) {
  final format = engine ?? defaultFormat;
  Object? irError;
  String? ir;
  try {
    ir = format.vsprintf(template, values);
  } on FormattingException catch (error) {
    irError = error;
  }
  Object? legacyError;
  String? legacy;
  try {
    legacy = debugFormatPrintfWithoutIr(template, format, values);
  } on FormattingException catch (error) {
    legacyError = error;
  }
  expect(ir, legacy, reason: template);
  expect(irError.runtimeType, legacyError.runtimeType,
      reason: '$template errors');
  if (irError is FormattingException &&
      legacyError is FormattingException) {
    expect(irError.toString(), legacyError.toString(), reason: template);
  }
}

  test('%s op matches the legacy path', () {
    const templates = [
      '%s', '%10s', '%-10s', '%.3s', '%10.3s', '%-10.3s',
    ];
    final values = <Object?>[
      'hello', '', 'éé', 42, null, 3.5, true,
    ];
    for (final template in templates) {
      for (final value in values) {
        expectPrintfParity(template, [value]);
        expectPrintfParity(template, [value], engine: graphemeFormat);
      }
    }
    // Dynamic options, including negative width and negative precision.
    for (final width in [0, 3, 12, -12, 100001]) {
      expectPrintfParity('%*s', [width, 'dyn']);
    }
    for (final precision in [0, 2, -1, 100001]) {
      expectPrintfParity('%.*s', [precision, 'dyn']);
    }
    expectPrintfParity('%*.*s', [8, 2, 'dynamic']);
    expectPrintfParity('%*s', ['not int', 'dyn']);
    expectPrintfParity('%s', []);
  });
```

- [ ] **Step 2: Прогнать — compile-тест падает**

Run: `dart test test/template_ir_compile_test.dart`
Expected: FAIL.

- [ ] **Step 3: Реализация**

Общий резолвер динамических опций (в `template_ir.dart`) — статика
запекается в op на этапе компиляции и сюда не попадает; литеральные
значения вне `_maximumSafePrintfOption` компилятор отправляет в
fallback, который кидает сегодняшнюю ошибку на каждый вызов:

```dart
/// Resolves a dynamic printf width/precision for a hot op, mirroring
/// _PrintfProcessor._resolveOption including error contexts. Static
/// options never pass through here: they are baked into ops at compile
/// time.
int _resolveIrPrintfOption(
  _PrintfProcessor frame,
  _PrintfConversionNode node,
  int argumentIndex,
  String role,
) {
  final argument = frame._argumentAt(argumentIndex, node, specifier: role);
  if (argument is! int || !_isIntegerValue(argument)) {
    throw UnsupportedFormatValueException(
      _printfContext(
        frame.template,
        node,
        specifier: role,
        argumentIndex: argumentIndex,
      ),
      argument,
    );
  }
  return frame._validateOption(
    node,
    argument,
    role,
    argumentIndex: argumentIndex,
  );
}
```

Сентинель -1 конфликтует с легальной шириной 0, поэтому op хранит
`bool hasWidth`/`bool hasPrecision` отдельно от значений:

```dart
final class _PrintfStringOp extends _PrintfOp {
  final _PrintfConversionNode node;
  final int valueArgIndex;
  final bool left;
  final bool hasWidth;
  final int staticWidth; // meaningful when hasWidth && widthArgIndex < 0
  final int widthArgIndex; // -1 static
  final bool hasPrecision;
  final int staticPrecision;
  final int precisionArgIndex; // -1 static
  final TextUnit textUnit;

  const _PrintfStringOp({
    required this.node,
    required this.valueArgIndex,
    required this.left,
    required this.hasWidth,
    required this.staticWidth,
    required this.widthArgIndex,
    required this.hasPrecision,
    required this.staticPrecision,
    required this.precisionArgIndex,
    required this.textUnit,
  });

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
    late final String text;
    try {
      text = argument.toString();
    } on FormattingException {
      rethrow;
    } on Object catch (_) {
      throw UnsupportedConversionException(
        _printfContext(frame.template, node, argumentIndex: valueArgIndex),
        argument,
      );
    }
    final truncated =
        precision == null ? text : textUnit.take(text, precision);
    if (width == null) {
      sink.writeString(truncated);
      return;
    }
    final padding = width - textUnit.length(truncated);
    if (!effectiveLeft) sink.fill(0x20, padding);
    sink.writeString(truncated);
    if (effectiveLeft) sink.fill(0x20, padding);
  }

  @override
  String describe() {
    final buffer = StringBuffer('str');
    if (hasWidth) buffer.write(widthArgIndex < 0 ? ':w$staticWidth' : ':w*');
    if (hasPrecision) {
      buffer.write(precisionArgIndex < 0 ? ':p$staticPrecision' : ':p*');
    }
    return buffer.toString();
  }
}
```

Ветка `_classifyPrintfConversion`:

```dart
  if (node.type == 's') {
    final width = node.width;
    final precision = node.precision;
    var left = _hasPrintfFlag(node.flags, _PrintfFlags.left);
    var staticWidth = 0;
    if (width case _LiteralPrintfOption(:final value)) {
      if (value < -_maximumSafePrintfOption ||
          value > _maximumSafePrintfOption) {
        return null; // Unsafe static width keeps today's per-call error.
      }
      staticWidth = value < 0 ? -value : value;
      if (value < 0) left = true;
    }
    var staticPrecision = 0;
    var hasPrecision = precision != null;
    if (precision case _LiteralPrintfOption(:final value)) {
      if (value > _maximumSafePrintfOption) return null;
      if (value < 0) hasPrecision = false;
      staticPrecision = value < 0 ? 0 : value;
    }
    return _PrintfStringOp(
      node: node,
      valueArgIndex: valueArgIndex,
      left: left,
      hasWidth: width != null,
      staticWidth: staticWidth,
      widthArgIndex: widthArgIndex,
      hasPrecision: hasPrecision,
      staticPrecision: staticPrecision,
      precisionArgIndex: precisionArgIndex,
      textUnit: textUnit,
    );
  }
```

`_maximumSafeOption` переносится из `_PrintfProcessor` в
топ-левел константу `_maximumSafePrintfOption` (файл
`printf_processor.dart`), процессор и классификатор используют её
совместно.

- [ ] **Step 4: Прогнать тесты, полный suite, node**

Run: `dart test test/template_ir_compile_test.dart test/template_ir_diff_test.dart && dart test && dart analyze lib test example && dart test -p node test/template_ir_diff_test.dart`
Expected: всё PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/template_ir.dart lib/src/printf_processor.dart \
  test/template_ir_compile_test.dart test/template_ir_diff_test.dart
git commit -m "perf: write printf %s conversions directly into the sink"
```

---

### Task 8: `_PrintfIntOp` — горячие `d/i/u/o/x/X`

**Files:**
- Modify: `lib/src/template_ir.dart`
- Test: `test/template_ir_compile_test.dart`,
  `test/template_ir_diff_test.dart`

**Interfaces:**
- Consumes: `_resolveIrPrintfOption` (Task 7), `CharSink.digitCount`,
  `CharSink.writeMagnitude`, `formatMagnitude`, `_PrintfFlags`.
- Produces: `_PrintfIntOp` с `describe()` вида
  `'int:d'`/`'int:d:w10'`/`'int:x:w*'`/`'int:d:p3'`; ветка
  `d/i/u/o/x/X` в `_classifyPrintfConversion`.

- [ ] **Step 1: Написать падающие тесты**

Compile-тест:

```dart
  test('printf integers compile to int ops', () {
    expect(
      debugCompiledProgramDescription(
        '%d|%10d|%-10d|%010d|%+d|% d|%#x|%#o|%.3d|%*d|%u|%X',
        printf: true,
        textUnit: TextUnit.unicodeScalars,
      ),
      ['int:d', 'literal', 'int:d:w10', 'literal', 'int:d:w10', 'literal',
          'int:d:w10', 'literal', 'int:d', 'literal', 'int:d', 'literal',
          'int:x', 'literal', 'int:o', 'literal', 'int:d:p3', 'literal',
          'int:d:w*', 'literal', 'int:u', 'literal', 'int:X'],
    );
  });
```

Дифф-тест:

```dart
  test('printf int op matches the legacy path', () {
    const templates = [
      '%d', '%i', '%10d', '%-10d', '%010d', '%+d', '% d', '%+010d',
      '%u', '%o', '%#o', '%x', '%#x', '%X', '%#X', '%.5d', '%10.5d',
      '%-10.5d', '%.0d', '%#.0o', '%#o', '%08x',
    ];
    final values = <Object?>[
      0, 1, -1, 42, -42, 9007199254740991, -9007199254740991,
      BigInt.parse('123456789012345678901234567890'),
      BigInt.parse('-123456789012345678901234567890'),
      'nope', 3.5, null,
    ];
    for (final template in templates) {
      for (final value in values) {
        expectPrintfParity(template, [value]);
      }
    }
    for (final width in [0, 5, -5, 100001]) {
      expectPrintfParity('%*d', [width, 42]);
      expectPrintfParity('%0*d', [width, 42]);
    }
    for (final precision in [0, 5, -1, 100001]) {
      expectPrintfParity('%.*d', [precision, 42]);
    }
    expectPrintfParity('%*.*d', [10, 4, -42]);
  });
```

- [ ] **Step 2: Прогнать — compile-тест падает**

Run: `dart test test/template_ir_compile_test.dart`
Expected: FAIL.

- [ ] **Step 3: Реализация**

Поля и резолюция опций — как у `_PrintfStringOp` (те же
`hasWidth`/`staticWidth`/`widthArgIndex` и precision-тройка), плюс:

```dart
  final String type; // d i u o x X
  final int radix;
  final bool uppercase;
  final bool signed; // false for 'u'
  final bool alternate;
  final bool spaceFlag;
  final bool signFlag;
  final bool zeroFlag;
```

Тело `write` (величина `int`; ветка BigInt отличается только
получением строки величины через `formatMagnitude` и её длины):

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
    late final bool negative;
    late final bool isZero;
    var magnitudeString = ''; // BigInt branch only
    var digitCount = 0;
    var bigInt = false;
    if (argument is int && _isIntegerValue(argument)) {
      negative = argument.isNegative;
      isZero = argument == 0;
      digitCount = CharSink.digitCount(argument, radix);
    } else if (argument is BigInt) {
      bigInt = true;
      negative = argument.isNegative;
      isZero = argument == BigInt.zero;
      magnitudeString = formatMagnitude(
        negative ? -argument : argument,
        radix,
        uppercase: uppercase,
      );
      digitCount = magnitudeString.length;
    } else {
      throw UnsupportedFormatValueException(_valueContext(frame), argument);
    }
    if (!signed && negative) {
      throw UnsupportedFormatValueException(_valueContext(frame), argument);
    }

    // digits='' for zero with precision 0, as in _formatPrintfInteger.
    var effectiveDigits = digitCount;
    if (isZero && precision == 0) effectiveDigits = 0;
    final zeroPad =
        precision != null && precision > effectiveDigits
            ? precision - effectiveDigits
            : 0;
    // Alternate prefix rules from _formatPrintfInteger: octal adds '0'
    // unless the digits already start with '0'; hex adds 0x/0X unless zero.
    final digitsStartWithZero =
        zeroPad > 0 || (isZero && effectiveDigits > 0);
    final prefix = switch (type) {
      'o' when alternate && !digitsStartWithZero => '0',
      'x' when alternate && !isZero => '0x',
      'X' when alternate && !isZero => '0X',
      _ => '',
    };
    final signChar =
        signed && negative
            ? 0x2d
            : signFlag
            ? 0x2b
            : spaceFlag
            ? 0x20
            : 0;
    final zero = zeroFlag && !effectiveLeft && precision == null;
    final content =
        effectiveDigits + zeroPad + prefix.length + (signChar == 0 ? 0 : 1);
    final padding = width == null ? 0 : width - content;
    final fillChar = zero ? 0x30 : 0x20;
    final align =
        effectiveLeft
            ? 0x3c
            : zero
            ? 0x3d
            : 0x3e;

    if (align == 0x3e) sink.fill(fillChar, padding);
    if (signChar != 0) sink.writeCharCode(signChar);
    if (prefix.isNotEmpty) sink.writeString(prefix);
    if (align == 0x3d) sink.fill(fillChar, padding);
    sink.fill(0x30, zeroPad);
    if (effectiveDigits > 0) {
      if (bigInt) {
        sink.writeString(magnitudeString);
      } else {
        sink.writeMagnitude(argument as int, radix, uppercase: uppercase);
      }
    }
    if (align == 0x3c) sink.fill(fillChar, padding);
  }

  FormatExceptionContext _valueContext(_PrintfProcessor frame) =>
      _printfContext(frame.template, node, argumentIndex: valueArgIndex);

  @override
  String describe() {
    final buffer = StringBuffer('int:$type');
    if (hasWidth) buffer.write(widthArgIndex < 0 ? ':w$staticWidth' : ':w*');
    if (hasPrecision) {
      buffer.write(precisionArgIndex < 0 ? ':p$staticPrecision' : ':p*');
    }
    return buffer.toString();
  }
```

Классификатор: `d/i/u/o/x/X` всегда компилируются в op (динамика
поддержана); литеральные опции вне `_maximumSafePrintfOption` — в
fallback, как в Task 7. `radix`: o→8, x/X→16, иначе 10;
`signed = type == 'd' || type == 'i'` — у остальных типов
отрицательное значение кидает, как в `_formatPrintfInteger`.

- [ ] **Step 4: Прогнать тесты, полный suite, node**

Run: `dart test test/template_ir_compile_test.dart test/template_ir_diff_test.dart test/template_ir_vm_test.dart && dart test && dart analyze lib test example && dart test -p node test/template_ir_diff_test.dart`
Expected: всё PASS, включая minInt-строку printf из Task 5.

- [ ] **Step 5: Commit**

```bash
git add lib/src/template_ir.dart test/template_ir_compile_test.dart \
  test/template_ir_diff_test.dart
git commit -m "perf: write printf integer conversions directly into the sink"
```

---

### Task 9: Сводный дифф-прогон и node-регистрация

**Files:**
- Modify: `test/template_ir_diff_test.dart`
- Modify: `HANDOFF.md` (раздел проверок — только команда node-прогона)

**Interfaces:**
- Consumes: `expectBraceParity`, `expectPrintfParity`.
- Produces: сводный кросс-op тест; зафиксированная node-команда.

- [ ] **Step 1: Дописать сводный тест**

```dart
  test('mixed templates with hot and fallback ops stay identical', () {
    expectBraceParity(
      'id={:08d} name={:<12s} score={:+.2f} raw={} hex={:#x}',
      positional: [77, 'Ann', 12.5, true, 255],
    );
    expectBraceParity(
      '{0} {1:>6s} {0:d} {value:^9d} {2:.1f}',
      positional: [1, 'x', 2.5],
      named: {'value': 42},
    );
    expectBraceParity(
      'auto {} then {:{}d} then {}',
      positional: [1, 2, 5, 'tail'],
    );
    expectPrintfParity(
      '[%s] %05.1f%% (%d of %d, %#x) %-8s|',
      ['run', 99.95, 3, 10, 255, 'ok'],
    );
    expectPrintfParity('%0*d/%.*s/%%', [6, 42, 2, 'abcdef']);
  });

  test('cache clearing does not change IR results', () {
    final before = format('{:10d}|{:<6s}', 42, 'ab');
    debugClearTemplateCaches();
    expect(format('{:10d}|{:<6s}', 42, 'ab'), before);
  });
```

- [ ] **Step 2: Прогнать и зафиксировать node-команду**

Run: `dart test test/template_ir_compile_test.dart test/template_ir_diff_test.dart && dart test -p node test/char_sink_test.dart test/template_ir_compile_test.dart test/template_ir_diff_test.dart`
Expected: PASS. Команду node-прогона добавить в HANDOFF.md к
существующему списку проверок.

- [ ] **Step 3: Полный suite + analyzer**

Run: `dart test && dart analyze lib test example`
Expected: PASS, 0 замечаний.

- [ ] **Step 4: Commit**

```bash
git add test/template_ir_diff_test.dart HANDOFF.md
git commit -m "test: add cross-op differential coverage for template IR"
```

---

### Task 10: A/B-бенчмарк `template_ir_benchmark`

**Files:**
- Create: `example/lib/src/template_ir_benchmark.dart`
- Create: `example/bin/template_ir_benchmark.dart`
- Modify: `example/lib/benchmark.dart` (экспорт)
- Test: `example/test/template_ir_benchmark_test.dart`

**Interfaces:**
- Consumes: seam'ы `debugFormatBraceWithoutIr`/
  `debugFormatPrintfWithoutIr` (импорт
  `package:format/src/engine.dart`), утилиты вывода
  `example/lib/src/utils/output.dart` (`h1`, `h2`, `accent`, `ok`,
  `accentWarning`), образец методики —
  `example/lib/src/double_modes_benchmark.dart`.
- Produces: `void runTemplateIrBenchmark({BenchmarkLineWriter?
  writeLine, int warmupOperations = 1000, int operations = 10000,
  int samples = 7, double equivalenceThresholdPercent = 5.0})`.

- [ ] **Step 1: Написать падающий интеграционный тест**

```dart
// example/test/template_ir_benchmark_test.dart
import 'package:example/benchmark.dart';
import 'package:test/test.dart';

void main() {
  test('template IR benchmark reports every scenario without diffs', () {
    final lines = <String>[];
    runTemplateIrBenchmark(
      writeLine: lines.add,
      warmupOperations: 10,
      operations: 50,
      samples: 3,
    );
    final output = lines.join('\n');
    expect(output, contains('{:10d}'));
    expect(output, contains('%0*d'));
    expect(output, contains('{:.2f}'));
    expect(output, isNot(contains('RESULTS DIFFER')));
    final verdicts =
        lines.where(
          (line) =>
              line.contains('IR FASTER') ||
              line.contains('LEGACY FASTER') ||
              line.contains('PERFORMANCE EQUAL'),
        );
    expect(verdicts.length, 10);
  });

  test('template IR benchmark validates its options', () {
    expect(
      () => runTemplateIrBenchmark(operations: 0),
      throwsArgumentError,
    );
  });
}
```

- [ ] **Step 2: Прогнать — падает**

Run: `dart test example/test/template_ir_benchmark_test.dart`
(запускать из каталога `example/`: `cd example && dart test
test/template_ir_benchmark_test.dart`; дальше по тексту команды
example-тестов подразумевают запуск из `example/`)
Expected: FAIL — `runTemplateIrBenchmark` не определён.

- [ ] **Step 3: Реализация**

`example/lib/src/template_ir_benchmark.dart` строится по образцу
`double_modes_benchmark.dart` (тот же `_measure` с чексуммой и
проверкой ожидаемого результата, то же чередование сторон и
медиана). Отличия:

```dart
import 'dart:math';

import 'package:format/format.dart';
import 'package:format/src/engine.dart' as engine;

import 'utils/output.dart';

typedef BenchmarkLineWriter = void Function(String line);

final _graphemes = Format(textUnit: TextUnit.graphemeClusters);

final class _IrScenario {
  final String label; // printed template label
  final String kind; // 'hot' | 'fallback-control'
  final String Function() ir;
  final String Function() legacy;

  const _IrScenario({
    required this.label,
    required this.kind,
    required this.ir,
    required this.legacy,
  });
}

final _scenarios = <_IrScenario>[
  _IrScenario(
    label: '{:10d}',
    kind: 'hot',
    ir: () => format('{:10d}', 12345),
    legacy: () => engine.debugFormatBraceWithoutIr(
      '{:10d}',
      defaultFormat,
      positional: const [12345],
    ),
  ),
  // ...и по этому образцу:
  // hot: '{:s}' c 'hello world', '{:<10s}' c 'hello',
  //      '{}' c 'hello', '%s' c 'hello world', '%10d' c 12345,
  //      '%0*d' c [7, 42] (динамические опции остаются горячими);
  // fallback-control: '{:.2f}' c 3.14159,
  //      '{:é^10s}' c 'abc' на _graphemes (грапемный fill).
];
```

Всего 10 сценариев: 8 hot + 2 fallback-control. Вывод по сценарию:

```text
----------------------------------------
hot template: {:10d}
IR:     "     12345"  0.123 µs/op
Legacy: "     12345"  0.456 µs/op
IR FASTER: 73.0%
```

Вердикты: `RESULTS DIFFER` (через `accentWarning`), если строки
разошлись; `PERFORMANCE EQUAL`, если разница ≤
`equivalenceThresholdPercent`; иначе `IR FASTER: N%` либо
`LEGACY FASTER: N%` (N — на сколько процентов медленнее проигравшая
сторона). Валидация опций — как в `runDoubleModesBenchmark`
(`ArgumentError` на неположительных значениях).

`example/bin/template_ir_benchmark.dart` — копия
`bin/double_modes_benchmark.dart` с `runTemplateIrBenchmark`.
В `example/lib/benchmark.dart` добавить экспорт
`src/template_ir_benchmark.dart`.

- [ ] **Step 4: Прогнать тесты и analyzer**

Run: `dart test test/template_ir_benchmark_test.dart` (из
`example/`) и `dart analyze lib test example` (из корня)
Expected: PASS, 0 замечаний.

- [ ] **Step 5: Запустить вживую и посмотреть результат**

Run: `sysctl -n vm.loadavg`, затем
`dart run example/bin/template_ir_benchmark.dart`
Expected: 10 сценариев, ноль `RESULTS DIFFER`; горячие — `IR
FASTER`, fallback-контрольные — `PERFORMANCE EQUAL` (небольшой
`LEGACY FASTER` в пределах порога допустим и означает «копирование
результата в sink»; заметный — сигнал на разбор до Task 11).

- [ ] **Step 6: Commit**

```bash
git add example/lib/src/template_ir_benchmark.dart \
  example/bin/template_ir_benchmark.dart example/lib/benchmark.dart \
  example/test/template_ir_benchmark_test.dart
git commit -m "bench: add IR vs legacy A/B benchmark runner"
```

---

### Task 11: Полная верификация, performance-гейт, handoff

**Files:**
- Modify: `HANDOFF.md`

**Interfaces:**
- Consumes: всё выше.
- Produces: зафиксированный GREEN и обновлённый handoff.

- [ ] **Step 1: Полный тестовый прогон**

Run: `dart test && (cd example && dart test) && dart test -p node test/char_sink_test.dart test/template_ir_compile_test.dart test/template_ir_diff_test.dart && dart analyze lib test example`
Expected: всё зелёное, 0 замечаний.

- [ ] **Step 2: Замер общей матрицы**

Run: `sysctl -n vm.loadavg` (load < 5), затем
`dart run example/bin/benchmark.dart`
Expected: quick ≤ 60 c; ключевые горячие сценарии (`{:10d}`,
`{:s}`, `{:<10s}`, `%s`, `%10d`, `printf.dynamic.hot.10`)
устойчиво быстрее RED-чисел; cold-сценарии и остальная матрица — в
пределах existing equivalence threshold; единственный ERROR —
намеренный sprintf 7.0 на минимальном int.

- [ ] **Step 3: A/B-прогон**

Run: `dart run example/bin/template_ir_benchmark.dart`
Expected: см. Task 10 Step 5; числа записать для handoff.

- [ ] **Step 4: Решение по гейту**

Если GREEN не достигнут (горячие сценарии не ускорились или есть
регрессии за порогом) — не коммитить итог; разбирать по правилу
«нет GREEN — нет коммита»: профилировать (первые подозреваемые —
`_ensure`-рост, `writeString` на fallback-путях, cold-компиляция),
чинить, повторять шаги 1–3. Эскалация для cold-регрессии описана в
спеке (компиляция со второго вызова) — отдельным решением с
пользователем.

- [ ] **Step 5: Обновить HANDOFF.md**

Отразить: IR-архитектуру (файлы, op'ы, seam'ы), числа RED → GREEN
обеих матриц, команду A/B-бенчмарка, незакрытые резервы (double-op,
пул sink'ов, удаление legacy-процессоров).

- [ ] **Step 6: Commit**

```bash
git add HANDOFF.md
git commit -m "docs: record template IR results and refresh handoff"
```

---

## Self-review плана (выполнен)

- Покрытие спеки: sink — Task 1; тотальная компиляция и fallback —
  Tasks 2–3; статические индексы printf — Task 3; горячие op'ы —
  Tasks 4–8; дифф-тест и seam формы — Tasks 2–9; A/B-бенчмарк —
  Task 10; гейты и cold-бюджет — Task 11. Вне охвата спеки ничего
  не добавлено.
- Типы/сигнатуры сведены: `CharSink.writeCodeUnits` вводится в
  Task 2 и используется literal-op'ами обоих диалектов;
  `_resolveIrPrintfOption` определяется в Task 7 в упрощённой
  сигнатуре (динамика-only), Task 3 объявляет её место в
  Interfaces; `_maximumSafePrintfOption` выносится в Task 7.
- Ловушки повторены в Global Constraints: двойная библиотека,
  `debugClearTemplateCaches` в `setUp`, VM-only minInt, load перед
  замерами.
