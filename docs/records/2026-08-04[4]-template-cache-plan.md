# План: кэш разобранных шаблонов

> **Состояние на 2026-08-16:** исполнен, вошло в 3.0.0. Чекбоксы в теле не
> проставлялись — открытым пунктом их читать нельзя.
> **Что это:** план реализации кэша разобранных шаблонов.
> **Связанные записи:** `2026-08-04[3]-template-cache-design.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Кэшировать AST шаблонов (cap 512, полная очистка при переполнении) и лениво мемоизировать `_FormatSpec` статических спецификаций в узле — парсинг уходит из горячего пути повторяющихся шаблонов.

**Architecture:** Новый part-файл `template_cache.dart` с двумя статическими Map и debug-seam'ами; процессоры переключаются на кэшированный lookup. `_FieldNode` получает два мемо-слота (по `TextUnit`); `formatValue` разделяется на обёртку и `formatParsedValue`. Бенчмарк получает cold-секцию с уникальными шаблонами.

**Tech Stack:** Dart; `package:test`; benchmark_harness (без изменений).

**Спека:** `docs/2026-08-04[3]-template-cache-design.md`.

## Global Constraints

- Порядок и содержание ошибок не меняются: мемоизация строго ленивая, ошибки парсинга не кэшируются (ни шаблонов, ни спецификаций).
- Ёмкость кэша 512, зашита константой; публичного API нет; seam'ы приватные (не экспортируются из `format.dart`).
- Никаких timing-ассертов в unit-тестах; performance RED/GREEN — диагностическим скриптом и бенчмарком.
- Quick-бенчмарк ≤ 60 с (потолок поднят пользователем); константы quick 45/165 не менять, пока лимит соблюдается.
- Строки ≤ 80 символов; analyzer без новых замечаний (3 pre-existing info в `test/benchmark_scenarios_test.dart` допустимы).
- Тесты кэша обязаны вызывать `debugClearTemplateCaches` в `setUp` — кэш общий на изолят.
- Коммиты `perf:`/`bench:` с трейлером `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: AST-кэш и seam'ы

**Files:**
- Create: `lib/src/template_cache.dart`
- Modify: `lib/src/engine.dart` (part-директива), `lib/src/brace_processor.dart:24`, `lib/src/printf_processor.dart:17`
- Test: `test/template_cache_test.dart` (новый)

**Interfaces:**
- Produces: `_cachedBraceTemplate(String)`, `_cachedPrintfTemplate(String)`; seam'ы `debugBraceTemplateCacheSize()`, `debugPrintfTemplateCacheSize()`, `debugClearTemplateCaches()`, `Object debugCachedBraceTemplate(String)`, `Object debugCachedPrintfTemplate(String)`.

- [ ] **Step 1: Написать падающие тесты**

`test/template_cache_test.dart`:

```dart
import 'package:format/format.dart';
import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/src/engine.dart' as engine;

void main() {
  setUp(engine.debugClearTemplateCaches);

  test('returns identical ASTs for repeated templates', () {
    final brace1 = engine.debugCachedBraceTemplate('{:10d} x');
    final brace2 = engine.debugCachedBraceTemplate('{:10d} x');
    expect(identical(brace1, brace2), isTrue);

    final printf1 = engine.debugCachedPrintfTemplate('%10d x');
    final printf2 = engine.debugCachedPrintfTemplate('%10d x');
    expect(identical(printf1, printf2), isTrue);

    expect(engine.debugBraceTemplateCacheSize(), 1);
    expect(engine.debugPrintfTemplateCacheSize(), 1);
  });

  test('clears the cache when capacity overflows', () {
    for (var index = 0; index < 512; index++) {
      engine.debugCachedBraceTemplate('unique $index {}');
    }
    expect(engine.debugBraceTemplateCacheSize(), 512);
    engine.debugCachedBraceTemplate('overflow {}');
    expect(engine.debugBraceTemplateCacheSize(), 1);
  });

  test('does not cache templates that fail to parse', () {
    expect(() => format('{:d', 1), throwsA(isA<FormattingException>()));
    expect(() => format('{:d', 1), throwsA(isA<FormattingException>()));
    expect(engine.debugBraceTemplateCacheSize(), 0);
  });

  test('formats through the cache on repeated calls', () {
    expect(format('{:10d}', 1), '         1');
    expect(format('{:10d}', 1), '         1');
    expect(engine.debugBraceTemplateCacheSize(), 1);
    expect(sprintf('%10d', 1), '         1');
    expect(sprintf('%10d', 1), '         1');
    expect(engine.debugPrintfTemplateCacheSize(), 1);
  });
}
```

Примечание: `FormattingException` — проверить экспорт из `package:format/format.dart`; если не экспортируется, использовать `engine.FormattingException`.

- [ ] **Step 2: Убедиться, что тесты падают**

Run: `dart test test/template_cache_test.dart`
Expected: ошибка компиляции — `debugClearTemplateCaches` не определён.

- [ ] **Step 3: Реализация**

`lib/src/template_cache.dart`:

```dart
part of 'engine.dart';

const _templateCacheCapacity = 512;

final _braceTemplateCache = <String, _BraceTemplate>{};
final _printfTemplateCache = <String, _PrintfTemplate>{};

_BraceTemplate _cachedBraceTemplate(String template) {
  final cached = _braceTemplateCache[template];
  if (cached != null) return cached;
  if (_braceTemplateCache.length >= _templateCacheCapacity) {
    _braceTemplateCache.clear();
  }
  return _braceTemplateCache[template] = _parseBraceTemplate(template);
}

_PrintfTemplate _cachedPrintfTemplate(String template) {
  final cached = _printfTemplateCache[template];
  if (cached != null) return cached;
  if (_printfTemplateCache.length >= _templateCacheCapacity) {
    _printfTemplateCache.clear();
  }
  return _printfTemplateCache[template] = _parsePrintfTemplate(template);
}

/// Test seams for the template cache. They are deliberately not exported by
/// `format.dart`.
int debugBraceTemplateCacheSize() => _braceTemplateCache.length;

int debugPrintfTemplateCacheSize() => _printfTemplateCache.length;

void debugClearTemplateCaches() {
  _braceTemplateCache.clear();
  _printfTemplateCache.clear();
}

Object debugCachedBraceTemplate(String template) =>
    _cachedBraceTemplate(template);

Object debugCachedPrintfTemplate(String template) =>
    _cachedPrintfTemplate(template);
```

`lib/src/engine.dart`: добавить `part 'template_cache.dart';` (после `part 'format_spec.dart';`).

`lib/src/brace_processor.dart`: `_parseBraceTemplate(template)` → `_cachedBraceTemplate(template)` в `format()`.

`lib/src/printf_processor.dart`: `_parsePrintfTemplate(template)` → `_cachedPrintfTemplate(template)` в `format()`.

Существующие seam'ы `debugParsePrintfTemplate`/`debugClearPrintfTemplateNodes` продолжают звать `_parsePrintfTemplate` напрямую (мимо кэша) — их не трогать.

- [ ] **Step 4: Убедиться, что тесты проходят**

Run: `dart test test/template_cache_test.dart && dart test && dart analyze lib test`
Expected: новый файл зелёный; вся сюита 332+4 зелёная; analyzer без новых замечаний.

- [ ] **Step 5: Commit**

```bash
git add lib/src/template_cache.dart lib/src/engine.dart lib/src/brace_processor.dart lib/src/printf_processor.dart test/template_cache_test.dart
git commit -m "perf: cache parsed templates

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Мемоизация статических спецификаций

**Files:**
- Modify: `lib/src/brace_ast.dart` (слоты в `_FieldNode`), `lib/src/value_formatter.dart` (разделение `formatValue`), `lib/src/brace_processor.dart` (`_formatField`)
- Test: `test/template_cache_test.dart`

**Interfaces:**
- Consumes: кэш из Task 1 (мемо-слоты имеют смысл только на разделяемых узлах).
- Produces: `_FieldNode.memoizedSpec(TextUnit)` / `memoizeSpec(TextUnit, _FormatSpec)`; `formatParsedValue(value, _FormatSpec, engine, context)`; `formatValue` — прежняя сигнатура-обёртка.

- [ ] **Step 1: Написать падающие тесты**

Добавить в `test/template_cache_test.dart`:

```dart
  test('memoizes static specifications per text unit', () {
    final graphemes = Format(textUnit: TextUnit.graphemeClusters);
    final scalars = Format(textUnit: TextUnit.unicodeScalars);
    // 'e' + U+0301: одна графема, но два скаляра — в скалярном режиме
    // спецификация некорректна, в графемном 'é' служит fill.
    const template = '{:e\u0301^6s}';

    expect(
      graphemes.format(template, 'ab'),
      'e\u0301e\u0301abe\u0301e\u0301',
    );
    expect(
      () => scalars.format(template, 'ab'),
      throwsA(isA<FormattingException>()),
    );
    expect(
      graphemes.format(template, 'ab'),
      'e\u0301e\u0301abe\u0301e\u0301',
    );
    expect(
      () => scalars.format(template, 'ab'),
      throwsA(isA<FormattingException>()),
    );
  });

  test('resolves dynamic specifications on every call', () {
    expect(format('{:{}d}', 42, 6), '    42');
    expect(format('{:{}d}', 42, 8), '      42');
  });

  test('invalid static specification throws on every call', () {
    expect(() => format('{:.d}', 1), throwsA(isA<FormattingException>()));
    expect(() => format('{:.d}', 1), throwsA(isA<FormattingException>()));
  });
```

Примечания: синтаксис динамической спецификации сверить с
`test/format_test.dart` (там есть вложенное поле); ожидаемые строки
первого теста пересчитать при реализации, если фактический вывод
отличается — но он обязан быть одинаковым на первом и втором вызове.

ВАЖНО: в реальном тест-файле template и ожидаемые строки записывать
ЯВНЫМИ Dart-escape'ами — `'{:e\u0301^6s}'` и
`'e\u0301e\u0301abe\u0301e\u0301'` (обратный слэш буквально в
исходнике) — а не готовыми символами «é». Предсоставленный é (U+00E9)
— один скаляр и валиден в обоих режимах, что сломает смысл теста;
явный escape защищает и от нормализации редактором.

- [ ] **Step 2: Убедиться в статусе тестов**

Run: `dart test test/template_cache_test.dart`
Expected: тесты Step 1 могут проходить и ДО мемоизации (они пиннят поведение). Это пиннинг-тесты; RED этой задачи — performance (Step 5). Если какой-то падает — исправить ожидание по фактическому выводу (не менять продакшен-код).

- [ ] **Step 3: Реализация**

`lib/src/brace_ast.dart`, в `_FieldNode` после конструктора:

```dart
  _FormatSpec? _scalarSpec;
  _FormatSpec? _graphemeSpec;

  _FormatSpec? memoizedSpec(TextUnit textUnit) => switch (textUnit) {
    TextUnit.unicodeScalars => _scalarSpec,
    TextUnit.graphemeClusters => _graphemeSpec,
  };

  void memoizeSpec(TextUnit textUnit, _FormatSpec spec) {
    switch (textUnit) {
      case TextUnit.unicodeScalars:
        _scalarSpec = spec;
      case TextUnit.graphemeClusters:
        _graphemeSpec = spec;
    }
  }
```

`lib/src/value_formatter.dart`: тело `formatValue` (всё после
`final spec = parseFormatSpec(...)`) переносится в
`formatParsedValue`; перед переносом проверить grep'ом, что тело не
использует строку `specification` (только `spec`):

```dart
String formatValue(
  Object? value,
  String specification,
  Format engine,
  FormatExceptionContext context,
) => formatParsedValue(
  value,
  parseFormatSpec(specification, engine.textUnit, context),
  engine,
  context,
);

// ignore: library_private_types_in_public_api
String formatParsedValue(
  Object? value,
  _FormatSpec spec,
  Format engine,
  FormatExceptionContext context,
) {
  // ...прежнее тело formatValue без строки parseFormatSpec...
}
```

`lib/src/brace_processor.dart`:

```dart
  String _formatField(
    _FieldResolver resolver,
    _FieldNode field,
    Object? value,
  ) {
    final converted =
        field.conversion == null
            ? value
            : applyConversion(
              field.conversion,
              value,
              engine,
              _context(field, ''),
            );
    final staticSpecification = _staticSpecificationText(field);
    if (staticSpecification != null) {
      final context = _context(field, staticSpecification);
      var spec = field.memoizedSpec(engine.textUnit);
      if (spec == null) {
        spec = parseFormatSpec(staticSpecification, engine.textUnit, context);
        field.memoizeSpec(engine.textUnit, spec);
      }
      return formatParsedValue(converted, spec, engine, context);
    }
    final specification = _resolveSpecification(resolver, field);
    final context = _context(field, specification);
    return formatValue(converted, specification, engine, context);
  }

  String? _staticSpecificationText(_FieldNode field) {
    final specification = field.specification;
    if (specification.isEmpty) return '';
    if (specification case [_LiteralNode(:final text)]) return text;
    return null;
  }
```

Из `_resolveSpecification` убрать шорткаты пустого/одиночного литерала
(их перехватывает `_staticSpecificationText`) — оставить чистый
StringBuffer-цикл для динамического пути.

- [ ] **Step 4: Убедиться, что тесты проходят**

Run: `dart test && dart analyze lib test`
Expected: вся сюита зелёная; analyzer без новых замечаний.

- [ ] **Step 5: Performance GREEN**

Run (из `example/`): диагностический скрипт
`<scratchpad>/string_diagnosis.dart` через
`dart --packages=.dart_tool/package_config.json`.
Expected: горячие `{:s}`/`{:10s}`/`{:<10s}` кратно быстрее прежних
0.26/0.36/0.37 мкс (ориентир ≤ 0.20); printf `%10s` тоже быстрее
прежних 0.30. Числа записать для отчёта и коммита.

- [ ] **Step 6: Commit**

```bash
git add lib/src/brace_ast.dart lib/src/value_formatter.dart lib/src/brace_processor.dart test/template_cache_test.dart
git commit -m "perf: memoize static brace specifications

<фактические числа из Step 5>

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Cold-секция бенчмарка и README

**Files:**
- Create: `example/lib/src/benchmark_cold.dart`
- Modify: `example/lib/benchmark.dart` (экспорт), `example/lib/src/comparison_benchmark.dart` (cold-секция), `example/README.md` (цифра quick)
- Test: `example/test/restored_benchmark_test.dart`

**Interfaces:**
- Consumes: `MyBenchmarkBase`, `BenchmarkDurations`, хелперы `utils/output.dart`.
- Produces: `BenchmarkFormat3ColdFormat`, `BenchmarkFormat3ColdSprintf`.

- [ ] **Step 1: Написать падающий тест**

В интеграционный тест `comparison benchmark skips unsupported runners...` в `example/test/restored_benchmark_test.dart` добавить:

```dart
    expect(output, contains('Cold: unique template per call'));
    expect(output, contains('(cold)'));
```

- [ ] **Step 2: Убедиться, что тест падает**

Run (из `example/`): `dart test test/restored_benchmark_test.dart`
Expected: FAIL — в выводе нет 'Cold:'.

- [ ] **Step 3: Реализация**

`example/lib/src/benchmark_cold.dart`:

```dart
import 'package:format/format.dart';

import 'my_benchmark_base.dart';

final _format3Cold = Format(textUnit: TextUnit.graphemeClusters);

final class BenchmarkFormat3ColdFormat extends MyBenchmarkBase {
  var _counter = 0;

  BenchmarkFormat3ColdFormat() : super(name: 'format 3.0 → format (cold)');

  @override
  bool get isSprintf => false;

  @override
  void run() {
    for (var call = 0; call < 10; call++) {
      output = _format3Cold.formatWith(
        'v${_counter++}={:10d}',
        positional: values,
      );
    }
  }
}

final class BenchmarkFormat3ColdSprintf extends MyBenchmarkBase {
  var _counter = 0;

  BenchmarkFormat3ColdSprintf() : super(name: 'format 3.0 → sprintf (cold)');

  @override
  bool get isSprintf => true;

  @override
  void run() {
    for (var call = 0; call < 10; call++) {
      output = _format3Cold.vsprintf('v${_counter++}=%10d', values);
    }
  }
}
```

`example/lib/benchmark.dart`: `export 'src/benchmark_cold.dart';` (по алфавиту, после `benchmark_format3_sprintf.dart`... фактически: между `src/benchmark_cold.dart` идёт ПЕРВЫМ по алфавиту среди benchmark_* — вставить перед `src/benchmark_format2_format.dart`).

`example/lib/src/comparison_benchmark.dart` — после цикла матрицы, перед итоговой сводкой:

```dart
  emit('');
  emit(h1('----------------------------------------'));
  emit('Cold: unique template per call (no cache hits)');
  emit('');
  final coldBenchmarks = [
    BenchmarkFormat3ColdFormat(),
    BenchmarkFormat3ColdSprintf(),
  ];
  for (final benchmark in coldBenchmarks) {
    benchmark.durations = resolved;
    final score = benchmark.go('{:10d}', [12345]);
    emit('${accent(benchmark.name)}: ${format('{:.3f}', score)} µs');
  }
```

(шаблон-аргумент `go` не используется cold-раннерами; OK-проверки нет —
вывод меняется от итерации к итерации.)

Импорт `benchmark_cold.dart` добавить в `comparison_benchmark.dart`.

`example/README.md`: цифру quick-режима обновить по фактическому
замеру Task 4 (округление до 5 с).

- [ ] **Step 4: Убедиться, что тесты проходят**

Run (из `example/`): `dart test && dart analyze .`
Expected: все тесты зелёные; analyzer чист.

- [ ] **Step 5: Commit**

```bash
git add lib/src/benchmark_cold.dart lib/benchmark.dart lib/src/comparison_benchmark.dart test/restored_benchmark_test.dart README.md
git commit -m "bench: add cold template scenario

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

(README добавить в коммит после Task 4, если цифра меняется — тогда
отдельным `bench: update quick mode figure`; либо выполнить Task 4
до коммита и включить сюда.)

---

### Task 4: Полная верификация

**Files:** нет новых (возможна правка цифры в `example/README.md`).

- [ ] **Step 1: Полные тесты и analyzer**

Run (корень): `dart test && dart analyze lib test example`
Run (`example/`): `dart test`
Expected: всё зелёное; analyzer — только 3 pre-existing info.

- [ ] **Step 2: Node-прогон**

Run (корень): `dart test -p node test/format_spec_fast_path_test.dart test/format_test.dart test/template_cache_test.dart`
Expected: зелёные (кэш обязан работать и в JS-профиле).

- [ ] **Step 3: Полный бенчмарк**

Run (из `example/`): `dart run bin/benchmark.dart 2>&1 | tee <scratchpad>/bench_cache.txt`, затем `tail -1` и `grep -c ERROR`.
Expected: `Mode: quick. Total: NN.N s`, NN.N ≤ 60; ERROR ровно 1
(намеренный sprintf 7.0); hot-колонки format 3.0 заметно быстрее
прежних; cold-строки в пределах ~0.4–0.7 мкс (сопоставимо с
до-кэшевыми полными вызовами).

- [ ] **Step 4: Обновить README и закоммитить остатки**

Если фактический Total изменил цифру (округление до 5 с) — обновить
`example/README.md` и включить в коммит Task 3 (если ещё не сделан)
или отдельный:

```bash
git add README.md
git commit -m "bench: update quick mode figure

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
