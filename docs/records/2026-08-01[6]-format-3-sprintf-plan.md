# Format 3 `sprintf` Implementation Plan

> **Состояние на 2026-08-16:** исполнен, вошло в 3.0.0. Чекбоксы в теле не
> проставлялись — открытым пунктом их читать нельзя.
> **Что это:** план реализации printf-диалекта.
> **Связанные записи:** `2026-08-01[3]-format-3-python-compatibility-design.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить стандартный `%...`-диалект C++23 через `sprintf`/`vsprintf`, используя общий типизированный слой Format 3 и сохраняя строгие Dart-ошибки и Unicode-семантику.

**Architecture:** Отдельный printf parser создаёт собственное закрытое дерево и потребляет аргументы последовательно, не переводя шаблон в `{...}`. Текстовые и числовые conversions используют общие primitives ядра, но отдельная C++ policy определяет допустимые флаги, integer precision, specials и hexadecimal float.

**Tech Stack:** Dart SDK `^3.7.2`, общий core из `2026-08-01-format-3-core.md`, C++23 reference generator (`g++`/glibc и `clang++`/libSystem), замороженный Dart package `sprintf` 7.0.0 только для benchmark.

## Global Constraints

- Единственный нормативный контракт `%...` — стандартный `std::sprintf` C++23; API стороннего Dart-пакета `sprintf` не является контрактом.
- Поддерживаются `%%`, `%c`, `%s`, `%d`, `%i`, `%u`, `%o`, `%x`, `%X`, `%f`, `%F`, `%e`, `%E`, `%g`, `%G`, `%a`, `%A`.
- `%n`, `%p`, length modifiers `hh/h/l/ll/j/z/t/L`, POSIX `%2$d`, C++26 `%b/%B` и custom conversions отвергаются типизированной ошибкой.
- Неприменимые к conversion flags, width или precision не игнорируются.
- `sprintf` принимает до десяти отдельных значений; `vsprintf` принимает `List<Object?>` любой длины; лишние значения игнорируются.
- `%u/%o/%x/%X` принимают только неотрицательные `int`/`BigInt`; скрытого fixed-width wrapping нет.
- `%s`, `%c`, width и precision используют `Format.textUnit`; default — Unicode scalars.
- Floating conversions принимают только `double` и используют `Format.numberLocale` для symbols, но core владеет rounding и notation.
- `%` parser выбирается измерением `RegExp`, scanner и hybrid; дизайн не предрешает победителя.
- Production-код изменяется только после RED-теста; все shell-команды идут через `rtk`; worktree не создаётся.

---

## Структура файлов

- `benchmark/parser_strategy.dart` — одинаковый corpus и три parser candidate.
- `benchmark/results/parser_strategy.json` — версии Dart/OS, сырые samples и выбранная стратегия.
- `benchmark/baselines/sprintf7/` — замороженный `sprintf` 7.0.0 commit `f1e74f2`, license и минимальная Dart 3 compatibility patch.
- `lib/src/printf_ast.dart` — literal/conversion nodes, flags и dynamic/static width/precision.
- `lib/src/printf_parser.dart` — выбранный строгий parser.
- `lib/src/printf_processor.dart` — последовательное потребление аргументов и сборка результата.
- `lib/src/printf_formatter.dart` — conversion policy поверх text/number primitives.
- `lib/src/api.dart`, `lib/src/format.dart`, `lib/format.dart` — `sprintf`/`vsprintf` верхнего уровня и методы экземпляра.
- `tool/generate_sprintf_fixtures.cpp` — C++23 reference executable.
- `tool/verify_sprintf_fixtures.dart` — проверка platform output против exact/allowed reference.
- `test/fixtures/sprintf_common.json` — обязательные outputs и разрешённые стандартом множества.
- `test/fixtures/sprintf_divergences.json` — утверждённые Dart-отличия.
- `test/sprintf_api_test.dart`, `test/printf_parser_test.dart`, `test/sprintf_text_test.dart`, `test/sprintf_integer_test.dart`, `test/sprintf_double_test.dart`, `test/sprintf_compatibility_test.dart` — проверки по ответственности.

---

### Task 1: Заморозить competitor и измерить стратегию parser

**Files:**
- Create: `benchmark/baselines/sprintf7/LICENSE`
- Create: `benchmark/baselines/sprintf7/README.md`
- Create: `benchmark/baselines/sprintf7/lib/sprintf.dart`
- Create: `benchmark/parser_strategy.dart`
- Create: `benchmark/results/parser_strategy.json`
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: воспроизводимый competitor source и JSON field `selected` со значением `regexp`, `scanner` или `hybrid`.
- Consumes: только benchmark corpus; production parser ещё не меняется.

- [ ] **Step 1: Добавить frozen source с provenance**

Скопировать исходники ровно из commit `f1e74f2`, сохранить BSD-2-Clause license.
В `README.md` записать package `sprintf` 7.0.0, commit, upstream URL, список
механических Dart 3 edits и запрет использования baseline как correctness
oracle. Не экспортировать baseline из `lib/format.dart`.

- [ ] **Step 2: Написать одинаковый parser corpus**

```dart
const parserCorpus = <String>[
  'literal only',
  '%d',
  '%+08.3f',
  '%-*.*s',
  '%#x %d %s %.17g',
  r'%% %1$d %llx %b %',
];
```

Каждая candidate возвращает список immutable records
`(offset, fragment, flags, width, precision, type)` или одну и ту же error
category. До измерения выполнить deep equality всех outputs.

- [ ] **Step 3: Реализовать три изолированные candidate**

- `regexp`: один заранее созданный `RegExp`, anchored с текущего offset;
- `scanner`: ручной UTF-16 проход и switch по ASCII symbols;
- `hybrid`: поиск следующего `%` через `String.indexOf`, затем anchored RegExp
  только для conversion.

Candidate не форматируют значения и не используют cache. Для cold samples
использовать заранее созданные уникальные строки; hot samples повторяют один
corpus.

- [ ] **Step 4: Запустить JIT/AOT/JavaScript measurement**

Run: `rtk dart run benchmark/parser_strategy.dart --runtime=jit --output=/private/tmp/parser-jit.json`

Run: `rtk dart compile exe benchmark/parser_strategy.dart -o /private/tmp/parser-strategy`

Run: `rtk /private/tmp/parser-strategy --runtime=aot --output=/private/tmp/parser-aot.json`

Run: `rtk dart compile js benchmark/parser_strategy.dart -o /private/tmp/parser-strategy.js`

Run: `rtk node /private/tmp/parser-strategy.js --runtime=js --output=/private/tmp/parser-js.json`

Expected: не менее 7 чередующихся samples на scenario; outputs candidates
идентичны.

- [ ] **Step 5: Зафиксировать выбор без ручного предпочтения**

Для каждого runtime нормализовать median к лучшему candidate, затем взять
геометрическое среднее cold+hot ratios трёх runtimes. `selected` получает
минимальный score; при равенстве в пределах 1% выбирать меньший source-size,
затем `scanner` как детерминированный tie-break. JSON хранит Dart version, OS,
CPU, samples, medians, scores и selected.

Run: `rtk dart run benchmark/parser_strategy.dart --merge=/private/tmp/parser-jit.json,/private/tmp/parser-aot.json,/private/tmp/parser-js.json --output=benchmark/results/parser_strategy.json`

Expected: committed JSON содержит ровно одну selected strategy.

- [ ] **Step 6: Commit**

```bash
rtk git add benchmark pubspec.yaml
rtk git commit -m "bench: choose sprintf parser strategy"
```

---

### Task 2: Публичные `sprintf`/`vsprintf` и методы `Format`

**Files:**
- Modify: `lib/src/engine.dart`
- Modify: `lib/src/api.dart`
- Modify: `lib/src/format.dart`
- Create: `lib/src/printf_processor.dart`
- Modify: `lib/format.dart`
- Create: `test/sprintf_api_test.dart`

**Interfaces:**
- Consumes: private missing-value sentinel и immutable `Format` из core plan.
- Produces: top-level и instance `sprintf(String, [Object? x10])`, `vsprintf(String, List<Object?>)`.

- [ ] **Step 1: Написать RED-тесты API и tear-offs**

```dart
test('exports sprintf and vsprintf at both API levels', () {
  expect(sprintf('%d %s', 42, 'answer'), '42 answer');
  expect(vsprintf('%s:%d', ['items', 3]), 'items:3');

  final engine = Format(textUnit: TextUnit.graphemeClusters);
  final appSprintf = engine.sprintf;
  final appVSprintf = engine.vsprintf;
  expect(appSprintf('%s', null), 'null');
  expect(appVSprintf('%%', const []), '%');
});
```

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/sprintf_api_test.dart`

Expected: compile failure — functions не существуют.

- [ ] **Step 3: Добавить exact wrappers**

Top-level `sprintf` повторяет десять optional parameters `format` и делегирует
`defaultFormat.sprintf`. Метод экземпляра собирает values до private sentinel и
вызывает `vsprintf`; явный `null` сохраняется. `vsprintf` передаёт
`List<Object?>.unmodifiable(values)` в `_PrintfProcessor`.

На этом шаге `_PrintfProcessor` минимально поддерживает literal, `%%`, `%s` и
`%d`, нужные API-test; прочие conversions дают `InvalidFormatException`, чтобы
RED следующих tasks был осмысленным.

- [ ] **Step 4: Подтвердить literal API GREEN**

Run: `rtk dart test test/sprintf_api_test.dart --plain-name "exports sprintf and vsprintf at both API levels"`

Expected: PASS после временного включения только `%s/%d` минимальным dispatch;
детали будут заменены policy Tasks 4–6.

- [ ] **Step 5: Commit**

```bash
rtk git add lib/format.dart lib/src/engine.dart lib/src/api.dart lib/src/format.dart lib/src/printf_processor.dart test/sprintf_api_test.dart
rtk git commit -m "feat: expose sprintf and vsprintf"
```

---

### Task 3: Строгий printf AST и выбранный parser

**Files:**
- Modify: `lib/src/engine.dart`
- Create: `lib/src/printf_ast.dart`
- Create: `lib/src/printf_parser.dart`
- Create: `test/printf_parser_test.dart`

**Interfaces:**
- Consumes: `benchmark/results/parser_strategy.json` decision.
- Produces: `_PrintfTemplate parsePrintfTemplate(String)` с immutable literal/conversion nodes.

- [ ] **Step 1: Написать RED parser matrix**

```dart
test('parses flags and dynamic options in consumption order', () {
  final debug = debugParsePrintfTemplate('%-+#0*.*f');
  expect(debug, contains('flags=-+#0'));
  expect(debug, contains('width=dynamic'));
  expect(debug, contains('precision=dynamic'));
  expect(debug, contains('type=f'));
});

for (final template in ['%', '%q', '%n', '%p', '%llx', '%2\$d', '%b', '%B', '%05s', '%.1c', '%1%']) {
  test('rejects unsupported printf form $template', () {
    expect(() => debugParsePrintfTemplate(template), throwsA(isA<FormattingException>()));
  });
}
```

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/printf_parser_test.dart`

Expected: compile failure — AST/parser отсутствуют.

- [ ] **Step 3: Реализовать AST**

Добавить `printf_ast.dart` и `printf_parser.dart` как parts `engine.dart`.
Structural helper `debugParsePrintfTemplate` доступен только через прямой import
`package:format/src/engine.dart` в parser test и не экспортируется публично.

```dart
enum PrintfFlag { left, sign, space, alternate, zero }

sealed class PrintfNode {
  final int offset;
  final String fragment;
  const PrintfNode(this.offset, this.fragment);
}

final class PrintfLiteralNode extends PrintfNode {
  final String text;
  const PrintfLiteralNode(super.offset, super.fragment, this.text);
}

sealed class PrintfOption { const PrintfOption(); }
final class LiteralPrintfOption extends PrintfOption {
  final int value;
  const LiteralPrintfOption(this.value);
}
final class DynamicPrintfOption extends PrintfOption { const DynamicPrintfOption(); }

final class PrintfConversionNode extends PrintfNode {
  final Set<PrintfFlag> flags;
  final PrintfOption? width;
  final PrintfOption? precision;
  final String type;

  PrintfConversionNode({
    required int offset,
    required String fragment,
    required Set<PrintfFlag> flags,
    required this.width,
    required this.precision,
    required this.type,
  }) : flags = Set.unmodifiable(flags),
       super(offset, fragment);
}
```

Повтор flags схлопывается Set. Literal option парсится с overflow check.

- [ ] **Step 4: Перенести только выбранную strategy в production**

Если `selected=regexp`, использовать один static final precompiled RegExp; если
`scanner`, использовать ASCII switch; если `hybrid`, использовать `indexOf` и
anchored RegExp. Не переносить две проигравшие candidate в `lib/`.

После syntactic parse валидировать таблицу:

| Conversion | Flags | Width | Precision |
| --- | --- | --- | --- |
| `%c` | `-` | yes | no |
| `%s` | `-` | yes | yes |
| `%d/%i` | `- + space 0` | yes | yes |
| `%u` | `- 0` | yes | yes |
| `%o/%x/%X` | `- # 0` | yes | yes |
| floats | `- + space # 0` | yes | yes |
| `%%` | none | no | no |

Unsupported type/unfinished `%` даёт `InvalidFormatException`; syntactically
valid, но неприменимая option — `InvalidSpecifierException`.

- [ ] **Step 5: Подтвердить GREEN и offsets**

Run: `rtk dart test test/printf_parser_test.dart`

Expected: PASS; every error checks template, UTF-16 offset, full fragment,
conversion when known.

- [ ] **Step 6: Commit**

```bash
rtk git add lib/src/engine.dart lib/src/printf_ast.dart lib/src/printf_parser.dart test/printf_parser_test.dart
rtk git commit -m "feat: parse C++23 printf templates"
```

---

### Task 4: Потребление аргументов, `%s`, `%c` и integer conversions

**Files:**
- Modify: `lib/src/engine.dart`
- Modify: `lib/src/printf_processor.dart`
- Create: `lib/src/printf_formatter.dart`
- Create: `test/sprintf_text_test.dart`
- Create: `test/sprintf_integer_test.dart`
- Modify: `lib/src/format.dart`

**Interfaces:**
- Consumes: printf AST, `TextUnit`, integer primitives и exception context core.
- Produces: sequential argument cursor; `%%/%s/%c/%d/%i/%u/%o/%x/%X`.

- [ ] **Step 1: Написать RED-тесты consumption и dynamic options**

```dart
test('consumes dynamic width then precision then value', () {
  expect(vsprintf('%*.*s', [6, 3, 'abcdef']), '   abc');
  expect(vsprintf('%*d', [-5, 42]), '42   ');
  expect(vsprintf('%.*d', [-1, 42]), '42');
});

test('ignores extra arguments but reports a missing argument index', () {
  expect(vsprintf('%d', [1, 2]), '1');
  expect(
    () => vsprintf('%d %s', [1]),
    throwsA(
      isA<MissingFormatArgumentException>().having(
        (error) => error.context.argumentIndex,
        'argumentIndex',
        1,
      ),
    ),
  );
});
```

- [ ] **Step 2: Написать RED-тесты text и integer contract**

```dart
test('uses TextUnit for printf strings', () {
  expect(sprintf('%.1s', 'e\u0301'), 'e');
  final graphemes = Format(textUnit: TextUnit.graphemeClusters);
  expect(graphemes.sprintf('%.1s', 'e\u0301'), 'e\u0301');
});

test('formats C integer precision without unsigned wrapping', () {
  expect(sprintf('%#.0o', 0), '0');
  expect(sprintf('%#X', 42), '0X2A');
  expect(sprintf('%08.3d', 42), '     042');
  expect(() => sprintf('%u', -1), throwsA(isA<UnsupportedFormatValueException>()));
});

test('applies printf flag precedence', () {
  expect(sprintf('% +d', 42), '+42');
  expect(sprintf('%-05d', 42), '42   ');
});

test('validates printf text and character values', () {
  expect(sprintf('%s', null), 'null');
  expect(sprintf('%c', 0x1f44b), '👋');
  expect(() => sprintf('%c', -1), throwsA(isA<UnsupportedFormatValueException>()));
});
```

- [ ] **Step 3: Подтвердить RED**

Run: `rtk dart test test/sprintf_text_test.dart test/sprintf_integer_test.dart`

Expected: FAIL на argument cursor и printf precision.

- [ ] **Step 4: Реализовать cursor и transactional output**

`_PrintfArgumentCursor.take(node, role)` увеличивает index только после наличия
аргумента. Dynamic width/precision обязаны быть `int`. Negative width добавляет
left flag и абсолютное значение; negative precision становится absent.
Processor сначала полностью форматирует conversion во временную строку, затем
добавляет её в `StringBuffer`, поэтому exception не возвращает partial output.

- [ ] **Step 5: Реализовать text/integer policy**

`%s` вызывает `value.toString()` и обрезает через `TextUnit.take`. `%c` принимает
один valid Unicode scalar. Integer policy переиспользует magnitude/radix helpers,
но precision означает minimum digits; value 0 с precision 0 даёт empty digits,
кроме `%#o`. Explicit integer precision отключает zero flag. `%u/%o/%x/%X`
проверяют nonnegative до форматирования.

- [ ] **Step 6: Подтвердить GREEN**

Run: `rtk dart test test/sprintf_text_test.dart test/sprintf_integer_test.dart test/sprintf_api_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
rtk git add lib/src/engine.dart lib/src/format.dart lib/src/printf_processor.dart lib/src/printf_formatter.dart test/sprintf_api_test.dart test/sprintf_text_test.dart test/sprintf_integer_test.dart
rtk git commit -m "feat: format printf text and integers"
```

---

### Task 5: Decimal floating conversions и special values

**Files:**
- Modify: `lib/src/printf_formatter.dart`
- Modify: `lib/src/number_format.dart`
- Create: `test/sprintf_double_test.dart`

**Interfaces:**
- Consumes: exact binary64 rounding and numeric padding core.
- Produces: `%f/%F/%e/%E/%g/%G`, C++ alternate form, specials and locale symbols.

- [ ] **Step 1: Написать RED decimal float matrix**

```dart
test('matches C++23 decimal float rules', () {
  expect(sprintf('%.0f', 2.5), '2');
  expect(sprintf('%e', 1.0), '1.000000e+00');
  expect(sprintf('%.0g', 12.0), '1e+01');
  expect(sprintf('%#.4g', 12.0), '12.00');
  expect(sprintf('%f', 1e-10), '0.000000');
});

test('uses spaces for zero-padded special values', () {
  expect(sprintf('%+08f', double.infinity), '    +inf');
  expect(sprintf('%+08f', double.nan), '    +nan');
});

test('floating printf conversions require double', () {
  expect(() => sprintf('%f', 1), throwsA(isA<UnsupportedFormatValueException>()));
});
```

Добавить uppercase, negative zero, very large fixed, carry at powers of ten,
precision 0/1/50, repeated flags and custom `NumberLocale` symbols.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/sprintf_double_test.dart`

Expected: FAIL — float printf policy отсутствует.

- [ ] **Step 3: Добавить C++ numeric policy поверх exact primitives**

Default precision 6; `g/G` precision 0 становится 1; scientific exponent минимум
2 digits; `g/G` выбирает exponential при `exp < -4 || exp >= precision`.
`#` сохраняет point для all floats и trailing zeros для `g/G`. `%f` никогда не
переключается в exponent form. Rounding — fixed ties-to-even policy Format.

- [ ] **Step 4: Реализовать special и locale behavior**

Lowercase conversions дают `inf/nan`, uppercase — `INF/NAN`. Sign flags
применяются до width. При special value zero flag заменяется spaces. Затем
`NumberLocale` заменяет decimal separator, exponent marker, signs и digits;
grouping flag `'` parser не принимает.

- [ ] **Step 5: Подтвердить GREEN**

Run: `rtk dart test test/sprintf_double_test.dart test/double_format_test.dart`

Expected: PASS и отсутствие regression `{...}` policy.

- [ ] **Step 6: Commit**

```bash
rtk git add lib/src/number_format.dart lib/src/printf_formatter.dart test/sprintf_double_test.dart
rtk git commit -m "feat: format C++ decimal floats"
```

---

### Task 6: Hexadecimal `%a/%A`

**Files:**
- Modify: `lib/src/binary64.dart`
- Modify: `lib/src/printf_formatter.dart`
- Modify: `test/sprintf_double_test.dart`

**Interfaces:**
- Consumes: exact IEEE-754 decomposition.
- Produces: deterministic hexadecimal exponential representation with exact default round-trip and ties-to-even explicit precision.

- [ ] **Step 1: Написать RED `%a/%A` tests**

```dart
test('formats hexadecimal doubles', () {
  expect(sprintf('%a', 1.5), '0x1.8p+0');
  expect(sprintf('%A', 1.5), '0X1.8P+0');
  expect(sprintf('%#.0a', 1.0), '0x1.p+0');
  expect(sprintf('%.1a', 1.96875), '0x2.0p+0');
});
```

Добавить zero, `-0.0`, smallest subnormal, min normal, max finite, specials,
width/sign/zero/left и precisions 0..13.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test test/sprintf_double_test.dart --plain-name "formats hexadecimal doubles"`

Expected: FAIL — `%a` отсутствует.

- [ ] **Step 3: Реализовать binary-to-hex conversion**

Normal values выводят leading hex digit и fraction nibbles из significand;
subnormal policy сохраняет C++-совместимый exponent `-1022`. Без precision
вывести минимальное количество nibbles, достаточное для exact double, удалив
trailing zero. С precision округлить отброшенные bits ties-to-even и
перенормализовать carry. `#` оставляет point при нуле fraction digits.

- [ ] **Step 4: Подтвердить GREEN**

Run: `rtk dart test test/sprintf_double_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
rtk git add lib/src/binary64.dart lib/src/printf_formatter.dart test/sprintf_double_test.dart
rtk git commit -m "feat: add hexadecimal printf floats"
```

---

### Task 7: C++23 fixtures и проверяемый список расхождений

**Files:**
- Create: `tool/generate_sprintf_fixtures.cpp`
- Create: `tool/verify_sprintf_fixtures.dart`
- Create: `test/fixtures/sprintf_common.json`
- Create: `test/fixtures/sprintf_divergences.json`
- Create: `test/sprintf_compatibility_test.dart`

**Interfaces:**
- Consumes: полный printf engine Tasks 2–6.
- Produces: committed normative fixtures, allowed result sets и divergence gate.

- [ ] **Step 1: Написать fixture runner и RED common cases**

```dart
test('matches committed std::sprintf C++23 fixtures', () async {
  final suite = await SprintfFixtureSuite.load('test/fixtures/sprintf_common.json');
  for (final fixture in suite.cases) {
    expect(
      () => vsprintf(fixture.template, fixture.arguments),
      fixture.matcher,
      reason: fixture.id,
    );
  }
});
```

Runner различает exact output, allowed outputs и typed error; fixture values
используют typed codec core.

- [ ] **Step 2: Реализовать C++ generator**

Generator компилирует статически типизированную таблицу cases и для каждого
вызывает `std::snprintf(nullptr, 0, ...)`, затем `std::sprintf` в достаточный
buffer. JSON header содержит compiler, standard library, C library, OS и
`LC_ALL=C`. Cases ограничены общей областью C++/Dart values.

Команды reference-generation на Linux CI:

Run: `rtk g++ -std=c++23 -O2 tool/generate_sprintf_fixtures.cpp -o /private/tmp/generate-sprintf-fixtures`

Run: `rtk env LC_ALL=C /private/tmp/generate-sprintf-fixtures /private/tmp/sprintf-linux.json`

Команды reference-generation на macOS и macOS CI:

Run: `rtk clang++ -std=c++23 -O2 tool/generate_sprintf_fixtures.cpp -o /private/tmp/generate-sprintf-fixtures`

Run: `rtk env LC_ALL=C /private/tmp/generate-sprintf-fixtures /private/tmp/sprintf-macos.json`

- [ ] **Step 3: Зафиксировать exact и allowed reference**

`sprintf_common.json` хранит exact result там, где C++23 задаёт его однозначно,
и sorted `allowed` set там, где стандарт допускает несколько написаний.
Platform output не коммитится как нормативный результат: Linux/macOS workflows
создают его заново, записывают toolchain versions и сохраняют CI artifact.

`verify_sprintf_fixtures.dart` проверяет каждый platform case против exact или
allowed entry и завершается 1 при missing case, extra case или unexplained
output.

Run: `rtk dart run tool/verify_sprintf_fixtures.dart --reference=test/fixtures/sprintf_common.json --actual=/private/tmp/sprintf-macos.json`

Expected на macOS: exit 0; Linux выполняет ту же команду со своим `/private/tmp/sprintf-linux.json` в обязательном workflow.

- [ ] **Step 4: Зафиксировать intentional divergences**

Отдельные records покрывают unsupported pointer/length/POSIX/C++26 forms,
Unicode `%s/%c`, arbitrary `toString`, wide integers/BigInt, negative unsigned
error, typed invalid-form error, fixed rounding mode, canonical specials и
`format_intl`. Каждый record содержит README anchor.

- [ ] **Step 5: Подтвердить полный GREEN `%`-диалекта**

Run: `rtk dart test test/sprintf_compatibility_test.dart test/printf_parser_test.dart test/sprintf_api_test.dart test/sprintf_text_test.dart test/sprintf_integer_test.dart test/sprintf_double_test.dart`

Expected: PASS.

Run: `rtk dart analyze`

Expected: no issues.

- [ ] **Step 6: Commit**

```bash
rtk git add tool/generate_sprintf_fixtures.cpp tool/verify_sprintf_fixtures.dart test/fixtures/sprintf_common.json test/fixtures/sprintf_divergences.json test/sprintf_compatibility_test.dart
rtk git commit -m "test: verify sprintf against C++23"
```
