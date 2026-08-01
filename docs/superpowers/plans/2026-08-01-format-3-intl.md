# Format 3 `format_intl` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Вынести locale-интеграцию `intl` в отдельный пакет `format_intl`, внедряемый через `Format(numberLocale: ...)`, без передачи округления и выбора notation библиотеке `intl`.

**Architecture:** Основной пакет экспортирует узкий `NumberLocale`; адаптер читает только symbols и grouping pattern из данных `intl`, преобразует их в immutable `IntlNumberLocale` и передаёт ядру. Один настроенный `Format` применяет backend как к `{...:n}`, так и к floating conversions `sprintf`.

**Tech Stack:** Dart SDK `^3.7.2`, Pub workspace, root `format 3.0.0`, `intl ^0.20.2` только в `packages/format_intl`, `test ^1.25.14`.

## Global Constraints

- Корневой package `format` не имеет зависимости `intl` и по умолчанию использует `CNumberLocale`.
- `packages/format_intl` зависит от `format ^3.0.0` и `intl ^0.20.2`; версии пакетов развиваются независимо.
- `IntlNumberLocale` предоставляет symbols, digits и grouping; основное округление, precision и notation остаются в `format`.
- `IntlNumberLocale.fromDefault()` снимает locale один раз; последующее изменение `Intl.defaultLocale` не меняет экземпляр.
- `format_intl` не регистрирует global formatter, не подменяет встроенный `n` и не изменяет `defaultFormat`.
- Ошибки locale construction/usage входят в `FormattingException`, а внутренние ошибки `intl` наружу не выходят.
- Локализованные digits и features сверх Python документируются как Dart extensions.
- Production-код изменяется через red-green-refactor; все shell-команды идут через `rtk`; текущие изменения не откатываются и worktree не создаётся.

---

## Структура файлов

- `pubspec.yaml` — root version `3.0.0`, workspace member и отсутствие `intl` dependency.
- `packages/format_intl/pubspec.yaml` — package metadata, `resolution: workspace`, dependencies.
- `packages/format_intl/lib/format_intl.dart` — публичный export только `IntlNumberLocale`.
- `packages/format_intl/lib/src/intl_number_locale.dart` — snapshot symbols и реализация `NumberLocale`.
- `packages/format_intl/lib/src/grouping_pattern.dart` — разбор primary/secondary grouping из decimal pattern.
- `packages/format_intl/test/intl_number_locale_test.dart` — symbols, digits, grouping и fromDefault.
- `packages/format_intl/test/format_integration_test.dart` — публичная интеграция `Format`, `n`, `sprintf`, method tear-offs.
- `packages/format_intl/README.md`, `CHANGELOG.md`, `analysis_options.yaml`, `LICENSE` — самостоятельный публикуемый package.
- `test/workspace_integration_test.dart` — root-level проверка импорта обоих packages без `lib/src`.

---

### Task 1: Создать Pub workspace и пустой публичный адаптер

**Files:**
- Modify: `pubspec.yaml`
- Create: `packages/format_intl/pubspec.yaml`
- Create: `packages/format_intl/analysis_options.yaml`
- Create: `packages/format_intl/lib/format_intl.dart`
- Create: `packages/format_intl/lib/src/intl_number_locale.dart`
- Create: `packages/format_intl/test/intl_number_locale_test.dart`
- Copy: `LICENSE` to `packages/format_intl/LICENSE`

**Interfaces:**
- Consumes: `NumberLocale` from core plan.
- Produces: resolvable workspace package and public `IntlNumberLocale` symbol.

- [ ] **Step 1: Написать RED compile test package API**

```dart
import 'package:format/format.dart';
import 'package:format_intl/format_intl.dart';
import 'package:test/test.dart';

void main() {
  test('IntlNumberLocale implements the core contract', () {
    final NumberLocale locale = IntlNumberLocale('en_US');
    expect(locale.decimalSeparator, '.');
  });
}
```

- [ ] **Step 2: Создать exact workspace metadata**

Root `pubspec.yaml`:

```yaml
name: format
version: 3.0.0
environment:
  sdk: ^3.7.2
workspace:
  - packages/format_intl
dependencies:
  characters: ^1.4.0
dev_dependencies:
  lints: ^4.0.0
  test: ^1.25.14
```

Child `pubspec.yaml`:

```yaml
name: format_intl
description: Intl locale adapter for the format package.
version: 1.0.0
environment:
  sdk: ^3.7.2
resolution: workspace
dependencies:
  format: ^3.0.0
  intl: ^0.20.2
dev_dependencies:
  lints: ^4.0.0
  test: ^1.25.14
```

- [ ] **Step 3: Подтвердить RED после dependency resolution**

Run: `rtk dart pub get`

Expected: dependencies resolve as one workspace.

Run: `rtk dart test packages/format_intl/test/intl_number_locale_test.dart`

Expected: compile failure — `IntlNumberLocale` ещё не реализован.

- [ ] **Step 4: Добавить минимальный class и export**

`format_intl.dart` экспортирует только `src/intl_number_locale.dart show
IntlNumberLocale`. Минимальный constructor хранит canonical locale name; getters
следующего task пока возвращают symbols C locale, чтобы compile test стал GREEN.

- [ ] **Step 5: Подтвердить GREEN scaffold**

Run: `rtk dart test packages/format_intl/test/intl_number_locale_test.dart`

Expected: PASS.

Run: `rtk dart analyze`

Expected: root workspace and child have no issues.

- [ ] **Step 6: Commit**

```bash
rtk git add pubspec.yaml pubspec.lock packages/format_intl
rtk git commit -m "feat: create format_intl workspace package"
```

---

### Task 2: Снять locale symbols без `NumberFormat`

**Files:**
- Modify: `packages/format_intl/lib/src/intl_number_locale.dart`
- Create: `packages/format_intl/lib/src/grouping_pattern.dart`
- Modify: `packages/format_intl/test/intl_number_locale_test.dart`

**Interfaces:**
- Consumes: `Intl.canonicalizedLocale`, `Intl.verifiedLocale`, `numberFormatSymbols` and `NumberSymbols` data.
- Produces: immutable `IntlNumberLocale` getters and digit translation; no `NumberFormat.format` call.

- [ ] **Step 1: Написать RED symbol tests**

```dart
test('reads separators, signs, exponent and grouping from intl data', () {
  final locale = IntlNumberLocale('en_US');
  expect(locale.decimalSeparator, '.');
  expect(locale.groupSeparator, ',');
  expect(locale.plusSign, '+');
  expect(locale.minusSign, '-');
  expect(locale.exponentSeparator, 'E');
  expect(locale.grouping, [3]);
  expect(locale.groupingEnabled, isTrue);
});

test('localizes contiguous decimal digits', () {
  final locale = IntlNumberLocale('ar');
  expect(locale.localizeDigits('120'), isNot('120'));
});
```

Добавить locale с Indian grouping pattern и invalid locale typed error.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test packages/format_intl/test/intl_number_locale_test.dart`

Expected: FAIL на actual symbols/grouping.

- [ ] **Step 3: Реализовать verified immutable snapshot**

Constructor вызывает `Intl.verifiedLocale` против keys `numberFormatSymbols`.
Полученный `NumberSymbols` сразу превращается в final String/List fields;
объект не читает global state после конструктора. Invalid locale оборачивается
в `FormatConfigurationException` с original locale в reason.

Imports ограничить:

```dart
import 'package:format/format.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:intl/number_symbols.dart';
import 'package:intl/number_symbols_data.dart' show numberFormatSymbols;
```

Не создавать `NumberFormat`.

- [ ] **Step 4: Реализовать grouping parser**

Из positive subpattern до `;` взять integer section до `.`. Размер справа от
последней comma — primary; между двумя последними comma — secondary. Для
`#,##0` вернуть `[3]`, для `#,##,##0` вернуть `[3, 2]`, без comma — empty list и
`groupingEnabled=false`. Result — unmodifiable.

- [ ] **Step 5: Реализовать digits**

Взять единственный rune `ZERO_DIGIT`; для каждого ASCII `0..9` заменить rune на
`zero + digit`. Остальные chars не менять. Если `ZERO_DIGIT` не один scalar,
constructor даёт `FormatConfigurationException`, а не некорректную таблицу.

- [ ] **Step 6: Подтвердить GREEN**

Run: `rtk dart test packages/format_intl/test/intl_number_locale_test.dart`

Expected: PASS для Western, Arabic and Indian cases.

- [ ] **Step 7: Commit**

```bash
rtk git add packages/format_intl/lib packages/format_intl/test/intl_number_locale_test.dart
rtk git commit -m "feat: adapt intl number symbols"
```

---

### Task 3: Интегрировать `n`, `sprintf` и locale snapshot

**Files:**
- Create: `packages/format_intl/test/format_integration_test.dart`
- Create: `test/workspace_integration_test.dart`
- Modify: `lib/src/number_format.dart`
- Modify: `lib/src/printf_formatter.dart`

**Interfaces:**
- Consumes: complete `IntlNumberLocale`, `Format(numberLocale:)`, method tear-offs.
- Produces: locale-aware `{...:n}` and printf floats from one configured engine.

- [ ] **Step 1: Написать RED integration tests через public imports**

```dart
test('one configured Format localizes both dialects', () {
  final engine = Format(numberLocale: IntlNumberLocale('uk_UA'));
  final formatUk = engine.format;
  final sprintfUk = engine.sprintf;

  expect(formatUk('{:n}', 1234), contains('1'));
  expect(formatUk('{:n}', 1234), isNot('1,234'));
  expect(sprintfUk('%.1f', 1.5), '1,5');
});

test('fromDefault snapshots the current locale', () {
  Intl.defaultLocale = 'en_US';
  final locale = IntlNumberLocale.fromDefault();
  Intl.defaultLocale = 'uk_UA';
  expect(locale.decimalSeparator, '.');
});
```

В root test импортировать `package:format/format.dart` и
`package:format_intl/format_intl.dart`, не `lib/src`.

- [ ] **Step 2: Подтвердить RED**

Run: `rtk dart test packages/format_intl/test/format_integration_test.dart test/workspace_integration_test.dart`

Expected: FAIL на grouping/digit mapping или printf locale.

- [ ] **Step 3: Применить locale в общей numeric pipeline**

Порядок операций должен быть: exact rounding → ASCII notation → grouping by
`grouping` → decimal/exponent/sign replacement → digit localization → width.
`n` включает locale grouping автоматически; explicit `,n`/`_n` остаются
`InvalidSpecifierException`. Printf float не включает grouping без standard
flag и поэтому меняет symbols/digits, но не добавляет groups.

- [ ] **Step 4: Обернуть backend failures**

Каждый вызов `NumberLocale` выполнять через core helper, который ловит
`Object, StackTrace` и создаёт `FormatExtensionException` с runtimeType backend,
original error, stack trace и field/conversion context.

- [ ] **Step 5: Подтвердить GREEN workspace**

Run: `rtk dart test packages/format_intl/test test/workspace_integration_test.dart`

Expected: PASS.

Run: `rtk dart test --chain-stack-traces`

Expected: all root and workspace tests PASS.

- [ ] **Step 6: Commit**

```bash
rtk git add lib/src/number_format.dart lib/src/printf_formatter.dart packages/format_intl/test test/workspace_integration_test.dart
rtk git commit -m "feat: localize both formatting dialects"
```

---

### Task 4: Подготовить самостоятельную документацию package

**Files:**
- Create: `packages/format_intl/README.md`
- Create: `packages/format_intl/CHANGELOG.md`
- Create: `packages/format_intl/example/format_intl_example.dart`
- Modify: `packages/format_intl/pubspec.yaml`

**Interfaces:**
- Consumes: final public adapter API.
- Produces: publishable package docs и runnable injection example.

- [ ] **Step 1: Написать documentation example как testable program**

```dart
import 'package:format/format.dart';
import 'package:format_intl/format_intl.dart';

void main() {
  final ukrainian = Format(
    numberLocale: IntlNumberLocale('uk_UA'),
  );
  final formatUk = ukrainian.format;
  final sprintfUk = ukrainian.sprintf;

  print(formatUk('{:n}', 1234567.5));
  print(sprintfUk('%.2f', 12.5));
}
```

- [ ] **Step 2: Написать README contract**

README объясняет install двух packages, constructor injection, four method
tear-offs, `fromDefault` snapshot, отсутствие dynamic tracking, automatic `n`
grouping, printf locale symbols и то, что IntlNumberLocale не округляет.
Отдельный раздел перечисляет localized digits как Dart extension.

- [ ] **Step 3: Добавить changelog и metadata**

`CHANGELOG.md` version 1.0.0 описывает initial adapter. `pubspec.yaml` получает
homepage/repository/issue_tracker, но не добавляет dependency root path.

- [ ] **Step 4: Проверить package publication shape**

Run из root: `rtk dart analyze`

Expected: no issues.

Run из `packages/format_intl`: `rtk dart pub publish --dry-run`

Expected: 0 warnings.

Run из root: `rtk dart test --chain-stack-traces`

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
rtk git add packages/format_intl
rtk git commit -m "docs: document format_intl adapter"
```
