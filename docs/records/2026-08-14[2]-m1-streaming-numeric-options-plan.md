# M1 Streaming Numeric Options Implementation Plan

Статус: исполнен 2026-08-14. План выполнялся через
`superpowers:executing-plans`. Архитектура реализации отличается от шага 2:
`lib/src/format_spec.dart` сохраняет материализованный путь до длины 256 и
использует потоковый курсор только выше порога; полностью потоковый вариант не
прошёл performance-check. Паритет двух путей проверяет production debug-seam,
вопреки первоначальному запрету задачи 2, шага 5. Итоговые замеры и
обоснование — в
`2026-08-14[1]-m1-streaming-numeric-options-design.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Убрать O(N)-материализацию единиц спецификации и цифр числового
item-key, сохранив язык, диагностику и холодную производительность.

**Architecture:** Общий brace-парсер спецификации переходит с eager
`List<String>` на последовательный курсор с lookahead не более двух единиц.
Числовой item-key сканируется прямо в диапазоне исходного шаблона и хранит не
более двадцати значащих цифр; строковый ключ по-прежнему становится
подстрокой, которую обязан удержать AST.

**Tech Stack:** Dart 3.12.2, `package:characters`, `package:test`, dart2js
`-O4 --no-minify`, dart2wasm, существующие benchmark runner и проверки
репозитория.

## Global Constraints

- Документы — по-русски, код и комментарии в коде — по-английски.
- Ведущие нули остаются допустимыми; новый предел длины токена не вводится.
- Классы, тексты и `FormatExceptionContext` ошибок не меняются.
- Fast path обычных ASCII-спецификаций и публичный API не меняются.
- `benchmark/baselines/**` не трогать.
- Нет локального performance GREEN — нет коммита.
- Из-за проектного правила полного прогона перед каждым коммитом промежуточных
  коммитов нет: один финальный коммит после всех задач и всех проверок.
- Чужие изменения не включать; `docs/backlog.md` не индексировать.

---

### Task 1: Потоковый числовой item-key

**Files:**
- Modify: `lib/src/brace_parser.dart:332-451`
- Test: `test/parser_test.dart`
- Create: `test/parser_memory_test.dart`
- Create: `test/fixtures/parser_memory_probe.dart`

**Interfaces:**
- Consumes: `_readScalarFrom`, `pythonDecimalDigitValue`,
  `_maximumIndexDigits`, `_decimalIndex`.
- Produces: static
  `_BraceParser._decimalDigits(String text, int start, int end) -> List<int>?`.

- [ ] **Step 1: Написать красный тест фактической памяти**

Создать `test/fixtures/parser_memory_probe.dart`. Зонд строит пять миллионов
нулей и шаблон до baseline, затем вызывает `format`, а в JSON печатает
`ProcessInfo.maxRss - beforeMaxRss` и исход. Для `item` значение — список из
одного элемента; для `width` — целое.

Создать VM-only `test/parser_memory_test.dart`, который запускает зонд через
`Platform.resolvedExecutable` и настоящий `.dart_tool/package_config.json`.
Первый тест покрывает item-key:

```dart
test('a numeric item key does not amplify its source into a digit list', () async {
  final result = await _probe('item');
  expect(result.outcome, 'value');
  expect(result.maxRssDelta, lessThan(20 * 1024 * 1024));
});
```

Предел 20 МиБ стоит между измеренными 114 МБ текущего пути и контролем root
index (0 МБ); он проверяет ресурсный контракт, а не время или частную форму
реализации.

В `test/parser_test.dart` добавить поведенческий контроль:

```dart
test('long zero item indexes keep their value without retaining the run', () {
  final zeros = '0' * 5000;
  expect(format('{0[$zeros]}', ['value']), 'value');
  expect(
    () => format('{0[${'9' * 5000}]}', ['value']),
    throwsA(isA<InvalidFormatException>()),
  );
});
```

- [ ] **Step 2: Подтвердить красный тест**

Run:

```sh
rtk dart test test/parser_test.dart test/parser_memory_test.dart
```

Expected: memory test FAIL — `maxRssDelta` выше 20 МиБ; поведенческий тест
PASS, подтверждая, что оптимизация не имеет права отвергнуть длинные нули.

- [ ] **Step 3: Реализовать ограниченный скан диапазона**

Изменить `_parseItem`: запомнить `end = _index`, проверить числовой диапазон
до `substring`, а строку создавать только при `decimalDigits == null`:

```dart
final end = _index;
_index++;
final decimalDigits = _decimalDigits(template, start, end);
if (decimalDigits != null) {
  return _IntegerItemAccess(_decimalIndex(decimalDigits, start, end));
}
return _StringItemAccess(template.substring(start, end));
```

Новая static `_BraceParser._decimalDigits` повторяет политику уже исправленной
`_readDecimalDigits`: отбрасывает ведущие нули, хранит максимум
`_maximumIndexDigits + 1`, но дочитывает весь диапазон и возвращает `null` при
первой нецифре.

- [ ] **Step 4: Подтвердить зелёный целевой тест и анализ**

Run:

```sh
rtk dart test test/parser_test.dart test/parser_memory_test.dart
rtk dart analyze --fatal-infos lib test
```

Expected: оба выхода 0.

---

### Task 2: Ленивый курсор общего парсера спецификации

**Files:**
- Modify: `lib/src/engine.dart:20-35`
- Modify: `lib/src/format_spec.dart:57-240,470-515`
- Test: `test/format_spec_fast_path_test.dart`
- Test: `test/parser_memory_test.dart`

**Interfaces:**
- Consumes: `TextUnit`, `String.runes`, `String.characters`, существующие
  предикаты `_isAlign`, `_isAsciiDigit`, `_isCustomNameContinue`.
- Produces: `_FormatSpecCursor` и перевод `_parseFormatSpecGeneral` на него.

- [ ] **Step 1: Добавить красный memory-case width и контроль поведения**

В `test/parser_memory_test.dart` добавить второй вызов того же реального
зонда:

```dart
test('a numeric width does not amplify its source into a unit list', () async {
  final result = await _probe('width');
  expect(result.outcome, '1');
  expect(result.maxRssDelta, lessThan(20 * 1024 * 1024));
});
```

В `test/format_spec_fast_path_test.dart` добавить:

```dart
test('long numeric options preserve zero and bounded failures', () {
  final zeros = '0' * 5000;
  final nines = '9' * 5000;
  expect(format('{:${zeros}d}', 1), '1');
  expect(format('{:.${zeros}s}', 'value'), '');
  expect(
    () => format('{:${nines}d}', 1),
    throwsA(isA<InvalidSpecifierException>()),
  );
  expect(
    () => format('{:.${nines}g}', 1.0),
    throwsA(isA<InvalidSpecifierException>()),
  );
});
```

- [ ] **Step 2: Подтвердить красный тест**

Run:

```sh
rtk dart test test/format_spec_fast_path_test.dart test/parser_memory_test.dart
```

Expected: width memory test FAIL — текущий путь даёт около 29 МБ сверх
baseline; поведенческий тест PASS.

- [ ] **Step 3: Добавить ленивый источник единиц**

Добавить `package:characters/characters.dart` в `engine.dart`. В
`format_spec.dart` заменить `_specificationUnits` на iterable, который
сохраняет прежний ASCII shortcut и CRLF-исключение:

```dart
Iterable<String> _formatSpecUnits(String source, TextUnit textUnit) sync* {
  var ascii = true;
  for (var index = 0; index < source.length; index++) {
    final unit = source.codeUnitAt(index);
    if (unit >= 0x80 || unit == 0x0d) {
      ascii = false;
      break;
    }
  }
  if (ascii) {
    for (var index = 0; index < source.length; index++) {
      yield source[index];
    }
    return;
  }
  switch (textUnit) {
    case TextUnit.unicodeScalars:
      yield* source.runes.map(String.fromCharCode);
    case TextUnit.graphemeClusters:
      yield* source.characters;
  }
}
```

- [ ] **Step 4: Добавить курсор с lookahead ≤2**

Курсор хранит `Iterator<String>`, список `_lookahead` и методы
`peek([offset])`, `take()`, `takeRest()`, `isDone`. `peek` наполняет буфер
только до запрошенного offset; парсер никогда не просит больше 1:

```dart
final class _FormatSpecCursor {
  final Iterator<String> _units;
  final List<String> _lookahead = [];

  _FormatSpecCursor(String source, TextUnit textUnit)
    : _units = _formatSpecUnits(source, textUnit).iterator;

  String? peek([int offset = 0]) {
    assert(offset <= 1);
    while (_lookahead.length <= offset && _units.moveNext()) {
      _lookahead.add(_units.current);
    }
    return offset < _lookahead.length ? _lookahead[offset] : null;
  }

  String take() => _lookahead.removeAt(0);
}
```

`take()` сначала гарантирует наличие через `peek()`. `takeRest()` пишет
текущий и последующие элементы в `StringBuffer`; это вызывается только для
custom payload, который итоговый `_FormatSpec` обязан удержать.

- [ ] **Step 5: Перевести общий парсер и `_readDecimal` на курсор**

Убрать `units`, `index`, `at` и локальный `take`; заменить проверки на
`cursor.peek()`, `cursor.peek(1)`, `cursor.take()`, `cursor.isDone`.
`_readDecimal` получает только курсор:

```dart
int _readDecimal(_FormatSpecCursor cursor) {
  var value = 0;
  while (cursor.peek() case final unit? when _isAsciiDigit(unit)) {
    if (value <= _maximumSafeFormatOption) {
      value = value * 10 + (unit.codeUnitAt(0) - 0x30);
    }
    cursor.take();
  }
  return value > _maximumSafeFormatOption
      ? _maximumSafeFormatOption + 1
      : value;
}
```

Production `_parseFormatSpecGeneral` создаёт курсор и разбирает его напрямую;
тестовых методов в production-код не добавлять.

- [ ] **Step 6: Подтвердить целевые тесты и фаззер**

Run:

```sh
rtk dart test test/format_spec_fast_path_test.dart test/parser_test.dart \
  test/parser_memory_test.dart test/template_ir_fuzz_test.dart
rtk dart analyze --fatal-infos lib test
```

Expected: все тесты и анализ зелёные.

---

### Task 3: Кроссрантаймовая и измерительная проверка

**Files:**
- Create temporarily: `/private/tmp/format_m1_probe.dart`
- Create temporarily: `/private/tmp/format_m1_benchmark.dart`
- No committed source files.

**Interfaces:**
- Consumes: публичные `format`, `Format`, `TextUnit`, внутренние сеттеры кэша
  через `package:format/src/engine.dart`.
- Produces: таблицы before/after по RSS и минимумам времени для записи в
  review и handoff.

- [ ] **Step 1: Прогнать целевые тесты на трёх рантаймах**

Run:

```sh
rtk dart test test/format_spec_fast_path_test.dart test/parser_test.dart
rtk dart test -p node test/format_spec_fast_path_test.dart test/parser_test.dart
rtk dart test -p node -c dart2wasm \
  test/format_spec_fast_path_test.dart test/parser_test.dart
```

Expected: все три выхода 0.

- [ ] **Step 2: Повторить зонд памяти**

Запустить существующую форму зонда отдельным процессом для width, precision,
root index и item index на 100 000, 1 000 000 и 5 000 000 нулей и девяток.
Expected: width/precision и item больше не дают дельту, линейную по списку;
5 млн должны быть одного порядка с root index, а успешные исходы и классы
ошибок должны совпасть с baseline из design.

- [ ] **Step 3: Снять baseline времени с чистого кода и candidate после правки**

`/private/tmp/format_m1_benchmark.dart` отключает кэш и меряет по одному
сценарию на процесс: `10,d`, `.2g`, Unicode fill, CRLF fill, custom payload,
числовой и строковый item-key. Каждый процесс делает 3 прогрева и 25–40
записанных раундов, выводит минимум наносекунд на операцию и checksum.

Baseline берётся из `git show HEAD:lib/...` во временной копии либо
чередующимся `git stash push lib/` → baseline → `git stash pop` → candidate;
документы не прячутся. Нельзя одновременно запускать два варианта.

- [ ] **Step 4: Прогнать VM A/B**

Run each scenario in alternating baseline/candidate order with the pinned Dart
3.12.2 executable. Expected: нет воспроизводимой регрессии; вывод совпадает,
минимумы повторяются минимум двумя парами.

- [ ] **Step 5: Прогнать dart2js A/B**

Compile:

```sh
rtk dart compile js -O4 --no-minify -Donly=<scenario> \
  /private/tmp/format_m1_benchmark.dart -o /private/tmp/m1-<variant>.js
```

Run each scenario via Node in alternating order. Expected: нет
воспроизводимой регрессии; если она есть, правка не коммитится и дизайн
пересматривается.

---

### Task 4: Реестры, полная проверка и финальный коммит

**Files:**
- Modify: `docs/records/2026-08-13[2]-project-review-codex.md`
- Modify: `docs/records/2026-08-14[1]-m1-streaming-numeric-options-design.md`
- Modify: `docs/handoff.md`
- Verify only: `docs/backlog.md`

**Interfaces:**
- Consumes: фактические тесты и таблицы замеров Task 3.
- Produces: окончательный вердикт M1 и актуальную точку входа следующей сессии.

- [ ] **Step 1: Записать окончательный вердикт M1**

В review явно разделить три пути: root index был закрыт ранее; item index и
width/precision закрыты этой правкой. Указать before/after RSS, VM/dart2js A/B,
имена тестов и способ проверки поломкой. Статус design сменить на «исполнен».

- [ ] **Step 2: Обновить handoff**

Вернуть публикацию 3.0.0 на первое место только после зелёных измерений;
обновить дату, состояние, сделанное и открытое. Не менять `docs/backlog.md`:
пункт туда владелец не добавлял.

- [ ] **Step 3: Прогнать форматирование и полный анализ**

Run все команды раздела `## Как проверить всё` из `docs/handoff.md`, начиная
с:

```sh
rtk dart format .
rtk dart analyze --fatal-infos lib test example tool
```

Затем VM, node, dart2wasm, benchmark/tool, `format_intl`, архив, генераторы,
покрытие, тесты и три runtime-прогона benchmark suite. Expected: каждый выход
0, покрытие не ниже 94 %.

- [ ] **Step 4: Проверить рабочее дерево и индексировать только свою работу**

Run:

```sh
rtk git diff --check
rtk git status --short
rtk git diff -- docs/backlog.md
rtk git add -A ':(exclude)docs/backlog.md'
rtk git diff --cached --check
```

Expected: в индексе только файлы M1, design, plan, review и handoff;
`docs/backlog.md` отсутствует.

- [ ] **Step 5: Финальный коммит прямо в main**

```sh
rtk git commit -m "fix: разбирать числовые части спецификации потоково"
```

После коммита проверить `rtk git status --short --branch` и сообщить SHA.
