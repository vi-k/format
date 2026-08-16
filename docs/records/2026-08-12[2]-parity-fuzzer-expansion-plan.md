# План: расширение parity-фаззера

> **Состояние на 2026-08-16:** исполнен 2026-08-12, все шесть задач. Одно
> отступление от него: правка вышла за `test/` на одну строку —
> `lib/src/engine.dart` переэкспортирует `AttributeLookup` и `Representation`,
> без чего задача 3 не собиралась. Пороги, стоящие в тексте заглушками, заменены
> измеренными; итоговые числа — в доккомментарии `_casesPerDialect`, а не здесь,
> потому что здесь они разошлись бы с кодом. Дизайн, из которого план следует, —
> `docs/records/2026-08-12[1]-parity-fuzzer-expansion-design.md`.
> **Что это:** план расширения parity-фаззера, шесть задач.
> **Связанные записи:** `2026-08-12[1]-parity-fuzzer-expansion-design.md`.

**Цель:** довести `test/template_ir_fuzz_test.dart` до покрытия шести осей
бэклога плюс лукапов и расширений, с порогами, выведенными замером на трёх
рантаймах.

**Устройство:** нынешние четыре теста остаются однополевыми и получают
новые конверсии и значения; мульти-полевые случаи выносятся в два новых
теста; `test/parity_harness.dart` получает тестовый тип, два лукапа,
репрезентацию и два движка. Оракул и способ сравнения не меняются.

## Что действует во всех задачах

- Правки только в `test/`. Кода пакета этот план не трогает; если
  расхождение найдётся, правка движка идёт отдельной задачей и с записью
  в CHANGELOG.
- **Performance GREEN не требуется:** гейта и матрицы правка не касается.
  Единственное временное исключение — шаг 7 задачи 4, где движок ломается
  нарочно и тут же возвращается.
- **Перед каждым коммитом — весь список проверок** из `docs/handoff.md`,
  раздел «Как проверить всё», а не подмножество. Скрипт, собирающий его
  целиком, лежит в скретчпаде сессии; прогон около пяти минут.
- Мержим прямо в `main`, без PR. `docs/backlog.md` в коммиты не идёт:
  `git add -A ':(exclude)docs/backlog.md'` из корня репозитория.
- Комментарии и код — по-английски; шапка файла — доккомментарий на
  `library`, у каждого `test(...)` комментарий «почему».
- Ссылки в доккомментариях — `[Symbol]`, где символ резолвится; бэктики
  для того, что символом не является.
- **Пороги ставятся под измеренным значением, а не наоборот.** Ни один
  порог в этом плане не выдумывается: сперва замер на VM, node и wasm,
  потом число.

## Порядок задач

Размер корпуса меняется первой задачей намеренно: все пороги должны быть
измерены на финальном объёме, иначе их придётся переснимать дважды.

---

### Задача 1: корпус 2000 и недостающие конверсии

**Файлы:**
- Правка: `test/template_ir_fuzz_test.dart:58` (`_casesPerDialect`),
  `:78-91` (`_braceConversions`), `:93-105` (`_printfConversions`)

**Отдаёт дальше:** размер корпуса `_casesPerDialect = 2000`, к которому
привязаны все пороги последующих задач.

- [ ] **Шаг 1: поднять корпус и дописать конверсии**

```dart
const _casesPerDialect = 2000;
```

```dart
const _braceConversions = [
  'f',
  'F',
  'e',
  'E',
  'g',
  'G',
  '%',
  'd',
  'x',
  'X',
  'o',
  'b',
  's',
  'n',
  'c',
];
const _printfFlags = ['-', '+', ' ', '#', '0'];
const _printfConversions = [
  'f',
  'F',
  'e',
  'E',
  'g',
  'G',
  'd',
  'i',
  'u',
  'x',
  'X',
  'o',
  'c',
  's',
];
```

`_matchedValue` править не нужно: `x`/`X`/`o`/`b` уже накрыты
целочисленной веткой, `c` — веткой кода символа.

- [ ] **Шаг 2: временно напечатать счётчики**

В конце каждого из четырёх тестов, перед `expect`, вставить:

```dart
    // temporary: removed once the guards below carry measured numbers
    print('distinct=${templates.length} rendered=$rendered');
```

В двух тестах со слепыми значениями переменной `rendered` нет — там
печатать только `distinct`.

- [ ] **Шаг 3: снять числа на трёх рантаймах**

```sh
dart test test/template_ir_fuzz_test.dart -r expanded 2>&1 | grep distinct
dart test -p node test/template_ir_fuzz_test.dart -r expanded 2>&1 \
  | grep distinct
dart test -p node -c dart2wasm -x no-dart2wasm \
  test/template_ir_fuzz_test.dart -r expanded 2>&1 | grep distinct
```

Ожидание: числа на трёх рантаймах близки, но не обязаны совпадать —
доля отрендеренных может разойтись на границах числовой модели. Записать
минимум по каждому тесту.

- [ ] **Шаг 4: поставить пороги и убрать печать**

Пороги остаются долями, если измеренное их с запасом перекрывает
(`> _casesPerDialect ~/ 4` для distinct, `> _casesPerDialect ~/ 2` для
rendered). Если новая конверсия просадила долю отрендеренных ниже
половины — поставить долю, лежащую под измеренным минимумом, и записать
рядом фактические числа:

```dart
    // Measured on the 2000-case corpus: <N> on the VM, <N> on node, <N>
    // under wasm. The floor sits below the smallest of the three, the way
    // the coverage floor and the gate baseline are one-sided.
    expect(rendered, greaterThan(_casesPerDialect ~/ 2));
```

- [ ] **Шаг 5: проверить, что конверсии действительно рисуются**

```sh
dart test test/template_ir_fuzz_test.dart
```

Плюс разовая проверка глазами: временно напечатать `templates` в
brace-тесте и убедиться, что среди них есть шаблоны с `o`, `b` и `X`.
Без этой проверки строчка в словаре могла бы не доехать до корпуса.

- [ ] **Шаг 6: весь список проверок и коммит**

```sh
git add -A ':(exclude)docs/backlog.md'
git commit -m "test(fuzz): корпус 2000 и конверсии o/b/X, o/X/c"
```

---

### Задача 2: Unicode-значения

**Файлы:**
- Правка: `test/template_ir_fuzz_test.dart:166-199` (`_value`,
  `_matchedValue`)

**Берёт из прошлой задачи:** `_casesPerDialect = 2000`.

**Отдаёт дальше:** `_unicodeStrings`, которым пользуется мульти-полевой
генератор задачи 4.

- [ ] **Шаг 1: завести словарь строк**

```dart
/// Strings whose code-unit, scalar and grapheme lengths all differ, so a
/// precision that truncates and a width that pads disagree between the two
/// [TextUnit] modes. The corpus held only `str###` before, where all three
/// lengths coincide and the modes could not be told apart.
const _unicodeStrings = <String>[
  '',
  'école',
  '\u{1F469}‍\u{1F4BB}',
  'אבג',
  'é\u{1F600}x',
];
```

- [ ] **Шаг 2: подключить их к обоим генераторам значений**

```dart
Object? _value(Random random) => switch (random.nextInt(9)) {
  0 => random.nextDouble() * pow(10.0, random.nextInt(40) - 20),
  1 => -random.nextDouble() * pow(10.0, random.nextInt(40) - 20),
  2 => random.nextInt(1 << 30) - (1 << 29),
  3 => _edgeDoubles[random.nextInt(_edgeDoubles.length)],
  4 => 'str${random.nextInt(1000)}',
  5 => BigInt.from(random.nextInt(1 << 30)).pow(1 + random.nextInt(4)),
  6 => null,
  7 => _unicodeStrings[random.nextInt(_unicodeStrings.length)],
  _ => random.nextBool(),
};
```

В `_matchedValue` строковая ветка раздваивается:

```dart
    's' =>
      random.nextInt(3) == 0
          ? _unicodeStrings[random.nextInt(_unicodeStrings.length)]
          : 'str${random.nextInt(1000)}',
```

- [ ] **Шаг 3: переснять пороги**

Повторить шаги 2–4 задачи 1: печать, три рантайма, числа. Ожидание —
доля отрендеренных не должна заметно просесть: пустая строка и Unicode
под `s` форматируются, а не отвергаются.

- [ ] **Шаг 4: убедиться, что графемный режим действительно задет**

```sh
dart test test/template_ir_fuzz_test.dart
dart test -p node test/template_ir_fuzz_test.dart
dart test -p node -c dart2wasm -x no-dart2wasm test/template_ir_fuzz_test.dart
```

Три рантайма здесь не формальность: усечение по точности считается в
кодовых единицах на вебе и в скалярах на VM, и расхождение проявилось бы
только там.

- [ ] **Шаг 5: весь список проверок и коммит**

```sh
git add -A ':(exclude)docs/backlog.md'
git commit -m "test(fuzz): Unicode-значения в корпусе"
```

---

### Задача 3: движки с расширениями

**Файлы:**
- Правка: `test/parity_harness.dart` (после `IrTestNumberLocale`)
- Правка: `test/template_ir_fuzz_test.dart:63-70` (`_engines`)

**Берёт из прошлых задач:** ничего.

**Отдаёт дальше:** `IrTestPoint`, `extensionFormat`, `ambiguousFormat` —
ими пользуется генератор задачи 4; `_engines` вырастает до восьми.

- [ ] **Шаг 1: написать проверку достижимости — она должна упасть**

В `test/template_ir_fuzz_test.dart`, первым тестом после пиннинга потока:

```dart
  // Two payloads in describeErrorPayload were unreachable for the whole
  // corpus: no engine registered an extension, so `.attr` on a non-Map
  // always ended in FormatLookupException and `!r` always took a built-in
  // branch. These two engines are what makes them reachable — and this
  // test is what keeps them reachable, since a future engine list that
  // dropped them would otherwise stay green.
  test('the extension engines reach the two unreachable payloads', () {
    const point = IrTestPoint(1, 2);
    expect(
      () => extensionFormat.formatWith('{0.boom}', positional: [point]),
      throwsA(isA<FormatExtensionException>()),
    );
    expect(
      () => ambiguousFormat.formatWith('{0.x}', positional: [point]),
      throwsA(isA<AmbiguousFormatterException>()),
    );
    expectBraceParity('{0.boom}', positional: [point], engine: extensionFormat);
    expectBraceParity('{0.x}', positional: [point], engine: ambiguousFormat);
    expect(extensionFormat.formatWith('{0!r}', positional: [point]), '<1;2>');
  });
```

- [ ] **Шаг 2: убедиться, что не компилируется**

```sh
dart test test/template_ir_fuzz_test.dart
```

Ожидание: ошибка компиляции — `IrTestPoint`, `extensionFormat` и
`ambiguousFormat` не определены.

- [ ] **Шаг 3: завести тип и расширения**

В `test/parity_harness.dart`:

```dart
/// A value type the engine knows nothing about.
///
/// Built-in handling takes priority over extensions, so an extension is
/// only ever consulted for a type the package has no branch of its own for:
/// a [Representation] on `String` or `int` would never be called.
final class IrTestPoint {
  final int x;
  final int y;

  const IrTestPoint(this.x, this.y);

  @override
  String toString() => 'IrTestPoint($x, $y)';
}

/// Resolves `{value.x}` on an [IrTestPoint], and explodes on `.boom`.
///
/// The explosion is deliberate and is the only way the corpus reaches
/// [FormatExtensionException]: a lookup that throws anything other than a
/// FormattingException has it wrapped, with the template location attached.
final class IrTestPointLookup extends AttributeLookup<IrTestPoint> {
  const IrTestPointLookup();

  @override
  bool canLookup(Object? value) => value is IrTestPoint;

  @override
  Object? lookup(IrTestPoint value, String attribute) => switch (attribute) {
    'x' => value.x,
    'y' => value.y,
    'boom' => throw StateError('lookup exploded on purpose'),
    // An absent attribute is the lookup's decision to report; returning
    // null keeps it a formatting case rather than a second error class.
    _ => null,
  };
}

/// A second lookup accepting the same type, so the engine that holds both
/// has no way to choose — which is [AmbiguousFormatterException].
final class IrTestPointMirrorLookup extends AttributeLookup<IrTestPoint> {
  const IrTestPointMirrorLookup();

  @override
  bool canLookup(Object? value) => value is IrTestPoint;

  @override
  Object? lookup(IrTestPoint value, String attribute) => 'mirror:$attribute';
}

/// Gives [IrTestPoint] its own `!r`/`!a` form, so the representation
/// conversions reach extension code instead of falling back to toString().
final class IrTestPointRepresentation extends Representation<IrTestPoint> {
  const IrTestPointRepresentation();

  @override
  bool canRepresent(Object? value) => value is IrTestPoint;

  @override
  String represent(IrTestPoint value) => '<${value.x};${value.y}>';
}

final extensionFormat = Format(
  lookups: const [IrTestPointLookup()],
  representations: const [IrTestPointRepresentation()],
);
final ambiguousFormat = Format(
  lookups: const [IrTestPointLookup(), IrTestPointMirrorLookup()],
);
```

- [ ] **Шаг 4: включить движки в список**

```dart
final _engines = <Format>[
  defaultFormat,
  graphemeFormat,
  compatibleFormat,
  compatibleGraphemes,
  localeFormat,
  shortSpellingFormat,
  extensionFormat,
  ambiguousFormat,
];
```

- [ ] **Шаг 5: прогнать и переснять пороги**

```sh
dart test test/template_ir_fuzz_test.dart
```

Ожидание: проверка достижимости зелёная. Восьмой движок разбавил корпус —
пороги переснять способом задачи 1 на трёх рантаймах.

- [ ] **Шаг 6: весь список проверок и коммит**

```sh
git add -A ':(exclude)docs/backlog.md'
git commit -m "test(fuzz): движки с лукапами и репрезентацией"
```

---

### Задача 4: мульти-полевой brace-фаззер

**Файлы:**
- Правка: `test/template_ir_fuzz_test.dart` (генераторы и новый тест)

**Берёт из прошлых задач:** `_unicodeStrings`, `IrTestPoint`, восемь
движков, `_casesPerDialect = 2000`.

**Отдаёт дальше:** `_multiFieldTemplate` — форму, которую задача 5
повторяет для printf.

Три факта о движке, на которых стоит генератор; проверены исполнением:

- парсер запрещает смешивать `{}` и `{0}` в одном шаблоне («Cannot switch
  from automatic to manual field numbering»), и вложенное поле подчиняется
  тому же режиму: `{0:{}d}` отвергается. Режим рисуется один раз на
  шаблон;
- именованный корень режим не переключает: `{} {k}` законно;
- автоматические индексы потребляются в порядке «корень поля, потом
  вложенные слева направо»: `{:{}d} {}` на `[1, 2, 3]` даёт `' 1 3'`.

- [ ] **Шаг 1: словари имён**

```dart
const _attributeNames = ['x', 'y', 'boom', 'nope'];
const _itemKeys = ['a', 'b'];
const _representationConversions = ['r', 's', 'a'];
```

- [ ] **Шаг 2: генератор одного поля**

```dart
/// Draws one field of a multi-field template and appends the values it
/// consumes to [positional] and [named].
///
/// Values are appended in *resolution* order — the root first, then the
/// nested fields of the specification left to right — because that is the
/// order the legacy resolver walks, and the order
/// `_automaticFieldCount`/`automaticBase` have to reproduce in the IR. A
/// generator that modelled the order wrongly would not raise a false
/// failure; it would only lower the rendered share, since the values would
/// stop suiting their conversions.
///
/// [automaticNumbering] is drawn once per template and honoured by every
/// field: mixing `{}` with `{0}` is rejected by the parser, so a template
/// that mixed them would test the same rejection two thousand times.
String _braceField(
  Random random,
  List<Object?> positional,
  Map<String, Object?> named, {
  required bool automaticNumbering,
  required int fieldIndex,
}) {
  final buffer = StringBuffer('{');
  // One field in four takes a named root; the rest follow the template's
  // numbering mode. One named draw in eight names a key nobody defined,
  // which is the MissingFormatArgumentException case.
  final namedRoot = random.nextInt(4) == 0;
  final rootKey = 'k$fieldIndex';
  if (namedRoot) {
    buffer.write(random.nextInt(8) == 0 ? 'absent$fieldIndex' : rootKey);
  } else if (!automaticNumbering) {
    // Name the slot this field is about to take, so the value suits it —
    // except one draw in eight, which points past the end on purpose.
    final slot = random.nextInt(8) == 0
        ? positional.length + 5
        : positional.length;
    buffer.write(slot);
  }

  final access = random.nextInt(6);
  final attribute = _attributeNames[random.nextInt(_attributeNames.length)];
  final itemKey = _itemKeys[random.nextInt(_itemKeys.length)];
  switch (access) {
    case 0:
      buffer.write('[0]');
    case 1:
      buffer.write('[$itemKey]');
    case 2:
      buffer.write('.$attribute');
    default:
      break;
  }

  if (random.nextInt(3) == 0) {
    buffer
      ..write('!')
      ..write(
        _representationConversions[random
            .nextInt(_representationConversions.length)],
      );
  }

  // The nested values are collected first but appended after the root, so
  // the slots line up with resolution order. Their explicit indices are
  // computed from where they will land, not from where they are drawn.
  final nested = <Object?>[];
  final rootSlots = namedRoot ? 0 : 1;
  final spec = random.nextInt(3) == 0
      ? _nestedBraceSpec(
          random,
          nested,
          automaticNumbering: automaticNumbering,
          firstSlot: positional.length + rootSlots,
        )
      : _braceSpec(random);
  if (spec.isNotEmpty) {
    buffer
      ..write(':')
      ..write(spec);
  }
  buffer.write('}');

  final leaf = _matchedValue(random, spec);
  final rootValue = switch (access) {
    0 => <Object?>[leaf, 'second'],
    1 => <Object?, Object?>{'a': leaf, 'b': leaf},
    2 => random.nextBool()
        ? <Object?, Object?>{attribute: leaf}
        : IrTestPoint(random.nextInt(100), random.nextInt(100)),
    _ => leaf,
  };
  if (namedRoot) {
    named[rootKey] = rootValue;
  } else {
    positional.add(rootValue);
  }
  positional.addAll(nested);
  return buffer.toString();
}
```

- [ ] **Шаг 3: генератор вложенной спецификации**

```dart
/// A specification whose width or precision is itself a field.
///
/// This is the shape that stays outside the IR: the specification is not
/// known when the program is compiled, so the field falls back and the
/// nested field consumes an automatic index of its own — the accounting
/// this whole test exists to compare.
String _nestedBraceSpec(
  Random random,
  List<Object?> nested, {
  required bool automaticNumbering,
  required int firstSlot,
}) {
  final buffer = StringBuffer();
  if (random.nextBool()) {
    buffer.write(
      _nestedField(
        random,
        nested,
        automaticNumbering: automaticNumbering,
        firstSlot: firstSlot,
      ),
    );
  } else {
    buffer
      ..write('.')
      ..write(
        _nestedField(
          random,
          nested,
          automaticNumbering: automaticNumbering,
          firstSlot: firstSlot,
        ),
      );
  }
  buffer.write(_braceConversions[random.nextInt(_braceConversions.length)]);
  return buffer.toString();
}

String _nestedField(
  Random random,
  List<Object?> nested, {
  required bool automaticNumbering,
  required int firstSlot,
}) {
  // One nested field in three reads the width from a named argument, which
  // is legal under both numbering modes and consumes no slot.
  if (random.nextInt(3) == 0) return '{w}';
  final slot = firstSlot + nested.length;
  nested.add(random.nextInt(12));
  return automaticNumbering ? '{}' : '{$slot}';
}
```

- [ ] **Шаг 4: генератор шаблона**

```dart
/// Builds a template of one to four fields with literals between them.
///
/// Literals are not decoration: a program of several ops has to interleave
/// them correctly, and the single-record literal optimization only applies
/// when the whole program is one literal.
String _multiFieldTemplate(
  Random random,
  List<Object?> positional,
  Map<String, Object?> named,
) {
  final automaticNumbering = random.nextBool();
  final count = 1 + random.nextInt(4);
  final buffer = StringBuffer('a');
  for (var field = 0; field < count; field++) {
    buffer
      ..write(
        _braceField(
          random,
          positional,
          named,
          automaticNumbering: automaticNumbering,
          fieldIndex: field,
        ),
      )
      ..write('|');
  }
  return buffer.toString();
}
```

- [ ] **Шаг 5: сам тест**

```dart
  // What the single-field passes above cannot reach. Three of the axes this
  // file now draws — representations, lookups and nested specifications —
  // all compile to the same fallback op, which calls the very function the
  // legacy path calls, so on a one-field template the comparison is close
  // to tautological. What is not tautological is the automatic-index
  // accounting: `_automaticFieldCount` and the `automaticBase` reset exist
  // only in the IR, legacy counts as it walks, and a nested field consumes
  // an index between two outer ones. That can only diverge when a template
  // holds more than one field.
  test('multi-field brace fuzz: IR matches the legacy oracle', () {
    final random = Random(_seed + 4);
    final templates = <String>{};
    var rendered = 0;
    for (var index = 0; index < _casesPerDialect; index++) {
      final positional = <Object?>[];
      final named = <String, Object?>{'w': 7};
      final template = _multiFieldTemplate(random, positional, named);
      final engine = _engines[random.nextInt(_engines.length)];
      templates.add(template);
      expectBraceParity(
        template,
        positional: positional,
        named: named,
        engine: engine,
        label: '#$index e${_engines.indexOf(engine)} p=$positional n=$named',
      );
      if (_renders(
        () => engine.formatWith(template, positional: positional, named: named),
      )) {
        rendered++;
      }
    }
    expect(templates.length, greaterThan(_casesPerDialect ~/ 4));
    expect(rendered, greaterThan(_casesPerDialect ~/ 4));
  });
```

Число в последнем `expect` — заглушка до замера следующего шага.

- [ ] **Шаг 6: замерить и поставить порог**

Печать `distinct`/`rendered`, три рантайма, минимум, порог под ним с
запасом и фактические числа в комментарии рядом. Если доля отрендеренных
оказалась ниже четверти — это сведения, а не повод подгонять генератор:
поставить порог под измеренным и записать, почему он такой низкий.

- [ ] **Шаг 7: проверить, что сторож — сторож**

Временно сломать сброс автоматического индекса в
`lib/src/template_ir.dart:108`:

```dart
    final resolver = frame.resolver;
```

```sh
dart test test/template_ir_fuzz_test.dart
```

Ожидание: мульти-полевой тест **краснеет**, однополевые остаются
зелёными. Это и есть доказательство, что новый тест меряет то, ради чего
написан. Вернуть строку:

```sh
git checkout lib/src/template_ir.dart
```

- [ ] **Шаг 8: весь список проверок и коммит**

```sh
git add -A ':(exclude)docs/backlog.md'
git commit -m "test(fuzz): мульти-полевые brace-шаблоны"
```

---

### Задача 5: мульти-конверсионный printf-фаззер

**Файлы:**
- Правка: `test/template_ir_fuzz_test.dart` (генератор и новый тест)

**Берёт из прошлых задач:** `_printfTemplate`, `_matchedValue`, восемь
движков.

- [ ] **Шаг 1: генератор шаблона**

```dart
/// Builds a printf template of one to four conversions.
///
/// The analogue of automatic-index accounting here is the order varargs are
/// drained: every `*` takes a value before the conversion it belongs to, and
/// a program of several ops has to keep that order across op boundaries.
String _multiPrintfTemplate(Random random, List<Object?> values) {
  final count = 1 + random.nextInt(4);
  final buffer = StringBuffer('x=');
  for (var conversion = 0; conversion < count; conversion++) {
    final spec = _printfTemplate(random);
    final stars = '*'.allMatches(spec).length;
    for (var star = 0; star < stars; star++) {
      values.add(random.nextInt(30) - 10);
    }
    values.add(_matchedValue(random, spec));
    buffer
      ..write(spec)
      ..write('|');
  }
  return buffer.toString();
}
```

- [ ] **Шаг 2: сам тест**

```dart
  // The printf counterpart of the multi-field pass. Separate rather than
  // shared: the dialects have separate parsers, separate processors and
  // separate legacy paths, and a single generic test would only hide which
  // of them diverged.
  test('multi-conversion printf fuzz: IR matches the legacy oracle', () {
    final random = Random(_seed + 5);
    final templates = <String>{};
    var rendered = 0;
    for (var index = 0; index < _casesPerDialect; index++) {
      final values = <Object?>[];
      final template = _multiPrintfTemplate(random, values);
      final engine = _engines[random.nextInt(_engines.length)];
      templates.add(template);
      expectPrintfParity(
        template,
        values,
        engine: engine,
        label: '#$index e${_engines.indexOf(engine)} v=$values',
      );
      if (_renders(() => engine.vsprintf(template, values))) rendered++;
    }
    expect(templates.length, greaterThan(_casesPerDialect ~/ 4));
    expect(rendered, greaterThan(_casesPerDialect ~/ 4));
  });
```

- [ ] **Шаг 3: замерить и поставить порог**

Тем же способом: печать, три рантайма, минимум, порог под ним, числа в
комментарии.

- [ ] **Шаг 4: весь список проверок и коммит**

```sh
git add -A ':(exclude)docs/backlog.md'
git commit -m "test(fuzz): мульти-конверсионные printf-шаблоны"
```

---

### Задача 6: шапка файла, handoff, пуш

**Файлы:**
- Правка: `test/template_ir_fuzz_test.dart:1-30` (шапка `library`)
- Правка: `docs/handoff.md`

- [ ] **Шаг 1: обновить шапку файла**

Шапка сейчас описывает четыре теста и одно поле на случай. Дописать: что
покрывают два новых теста, почему мульти-полевой шаблон — не «ещё больше
того же», а единственное место, где бухгалтерия автоматических индексов
вообще может разойтись, и что пороги — измеренные, а не выбранные.

- [ ] **Шаг 2: обновить handoff**

Строку `Статус:` с датой, раздел про сделанное, и вычеркнуть пункт из
списка открытого. Записать прирост времени `dart test` как факт. Заодно
поправить числа тестов в разделе «Как проверить всё»: VM 556, node 377
при четырёх пропущенных, wasm 360 — на 2026-08-12 в handoff стоят
прежние.

- [ ] **Шаг 3: проставить статусы в двух документах**

В шапках `2026-08-12[1]-...-design.md` и `2026-08-12[2]-...-plan.md`
заменить «не исполнен» на «исполнен» либо «исполнен частично» с перечнем
открытого.

- [ ] **Шаг 4: весь список проверок, коммит и пуш**

```sh
git add -A ':(exclude)docs/backlog.md'
git commit -m "docs: расширение parity-фаззера исполнено"
git push
```

Пуш один на весь заход: CI гоняет пять джоб на push, и гонять их шесть
раз подряд незачем.

## Чего в плане нет намеренно

- **Правок движка.** Если мульти-полевой корпус найдёт расхождение, это
  отдельная задача с собственным замером и записью в CHANGELOG, а не шаг
  внутри этой.
- **Бампа сида.** Генераторы меняются, значит корпус и так новый.
- **Пункта «вычеркнуть из бэклога».** `docs/backlog.md` ведёт владелец.
