# Format 3 Core Implementation Plan

Статус: исполнен, вошло в 3.0.0. Чекбоксы в теле не проставлялись — открытым пунктом их читать нельзя.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Построить Python-совместимое ядро Format 3 с неизменяемым `Format`, двухуровневым API `format`/`formatWith`, строгой грамматикой `{...}`, точным числовым форматированием и расширениями Dart.

**Architecture:** Синтаксический анализатор фигурных полей создаёт закрытое дерево шаблона, resolver отдельно получает значения и выполняет conversions, а общий типизированный слой форматирует текст, целые числа и `double`. Публичный `Format` хранит неизменяемую конфигурацию; функции верхнего уровня только делегируют `defaultFormat`.

**Tech Stack:** Dart SDK `^3.7.2`, `characters ^1.4.0`, `test ^1.25.14`, Python 3.14 только для осознанной генерации эталонов.

## Global Constraints

- Нормативный контракт `{...}` — `str.format()` Python 3.14; `std::format` является вторичным ориентиром.
- `format` принимает от нуля до десяти отдельных значений; `formatWith` принимает одновременно `List<Object?> positional` и `Map<String, Object?> named`.
- `List` и `Map` в `format` являются одним значением и не раскрываются автоматически.
- `formatNamed`, глобальные `registerFormatter`/`unregisterFormatter`, String extensions и `Map<Symbol, Object?>` удаляются.
- `Format` и все переданные ему коллекции конфигурации неизменяемы после конструктора.
- `TextUnit.unicodeScalars` используется по умолчанию; `TextUnit.graphemeClusters` включается явно.
- Основной пакет не зависит от `intl`; `n` использует встроенный `CNumberLocale`.
- Пользовательские formatter не заменяют встроенные specifier и получают `payload` после второго `:`.
- Все ошибки принадлежат типизированной иерархии `FormattingException`; сырые ошибки реализации наружу не выходят.
- Публичного API предварительно разобранного шаблона нет.
- Production-код изменяется через red-green-refactor: сначала падающий тест, затем минимальная реализация, затем переработка.
- Все shell-команды запускаются через `rtk`; работа выполняется в текущем дереве без worktree и без отката существующих изменений.

Порядок исполнения набора: этот core plan → `2026-08-01-format-3-sprintf.md` →
`2026-08-01-format-3-intl.md` →
`2026-08-01-format-3-verification-release.md`.

---

## Структура файлов

- `lib/format.dart` — единственная публичная точка экспорта.
- `lib/src/engine.dart` — внутренняя library, imports и `part` declarations всех закрытых engine-файлов.
- `lib/src/api.dart` — part с `defaultFormat` и четырьмя делегирующими функциями верхнего уровня; в этом плане реализуются `format` и `formatWith`, а `%`-функции добавляются следующим планом.
- `lib/src/format.dart` — part с неизменяемой конфигурацией `Format` и методами экземпляра.
- `lib/src/errors.dart` — вся публичная иерархия ошибок и контекст шаблона.
- `lib/src/extensions.dart` — `Formatter<T>`, `FormatOptions`, `AttributeLookup<T>` и `Representation<T>`.
- `lib/src/number_locale.dart` — `NumberLocale`, `CNumberLocale` и locale-операции общего числового слоя.
- `lib/src/text_unit.dart` — `TextUnit`, измерение, обрезка и проверка fill.
- `lib/src/brace_ast.dart` — закрытые узлы разобранного `{...}`-шаблона.
- `lib/src/python_identifier.dart` — сгенерированные Python 3.14 XID- и decimal-ranges.
- `lib/src/brace_parser.dart` — строгий анализ скобок, полей, цепочек lookup, conversions и вложенных полей.
- `lib/src/field_resolver.dart` — нумерация аргументов и разрешение `.attribute`/`[item]`.
- `lib/src/representation.dart` — встроенные `!r`, `!a`, защита от рекурсии и пользовательские representation.
- `lib/src/format_spec.dart` — разбор стандартной Python-спецификации и пользовательского `name:payload`.
- `lib/src/binary64.dart` — точное разложение IEEE-754 и десятичное округление через `BigInt`.
- `lib/src/number_format.dart` — общие примитивы целого и вещественного форматирования, знака, группировки и padding.
- `lib/src/value_formatter.dart` — политика `{...}` для строк, `c`, чисел, `n`, пользовательских formatter и пустой спецификации.
- `lib/src/brace_processor.dart` — интеграция дерева, resolver, conversions, вложенной спецификации и formatter.
- `tool/generate_python_fixtures.py` — воспроизводимая генерация эталонов Python 3.14.
- `tool/generate_python_identifiers.py` — воспроизводимая генерация identifier/digit tables из Python 3.14.
- `test/fixtures/python_format.json` — сохранённые эталоны и версия генератора.
- `test/fixtures/python_divergences.json` — утверждённые намеренные отличия Dart.
- `test/support/fixture_value.dart` — кодирование `BigInt`, `-0.0`, `nan` и бесконечностей.
- `test/*_test.dart` — тесты по ответственности вместо одного растущего файла.

---

### Task 1: Публичные value types и полная иерархия ошибок

**Files:**
- Modify: `lib/src/errors.dart`
- Create: `lib/src/extensions.dart`
- Create: `lib/src/number_locale.dart`
- Create: `lib/src/text_unit.dart`
- Modify: `lib/format.dart`
- Modify: `test/api_test.dart`
- Create: `test/errors_test.dart`

**Interfaces:**
- Produces: `FormattingException`, `FormatExceptionContext`, все конкретные исключения, `Formatter<T>`, `FormatOptions`, `AttributeLookup<T>`, `Representation<T>`, `NumberLocale`, `CNumberLocale`, `TextUnit`.
- Consumes: только `characters` внутри операций `TextUnit`; новые публичные типы не импортируют parser или processor.

- [ ] **Step 1: Написать падающий тест публичных типов**

```dart
test('exports Format 3 extension and locale contracts', () {
  const options = FormatOptions(
    sign: '+',
    normalizeNegativeZero: true,
    alternate: true,
    zero: true,
    grouping: '_',
    precision: 3,
    payload: 'pretty',
  );
  expect(options.payload, 'pretty');
  expect(const CNumberLocale().decimalSeparator, '.');
  expect(TextUnit.values, [
    TextUnit.unicodeScalars,
    TextUnit.graphemeClusters,
  ]);
});
```

Добавить compile-time реализации `Formatter`, `AttributeLookup` и
`Representation` в `test/api_test.dart`, чтобы внешний пакет мог их расширять.

- [ ] **Step 2: Запустить тест и подтвердить RED**

Run: `rtk dart test test/api_test.dart`

Expected: compile failure — контракты Format 3 ещё не экспортируются.

- [ ] **Step 3: Реализовать минимальные публичные контракты**

В `lib/src/extensions.dart` определить точные сигнатуры:

```dart
abstract base class Formatter<T> {
  const Formatter();
  String get specifier;
  bool canFormat(Object? value);
  String format(T value, FormatOptions options);
}

final class FormatOptions {
  final String? sign;
  final bool normalizeNegativeZero;
  final bool alternate;
  final bool zero;
  final String? grouping;
  final int? precision;
  final String? payload;

  const FormatOptions({
    this.sign,
    this.normalizeNegativeZero = false,
    this.alternate = false,
    this.zero = false,
    this.grouping,
    this.precision,
    this.payload,
  });
}

abstract base class AttributeLookup<T> {
  const AttributeLookup();
  bool canLookup(Object? value);
  Object? lookup(T value, String attribute);
}

abstract base class Representation<T> {
  const Representation();
  bool canRepresent(Object? value);
  String represent(T value);
}
```

В `lib/src/number_locale.dart` определить `NumberLocale` с символами
`decimalSeparator`, `groupSeparator`, `plusSign`, `minusSign`,
`exponentSeparator`, свойством `bool groupingEnabled`, схемой
`List<int> grouping` и методом `String localizeDigits(String asciiDigits)`.
`CNumberLocale` возвращает `.`, `,`, `+`, `-`, `e`, `false`, `[3]` и исходные
ASCII-цифры.

```dart
abstract interface class NumberLocale {
  String get decimalSeparator;
  String get groupSeparator;
  String get plusSign;
  String get minusSign;
  String get exponentSeparator;
  bool get groupingEnabled;
  List<int> get grouping;
  String localizeDigits(String asciiDigits);
}

final class CNumberLocale implements NumberLocale {
  const CNumberLocale();

  @override
  String get decimalSeparator => '.';
  @override
  String get groupSeparator => ',';
  @override
  String get plusSign => '+';
  @override
  String get minusSign => '-';
  @override
  String get exponentSeparator => 'e';
  @override
  bool get groupingEnabled => false;
  @override
  List<int> get grouping => const [3];
  @override
  String localizeDigits(String asciiDigits) => asciiDigits;
}
```

В `lib/src/text_unit.dart` определить enum из спецификации. Внутренние методы
`length`, `take` и `split` должны использовать `String.runes` для
`unicodeScalars` и `String.characters` для `graphemeClusters`.

- [ ] **Step 4: Реализовать структурированный контекст ошибок**

Базовый контекст должен хранить только применимые значения:

```dart
final class FormatExceptionContext {
  final String? template;
  final int? offset;
  final String? fragment;
  final String? specifier;
  final String? conversion;
  final int? argumentIndex;

  const FormatExceptionContext({
    this.template,
    this.offset,
    this.fragment,
    this.specifier,
    this.conversion,
    this.argumentIndex,
  });
}

sealed class FormattingException implements Exception {
  final String message;
  final FormatExceptionContext context;
  const FormattingException(this.message, this.context);
}
```

Реализовать `InvalidFormatException(reason)`,
`InvalidSpecifierException(reason)`, `MissingFormatArgumentException(key)`,
`FormatLookupException(segment, value)`,
`UnsupportedConversionException(value)`,
`UnsupportedFormatValueException(value)`,
`FormatConfigurationException(reason)`,
`AmbiguousFormatterException(value, matches)` и
`FormatExtensionException(extension, error, stackTrace)`. Коллекции в ошибках
копировать через `List.unmodifiable`.

- [ ] **Step 5: Проверить структурированные поля и отсутствие сырых ошибок**

```dart
test('formatting errors retain machine-readable context', () {
  const context = FormatExceptionContext(
    template: '{value:q}',
    offset: 0,
    fragment: '{value:q}',
    specifier: 'q',
  );
  const error = InvalidSpecifierException(context, 'unknown specifier');
  expect(error.context.offset, 0);
  expect(error.context.specifier, 'q');
  expect(error.reason, 'unknown specifier');
});
```

Run: `rtk dart test test/api_test.dart test/errors_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
rtk git add lib/format.dart lib/src/errors.dart lib/src/extensions.dart lib/src/number_locale.dart lib/src/text_unit.dart test/api_test.dart test/errors_test.dart
rtk git commit -m "feat: define Format 3 public contracts"
```

---

### Task 2: Неизменяемый `Format` и двухуровневый API

**Files:**
- Create: `lib/src/engine.dart`
- Create: `lib/src/api.dart`
- Replace: `lib/src/format.dart`
- Create: `lib/src/brace_processor.dart`
- Modify: `lib/format.dart`
- Modify: `test/api_test.dart`
- Modify: `test/formatter_registry_test.dart`

**Interfaces:**
- Consumes: типы Task 1.
- Produces: `defaultFormat`, top-level `format`, `formatWith`, `Format.format`, `Format.formatWith`; закрытые списки formatter/lookups/representations и настройки `numberLocale`, `textUnit`.

- [ ] **Step 1: Написать RED-тесты сигнатур и делегирования**

```dart
test('format accepts separate nullable values and formatWith accepts both maps', () {
  expect(format('{} {}', 'a', null), 'a null');
  expect(
    formatWith(
      '{0} {name}',
      positional: const ['hello'],
      named: const {'name': 'world'},
    ),
    'hello world',
  );
});

test('a custom Format exposes reusable method tear-offs', () {
  final configured = Format(textUnit: TextUnit.graphemeClusters);
  final appFormat = configured.format;
  final appFormatWith = configured.formatWith;
  expect(appFormat('{}', 'ok'), 'ok');
  expect(appFormatWith('{name}', named: const {'name': 'ok'}), 'ok');
});
```

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/api_test.dart`

Expected: compile failure из-за старых `format(String, List)` и `formatNamed`.

- [ ] **Step 3: Реализовать sentinel и точные обёртки**

`lib/src/engine.dart` импортирует public contract files и объявляет
`part 'api.dart'`, `part 'format.dart'`, `part 'brace_processor.dart'`.
Остальные закрытые engine-файлы последующих tasks добавляются как parts этой же
library, поэтому `_...` types остаются недоступны пользователю и доступны между
небольшими файлами. `api.dart` и `format.dart` начинают с
`part of 'engine.dart';`.

В `lib/src/api.dart` использовать приватный enum-sentinel:

```dart
enum _MissingValue { value }

final defaultFormat = Format();

String format(
  String template, [
  Object? value1 = _MissingValue.value,
  Object? value2 = _MissingValue.value,
  Object? value3 = _MissingValue.value,
  Object? value4 = _MissingValue.value,
  Object? value5 = _MissingValue.value,
  Object? value6 = _MissingValue.value,
  Object? value7 = _MissingValue.value,
  Object? value8 = _MissingValue.value,
  Object? value9 = _MissingValue.value,
  Object? value10 = _MissingValue.value,
]) => defaultFormat.format(
  template,
  value1,
  value2,
  value3,
  value4,
  value5,
  value6,
  value7,
  value8,
  value9,
  value10,
);

String formatWith(
  String template, {
  List<Object?> positional = const [],
  Map<String, Object?> named = const {},
}) => defaultFormat.formatWith(
  template,
  positional: positional,
  named: named,
);
```

Метод `Format.format` собирает значения до первого sentinel и вызывает
`formatWith`. Явный `null` остаётся в списке. На этой стадии закрытый
`_BraceProcessor` может поддерживать литералы и простые `{}`/`{name}`; полная
грамматика добавляется следующими задачами.

- [ ] **Step 4: Перенести registry в конструктор и сделать конфигурацию immutable**

```dart
final class Format {
  final List<Formatter<dynamic>> formatters;
  final List<AttributeLookup<dynamic>> lookups;
  final List<Representation<dynamic>> representations;
  final NumberLocale numberLocale;
  final TextUnit textUnit;

  Format({
    Iterable<Formatter<dynamic>> formatters = const [],
    Iterable<AttributeLookup<dynamic>> lookups = const [],
    Iterable<Representation<dynamic>> representations = const [],
    this.numberLocale = const CNumberLocale(),
    this.textUnit = TextUnit.unicodeScalars,
  }) : formatters = List.unmodifiable(formatters),
       lookups = List.unmodifiable(lookups),
       representations = List.unmodifiable(representations) {
    _validateConfiguration();
  }
}
```

В `_validateConfiguration` отвергать не-ASCII имя, встроенное имя, дубликат
specifier и повтор одного экземпляра расширения через
`FormatConfigurationException`. Зарезервированный set равен
`b,c,d,e,E,f,F,g,G,n,o,s,x,X,%`. Удалить статические mutating methods.

- [ ] **Step 5: Проверить новый API и отсутствие старого экспорта**

Run: `rtk dart test test/api_test.dart test/formatter_registry_test.dart`

Expected: PASS; тесты используют отдельный `Format(formatters: [...])`, а имя
`formatNamed` отсутствует в публичном export.

Run: `rtk dart analyze`

Expected: no issues.

- [ ] **Step 6: Commit**

```bash
rtk git add lib/format.dart lib/src/engine.dart lib/src/api.dart lib/src/format.dart lib/src/brace_processor.dart test/api_test.dart test/formatter_registry_test.dart
rtk git commit -m "feat: add immutable Format 3 facade"
```

---

### Task 3: Строгий parser фигурных полей и закрытое дерево

**Files:**
- Modify: `lib/src/engine.dart`
- Create: `lib/src/brace_ast.dart`
- Create: `lib/src/python_identifier.dart`
- Create: `lib/src/brace_parser.dart`
- Create: `tool/generate_python_identifiers.py`
- Replace: `test/parser_test.dart`

**Interfaces:**
- Consumes: `InvalidFormatException`, `UnsupportedConversionException`.
- Produces: `_BraceTemplate parseBraceTemplate(String template)` с `_LiteralNode` и `_FieldNode`; `_FieldNode` хранит root, lookup-сегменты, conversion, spec-template, offset и fragment.

- [ ] **Step 1: Написать RED-тесты грамматики и нумерации**

```dart
test('parses nested fields and lookup chains', () {
  final debug = debugParseBraceTemplate('{user.items[0].name!r:{width}}');
  expect(debug, contains('root=user'));
  expect(debug, contains('attribute=items'));
  expect(debug, contains('item=0'));
  expect(debug, contains('conversion=r'));
  expect(debug, contains('nested=width'));
});

for (final template in ['{0} {}', '{} {1}', '{:{:{}}}', '{ name }', "{'name'}"]) {
  test('rejects invalid field grammar: $template', () {
    expect(
      () => debugParseBraceTemplate(template),
      throwsA(isA<InvalidFormatException>()),
    );
  });
}
```

Parser files являются parts `engine.dart`. Для единственной structural проверки
`engine.dart` предоставляет неэкспортируемую из `lib/format.dart` функцию
`String debugParseBraceTemplate(String)`. `test/parser_test.dart` импортирует
`package:format/src/engine.dart`; остальные parser tests идут через public API.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/parser_test.dart`

Expected: compile failure — нового parser и AST нет.

- [ ] **Step 3: Реализовать узлы AST**

```dart
sealed class BraceNode {
  final int offset;
  final String fragment;
  const BraceNode(this.offset, this.fragment);
}

final class LiteralNode extends BraceNode {
  final String text;
  const LiteralNode(super.offset, super.fragment, this.text);
}

final class FieldNode extends BraceNode {
  final FieldRoot root;
  final List<FieldAccess> accesses;
  final String? conversion;
  final List<BraceNode> specification;
  const FieldNode({
    required super.offset,
    required super.fragment,
    required this.root,
    required this.accesses,
    required this.conversion,
    required this.specification,
  });
}

sealed class FieldRoot { const FieldRoot(); }
final class AutomaticRoot extends FieldRoot { const AutomaticRoot(); }
final class PositionalRoot extends FieldRoot {
  final int index;
  const PositionalRoot(this.index);
}
final class NamedRoot extends FieldRoot {
  final String name;
  const NamedRoot(this.name);
}

sealed class FieldAccess { const FieldAccess(); }
final class AttributeAccess extends FieldAccess {
  final String name;
  const AttributeAccess(this.name);
}
final class IntegerItemAccess extends FieldAccess {
  final int index;
  const IntegerItemAccess(this.index);
}
final class StringItemAccess extends FieldAccess {
  final String key;
  const StringItemAccess(this.key);
}
```

`FieldRoot` различает automatic, positional и named. `FieldAccess` различает
attribute, integer item и literal string item. Все списки неизменяемы.

- [ ] **Step 4: Сгенерировать Python identifier и decimal tables**

`tool/generate_python_identifiers.py` проходит все scalars `0..0x10ffff`,
использует `chr(code).isidentifier()` для start,
`('A' + chr(code)).isidentifier()` для continue и
`unicodedata.decimal(chr(code), None)` для decimal value. Он сжимает соседние
scalars в ranges, записывает `unicodedata.unidata_version` и создаёт
`lib/src/python_identifier.dart` с binary-search helpers
`isPythonIdentifierStart`, `isPythonIdentifierContinue` и
`pythonDecimalDigitValue`.

Run: `rtk python3.14 tool/generate_python_identifiers.py`

Expected: повторный запуск не меняет generated Dart file.

- [ ] **Step 5: Реализовать однопроходный parser с глубиной вложения**

Parser проходит UTF-16 offsets без форматирования значений. Он:

1. превращает `{{`/`}}` в literal;
2. читает root и lookup chain до `!`, `:` или `}`;
3. принимает только `!s`, `!r`, `!a`;
4. разбирает specification как literal и вложенные `FieldNode` на глубине 1;
5. запрещает вторую вложенность;
6. хранит mode automatic/manual и отвергает их смешивание во всём шаблоне,
   включая вложенные поля;
7. использует generated Python XID tables для root/attribute;
8. собирает числовой root/item из `pythonDecimalDigitValue`, проверяет range
   через `BigInt` и только затем преобразует в Dart `int`.

Любая ошибка создаётся через helper `_invalid(offset, end, reason)`, чтобы
`template`, `offset` и точный `fragment` всегда присутствовали.

- [ ] **Step 6: Проверить parser edge cases**

Run: `rtk dart test test/parser_test.dart`

Expected: PASS для escaped braces, `[arbitrary key]`, Unicode identifiers,
вложенной ширины/precision; typed FAIL для unmatched braces, quotes, whitespace,
mixed numbering и depth 2.

- [ ] **Step 7: Commit**

```bash
rtk git add lib/src/engine.dart lib/src/brace_ast.dart lib/src/python_identifier.dart lib/src/brace_parser.dart tool/generate_python_identifiers.py test/parser_test.dart
rtk git commit -m "feat: parse Python format fields"
```

---

### Task 4: Разрешение аргументов и lookup extensions

**Files:**
- Modify: `lib/src/engine.dart`
- Create: `lib/src/field_resolver.dart`
- Create: `test/lookup_test.dart`
- Modify: `lib/src/brace_processor.dart`

**Interfaces:**
- Consumes: `FieldRoot`, `FieldAccess`, immutable lookups from `Format`.
- Produces: `Object? resolveField(FieldNode, positional, named, Format)`; built-in `List` index, `Map` item and `.name`, exactly one matching `AttributeLookup` for other objects.

- [ ] **Step 1: Написать падающие lookup-тесты через публичный API**

```dart
test('resolves positional, named, item and Map attribute paths', () {
  expect(
    formatWith(
      '{0[1]} {user.name} {user[address]}',
      positional: const [<String>['zero', 'one']],
      named: const {
        'user': {'name': 'Ada', 'address': 'London'},
      },
    ),
    'one Ada London',
  );
});

test('uses exactly one custom attribute lookup', () {
  final engine = Format(lookups: [PersonLookup()]);
  expect(engine.formatWith('{person.name}', named: {'person': Person('Ada')}), 'Ada');
});
```

Добавить отдельные expectations для missing root, range error, missing Map key,
unsupported attribute и двух matching lookups.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/lookup_test.dart`

Expected: FAIL на цепочках и пользовательском lookup.

- [ ] **Step 3: Реализовать root resolution и built-ins**

`FieldResolver` хранит один automatic index на весь вызов processor. Automatic
root увеличивает его на 1; manual root не меняет его. Named root использует
`containsKey`, чтобы отличить отсутствующее имя от значения `null`.

Для каждого access:

```dart
switch (access) {
  case IntegerItemAccess(:final index):
    if (value is List<Object?>) return value[index];
    if (value is Map<Object?, Object?> && value.containsKey(index)) {
      return value[index];
    }
  case StringItemAccess(:final key):
    if (value is Map<Object?, Object?> && value.containsKey(key)) {
      return value[key];
    }
  case AttributeAccess(:final name):
    if (value is Map<Object?, Object?> && value.containsKey(name)) {
      return value[name];
    }
}
```

Обернуть `RangeError` и отсутствующие сегменты в `FormatLookupException` с
исходным field context.

- [ ] **Step 4: Реализовать dispatch пользовательского lookup**

Собрать все `lookup.canLookup(value)`. Ноль совпадений даёт
`FormatLookupException`, больше одного — `AmbiguousFormatterException` с
именами runtime types. Вызов `lookup.lookup` оборачивать в
`FormatExtensionException`, сохраняя original error и stack trace.

- [ ] **Step 5: Подтвердить GREEN**

Run: `rtk dart test test/lookup_test.dart test/parser_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
rtk git add lib/src/engine.dart lib/src/field_resolver.dart lib/src/brace_processor.dart test/lookup_test.dart
rtk git commit -m "feat: resolve Python field paths"
```

---

### Task 5: `!s`, `!r`, `!a` и рекурсивные representations

**Files:**
- Modify: `lib/src/engine.dart`
- Create: `lib/src/representation.dart`
- Create: `test/conversion_test.dart`
- Modify: `lib/src/brace_processor.dart`

**Interfaces:**
- Consumes: `Format.representations`, field context.
- Produces: `Object? applyConversion(String?, Object?, Format, context)`; `!s` возвращает String, `!r`/`!a` используют детерминированный representer.

- [ ] **Step 1: Написать RED-тесты встроенных conversions**

```dart
test('implements deterministic repr and ascii conversion', () {
  expect(format('{!r}', "a\n'b"), r'''"a\n'b"''');
  expect(format('{!a}', 'Привет'), contains(r'\u'));
  expect(format('{!r}', [true, null, 'x']), "[true, null, 'x']");
});

test('marks recursive containers without recursing forever', () {
  final values = <Object?>[];
  values.add(values);
  expect(format('{!r}', values), '[[...]]');
});
```

Добавить tests для `Map`, `Set`, `set()`, кавычек, control escapes, `nan`,
`inf`, `-0.0`, порядка итерации и unsupported object.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/conversion_test.dart`

Expected: FAIL — conversions ещё не применяются.

- [ ] **Step 3: Реализовать встроенный representer**

`RepresentationWriter` держит identity-set активных контейнеров. Для String
выбирает одинарную кавычку, если она уменьшает escaping, иначе двойную;
экранирует `\\`, выбранную кавычку, `\t`, `\n`, `\r` и управляющие scalars.
Контейнер добавляется в active set перед обходом и удаляется в `finally`.

Числа используют общий канонический output; `bool` и `null` намеренно дают
`true`, `false`, `null`. Неизвестный объект проходит через ровно одну
`Representation`; ноль совпадений даёт `UnsupportedConversionException`, два —
`AmbiguousFormatterException`, ошибка extension оборачивается.

- [ ] **Step 4: Реализовать ASCII escaping**

После `!r` пройти Unicode scalars и оставить `0x20..0x7e`. Остальные кодировать
как `\xhh` до `0xff`, `\uhhhh` до `0xffff`, `\Uhhhhhhhh` выше; hex digits —
lowercase, длина фиксирована.

- [ ] **Step 5: Подтвердить GREEN и Python cases**

Run: `rtk dart test test/conversion_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
rtk git add lib/src/engine.dart lib/src/representation.dart lib/src/brace_processor.dart test/conversion_test.dart
rtk git commit -m "feat: add deterministic format conversions"
```

---

### Task 6: Text units, строки, fill, alignment и `c`

**Files:**
- Modify: `lib/src/engine.dart`
- Modify: `lib/src/text_unit.dart`
- Create: `lib/src/format_spec.dart`
- Create: `lib/src/value_formatter.dart`
- Create: `test/text_format_test.dart`

**Interfaces:**
- Consumes: `TextUnit`, parsed specification string, typed errors.
- Produces: `_FormatSpec`, `parseFormatSpec`, `formatText`, `applyFieldWidth`; strict string and `c` behavior reusable by `sprintf`.

- [ ] **Step 1: Написать RED-тесты Unicode и строгих строковых опций**

```dart
test('uses Unicode scalars by default and graphemes when configured', () {
  expect(format('{:.1s}', 'e\u0301'), 'e');
  final graphemes = Format(textUnit: TextUnit.graphemeClusters);
  expect(graphemes.format('{:.1s}', 'e\u0301'), 'e\u0301');
});

for (final template in ['{:+s}', '{:#.4s}', '{:04s}', '{:.1c}', '{:|4s}', '{:ab>4s}']) {
  test('rejects invalid text spec $template', () {
    expect(() => format(template, 'x'), throwsA(isA<InvalidSpecifierException>()));
  });
}
```

Добавить `c` tests для `0`, `0x10ffff`, `-1`, `0x110000`, surrogate range,
`List<int>`, width и default right alignment.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/text_format_test.dart`

Expected: FAIL на новом default text unit и strict validation.

- [ ] **Step 3: Реализовать spec lexer и строковую policy**

Parser возвращает один exact value object:

```dart
final class _FormatSpec {
  final String? fill;
  final String? align;
  final String? sign;
  final bool normalizeNegativeZero;
  final bool alternate;
  final bool zero;
  final int? width;
  final String? grouping;
  final int? precision;
  final String? fractionalGrouping;
  final String? type;
  final String? customName;
  final String? payload;

  const _FormatSpec({
    this.fill,
    this.align,
    this.sign,
    this.normalizeNegativeZero = false,
    this.alternate = false,
    this.zero = false,
    this.width,
    this.grouping,
    this.precision,
    this.fractionalGrouping,
    this.type,
    this.customName,
    this.payload,
  });
}
```

`parseFormatSpec` читает одну text unit как optional fill только когда следующая
unit — `<`, `>`, `=`, `^`. Затем читает sign, `z`, `#`, `0`, width, grouping,
fractional grouping, precision и type без regex-capture ambiguity. Остаток после
встроенного type запрещён; для custom name/payload он сохраняется Task 9.

Для String разрешить только fill, `<`/`>`/`^`, width, precision и `s`. Пустой
type равен `s`. Fill обязан быть одной выбранной text unit. `applyFieldWidth`
считает длину тем же `TextUnit` и делит нечётный center padding так, чтобы
лишняя unit была справа, как Python.

- [ ] **Step 4: Реализовать `c` без raw RangeError**

Принимать только `int`/`BigInt`, который помещается в `0..0x10ffff` и не входит
в `0xd800..0xdfff`. Создавать `String.fromCharCode` только после проверки.
Неверное значение даёт `UnsupportedFormatValueException`; precision и прочие
недопустимые опции — `InvalidSpecifierException`.

- [ ] **Step 5: Подтвердить GREEN**

Run: `rtk dart test test/text_format_test.dart`

Expected: PASS для scalars, graphemes, multi-scalar fill rejection и typed `c`
errors.

- [ ] **Step 6: Commit**

```bash
rtk git add lib/src/engine.dart lib/src/text_unit.dart lib/src/format_spec.dart lib/src/value_formatter.dart test/text_format_test.dart
rtk git commit -m "feat: format strict Unicode text fields"
```

---

### Task 7: Целые числа, `BigInt`, grouping, alternate form и `=`

**Files:**
- Modify: `lib/src/engine.dart`
- Create: `lib/src/number_format.dart`
- Modify: `lib/src/value_formatter.dart`
- Create: `test/integer_format_test.dart`

**Interfaces:**
- Consumes: `_FormatSpec`, `NumberLocale`, `TextUnit` padding.
- Produces: `formatBraceInteger(Object value, _FormatSpec spec, Format settings)` и общие helpers `formatMagnitude`, `groupDigits`, `applyNumericWidth` для следующего плана.

- [ ] **Step 1: Написать RED-тесты Python integer contract**

```dart
test('formats alternate integer forms and sign-aware alignment', () {
  expect(format('{:#b}', 42), '0b101010');
  expect(format('{:#o}', 42), '0o52');
  expect(format('{:#X}', 42), '0X2A');
  expect(format('{:=+8d}', 42), '+     42');
  expect(format('{:0=+8d}', 42), '+0000042');
});

test('groups decimal and non-decimal digits like Python', () {
  expect(format('{:,d}', 1234567), '1,234,567');
  expect(format('{:_x}', 0x12345678), '1234_5678');
});
```

Добавить matrix для `int`/`BigInt`, negative prefixes, sign flags, zero,
width, `<`/`>`/`^`/`=`, forbidden precision, `c`, `n`, and invalid groupings.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/integer_format_test.dart`

Expected: FAIL на `#b`, `#o`, `#X` и `=`.

- [ ] **Step 3: Реализовать форматирование magnitude**

Преобразовать `int` в `BigInt.from(value)` и далее работать одинаково. Отделить
sign от magnitude до `toRadixString`. Для radix 2/8/16 применить uppercase
только к digits и правильному prefix. `groupDigits` идёт справа налево по 3 или
4 ASCII digits, не затрагивая sign/prefix.

- [ ] **Step 4: Реализовать sign-aware width**

`applyNumericWidth` собирает `sign + prefix + digits`. Для align `=` padding
вставляется между `sign+prefix` и digits. Флаг `0` без явного align равен
`fill='0', align='='`. Обычные `<`, `>`, `^` применяются к готовому полю.
Недопустимые sign, `z`, precision, fractional grouping и types валидируются до
форматирования.

- [ ] **Step 5: Реализовать базовый `n` через `CNumberLocale`**

`n` использует decimal digits, `numberLocale.grouping` и locale-symbols, но
запрещает явные `,n`/`_n`. Для `CNumberLocale` результат совпадает с начальной
C locale Python и не группируется. Вызовы locale methods оборачиваются в
`FormatExtensionException`.

- [ ] **Step 6: Подтвердить GREEN**

Run: `rtk dart test test/integer_format_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
rtk git add lib/src/engine.dart lib/src/number_format.dart lib/src/value_formatter.dart test/integer_format_test.dart
rtk git commit -m "feat: match Python integer formatting"
```

---

### Task 8: Точное IEEE-754 округление и Python `f`/`e`/`g`/`%`

**Files:**
- Modify: `lib/src/engine.dart`
- Create: `lib/src/binary64.dart`
- Modify: `lib/src/number_format.dart`
- Modify: `lib/src/value_formatter.dart`
- Create: `test/double_format_test.dart`

**Interfaces:**
- Consumes: numeric helpers Task 7.
- Produces: `Binary64.fromDouble`, exact ties-to-even scaling, Python default float, `f/F/e/E/g/G/%`, negative-zero normalization and special values.

- [ ] **Step 1: Написать RED-тесты известных несовпадений Format 2**

```dart
test('matches Python rounding, exponent and general thresholds', () {
  expect(format('{:.0f}', 2.5), '2');
  expect(format('{:.0f}', -2.5), '-2');
  expect(format('{:g}', 1e-6), '1e-06');
  expect(format('{:.0g}', 12.0), '1e+01');
  expect(format('{:e}', 1.0), '1.000000e+00');
});

test('default double uses Python shortest representation', () {
  expect(format('{}', 1.23456789), '1.23456789');
  expect(format('{}', 1.0), '1.0');
  expect(format('{}', -0.0), '-0.0');
});

test('integers use Python floating conversions with overflow protection', () {
  expect(format('{:.1f}', 2), '2.0');
  expect(
    () => format('{:f}', BigInt.one << 20000),
    throwsA(isA<UnsupportedFormatValueException>()),
  );
});
```

Добавить boundary matrix около powers of ten, subnormal values, max finite,
precision 0/1/20/50, `#`, `z`, grouping дробной части, nan/inf signs и `%`.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/double_format_test.dart`

Expected: FAIL на ties-to-even, exponent width, `.0g` и default double.

- [ ] **Step 3: Реализовать точное разложение binary64**

Через `ByteData(8)..setFloat64(0, value)` получить sign bit, 11-bit exponent и
52-bit fraction. Для normal добавить hidden bit; для subnormal exponent равен
`-1074`. Представить абсолютное значение как `significand * 2^exponent2`.

Метод округления масштабирует рациональное число степенью 10, выполняет
`quotient/remainder` через `BigInt`, сравнивает `2 * remainder` с denominator и
при точной половине округляет quotient к чётному. Никакие
`toStringAsFixed/Exponential/Precision` не определяют финальное округление.

- [ ] **Step 4: Реализовать fixed/scientific/general policies**

Для fixed округлять `value * 10^precision`. Для scientific сначала определить
decimal exponent сравнением BigInt с powers of ten, затем округлить нужное число
significant digits и повторно нормализовать carry. Exponent выводить со знаком и
минимум двумя цифрами. General использует scientific при `exp < -4` или
`exp >= precision`; без `#` удаляет trailing zero и point.

Default float берёт shortest round-trip digits из `double.toString()`, но заново
выбирает fixed/scientific по Python cutoff `exp < -4 || exp >= 16`, нормализует
exponent и гарантирует `.0` в fixed integer form. Все fixture cases обязаны
подтвердить, что источник shortest digits не создаёт расхождений.

- [ ] **Step 5: Реализовать specials, `z`, `%` и locale symbols**

Сначала округлить, затем применить `z` к отрицательному нулю. `nan`/`inf`
получают sign policy Python и uppercase для `F/G`. `%` форматирует `value * 100`
как fixed и добавляет `%`. Grouping integer/fractional частей выполняется после
округления, до locale digit translation; padding выполняется последним.
`int`/`BigInt` для floating type сначала преобразуется через `toDouble()`;
не-конечный результат конечного целого даёт `UnsupportedFormatValueException`.

- [ ] **Step 6: Подтвердить GREEN**

Run: `rtk dart test test/double_format_test.dart test/integer_format_test.dart`

Expected: PASS для всех boundary cases без precision ceiling 18/20/21.

- [ ] **Step 7: Commit**

```bash
rtk git add lib/src/engine.dart lib/src/binary64.dart lib/src/number_format.dart lib/src/value_formatter.dart test/double_format_test.dart
rtk git commit -m "feat: match Python double formatting"
```

---

### Task 9: Пользовательские formatter, `payload` и вложенные specs

**Files:**
- Modify: `lib/src/engine.dart`
- Modify: `lib/src/format_spec.dart`
- Modify: `lib/src/value_formatter.dart`
- Modify: `lib/src/brace_processor.dart`
- Replace: `test/formatter_registry_test.dart`
- Create: `test/custom_formatter_test.dart`

**Interfaces:**
- Consumes: immutable `Format.formatters`, resolved nested specification.
- Produces: strict `name[:payload]`, automatic unique formatter selection and core-owned fill/align/width.

- [ ] **Step 1: Написать RED-тесты payload и immutable registry**

```dart
test('passes resolved payload and options to a custom formatter', () {
  final engine = Format(formatters: [ProbeFormatter()]);
  expect(
    engine.formatWith(
      '{value:*^12json:{mode}}',
      named: const {'value': 42, 'mode': 'pretty'},
    ),
    '**pretty:42**',
  );
});

test('rejects attempts to register built-in names', () {
  expect(
    () => Format(formatters: [AliasFormatter('d')]),
    throwsA(isA<FormatConfigurationException>()),
  );
});

test('keeps Dart bool and null tokens but rejects numeric specs', () {
  expect(format('{}', true), 'true');
  expect(format('{}', null), 'null');
  expect(() => format('{:d}', true), throwsA(isA<UnsupportedFormatValueException>()));
  expect(() => format('{:f}', null), throwsA(isA<UnsupportedFormatValueException>()));
});
```

Добавить пустой payload, payload с `:`, nested payload, automatic selection,
fallback `toString`, ambiguous matches и extension error wrapping.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/custom_formatter_test.dart test/formatter_registry_test.dart`

Expected: FAIL на constructor registry и payload.

- [ ] **Step 3: Реализовать разбор custom spec**

После стандартной внешней части lexer читает ASCII identifier. Если имя не
является встроенным type, остаток обязан быть пустым или начинаться с `:`;
после первого `:` весь остаток становится payload. Старые quoted templates не
принимаются. Вложенные nodes уже разрешены processor до этого разбора.

- [ ] **Step 4: Реализовать dispatch и границу ответственности**

При explicit name найти formatter по immutable map. Проверить `canFormat`,
вызвать с `FormatOptions`; core затем применяет только fill/align/width. Sign,
`z`, `#`, zero, grouping и precision передаются formatter без интерпретации.
При пустом spec built-in type имеет приоритет, затем ровно один custom match,
затем `toString()`.

`bool` и `null` с пустой specification дают Dart tokens `true`/`false`/`null`.
Любая числовая specification для них даёт `UnsupportedFormatValueException`;
прочий объект с непустой specification без custom formatter также отклоняется.

- [ ] **Step 5: Подтвердить GREEN**

Run: `rtk dart test test/custom_formatter_test.dart test/formatter_registry_test.dart`

Expected: PASS; глобального изменяемого состояния между тестами нет.

- [ ] **Step 6: Commit**

```bash
rtk git add lib/src/engine.dart lib/src/format_spec.dart lib/src/value_formatter.dart lib/src/brace_processor.dart test/formatter_registry_test.dart test/custom_formatter_test.dart
rtk git commit -m "feat: add immutable custom formatters"
```

---

### Task 10: Python 3.14 fixtures и полная интеграция `{...}`

**Files:**
- Modify: `lib/src/engine.dart`
- Create: `tool/generate_python_fixtures.py`
- Create: `test/support/fixture_value.dart`
- Create: `test/fixtures/python_format.json`
- Create: `test/fixtures/python_divergences.json`
- Create: `test/python_compatibility_test.dart`
- Replace: `test/format_test.dart`
- Modify: `lib/src/brace_processor.dart`
- Modify: `lib/format.dart`
- Modify: `pubspec.yaml`
- Delete: `lib/src/processor.dart`
- Delete: `lib/src/formatter.dart`
- Delete: `lib/src/options.dart`
- Delete: `lib/src/utils/utils.dart`

**Interfaces:**
- Consumes: все core interfaces Tasks 1–9.
- Produces: полный публичный `{...}` engine и воспроизводимый differential suite без runtime-зависимости от Python.

- [ ] **Step 1: Определить typed fixture schema и падающий runner**

Каждое значение кодировать объектом `{"type": ..., "value": ...}`. Типы:
`null`, `bool`, `string`, `int`, `bigint`, `double`, `list`, `map`, `set`;
double tokens `-0`, `nan`, `inf`, `-inf` не являются JSON numbers.

```dart
test('matches committed Python 3.14 fixtures', () async {
  final suite = await PythonFixtureSuite.load('test/fixtures/python_format.json');
  for (final fixture in suite.cases) {
    expect(
      () => formatWith(
        fixture.template,
        positional: fixture.positional,
        named: fixture.named,
      ),
      fixture.matcher,
      reason: fixture.id,
    );
  }
});
```

- [ ] **Step 2: Подтвердить RED на первом наборе эталонов**

Run: `rtk dart test test/python_compatibility_test.dart`

Expected: FAIL с идентификаторами ещё не интегрированных nested/default/error
cases, а не с ошибкой чтения fixture.

- [ ] **Step 3: Реализовать генератор Python 3.14**

`tool/generate_python_fixtures.py` декодирует typed values, вызывает
`template.format(*positional, **named)`, записывает output или стабильную
категорию `ValueError`/`IndexError`/`KeyError`, сортирует cases по id и добавляет:

```json
{
  "generator": {
    "implementation": "CPython",
    "version": "3.14"
  }
}
```

Команда генерации:

Run: `rtk python3.14 tool/generate_python_fixtures.py`

Expected: повторный запуск не меняет `test/fixtures/python_format.json`.

- [ ] **Step 4: Заполнить основной suite и intentional divergences**

Основной JSON покрывает grammar, nested fields, lookup общей области, strings,
all integer types, all float types, grouping, specials и errors. Отдельный JSON
содержит stable id, Python result/error, Dart result/error, reason и README
anchor для: Dart bool/null tokens, lookup hooks, Map `.name`, library repr/ascii,
container order, custom payload, grapheme mode и locale extensions.

- [ ] **Step 5: Интегрировать processor и удалить Format 2 internals**

`BraceProcessor.format` должен выполнить parse → resolve → conversion → resolve
nested spec → parse spec → format value → append через `StringBuffer`. Удалить
старые `processor.dart`, `formatter.dart`, `options.dart` только после переноса
всех публично поддерживаемых imports. Удалить старый `utils.dart`: его `cut`
реализует исключённую ellipsis-семантику `#s` и не используется строгим
движком. `lib/format.dart` экспортирует только Format 3 API и extension
contracts.

Удалить `intl` из root dependencies. Оставить `characters`. Обновить version до
`3.0.0` только в финальном release-плане, чтобы промежуточные commits не
выглядели опубликованным release.

- [ ] **Step 6: Подтвердить полный GREEN ядра**

Run: `rtk dart format lib test tool`

Expected: formatter completes and reports only files changed by this plan.

Run: `rtk dart format --output=none --set-exit-if-changed lib test tool`

Expected: no further changes.

Run: `rtk dart analyze`

Expected: no issues.

Run: `rtk dart test --chain-stack-traces`

Expected: all core and Python fixture tests PASS; Python executable не нужен.

- [ ] **Step 7: Commit**

```bash
rtk git add lib/format.dart lib/src/engine.dart lib/src/brace_processor.dart lib/src/processor.dart lib/src/formatter.dart lib/src/options.dart lib/src/utils/utils.dart test/support/fixture_value.dart test/fixtures/python_format.json test/fixtures/python_divergences.json test/python_compatibility_test.dart test/format_test.dart tool/generate_python_fixtures.py pubspec.yaml
rtk git commit -m "feat: complete Python-compatible Format 3 core"
```
