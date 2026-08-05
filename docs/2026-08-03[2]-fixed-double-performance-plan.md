# Fixed Double Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ускорить Python-совместимый формат `f` для обычных `double`, сохранив точный fallback и закрепив крайние значения тестами.

**Architecture:** Общий `_formatFixed` сначала пытается получить безопасный результат через `toStringAsFixed`, а затем возвращается к существующему `Binary64`/`BigInt`-округлению. Безопасность fast path определяется точностью, диапазоном значения и масштабированным half-even случаем. Brace и printf используют один и тот же helper.

**Tech Stack:** Dart 3.12, `package:test`, встроенный `benchmark_harness`, release benchmark JIT/AOT.

## Global Constraints

- Спецификации и планы пишутся по-русски; имена API и команды сохраняют исходное написание.
- Python-совместимое round-half-even и все существующие результаты менять нельзя.
- Fast path разрешён только для точности `0…20`, `abs(value) < 1e21`, масштабированного значения меньше `2^52` и безопасного half-even случая.
- Значения вне fast path обязаны использовать существующее точное округление.
- Замороженные Format 2 и sprintf7 baseline не изменяются.
- Performance gate для каждого нового ключевого `f`-сценария: Format 3 / Format 2 не больше `1.05` в обоих повторных JIT- и AOT-прогонах.

---

### Task 1: Крайние значения integer и double

**Files:**
- Modify: `test/sprintf_integer_test.dart`
- Modify: `test/double_format_test.dart`

**Interfaces:**
- Consumes: публичные `format`, `sprintf` и `BigInt`.
- Produces: литеральные регрессионные ожидания для границ и half-even.

- [x] **Step 1: Добавить integer-регрессию**

Добавить тест, который проверяет `%d` для `-9223372036854775808`,
`9223372036854775807`, нуля и `BigInt` на единицу за обеими границами.
Ожидаемые строки задать литералами; минимальный `int` обязан иметь ровно один
минус.

- [x] **Step 2: Добавить double-матрицу**

Добавить отдельный тест публичного `format` для `2.5`, `3.5`, `1.25`, `1.75`,
`0.0`, `-0.0`, `5e-324`, `1.7976931348623157e308`, точностей 20 и 21.
Ожидания не вычислять кодом пакета.

- [x] **Step 3: Запустить целевые тесты**

Run: `rtk dart test test/sprintf_integer_test.dart test/double_format_test.dart`
Expected: PASS, поскольку это характеристические тесты существующего контракта;
они защищают следующую оптимизацию от изменения поведения.

- [x] **Step 4: Закоммитить тестовую матрицу**

```sh
rtk git add test/sprintf_integer_test.dart test/double_format_test.dart
rtk git commit -m "test: cover numeric edge values"
```

### Task 2: Ключевой benchmark большого fixed double

**Files:**
- Modify: `test/benchmark_scenarios_test.dart`
- Modify: `benchmark/scenarios.dart`

**Interfaces:**
- Consumes: `benchmarkScenarios` и frozen Format 2 comparator.
- Produces: `brace.double.fixed_large.hot`, ключевой performance-сценарий.

- [x] **Step 1: Написать падающий тест сценария**

Тест находит `brace.double.fixed_large.hot` и проверяет template `{:.2f}`,
значение `12345678901234.568`, ожидаемую строку `12345678901234.57`,
`comparisonKind == performance` и `keyScenario == true`.

- [x] **Step 2: Подтвердить RED**

Run: `rtk dart test test/benchmark_scenarios_test.dart`
Expected: FAIL, потому что сценарий ещё отсутствует.

- [x] **Step 3: Добавить минимальный benchmark-сценарий**

Добавить `_braceComparable('brace.double.fixed_large', ...)` рядом с
`brace.double.fixed`, не меняя существующие идентификаторы и thresholds.

- [x] **Step 4: Подтвердить GREEN**

Run: `rtk dart test test/benchmark_scenarios_test.dart`
Expected: PASS.

- [x] **Step 5: Зафиксировать benchmark-контракт**

```sh
rtk git add benchmark/scenarios.dart test/benchmark_scenarios_test.dart
rtk git commit -m "test: benchmark large fixed doubles"
```

### Task 3: Безопасный fast path fixed double

**Files:**
- Modify: `lib/src/number_format.dart`
- Test: `test/double_format_test.dart`
- Test: `test/sprintf_double_test.dart`

**Interfaces:**
- Consumes: `_AsciiFloat`, `Binary64`, исходный `double`, precision и alternate.
- Produces: `_formatFixed(double source, Binary64 binary, int precision, bool alternate)` и приватный nullable fast-path helper.

- [x] **Step 1: Зафиксировать performance RED**

Выполнить два JIT и два AOT отчёта на чистой ревизии до изменения. Оба
повторных результата `brace.double.fixed.hot` и
`brace.double.fixed_large.hot` должны превышать лимит `1.05` хотя бы для
одного сценария; сохранить JSON в `/private/tmp`.

- [x] **Step 2: Реализовать минимальный fast path**

Добавить таблицу `10^0…10^20`, helper с ограничениями из Global Constraints и
передать исходный `double` во все вызовы `_formatFixed`. Для небезопасного
half-even, большой величины и высокой точности вернуть `null` и вызвать
существующий точный код.

- [x] **Step 3: Запустить целевые корректностные тесты**

Run: `rtk dart test test/double_format_test.dart test/sprintf_double_test.dart test/python_compatibility_test.dart`
Expected: PASS.

- [x] **Step 4: Запустить полный набор тестов и анализ**

Run: `rtk dart test`
Expected: PASS.

Run: `rtk dart analyze`
Expected: exit 0 без новых diagnostics.

- [x] **Step 5: Зафиксировать реализацию**

```sh
rtk git add lib/src/number_format.dart
rtk git commit -m "perf: accelerate safe fixed doubles"
```

### Task 4: Повторная проверка производительности и релиза

**Files:**
- Verify: `benchmark/runner.dart`
- Verify: `example/bin/benchmark.dart`

**Interfaces:**
- Consumes: чистую итоговую 40-символьную Git revision.
- Produces: два JIT и два AOT JSON-отчёта с воспроизводимыми ratios.

- [x] **Step 1: Запустить два gateable JIT-отчёта**

Использовать `-Dformat.benchmark.sourceRevision=<40hex>`, `--run=1` и
`--run=2`, сохранив отчёты в `/private/tmp/fixed-double-jit-*.json`.

- [x] **Step 2: Запустить два gateable AOT-отчёта**

Скомпилировать один executable с той же revision и выполнить `--run=1` и
`--run=2`, сохранив `/private/tmp/fixed-double-aot-*.json`.

- [x] **Step 3: Проверить ratios**

Через `jq` проверить `gateable == true`, совпадение `sourceRevision` и ratio
не больше `1.05` для `brace.double.fixed.hot` и
`brace.double.fixed_large.hot` во всех четырёх отчётах.

- [x] **Step 4: Запустить пользовательский benchmark**

Run: `cd example && rtk dart run bin/benchmark.dart`
Expected: оба `{:.2f}` значения Format 3 не медленнее Format 2 в устойчивом
измерении; известное расхождение замороженного sprintf7 на minInt допускается.

- [x] **Step 5: Финальная проверка**

Run: `rtk dart test`

Run: `rtk dart test` в `example/` и `packages/format_intl/`.

Run: `rtk dart analyze` в корне и `packages/format_intl/`.

Run: `rtk dart pub publish --dry-run` в корне и `packages/format_intl/`.

Expected: тесты проходят, анализ не содержит новых ошибок, оба dry-run имеют
0 warnings, рабочее дерево чистое после итогового коммита.
