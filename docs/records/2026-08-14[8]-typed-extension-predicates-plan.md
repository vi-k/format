# Typed Extension Predicates Implementation Plan

> **Состояние на 2026-08-16:** исполнен 2026-08-14 коммитом `4d74070`. Tasks 1–7
> завершены через `superpowers:executing-plans`; полный обязательный прогон
> GREEN, scope и index проверены. Чекбоксы в теле отражают состояние плана до
> итогового коммита.
> **Что это:** план реализации типизированных предикатов расширений.
> **Связанные записи:** `2026-08-14[7]-typed-extension-predicates-design.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` for inline execution or
> `superpowers:subagent-driven-development` when the owner explicitly requests
> delegated execution. Track every checkbox and preserve the RED/GREEN order.

**Goal:** Сделать `canFormat`, `canLookup` и `canRepresent` типизированными по
`T`, принять весь `T` по умолчанию и перенести первичную проверку типа внутрь
движка без изменения диспетчеризации и ошибок.

**Architecture:** Каждый публичный generic-класс хранит приватный `_accepts`,
который ещё видит реальный `T` и выполняет `value is T && can*(value)`.
Три документированные как внутренние top-level функции в `extensions.dart`
дают движку доступ к этим приватным методам; публичные фасады уже используют
`show`, поэтому новые функции не экспортируются из поддерживаемого API.
Существующие `try`/`catch` движка остаются вокруг вызова helper и продолжают
оборачивать только пользовательский `can*`.

**Tech Stack:** Dart SDK с нижней границей 3.7.2, reified generic type checks,
`package:test`, публичные фасады `package:format/format.dart`, VM, dart2js,
dart2wasm.

## Global Constraints

- Источник решения —
  `docs/records/2026-08-14[7]-typed-extension-predicates-design.md`; не
  добавлять переходный `Object?`-мост, второй предикат или `covariant`.
- Итоговая публичная форма — `bool canFormat(T value) => true`,
  `bool canLookup(T value) => true`, `bool canRepresent(T value) => true`.
- Несовпадение `value is T` означает «расширение не подходит» и не вызывает
  пользовательский предикат. Исключение из typed-предиката после успешной
  проверки сохраняет нынешнюю оболочку `FormatExtensionException`, исходную
  ошибку, stack trace и контекст.
- Не менять встроенный приоритет, порядок обхода, неоднозначность, fallback,
  `specifier`, `FormatOptions`, конструктор `Format`, версию `3.0.0` и
  публикацию пакета.
- Не редактировать замороженные baseline-пакеты и историческое содержание
  закрытых design/review-записей; у design и plan меняется только статус.
- Код и комментарии в коде пишутся по-английски, проектные документы —
  по-русски. Все shell-команды запускаются через `rtk`, файлы меняются через
  `apply_patch`.
- Работа идёт прямо в `main`, без PR. Промежуточных кодовых коммитов нет:
  тесты, реализация, миграция, документация, handoff и вычеркнутый пункт
  `docs/backlog.md` входят в один атомарный коммит после полного обязательного
  прогона.
- Изменение не заявляется как ускорение: отдельный локальный performance A/B
  не требуется, но benchmark suite и три quick-матрицы обязательны как часть
  полного прогона.

---

### Task 1: Типизировать `Formatter<T>` через тесты

**Files:**
- Modify: `test/custom_formatter_test.dart:28-121,130-406`
- Modify: `lib/src/extensions.dart:3-65`
- Modify: `lib/src/value_formatter.dart:124-141`

**Interfaces:**
- Changes: `Formatter<T>.canFormat(Object?)` →
  `Formatter<T>.canFormat(T) => true`.
- Adds internally: `Formatter<T>._accepts(Object?)` and
  `formatterAccepts(Formatter<dynamic>, Object?)`.
- Preserves: named selection, automatic selection, built-in priority,
  ambiguity and callback error wrapping.

- [x] **Step 1: Перевести formatter-фикстуры на желаемый контракт**

В `test/custom_formatter_test.dart` удалить повторяющие типовую проверку
override'ы из `_OptionsFormatter`, `_AutomaticFormatter`, `_ThrowingFormat` и
`_FormattingErrorFormatter`. У `_NamedFormatter<Object?>` также удалить
безусловный override: default обязан принимать весь `Object?`.

Сохранить `_ProbeFormatter<Object?>` как пример дополнительного фильтра внутри
широкого `T`. У `_ThrowingCanFormat` изменить сигнатуру на:

```dart
  @override
  bool canFormat(_Value value) => throw StateError('canFormat failed');
```

Добавить рядом фикстуру, которая принимает только часть `_Value`:

```dart
final class _SelectiveFormatter extends Formatter<_Value> {
  @override
  String get specifier => 'selective';

  @override
  bool canFormat(_Value value) => value.name.startsWith('accepted');

  @override
  String format(_Value value, FormatOptions options) => value.name;
}
```

Добавить два теста:

1. `_AutomaticFormatter` без `canFormat` автоматически форматирует `_Value` —
   существующий `empty specifications select one automatic formatter` уже
   служит compile/runtime-доказательством default.
2. `_SelectiveFormatter` форматирует `_Value('accepted-one')`, но для
   `_Value('rejected')` под явным `{:selective}` даёт
   `UnsupportedFormatValueException`.
3. `Format(formatters: [_ThrowingCanFormat()])` при явном
   `{:throwsCan}` и значении другого типа (`Object()`) даёт
   `UnsupportedFormatValueException`, а не `FormatExtensionException`: typed
   callback не должен быть вызван до `value is _Value`.

Существующий тест `custom formatter callback failures retain formatting
context` оставить для `_Value('x')`: он докажет, что после успешного guard
исключение из typed-предиката всё ещё оборачивается.

- [x] **Step 2: Получить RED на старом API**

Run from the repository root:

```sh
rtk dart format test/custom_formatter_test.dart
rtk dart test test/custom_formatter_test.dart
```

Expected: тестовый файл не компилируется. Классы без `canFormat(Object?)` не
реализуют нынешний abstract-метод, а `canFormat(_Value)` не является валидным
override сигнатуры `canFormat(Object?)`. Зафиксировать именно этот RED до
правки `lib/`.

- [x] **Step 3: Реализовать type guard в `Formatter<T>`**

В `lib/src/extensions.dart` заменить контракт предиката на default и добавить
приватный метод класса:

```dart
  /// Whether this formatter accepts [value] after its type has been checked.
  ///
  /// The engine filters values outside [T] before calling this method. Override
  /// it only to express a narrower condition within [T].
  ///
  /// {@macro format.extension_failure}
  bool canFormat(T value) => true;

  bool _accepts(Object? value) => value is T && canFormat(value);
```

После класса `Formatter` добавить доступную только внутренним импортам
функцию с dartdoc, достаточным для `public_member_api_docs`:

```dart
/// Checks [value] against a formatter's reified type and typed predicate.
///
/// Internal to the engine; not exported from the package facade.
bool formatterAccepts(Formatter<dynamic> formatter, Object? value) =>
    formatter._accepts(value);
```

В общем macro `format.extension_failure` удалить утверждение, что ошибочный
`true` приводит к `TypeError`: guard теперь делает этот случай невозможным.
Оставить описание оборачивания пользовательских ошибок и
`StackOverflowError` при рекурсивном вызове движка.

В `lib/src/value_formatter.dart` внутри `_canFormat` заменить только вызов:

```dart
    return formatterAccepts(formatter, value);
```

Не переносить проверку за пределы существующего `try`: сам type guard не
бросает, но следующий за ним пользовательский `canFormat` обязан сохранить
обёртку.

- [x] **Step 4: Получить GREEN для formatter-контракта**

```sh
rtk dart format lib/src/extensions.dart lib/src/value_formatter.dart test/custom_formatter_test.dart
rtk dart test test/custom_formatter_test.dart
```

Expected: PASS. В частности проходят default без override, subset-предикат,
отсечение чужого типа до callback, существующие ambiguity и failure tests.

---

### Task 2: Типизировать `AttributeLookup<T>` через тесты

**Files:**
- Modify: `test/lookup_test.dart:24-82,156-326`
- Modify: `lib/src/extensions.dart:115-139`
- Modify: `lib/src/field_resolver.dart:100-117`

**Interfaces:**
- Changes: `AttributeLookup<T>.canLookup(Object?)` →
  `AttributeLookup<T>.canLookup(T) => true`.
- Adds internally: `AttributeLookup<T>._accepts(Object?)` and
  `attributeLookupAccepts(AttributeLookup<dynamic>, Object?)`.
- Preserves: `Map` shortcut, missing-step error, ambiguity and callback error
  wrapping.

- [x] **Step 1: Перевести lookup-фикстуры на желаемый контракт**

В `test/lookup_test.dart` удалить типовые override'ы `canLookup` у
`PersonLookup`, `AnotherPersonLookup`, `MapFallbackLookup` и `ThrowingLookup`.
У `ThrowingCanLookup` изменить параметр с `Object?` на `Person`.

Добавить:

```dart
final class SelectivePersonLookup extends AttributeLookup<Person> {
  @override
  bool canLookup(Person value) => value.name.startsWith('A');

  @override
  Object? lookup(Person value, String attribute) => value.name;
}
```

Рядом с `uses exactly one custom attribute lookup` добавить тест, который:

- подтверждает `Ada` через `SelectivePersonLookup`;
- получает `FormatLookupException` для `Bob`, потому что значение имеет
  правильный `Person`, но typed-предикат отверг его.

Добавить отдельный guard-тест с `ThrowingCanLookup`: передать через именованный
аргумент `Object()` в `{value.name}` и ожидать `FormatLookupException`, а не
`FormatExtensionException`. Существующий тест с `Person('Ada')` остаётся и
доказывает прежнюю обёртку пользовательского исключения после guard.

- [x] **Step 2: Получить RED на старом lookup API**

```sh
rtk dart format test/lookup_test.dart
rtk dart test test/lookup_test.dart
```

Expected: compile failure из-за отсутствующих реализаций
`canLookup(Object?)` и несовместимых typed overrides.

- [x] **Step 3: Реализовать type guard в `AttributeLookup<T>`**

В `lib/src/extensions.dart` заменить метод и добавить `_accepts`:

```dart
  /// Whether this lookup accepts [value] after its type has been checked.
  ///
  /// The engine filters values outside [T] before calling this method. Override
  /// it only to express a narrower condition within [T].
  ///
  /// {@macro format.extension_failure}
  bool canLookup(T value) => true;

  bool _accepts(Object? value) => value is T && canLookup(value);
```

После класса добавить:

```dart
/// Checks [value] against a lookup's reified type and typed predicate.
///
/// Internal to the engine; not exported from the package facade.
bool attributeLookupAccepts(
  AttributeLookup<dynamic> lookup,
  Object? value,
) => lookup._accepts(value);
```

В `lib/src/field_resolver.dart` внутри существующего `try` заменить вызов на:

```dart
      return attributeLookupAccepts(lookup, value);
```

Не менять ветку встроенного `Map`, накопление matches и `_lookup`.

- [x] **Step 4: Получить GREEN для lookup-контракта**

```sh
rtk dart format lib/src/extensions.dart lib/src/field_resolver.dart test/lookup_test.dart
rtk dart test test/lookup_test.dart
```

Expected: PASS, включая default lookup, subset, guard, ambiguity, исходную
ошибку и stack trace.

---

### Task 3: Типизировать `Representation<T>` через тесты

**Files:**
- Modify: `test/conversion_test.dart:29-70,211-471,490-523`
- Modify: `lib/src/extensions.dart:141-163`
- Modify: `lib/src/representation.dart:178-224`

**Interfaces:**
- Changes: `Representation<T>.canRepresent(Object?)` →
  `Representation<T>.canRepresent(T) => true`.
- Adds internally: `Representation<T>._accepts(Object?)` and
  `representationAccepts(Representation<dynamic>, Object?)`.
- Preserves: built-in representation priority, recursive representation,
  ambiguity and callback error wrapping.

- [x] **Step 1: Перевести representation-фикстуры на желаемый контракт**

В `test/conversion_test.dart` удалить типовые override'ы у
`_TokenRepresentation`, `_NamedTokenRepresentation`, `_ThrowingRepresent`,
`_OrderedValuesRepresentation`, `_MapRepresentation` и
`_BigIntRepresentation`. У `_ThrowingCanRepresent` изменить параметр на
`_Token`.

Добавить:

```dart
final class _SelectiveTokenRepresentation extends Representation<_Token> {
  @override
  bool canRepresent(_Token value) => value.value.startsWith('accepted');

  @override
  String represent(_Token value) => '<${value.value}>';
}
```

Добавить тест на `accepted-one` и `rejected`: первый даёт
`'<accepted-one>'`, второй — `UnsupportedConversionException`. Добавить
guard-тест: движок только с `_ThrowingCanRepresent` получает неизвестный
объект другого типа в `{!r}` и возвращает `UnsupportedConversionException`,
не вызывая typed callback. Существующий тест на `_Token` и ошибку callback
оставить без ослабления.

- [x] **Step 2: Получить RED на старом representation API**

```sh
rtk dart format test/conversion_test.dart
rtk dart test test/conversion_test.dart
```

Expected: compile failure из-за старого abstract-метода с `Object?` и новых
typed overrides.

- [x] **Step 3: Реализовать type guard в `Representation<T>`**

В `lib/src/extensions.dart` заменить метод и добавить `_accepts`:

```dart
  /// Whether this representation accepts [value] after its type is checked.
  ///
  /// The engine filters values outside [T] before calling this method. Override
  /// it only to express a narrower condition within [T].
  ///
  /// {@macro format.extension_failure}
  bool canRepresent(T value) => true;

  bool _accepts(Object? value) => value is T && canRepresent(value);
```

После класса добавить:

```dart
/// Checks [value] against a representation's reified type and typed predicate.
///
/// Internal to the engine; not exported from the package facade.
bool representationAccepts(
  Representation<dynamic> representation,
  Object? value,
) => representation._accepts(value);
```

В `lib/src/representation.dart` внутри `_canRepresent` заменить вызов на:

```dart
      return representationAccepts(representation, value);
```

- [x] **Step 4: Получить GREEN для representation-контракта**

```sh
rtk dart format lib/src/extensions.dart lib/src/representation.dart test/conversion_test.dart
rtk dart test test/conversion_test.dart
```

Expected: PASS, включая default representation, subset, guard, ambiguity и
оборачивание typed callback.

---

### Task 4: Закрепить nullable и широкие generic-параметры

**Files:**
- Modify: `test/custom_formatter_test.dart`
- Modify: `test/lookup_test.dart`
- Modify: `test/conversion_test.dart`

**Contract:** `_accepts` обязан следовать обычной Dart-семантике `T` для
`Object?`, nullable-типа и `dynamic`, а не трактовать `null` отдельно.

- [x] **Step 1: Добавить минимальные nullable-фикстуры**

Добавить по одному узкому тестовому extension point с nullable `T`, в котором
`can*` записывает полученное значение и возвращает `true`. Выбрать пути, где
встроенный приоритет не перехватит проверяемое значение:

- formatter: явно названный `Formatter<_Value?>` форматирует `null`;
- lookup: `AttributeLookup<Person?>` получает `null` при обращении к
  `{value.name}`;
- representation: если встроенный `null` не доходит до реестра, проверить
  nullable guard напрямую через существующий внутренний test import
  `package:format/src/extensions.dart`, не меняя публичный facade.

Для `Formatter<Object?>` сохранить `_NamedFormatter` и его существующий
именованный вызов на built-in `int`: это доказывает, что широкий generic не
теряет значения. Для `dynamic` отдельная семантика совпадает с `Object?` на
достижимых значениях и не требует дублирующего публичного теста.

- [x] **Step 2: Проверить nullable-контракт**

```sh
rtk dart format test/custom_formatter_test.dart test/lookup_test.dart test/conversion_test.dart
rtk dart test test/custom_formatter_test.dart test/lookup_test.dart test/conversion_test.dart
```

Expected: PASS; `null` доходит до typed callback ровно там, где движок не
перехватывает его раньше собственным правилом.

---

### Task 5: Мигрировать все реализации и публичные примеры

**Files:**
- Modify: `example/format_example.dart:3-14`
- Modify: `benchmark/scenarios.dart:790-801`
- Modify: `test/format_test.dart:18-34`
- Modify: `test/formatter_registry_test.dart:23-81,255-266`
- Modify: `test/api_test.dart:16-31`
- Modify: `test/python_compatibility_test.dart:329-355`
- Modify: `test/parity_harness.dart:92-137`
- Modify: `README.md:310-450`
- Modify: `README.ru.md:324-466`
- Modify: `CHANGELOG.md:3-10`

- [x] **Step 1: Удалить boilerplate и сохранить настоящие предикаты**

По всему незамороженному Dart-коду удалить override, если он равен только
`value is T` или безусловному `true`. Это касается example, benchmark,
`_TracingRepresentation`, API-фикстур, parity harness, Python compatibility и
вспомогательных representation в conversion tests.

Сохранить предикаты, которые несут поведение сверх типа:

- `_ProbeFormatter<Object?>`: `value is int`;
- `EmptyLookup<Object?>`: `false`;
- `EmptyRepresentation<Object?>`: `false`;
- `DecayingSpecifierFormatter<Object?>`: бросает ошибку;
- новые selective/nullable-фикстуры.

У сохранённых предикатов параметр должен быть ровно `T`. Удалить безусловный
`canFormat` из `NamedFormatter`, `ThrowingSpecifierFormatter` и
`_LocatedFailureFormatter`: default выражает их контракт.

Проверить остаток:

```sh
rtk rg -n "bool can(Format|Lookup|Represent)" \
  --glob '*.dart' --glob '!benchmark/baselines/**' .
```

Expected: три default-метода в `lib/src/extensions.dart` и только
содержательные typed overrides в тестах; ни одного `value is T` boilerplate.

- [x] **Step 2: Обновить английский README и example**

В трёх extension-разделах `README.md` удалить `can*(Object?) => value is T`
из обычных примеров. Рядом объяснить:

- движок сначала проверяет generic-параметр;
- default принимает весь `T`, поэтому обычный extension реализует только
  рабочий метод;
- override typed `can*` нужен для дополнительного условия внутри `T`.

Показать один короткий пример дополнительного условия, например
`bool canFormat(Money value) => value.currency == 'KZT'`, без дублирования во
всех трёх разделах. `example/format_example.dart` должен компилироваться без
`canFormat`.

- [x] **Step 3: Синхронно обновить русский README**

В `README.ru.md` внести ту же информацию и тот же смысл примеров по-русски.
Не добавлять новых якорей без необходимости; существующие оглавление и
markdown anchors должны остаться валидны.

- [x] **Step 4: Записать ломающее изменение и миграцию в CHANGELOG**

В начало `## Unreleased` добавить пункт:

- `canFormat`, `canLookup`, `canRepresent` теперь получают `T`, а движок
  проверяет тип до пользовательского callback;
- методы имеют default `true`;
- миграция: удалить `value is T`, а дополнительный фильтр переписать с
  `Object?` на `T`;
- это breaking change для кода, уже написанного против 3.0.0.

Версию в `pubspec.yaml` не менять и релиз не выполнять.

- [x] **Step 5: Проверить миграцию по статике и focused tests**

```sh
rtk dart format lib test example benchmark/scenarios.dart
rtk dart analyze --fatal-infos lib test example tool
rtk dart test test/api_test.dart test/markdown_anchors_test.dart test/format_test.dart test/formatter_registry_test.dart test/template_ir_diff_test.dart test/template_ir_fuzz_test.dart test/python_compatibility_test.dart
```

Expected: format не меняет уже отформатированные файлы, analyze чистый,
публичный facade по-прежнему позволяет реализовать все три extension point,
README anchors, оба потребителя `test/parity_harness.dart` и остальные
мигрированные потребители PASS.

---

### Task 6: Завершить живые документы и исполненный пункт бэклога

**Files:**
- Modify: `docs/backlog.md:1-9`
- Modify: `docs/handoff.md:1-20,1160-1190` и добавить итоговый раздел
- Modify: `docs/records/2026-08-14[7]-typed-extension-predicates-design.md:1-4`
- Modify: `docs/records/2026-08-14[8]-typed-extension-predicates-plan.md:1-5`

- [x] **Step 1: Вычеркнуть только исполненный пункт бэклога**

Первый пункт `docs/backlog.md` не удалять, а зачеркнуть и дописать короткий
исход: generic `T` проверяет движок, typed-предикат остаётся для подмножества.
Второй пункт про полное описание форматов оставить побайтно неизменным и
открытым.

- [x] **Step 2: Обновить design и plan statuses**

В design поставить статус «исполнен 2026-08-14» без переписывания
согласованного тела. В этом плане после фактического выполнения отметить все
checkbox и заменить начальный статус на итоговый с результатом обязательного
прогона.

- [x] **Step 3: Синхронизировать handoff**

Обновить `Статус:` вверху, добавить раздел
`## Что сделано 2026-08-14 (типизированные предикаты расширений)` с:

- окончательной публичной сигнатурой и внутренним guard;
- тестами default/subset/wrong type/null/error wrapping;
- фактом breaking change относительно сегодняшнего 3.0.0;
- ссылками на design и plan;
- итогами полного прогона из Task 7.

В `## Что открыто` заменить устаревшее «бэклог пуст» на второй, всё ещё
открытый пункт про единый источник полного описания форматов. Исторические
разделы не переписывать, но живое состояние не должно противоречить
`docs/backlog.md`.

- [x] **Step 4: Проверить отсутствие незавершённых формулировок**

```sh
rtk rg -n "T[D]O|T[B]D|FIX[M]E|placeholde[r]|ждёт реализаци[юи]|ещё не нача[тт]" \
  docs/records/'2026-08-14[7]-typed-extension-predicates-design.md' \
  docs/records/'2026-08-14[8]-typed-extension-predicates-plan.md'
rtk git diff --check
```

Expected: первый поиск не находит незавершённых маркеров, `git diff --check`
молчит. Слово `TODO` в заголовке самого `docs/backlog.md` этим поиском
намеренно не проверяется.

---

### Task 7: Полный обязательный прогон и атомарный коммит

**Files:**
- Verify: весь репозиторий и опубликованный архив
- Commit: все изменения Tasks 1–6, включая исполненный пункт backlog

- [x] **Step 1: Проверить форматирование и статический анализ**

Run from the repository root:

```sh
rtk dart format .
rtk dart analyze --fatal-infos lib test example tool
```

Expected: formatter сообщает 0 changed при повторном запуске; analyze — no
issues.

- [x] **Step 2: Прогнать весь пакет на трёх рантаймах**

```sh
rtk dart test
rtk dart test -p node
rtk dart test -p node -c dart2wasm -x no-dart2wasm
```

Expected: все доступные тесты PASS; остаются только документированные
platform skips. Не заменять эти команды выборкой файлов.

- [x] **Step 3: Прогнать вспомогательные пакеты и автономный архив**

```sh
rtk dart test benchmark/test tool/test
```

Run from `packages/format_intl`:

```sh
rtk dart test
```

Run again from the repository root:

```sh
rtk dart run tool/verify_package_archive.dart
rtk dart run tool/verify_generated_artifacts.dart
```

Expected: auxiliary tests, `format_intl`, самостоятельная сборка/тест архива
и генераторы PASS. Если машине недоступны CPython 3.14 или C++23, выполнить
документированные `--self-test` и явно зафиксировать ограничение вместо
ложного полного GREEN; на текущей машине ожидается полный прогон.

- [x] **Step 4: Проверить покрытие**

```sh
rtk dart test --coverage=.coverage
rtk dart run coverage:format_coverage --lcov --in=.coverage --out=coverage/lcov.info --report-on=lib --packages=.dart_tool/package_config.json
rtk dart run tool/check_coverage.dart --lcov=coverage/lcov.info
```

Expected: tests PASS, общий показатель не ниже 94%. Новые guard-ветки должны
быть покрыты тестами wrong type и matching type.

- [x] **Step 5: Прогнать benchmark suite и три quick-матрицы**

Run from `benchmark/suite`:

```sh
rtk dart pub get
rtk dart test
rtk dart run tool/run.dart --runtime=vm
rtk dart run tool/run.dart --runtime=js
rtk dart run tool/run.dart --runtime=wasm
```

Expected: 15 suite tests PASS, все три матрицы завершаются успешно. Числа
информационные: изменение не заявлено как performance work, матрица и gate
baseline не меняются.

- [x] **Step 6: Проверить scope и staged diff**

Run from the repository root:

```sh
rtk git status --short
rtk git diff --stat
rtk git diff --check
rtk git diff -- docs/backlog.md
```

Expected: только файлы этого плана; в backlog зачёркнут первый пункт и
неизменён второй. Второй пункт остаётся пользовательской незавершённой правкой
и не должен попасть в commit.

Сначала поставить весь worktree, исключив пользовательский backlog. Затем
через `apply_patch` временно убрать из worktree только две строки второго
пункта, явно добавить в index версию backlog с одним зачёркнутым исполненным
пунктом и сразу вернуть второй пункт в worktree через `apply_patch`:

```sh
rtk git add -A ':(exclude)docs/backlog.md'
rtk git add docs/backlog.md
rtk git diff --cached --check
rtk git diff --cached --stat
rtk git diff -- docs/backlog.md
```

Просмотреть staged diff и убедиться, что `pubspec.yaml`, baseline-пакеты,
performance gate и второй backlog-пункт отсутствуют. Последняя команда должна
показывать только возвращённый второй пункт как unstaged owner change.

- [x] **Step 7: Создать один implementation commit**

```sh
rtk git commit -m "feat: типизировать предикаты расширений"
rtk git status --short
```

Expected: commit успешен; единственное оставшееся изменение рабочего дерева —
незавершённый второй пункт `docs/backlog.md`, принадлежащий владельцу. Push,
публикация, git tag и GitHub Release не входят в эту работу и без отдельного
запроса не выполняются.

---

## Acceptance Checklist

- [x] `Formatter<T>`, `AttributeLookup<T>` и `Representation<T>` имеют typed
  default-предикаты, принимающие весь `T`.
- [x] Движок отсекает неверный runtime type до пользовательского callback для
  всех трёх extension point.
- [x] Дополнительный typed-предикат может отвергнуть часть значений своего
  `T`; его исключения сохраняют прежнюю диагностику.
- [x] Built-in priority, fallback, ambiguity, order и error types не изменены.
- [x] Nullable и `Object?` ведут себя по обычным правилам Dart.
- [x] В незамороженном коде и README нет boilerplate `value is T`.
- [x] CHANGELOG содержит breaking migration, версия остаётся `3.0.0`.
- [x] Первый backlog-пункт зачёркнут в implementation commit, второй открыт.
- [x] Handoff отражает актуальное состояние и фактические результаты полного
  обязательного прогона.
- [x] Все обязательные проверки GREEN до коммита.
