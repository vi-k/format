# JavaScript Character Fast Path Implementation Plan

Статус: исполнен 2026-08-14 коммитом `17c0419`. Tasks 1–3 завершены через
`superpowers:executing-plans`; A/B и полный обязательный прогон GREEN.
Чекбоксы в теле отражают состояние плана до итогового коммита.

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Убрать промежуточный `BigInt` из обычного `int`-пути `{:c}` и `%c`,
сохранив Unicode-контракт и подтвердив ускорение под dart2js локальным A/B.

**Architecture:** Общий `_unicodeScalar` разделяет исходные `int` и `BigInt`:
первый сравнивается с Unicode-границами напрямую, второй сохраняет точную
`BigInt`-проверку. Публичные brace- и printf-тесты закрепляют одинаковые
границы, а один временный harness компилируется до и после правки и запускает
по одному сценарию на процесс.

**Tech Stack:** Dart stable 3.13.0, dart2js `-O4 --no-minify`, Node.js 24.8.0,
`package:test`, существующие Format 3 и замороженная Format 1.6 baseline.

## Global Constraints

- Документы пишутся по-русски, код и комментарии в коде — по-английски.
- Публичный API, допустимые значения, Unicode-границы, typed errors, ширина и
  выравнивание не меняются.
- Настоящий `BigInt` остаётся поддержанным; обычный `int` не превращается в
  `BigInt` на успешном пути.
- IR, кэш шаблонов, матрица performance gate и её эталон не меняются.
- Производительность решает локальный A/B: все парные запуски обычного `int`
  должны идти в сторону ускорения, минимум должен улучшиться не менее чем на
  10%, `%c` не должен замедлиться, а Format 3 `{:c}` должен стать заметно
  быстрее Format 1.6.
- Если performance GREEN не подтверждается, правка `lib/` откатывается и не
  коммитится как ускорение; измеренный отрицательный результат остаётся в
  документации.
- Промежуточных кодовых коммитов нет: тесты, реализация, `CHANGELOG.md`,
  `docs/handoff.md`, исполненный пункт `docs/backlog.md` и этот план входят в
  один атомарный follow-up после полного списка проверок.
- Работа ведётся прямо в `main`, без PR. Перед коммитом выполняется весь раздел
  `## Как проверить всё` из `docs/handoff.md`, после push проверяется CI точной
  ревизии.
- Каждая исполняемая shell-команда проходит через `rtk`; файлы меняются через
  `apply_patch`.

---

### Task 1: Закрепить контракт и снять красный performance-эталон

**Files:**
- Modify: `test/text_format_test.dart:139-207`
- Modify: `test/sprintf_text_test.dart:184-216`
- Create outside repository: `/private/tmp/format-c-benchmark.dart`
- Create outside repository: `/private/tmp/run-format-c-benchmark.cjs`
- Create outside repository: `/private/tmp/check-format-c-improvement.dart`
- Produce outside repository: `/private/tmp/format-c-before.js`

**Interfaces:**
- Consumes: публичные `format`, `Format.formatWith`, `sprintf` и замороженный
  `format16.format`.
- Produces: граничные characterization-тесты для `int` и `BigInt` и
  неизменяемую dart2js-сборку старой реализации для A/B.

- [x] **Step 1: Расширить допустимые Unicode-границы brace-теста**

Заменить отдельные ожидания начала теста
`formats Unicode scalar values with c` в `test/text_format_test.dart` на:

```dart
    for (final scalar in [0, 0xd7ff, 0xe000, 0x10ffff]) {
      expect(format('{:c}', scalar), String.fromCharCode(scalar));
    }
    for (final scalar in [
      BigInt.zero,
      BigInt.from(0xd7ff),
      BigInt.from(0xe000),
      BigInt.from(0x10ffff),
    ]) {
      expect(format('{:c}', scalar), String.fromCharCode(scalar.toInt()));
    }
```

Сохранить существующие проверки ширины и выравнивания. В список
недопустимых значений этого файла добавить `0xdfff`,
`BigInt.from(0xd800)` и `BigInt.from(0xdfff)`; уже имеющиеся `-1`,
`0x110000`, `0xd800`, `BigInt.from(-1)`, `BigInt.from(0x110000)`, список и
строку оставить.

- [x] **Step 2: Расширить те же границы printf-теста**

В начале теста `formats Unicode scalar values with c` в
`test/sprintf_text_test.dart` использовать:

```dart
    for (final scalar in [0, 0xd7ff, 0xe000, 0x10ffff]) {
      expect(sprintf('%c', scalar), String.fromCharCode(scalar));
    }
    for (final scalar in [
      BigInt.zero,
      BigInt.from(0xd7ff),
      BigInt.from(0xe000),
      BigInt.from(0x10ffff),
    ]) {
      expect(sprintf('%c', scalar), String.fromCharCode(scalar.toInt()));
    }
```

Сохранить проверки astral-width и left alignment. В список значений теста
`rejects invalid Unicode scalar values with typed context` добавить
`0xdfff`, `BigInt.from(-1)`, `BigInt.from(0xd800)`,
`BigInt.from(0xdfff)` и `BigInt.from(0x110000)`.

- [x] **Step 3: Запустить characterization-тесты до реализации**

Run from the repository root:

```sh
rtk dart format test/text_format_test.dart test/sprintf_text_test.dart
rtk dart test test/text_format_test.dart test/sprintf_text_test.dart
rtk dart test -p node test/text_format_test.dart test/sprintf_text_test.dart
rtk dart test -p node -c dart2wasm -x no-dart2wasm test/text_format_test.dart test/sprintf_text_test.dart
```

Expected: все проверки PASS. Здесь зелёный результат намеренный: поведение уже
реализовано, тесты фиксируют контракт перед внутренней оптимизацией. Красная
фаза задачи — измеряемый performance-критерий следующего шага.

- [x] **Step 4: Создать одно-сценарный временный harness**

Создать `/private/tmp/format-c-benchmark.dart` через `apply_patch` с точным
содержимым:

```dart
import 'package:format/format.dart';
import 'package:format16_baseline/format16.dart' as format16;

const _warmups = 5;
const _rounds = 30;
const _operations = 1000000;
const _intValues = <Object?>[65];
final _bigIntValues = <Object?>[BigInt.from(65)];
final _engine = Format();

void main(List<String> arguments) {
  if (arguments.length != 1) {
    throw ArgumentError('Expected one scenario name.');
  }
  final scenario = arguments.single;
  final operation = switch (scenario) {
    'brace-int' => () =>
      _engine.formatWith('{:c}', positional: _intValues),
    'printf-int' => () => sprintf('%c', 65),
    'brace-bigint' => () =>
      _engine.formatWith('{:c}', positional: _bigIntValues),
    'printf-bigint' => () => sprintf('%c', BigInt.from(65)),
    'format16' => () => format16.format('{:c}', _intValues),
    _ => throw ArgumentError.value(scenario, 'scenario'),
  };

  var minimum = double.infinity;
  var totalChecksum = 0;
  for (var round = 0; round < _warmups + _rounds; round++) {
    final stopwatch = Stopwatch()..start();
    var checksum = 0;
    for (var index = 0; index < _operations; index++) {
      checksum += operation().codeUnitAt(0);
    }
    stopwatch.stop();
    totalChecksum ^= checksum;
    if (round >= _warmups) {
      final nanoseconds =
          stopwatch.elapsedMicroseconds * 1000 / _operations;
      if (nanoseconds < minimum) minimum = nanoseconds;
    }
  }
  print(
    '$scenario ${minimum.toStringAsFixed(2)} ns checksum=$totalChecksum',
  );
}
```

Создать `/private/tmp/run-format-c-benchmark.cjs` через `apply_patch`, чтобы
Node передал имя сценария скомпилированному dart2js `main(List<String>)`:

```js
const compiledPath = process.argv[2];
const args = process.argv.slice(3);

globalThis.dartMainRunner = (main) => main(args);
require(compiledPath);
```

- [x] **Step 5: Скомпилировать и измерить старую реализацию**

Run:

```sh
rtk dart compile js -O4 --no-minify --packages=benchmark/suite/.dart_tool/package_config.json /private/tmp/format-c-benchmark.dart -o /private/tmp/format-c-before.js
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js brace-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js printf-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js brace-bigint
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js printf-bigint
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js format16
```

Expected: каждый сценарий печатает ненулевой checksum. На текущей ревизии
`brace-int` примерно равен `format16` и тем самым не выполняет согласованный
performance-критерий; `/private/tmp/format-c-before.js` больше не
перекомпилировать после изменения `lib/`.

- [x] **Step 6: Увидеть RED на требовании десятипроцентного A/B**

Создать `/private/tmp/check-format-c-improvement.dart` через `apply_patch`:

```dart
void main(List<String> arguments) {
  if (arguments.length != 2) {
    throw ArgumentError('Expected before and candidate minima.');
  }
  final before = double.parse(arguments[0]);
  final candidate = double.parse(arguments[1]);
  final limit = before * 0.9;
  if (candidate > limit) {
    throw StateError(
      'Expected candidate <= ${limit.toStringAsFixed(2)} ns, '
      'got ${candidate.toStringAsFixed(2)} ns.',
    );
  }
}
```

Перед production-правкой передать checker'у дважды измеренный минимум
`brace-int` старой сборки:

```sh
rtk dart /private/tmp/check-format-c-improvement.dart 133 133
```

Expected: FAIL с `Expected candidate <= 119.70 ns, got 133.00 ns.` Кандидат
пока совпадает с baseline и не может показать требуемое ускорение; после Task
2 второй аргумент заменяется измеренным after-минимумом.

### Task 2: Добавить общий `int`-fast path и доказать ускорение

**Files:**
- Modify: `lib/src/value_formatter.dart:362-382`
- Read through shared part library: `lib/src/number_format.dart`
- Produce outside repository: `/private/tmp/format-c-after.js`

**Interfaces:**
- Consumes: `_isIntegerValue(Object?) -> bool` и исходный
  `FormatExceptionContext`.
- Produces: `_unicodeScalar(Object?, FormatExceptionContext) -> int` с
  отдельными успешными ветвями `int` и `BigInt` и единым typed-error путём.

- [x] **Step 1: Реализовать минимальное разделение типов**

Заменить `_unicodeScalar` в `lib/src/value_formatter.dart` на:

```dart
int _unicodeScalar(Object? value, FormatExceptionContext context) {
  const maximum = 0x10ffff;
  const surrogateStart = 0xd800;
  const surrogateEnd = 0xdfff;

  if (value is int && _isIntegerValue(value)) {
    if (value >= 0 &&
        value <= maximum &&
        (value < surrogateStart || value > surrogateEnd)) {
      return value;
    }
  } else if (value is BigInt) {
    if (value >= BigInt.zero &&
        value <= BigInt.from(maximum) &&
        (value < BigInt.from(surrogateStart) ||
            value > BigInt.from(surrogateEnd))) {
      return value.toInt();
    }
  }
  throw UnsupportedFormatValueException(context, value);
}
```

Не добавлять новые IR-операции, платформенные ветви, public seams или кэши
`BigInt`-границ.

- [x] **Step 2: Подтвердить поведение на трёх рантаймах**

Run:

```sh
rtk dart format lib/src/value_formatter.dart test/text_format_test.dart test/sprintf_text_test.dart
rtk dart analyze --fatal-infos lib test
rtk dart test test/text_format_test.dart test/sprintf_text_test.dart
rtk dart test -p node test/text_format_test.dart test/sprintf_text_test.dart
rtk dart test -p node -c dart2wasm -x no-dart2wasm test/text_format_test.dart test/sprintf_text_test.dart
```

Expected: analyze clean; все новые и существующие `c`-проверки PASS, включая
typed context, суррогаты, astral-width и обе исходные числовые ветви.

- [x] **Step 3: Скомпилировать after-сборку тем же компилятором**

Run:

```sh
rtk dart compile js -O4 --no-minify --packages=benchmark/suite/.dart_tool/package_config.json /private/tmp/format-c-benchmark.dart -o /private/tmp/format-c-after.js
```

Expected: компиляция успешна; `/private/tmp/format-c-before.js` всё ещё имеет
время создания до правки `lib/src/value_formatter.dart`.

- [x] **Step 4: Выполнить три чередующихся A/B-пары обычного `int`**

Run в указанном порядке, чтобы соседние процессы не давали одному варианту
постоянное преимущество очередности:

```sh
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js brace-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js brace-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js printf-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js printf-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js brace-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js brace-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js printf-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js printf-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js brace-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js brace-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js printf-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js printf-int
```

Expected: во всех трёх парах after быстрее для `brace-int` и не медленнее для
`printf-int`; лучший after-минимум каждого обычного `int` улучшен не менее чем
на 10% относительно лучшего before-минимума.

- [x] **Step 5: Проверить Format 1.6 и настоящий `BigInt`**

Run в прямом, затем обратном порядке:

```sh
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js format16
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js brace-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js brace-bigint
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js brace-bigint
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js printf-bigint
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js printf-bigint
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js printf-bigint
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js printf-bigint
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js brace-bigint
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-before.js brace-bigint
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js brace-int
rtk node /private/tmp/run-format-c-benchmark.cjs /private/tmp/format-c-after.js format16
```

Expected: after `brace-int` заметно быстрее Format 1.6; `BigInt` сохраняет
результат и не показывает воспроизводимого замедления. Записать все минимумы,
отношения before/after и checksum в design и handoff, не усредняя их с
quick-матрицей.

- [x] **Step 6: Принять или отклонить performance-правку**

Если каждый критерий Global Constraints выполнен, отметить локальный A/B как
GREEN и продолжить. Если хотя бы один критерий не выполнен, через
`apply_patch` вернуть только `_unicodeScalar` к состоянию до Task 2, повторить
точечные тесты и документировать доказанный отрицательный результат без слов
об ускорении.

### Task 3: Завершить документацию, полный прогон и атомарный коммит

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/backlog.md`
- Modify: `docs/handoff.md`
- Modify: `docs/records/2026-08-14[5]-javascript-character-fast-path-design.md`
- Modify: `docs/records/2026-08-14[6]-javascript-character-fast-path-plan.md`
- Commit: файлы Tasks 1–3 одним коммитом.

**Interfaces:**
- Consumes: локальный performance GREEN и зелёные точечные тесты Task 2.
- Produces: актуальные changelog/handoff, пустой исполненный backlog и один
  проверенный коммит в `main`.

- [x] **Step 1: Записать результат без изменения gate baseline**

В `CHANGELOG.md` перед `## 3.0.0` добавить `## Unreleased` и один английский
пункт: обычный `int` для `{:c}` и `%c` больше не конвертируется в `BigInt`;
указать измеренные dart2js before/after для обоих диалектов и сравнение
Format 3 `{:c}` с Format 1.6.

В design сменить статус на «исполнен 2026-08-14» и записать точную методику,
таблицу всех A/B-минимумов и вывод GREEN. В этом плане отметить Tasks 1–2 и
выполненные шаги Task 3. Матрицу и `benchmark/results/gate-baseline.json` не
менять.

- [x] **Step 2: Вычеркнуть исполненный backlog и обновить handoff**

Удалить из `docs/backlog.md` только строку:

```markdown
- Посмотреть медленный "c" на js.
```

Сохранить заголовок и объяснение владельца. В `docs/handoff.md` обновить
строку статуса и состояние, перенести `c` в сделанное с точными A/B-цифрами и
убрать его из `## Что открыто`. Прямо записать, что `docs/backlog.md` пуст и
следующего дела владельца нет; предложение про эталоны по процессорам оставить
в разделе «Ждёт решения владельца», не превращая его в активную задачу и не
переписывая реестры вердиктов.

- [x] **Step 3: Выполнить полный обязательный набор с начала**

Run from the repository root:

```sh
rtk dart format .
rtk dart analyze --fatal-infos lib test example tool
rtk dart test
rtk dart test -p node
rtk dart test -p node -c dart2wasm -x no-dart2wasm
rtk dart test benchmark/test tool/test
(cd packages/format_intl && rtk dart test)
rtk dart run tool/verify_package_archive.dart
rtk dart run tool/verify_generated_artifacts.dart
rtk dart test --coverage=.coverage
rtk dart run coverage:format_coverage --lcov --in=.coverage --out=coverage/lcov.info --report-on=lib --packages=.dart_tool/package_config.json
rtk dart run tool/check_coverage.dart --lcov=coverage/lcov.info
(cd benchmark/suite && rtk dart pub get && rtk dart test)
(cd benchmark/suite && rtk dart run tool/run.dart --runtime=vm)
(cd benchmark/suite && rtk dart run tool/run.dart --runtime=js)
(cd benchmark/suite && rtk dart run tool/run.dart --runtime=wasm)
```

Expected: format/analyze clean; все VM, Node и Wasm-тесты PASS; auxiliary и
`format_intl` PASS; архив самостоятелен; генераторы совпадают; покрытие не ниже
94%; suite PASS; три quick-матрицы завершаются с exit code 0. Зафиксировать в
handoff фактические количества тестов, покрытие и длительности матриц.

Если после последней правки любая проверка падает, применить
`superpowers:systematic-debugging`, устранить коренную причину и повторить весь
этот список с начала.

- [ ] **Step 4: Проверить границы diff и staged-состава**

Run:

```sh
rtk git diff --check
rtk git diff --stat
rtk git diff -- benchmark/results/gate-baseline.json
rtk git status --short
rtk git add -A ':(exclude)docs/backlog.md'
rtk git add docs/backlog.md
rtk git diff --cached --check
rtk git diff --cached --stat
rtk git diff --cached -- docs/backlog.md
```

Expected: изменены только перечисленные файлы; gate baseline отсутствует в
diff; staged backlog удаляет ровно исполненную строку; временный harness и обе
JS-сборки находятся только в `/private/tmp`.

- [ ] **Step 5: Создать и опубликовать атомарный коммит**

Run:

```sh
rtk git commit -m 'perf: ускорить c под JavaScript'
rtk git push origin main
rtk git rev-parse HEAD
rtk git status --short --branch
```

Expected: commit создан в `main`, push успешен, рабочее дерево чистое и
синхронизировано с `origin/main`.

- [ ] **Step 6: Проверить push-CI точной ревизии**

Run:

```sh
rtk gh run list --workflow=ci.yaml --branch=main --event=push --limit=5
```

Выбрать run, чей `headSha` равен SHA из Step 5, дождаться завершения и
проверить jobs `checks (3.7.2)`, `checks (stable)`, `benchmark-suite`,
`generated-artifacts` и `coverage`. Expected: все пять success;
`performance-gate` на обычном push skipped. После этого сменить статус design
и этого плана на исполненный только последующим документальным коммитом, если
точный SHA/CI невозможно было правдиво записать до исходного коммита.
