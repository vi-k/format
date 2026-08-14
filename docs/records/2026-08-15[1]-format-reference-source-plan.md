# Единый справочник форматов — Implementation Plan

Статус: утверждён владельцем 2026-08-15; выбран вариант 1 — исполнение через
`superpowers:subagent-driven-development`. Реализация ещё не начиналась.

> **Для агентных исполнителей:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Цель:** Построить из одного типизированного каталога полный английский и
русский справочник brace/printf, исполняемую conformance-проекцию и проверку
устаревших generated artifacts.

**Архитектура:** Редактируемая семантика живёт только в
`tool/src/format_reference_contract.dart`; production-парсеры остаются
специализированными. Генератор строит два Markdown-блока и Dart-проекцию для
архивных тестов, а непубличные seams сверяют каталог с фактическими конечными
множествами parser-кода.

**Технологии:** Dart 3.7.2+, `package:test`, const-модели Dart, Markdown,
существующие публичные `format`/`formatWith`/`sprintf`/`vsprintf`, внутренний
`package:format/src/engine.dart` только для inventory seams.

**Режим исполнения:** владелец выбрал вариант 1 —
`superpowers:subagent-driven-development`. После рестарта не запрашивать выбор
повторно: подготовить SDD workspace/ledger, выполнить preflight всего плана и
запустить implementer для Task 1. На момент записи реализация не начиналась.

## Глобальные ограничения

- Не менять синтаксис, результаты форматирования, публичные экспорты, версию
  `3.0.0`, зависимости или performance baseline.
- Единственный редактируемый источник типов, опций, правил, пределов,
  переводов и conformance outcomes —
  `tool/src/format_reference_contract.dart`.
- `/tool` исключён из pub-архива, поэтому корневой conformance-тест читает
  сгенерированный `test/support/format_reference_cases.dart`, а не импортирует
  каталог напрямую.
- Генерация документации никогда не вычисляет expected output через formatter
  engine: ожидаемая строка или точный класс ошибки записаны в каталоге.
- `README.md` остаётся нормативным prose-источником; `README.ru.md` — переводом
  тех же semantic rows. Ручные deep-dive разделы не генерируются.
- Код, имена и комментарии в Dart — по-английски; проектные документы —
  по-русски.
- Работать прямо в `main`, без PR. Все shell-команды выполнять через `rtk`.
- До финального выполнения не добавлять `docs/backlog.md` в промежуточные
  коммиты. После выполнения удалить второй пункт из рабочей копии; поскольку он
  пришёл незакоммиченным поверх пустого backlog, проверить, что итоговый diff
  файла исчез, и всё равно выполнить отдельный `rtk git add docs/backlog.md`.
- Работа не заявлена как ускорение. Отдельный performance A/B не нужен; если
  штатные матрицы покажут регрессию после извлечения printf mask-функции,
  коммит остановить и сначала устранить причину.

### Полный gate перед каждым implementation-коммитом

Каждый шаг `Commit` ниже предваряется всем списком; targeted-тесты внутри задачи
его не заменяют. Все команды должны завершиться с кодом 0, generated artifacts
должны совпасть, покрытие должно быть не ниже 94%, а quick-матрицы — GREEN.

```sh
rtk dart format .
rtk dart analyze --fatal-infos lib test example tool
rtk dart test
rtk dart test -p node
rtk dart test -p node -c dart2wasm -x no-dart2wasm
rtk dart test benchmark/test tool/test
rtk dart test                         # из packages/format_intl
rtk dart run tool/verify_package_archive.dart
rtk dart run tool/verify_generated_artifacts.dart
rtk dart test --coverage=.coverage
rtk dart run coverage:format_coverage --lcov --in=.coverage \
  --out=coverage/lcov.info --report-on=lib \
  --packages=.dart_tool/package_config.json
rtk dart run tool/check_coverage.dart --lcov=coverage/lcov.info
rtk dart pub get                      # из benchmark/suite
rtk dart test                         # из benchmark/suite
rtk dart run tool/run.dart --runtime=vm    # из benchmark/suite
rtk dart run tool/run.dart --runtime=js    # из benchmark/suite
rtk dart run tool/run.dart --runtime=wasm  # из benchmark/suite
```

После gate выполнить `rtk git diff --check`, добавить только названные файлы,
проверить `rtk git diff --cached --check` и staged diff целиком.

---

## Карта файлов

- `tool/src/format_reference_model.dart` — типы каталога и ожидаемых исходов;
  логики рендеринга здесь нет.
- `tool/src/format_reference_contract.dart` — один const-каталог со всеми
  semantic rows, переводами и conformance-вызовами.
- `tool/src/format_reference_validator.dart` — структурная целостность,
  evidence, ссылки, уникальность и полнота локализаций.
- `tool/src/format_reference_renderer.dart` — чистый Markdown/Dart rendering,
  markers и построение всех новых содержимых в памяти.
- `tool/src/format_reference_generator.dart` — файловый `--write`/`--check`
  слой, пригодный для вызова из тестов и общего verifier.
- `tool/generate_format_reference.dart` — только разбор CLI и exit code.
- `tool/test/format_reference_contract_test.dart` — красные пути validator.
- `tool/test/format_reference_generator_test.dart` — scratch-файлы, markers,
  детерминизм и гарантия «ошибка до записи».
- `test/support/format_reference_cases.dart` — generated Dart-проекция,
  которая остаётся внутри pub-архива.
- `test/format_reference_contract_test.dart` — выполнение проекции через
  публичный facade и сверка parser inventory через внутренние seams.
- `lib/src/format_spec.dart` — read-only seam множества brace types.
- `lib/src/printf_parser.dart` — единая функция допустимого flag mask и
  read-only seams printf types/flags.
- `README.md`, `README.ru.md` — generated-блоки плюс ручные ссылки вместо
  прежних копий матриц.
- `tool/verify_generated_artifacts.dart` — общий non-writing gate.
- `docs/records/2026-08-14[9]-format-reference-source-design.md` и
  `docs/handoff.md` — утверждённый статус, ход реализации и результаты gate.

---

### Задача 1: Типизированный каталог и его validator

**Файлы:**
- Создать: `tool/src/format_reference_model.dart`
- Создать: `tool/src/format_reference_contract.dart`
- Создать: `tool/src/format_reference_validator.dart`
- Создать: `tool/test/format_reference_contract_test.dart`
- Изменить: `docs/records/2026-08-14[9]-format-reference-source-design.md`
- Изменить: `docs/handoff.md`
- Добавить в первый implementation-коммит:
  `docs/records/2026-08-15[1]-format-reference-source-plan.md`

**Интерфейсы:**
- Потребляет: утверждённые сущности `DialectContract`, `GrammarRule`,
  `OptionContract`, `TypeContract`, `ConformanceCase`, `LocalizedText`.
- Производит: `const formatReferenceContract` и
  `List<String> validateFormatReferenceContract(FormatReferenceContract)`;
  последующие задачи не переопределяют семантические данные.

- [ ] **Шаг 1: Написать падающие тесты структурной целостности**

  Тест должен сначала импортировать ещё не существующие model, contract и
  validator, затем закрепить успешный полный каталог и каждый красный путь:

  ```dart
  test('the complete reference contract is structurally valid', () {
    expect(validateFormatReferenceContract(formatReferenceContract), isEmpty);
  });

  test('duplicate semantic ids are rejected', () {
    final contract = fixtureContract(
      rules: const [
        GrammarRule(
          id: 'same',
          syntax: 'a',
          text: LocalizedText('a', 'а'),
        ),
        GrammarRule(
          id: 'same',
          syntax: 'b',
          text: LocalizedText('b', 'б'),
        ),
      ],
    );
    expect(
      validateFormatReferenceContract(contract),
      contains(contains('duplicate semantic id: same')),
    );
  });

  FormatReferenceContract fixtureContract({
    List<GrammarRule> rules = const [],
  }) => FormatReferenceContract(
    brace: DialectContract(
      dialect: ReferenceDialect.brace,
      title: const LocalizedText('Brace', 'Фигурный'),
      grammar: rules,
      options: const [],
      types: const [],
    ),
    printf: const DialectContract(
      dialect: ReferenceDialect.printf,
      title: LocalizedText('Printf', 'Printf'),
      grammar: [],
      options: [],
      types: [],
    ),
    limits: const [],
    errors: const [],
    cases: const [],
  );
  ```

  В той же таблице fixture-мутаций закрепить точные диагностики:

  | мутация | обязательный фрагмент issue |
  |---|---|
  | пустой `en` или `ru` | `missing translation` |
  | повторный type token или option token на одной позиции | `duplicate token` |
  | неизвестный option id в type | `unknown option` |
  | повторный conformance id | `duplicate conformance id` |
  | success-case, указывающий на error outcome | `success evidence is not output` |
  | failure-case, указывающий на output | `failure evidence is not error` |
  | правило с `requiresSuccessCase: true` без успеха | `missing success evidence` |
  | правило с `requiresFailureCase: true` без отказа | `missing failure evidence` |
  | ссылка на отсутствующий case id | `unknown conformance case` |

  Неизвестная value category не получает искусственного runtime-теста:
  ссылка хранится как `ValueCategory`, поэтому такое состояние отвергает
  analyzer ещё до validator. Строковыми остаются только option/case ids, для
  которых validator действительно нужен.

- [ ] **Шаг 2: Запустить тест и увидеть ожидаемый compile failure**

  Run: `rtk dart test tool/test/format_reference_contract_test.dart`

  Expected: FAIL на отсутствующем
  `tool/src/format_reference_model.dart`; тест не должен проходить за счёт
  существующих runtime-таблиц.

- [ ] **Шаг 3: Создать точную модель каталога**

  В `format_reference_model.dart` определить неизменяемые const-типы с этими
  именами и полями:

  ```dart
  enum ReferenceLanguage { english, russian }
  enum ReferenceDialect { brace, printf }
  enum ValueCategory {
    any,
    text,
    integer,
    nonNegativeInteger,
    floating,
    custom,
    none,
  }
  enum PublicCall {
    format,
    formatWith,
    sprintf,
    vsprintf,
    configuredFormat,
  }
  enum FormattingErrorKind {
    invalidFormat,
    invalidSpecifier,
    missingArgument,
    unsupportedConversion,
    unsupportedValue,
  }

  final class LocalizedText {
    final String english;
    final String russian;
    const LocalizedText(this.english, this.russian);
    String inLanguage(ReferenceLanguage language) => switch (language) {
      ReferenceLanguage.english => english,
      ReferenceLanguage.russian => russian,
    };
  }

  final class RuleEvidence {
    final List<String> successCaseIds;
    final List<String> failureCaseIds;
    final bool requiresSuccessCase;
    final bool requiresFailureCase;
    const RuleEvidence({
      required this.successCaseIds,
      this.failureCaseIds = const [],
      this.requiresSuccessCase = true,
      this.requiresFailureCase = false,
    });
  }

  final class GrammarRule {
    final String id;
    final String syntax;
    final LocalizedText text;
    final RuleEvidence evidence;
    const GrammarRule({
      required this.id,
      required this.syntax,
      required this.text,
      this.evidence = const RuleEvidence(successCaseIds: []),
    });
  }

  final class OptionContract {
    final String id;
    final List<String> tokens;
    final int order;
    final LocalizedText meaning;
    final LocalizedText defaultValue;
    final List<ValueCategory> appliesTo;
    final RuleEvidence evidence;
    const OptionContract({
      required this.id,
      required this.tokens,
      required this.order,
      required this.meaning,
      required this.defaultValue,
      required this.appliesTo,
      required this.evidence,
    });
  }

  final class TypeContract {
    final String id;
    final List<String> tokens;
    final List<ValueCategory> accepts;
    final List<String> optionIds;
    final LocalizedText result;
    final LocalizedText defaultPrecision;
    final LocalizedText? deepLink;
    final RuleEvidence evidence;
    const TypeContract({
      required this.id,
      required this.tokens,
      required this.accepts,
      required this.optionIds,
      required this.result,
      required this.defaultPrecision,
      required this.evidence,
      this.deepLink,
    });
  }

  sealed class ExpectedOutcome { const ExpectedOutcome(); }
  final class OutputOutcome extends ExpectedOutcome {
    final String value;
    const OutputOutcome(this.value);
  }
  final class ErrorOutcome extends ExpectedOutcome {
    final FormattingErrorKind kind;
    const ErrorOutcome(this.kind);
  }

  final class ConformanceCase {
    final String id;
    final PublicCall call;
    final String dartExpression;
    final ExpectedOutcome expected;
    const ConformanceCase({
      required this.id,
      required this.call,
      required this.dartExpression,
      required this.expected,
    });
  }

  final class DialectContract {
    final ReferenceDialect dialect;
    final LocalizedText title;
    final List<GrammarRule> grammar;
    final List<OptionContract> options;
    final List<TypeContract> types;
    const DialectContract({
      required this.dialect,
      required this.title,
      required this.grammar,
      required this.options,
      required this.types,
    });
  }

  final class FormatReferenceContract {
    final DialectContract brace;
    final DialectContract printf;
    final List<GrammarRule> limits;
    final List<GrammarRule> errors;
    final List<ConformanceCase> cases;
    const FormatReferenceContract({
      required this.brace,
      required this.printf,
      required this.limits,
      required this.errors,
      required this.cases,
    });
  }
  ```

- [ ] **Шаг 4: Записать полный const-каталог без prose-дубликатов**

  Grammar IDs и их точная документационная нотация:

  | id | syntax | смысл EN / RU |
  |---|---|---|
  | `brace.template` | `template = (literal | "{{" | "}}" | replacement_field)*` | doubled braces emit literals / удвоенные скобки дают литералы |
  | `brace.field` | `replacement_field = "{" field_name? lookup* conversion? format_spec? "}"` | field parts have this order / части поля идут только в этом порядке |
  | `brace.root` | `field_name = decimal_index | python_identifier` | empty is automatic; Python Unicode decimal digits are positional; an identifier is named / пустое имя автоматическое; десятичные Unicode-цифры Python позиционные; identifier именованный |
  | `brace.lookup` | `lookup = "." python_identifier | "[" item_key "]"` | Unicode identifier attributes and non-empty unquoted item chains / Unicode-identifier атрибуты и цепочки непустых некавыченных ключей |
  | `brace.numbering` | `automatic xor manual positional numbering` | automatic and numeric roots never mix / автоматическая и числовая ручная нумерация не смешиваются |
  | `brace.conversion` | `conversion = "!" ("s" | "r" | "a")` | conversion precedes the specification / конверсия стоит до спецификации |
  | `brace.nesting` | `format_spec may contain replacement_field at depth 1` | one nested level; nested specifications cannot nest again / один вложенный уровень без следующего |
  | `brace.specification` | `[[fill]align][sign]["z"]["#"]["0"][width][grouping]["." (precision [grouping] | grouping)][type | custom_name [":" payload]]` | exact option order / точный порядок опций |
  | `brace.custom` | `custom_name = ASCII_LETTER (ASCII_LETTER | ASCII_DIGIT | "_")*` | built-ins reserved, payload follows colon / встроенные имена зарезервированы, payload идёт после двоеточия |
  | `printf.template` | `template = (literal | conversion)*` | percent begins every conversion / процент начинает каждую конверсию |
  | `printf.conversion` | `conversion = "%" flags width? precision? type` | fixed order / фиксированный порядок |
  | `printf.flags` | `flags = ("-" | "+" | " " | "#" | "0")*` | repeats collapse; `+` beats space, `-` beats zero / повторы схлопываются; `+` сильнее пробела, `-` сильнее нуля |
  | `printf.width` | `width = ASCII_DIGIT+ | "*"` | dynamic width is consumed before precision and value / динамическая ширина потребляется до точности и значения |
  | `printf.precision` | `precision = "." (ASCII_DIGIT* | "*")` | empty is zero; negative dynamic precision is absent / пустая равна нулю, отрицательная динамическая отсутствует |
  | `printf.omissions` | `no "$" positions; no h/l/j/z/t/L modifiers` | unsupported C/POSIX syntax is rejected / неподдержанный синтаксис C/POSIX отвергается |

  Brace options обязаны иметь эти токены, order и применимость:

  | id | tokens | order | applies to | default/interaction |
  |---|---|---:|---|---|
  | `brace.fill_align` | `<`, `>`, `^`, `=` plus optional one-TextUnit fill | 1 | text, integer, floating, custom; `=` only numeric | text/custom left, numbers right; `0` implies sign-aware `=` when align absent |
  | `brace.sign` | `+`, `-`, space | 2 | integer, floating, custom | minus only |
  | `brace.negative_zero` | `z` | 3 | floating, custom | off; clears a sign only after rounding to zero |
  | `brace.alternate` | `#` | 4 | integer, floating, custom | off; radix prefix or forced decimal point; no visible prefix for decimal integer |
  | `brace.zero` | `0` | 5 | integer, floating, custom | off; numeric sign-aware zero padding, passed through to custom formatter |
  | `brace.width` | ASCII digits | 6 | text, integer, floating, custom | absent; range 0…100000 |
  | `brace.integer_grouping` | `,`, `_` | 7 | integer, floating, custom | absent; comma only decimal integer, underscore all non-`n` radices; custom receives only this separator |
  | `brace.precision` | `.` plus ASCII digits | 8 | text, floating, custom | absent; truncates text, controls numeric digits, passes integer value to custom |
  | `brace.fraction_grouping` | `.,`, `._` or suffix after precision | 9 | floating; syntactically accepted but not exposed for custom | absent; groups fractional digits after rounding |
  | `brace.type` | built-in letter or custom name | 10 | all | inferred from value when empty |
  | `brace.payload` | `:` plus balanced specification text | 11 | custom | absent differs from empty; nested fields resolve before callback |

  Brace type matrix:

  | id/tokens | accepts | options | default precision/result |
  |---|---|---|---|
  | `brace.none` / empty | any | options selected by runtime value; empty custom selection allowed | `toString`, numeric shortest, or one matching formatter |
  | `brace.string` / `s` | text | fill/align, width, precision | no precision; original or truncated text |
  | `brace.character` / `c` | integer | fill/align except `=`, width | Unicode scalar, no precision |
  | `brace.decimal` / `d` | integer | numeric layout, sign, `#`, `0`, `,`/`_` | exact decimal, no precision |
  | `brace.binary` / `b` | integer | numeric layout, sign, `#`, `0`, `_` | exact binary, no precision |
  | `brace.octal` / `o` | integer | numeric layout, sign, `#`, `0`, `_` | exact octal, no precision |
  | `brace.hex` / `x`, `X` | integer | numeric layout, sign, `#`, `0`, `_` | exact lower/upper hexadecimal, no precision |
  | `brace.locale_number` / `n` | integer, floating | numeric layout, sign, `z`, `#`, `0`, precision; no explicit grouping | configured locale; floating general default |
  | `brace.fixed` / `f`, `F` | integer, floating | all floating options | 6 fractional digits |
  | `brace.scientific` / `e`, `E` | integer, floating | all floating options | SDK shortest exponent or compatible precision 6 |
  | `brace.general` / `g`, `G` | integer, floating | all floating options | SDK shortest or compatible significant precision 6 |
  | `brace.percent` / `%` | integer, floating | all floating options | multiply by 100, fixed precision 6, append `%` |
  | `brace.custom_type` / ASCII name | formatter's `T` | every parsed option except numeric `=`; engine applies fill/align/width | callback output; optional payload |

  Printf options and exact flag table:

  | id | tokens | applies/default |
  |---|---|---|
  | `printf.left` | `-` | all value conversions; right is default |
  | `printf.sign` | `+` | `d`, `i`, floating; minus-only default |
  | `printf.space` | space | `d`, `i`, floating; ignored when `+` exists |
  | `printf.alternate` | `#` | `o`, `x`, `X`, floating; off |
  | `printf.zero` | `0` | numeric conversions; off; disabled by `-`, and for integers by precision |
  | `printf.width` | ASCII digits or `*` | every value conversion; absent; `%%` forbids it |
  | `printf.precision` | `.digits`, `.`, or `.*` | `s`, integer, floating; absent; `%c` and `%%` forbid it |

  | conversions | allowed flags |
  |---|---|
  | `c`, `s` | `-` |
  | `d`, `i` | `-`, `+`, space, `0` |
  | `u` | `-`, `0` |
  | `o`, `x`, `X` | `-`, `#`, `0` |
  | `a`, `A`, `e`, `E`, `f`, `F`, `g`, `G` | `-`, `+`, space, `#`, `0` |
  | `%` | none |

  Printf type matrix:

  | id/tokens | accepts | precision/result |
  |---|---|---|
  | `printf.string` / `s` | any | absent means full `toString`; precision truncates by `TextUnit` |
  | `printf.character` / `c` | integer | Unicode scalar; precision forbidden |
  | `printf.signed` / `d`, `i` | integer | minimum digit count; absent means no leading precision zeros |
  | `printf.unsigned_decimal` / `u` | non-negative integer | decimal; negatives rejected |
  | `printf.octal` / `o` | non-negative integer | octal; `#` forces a leading zero digit |
  | `printf.hex` / `x`, `X` | non-negative integer | lower/upper hexadecimal; nonzero `#` adds `0x`/`0X` |
  | `printf.fixed` / `f`, `F` | floating | 6 in fixed/compatible path |
  | `printf.scientific` / `e`, `E` | floating | SDK exponent spelling when absent, otherwise requested; compatible default 6 |
  | `printf.general` / `g`, `G` | floating | SDK `toString` when absent; compatible significant precision 6 |
  | `printf.hex_float` / `a`, `A` | floating | exact trimmed binary64 when absent; requested hexadecimal fractional digits otherwise |
  | `printf.percent` / `%` | none | writes `%`, consumes no argument, forbids flags/width/precision |

  Limits rows:

  | id | exact contract |
  |---|---|
  | `limit.option` | brace and printf literal width/precision ≤ 100000 |
  | `limit.dynamic_width` | printf dynamic width −100000…100000; negative means left alignment |
  | `limit.dynamic_precision` | printf dynamic precision ≤ 100000; every negative value means absent |
  | `limit.fill_units` | `width * fill.length ≤ 200000` UTF-16 code units |
  | `limit.index` | brace positional and numeric item index ≤ 9223372036854775807 |
  | `limit.nesting` | one nested replacement-field level |
  | `limit.dart_precision` | Dart profile: general/empty/`n` 1…21; `f`/`e`/`%` 0…20 |
  | `limit.compatible_precision` | compatible profile accepts 0…100000; `g` precision 0 behaves as 1 |

  Error rows map exactly:

  | id | class |
  |---|---|
  | `error.grammar` | `InvalidFormatException` |
  | `error.options` | `InvalidSpecifierException` |
  | `error.value` | `UnsupportedFormatValueException` |
  | `error.conversion` | `UnsupportedConversionException` |
  | `error.argument` | `MissingFormatArgumentException` |

  Короткие строки `LocalizedText` задаются непосредственно в catalog; renderer
  не переводит и не склеивает смысл самостоятельно. Для option/type rows
  использовать эти пары EN / RU:

  | id | English | Русский |
  |---|---|---|
  | `brace.fill_align` | Fill with one text unit and align left, right, center, or after the sign. | Заполнить одной текстовой единицей и выровнять влево, вправо, по центру или после знака. |
  | `brace.sign` | Select the sign for numeric output. | Выбрать знак числового результата. |
  | `brace.negative_zero` | Remove the minus when rounding produces zero. | Убрать минус, когда округление даёт ноль. |
  | `brace.alternate` | Request a radix prefix or decimal point. | Запросить префикс системы счисления или десятичную точку. |
  | `brace.zero` | Request sign-aware numeric zero padding. | Запросить числовое дополнение нулями после знака. |
  | `brace.width` | Set the minimum field width. | Задать минимальную ширину поля. |
  | `brace.integer_grouping` | Group integer digits with comma or underscore. | Группировать целые цифры запятой или подчёркиванием. |
  | `brace.precision` | Truncate text or control numeric precision. | Обрезать текст или задать точность числа. |
  | `brace.fraction_grouping` | Group fractional digits after rounding. | Группировать дробные цифры после округления. |
  | `brace.type` | Select a built-in presentation or custom formatter. | Выбрать встроенное представление или собственный форматтер. |
  | `brace.payload` | Pass resolved text after the custom formatter name. | Передать разрешённый текст после имени собственного форматтера. |
  | `printf.left` | Left-align the converted value. | Выровнять преобразованное значение влево. |
  | `printf.sign` | Show a plus sign for a non-negative signed value. | Показывать плюс у неотрицательного знакового значения. |
  | `printf.space` | Prefix a non-negative signed value with a space. | Ставить пробел перед неотрицательным знаковым значением. |
  | `printf.alternate` | Request the conversion's alternate form. | Запросить альтернативную форму конверсии. |
  | `printf.zero` | Pad a numeric conversion with zeros. | Дополнить числовую конверсию нулями. |
  | `printf.width` | Set literal or argument-supplied minimum width. | Задать литеральную или полученную из аргумента минимальную ширину. |
  | `printf.precision` | Set literal or argument-supplied precision. | Задать литеральную или полученную из аргумента точность. |

  | type id | English result | Русский результат |
  |---|---|---|
  | `brace.none` | Value-default text or one matching custom formatter. | Текст значения по умолчанию или единственный подходящий форматтер. |
  | `brace.string` | Text, optionally truncated. | Текст, при необходимости обрезанный. |
  | `brace.character` | One Unicode scalar. | Один скаляр Unicode. |
  | `brace.decimal` | Exact decimal integer. | Точное десятичное целое. |
  | `brace.binary` | Exact binary integer. | Точное двоичное целое. |
  | `brace.octal` | Exact octal integer. | Точное восьмеричное целое. |
  | `brace.hex` | Exact lower- or uppercase hexadecimal integer. | Точное шестнадцатеричное целое в нижнем или верхнем регистре. |
  | `brace.locale_number` | Locale-aware decimal or general number. | Десятичное или общее число с учётом локали. |
  | `brace.fixed` | Fixed-point number. | Число с фиксированной точкой. |
  | `brace.scientific` | Scientific notation. | Научная запись. |
  | `brace.general` | General decimal notation. | Общая десятичная запись. |
  | `brace.percent` | Value multiplied by 100 with a percent suffix. | Значение, умноженное на 100, со знаком процента. |
  | `brace.custom_type` | Custom callback output with engine-applied layout. | Результат callback с раскладкой, применённой движком. |
  | `printf.string` | `toString()` text, optionally truncated. | Текст `toString()`, при необходимости обрезанный. |
  | `printf.character` | One Unicode scalar. | Один скаляр Unicode. |
  | `printf.signed` | Signed decimal integer. | Знаковое десятичное целое. |
  | `printf.unsigned_decimal` | Non-negative decimal integer. | Неотрицательное десятичное целое. |
  | `printf.octal` | Non-negative octal integer. | Неотрицательное восьмеричное целое. |
  | `printf.hex` | Non-negative hexadecimal integer. | Неотрицательное шестнадцатеричное целое. |
  | `printf.fixed` | Fixed-point double. | `double` с фиксированной точкой. |
  | `printf.scientific` | Scientific double. | `double` в научной записи. |
  | `printf.general` | General decimal double. | `double` в общей десятичной записи. |
  | `printf.hex_float` | Exact hexadecimal binary64 notation. | Точная шестнадцатеричная запись binary64. |
  | `printf.percent` | Literal percent; no value consumed. | Литеральный процент; значение не потребляется. |

  Значения `defaultPrecision` берутся дословно из type matrices выше и имеют
  русские пары `не задана`, `6 дробных цифр`, `6 значащих цифр`,
  `точная сокращённая запись` и `зависит от типа значения`. Ссылки deep-dive
  используют exact anchors:

  | topic | English | Русский |
  |---|---|---|
  | text | `#text-formatting` | `#форматирование-текста` |
  | character | `#character-values` | `#символьные-значения` |
  | Unicode | `#unicode-text-units` | `#единицы-измерения-текста-в-unicode` |
  | double profiles | `#double-formatting-profiles` | `#профили-форматирования-double` |
  | locale | `#number-locales` | `#числовые-локали` |
  | custom | `#custom-formatters` | `#собственные-форматтеры` |
  | printf deep dive | `#sprintf` | `#sprintf` |

  Limits use the exact numbers from their table and these titles:
  `Safe option size` / `Безопасный размер опции`, `Dynamic width` /
  `Динамическая ширина`, `Dynamic precision` / `Динамическая точность`,
  `Fill expansion` / `Расширение заполнителя`, `Field indexes` / `Индексы
  полей`, `Nesting depth` / `Глубина вложенности`, `Dart-profile precision` /
  `Точность Dart-профиля`, `Compatible-profile precision` / `Точность
  compatible-профиля`. Error rows use `Malformed template` / `Неправильный
  шаблон`, `Inapplicable options` / `Неприменимые опции`, `Unsupported value` /
  `Неподдержанное значение`, `Unsupported brace conversion` /
  `Неподдержанная brace-конверсия`, `Missing argument` / `Отсутствующий
  аргумент`; рядом renderer печатает concrete class из error table.

- [ ] **Шаг 5: Записать исполняемые cases и evidence**

  Каталог содержит эти exact calls; строки `dartExpression` копируются в
  generated Dart как closures, а `expected` никогда не вычисляется генератором.

  Brace grammar/layout cases:

  | id | expression | expected |
  |---|---|---|
  | `brace.escape.output` | `format('{{x}}')` | `{x}` |
  | `brace.positional.output` | `format('{1}/{0}', 'a', 'b')` | `b/a` |
  | `brace.lookup.output` | `formatWith('{user.items[1]}', named: const {'user': {'items': ['a', 'b']}})` | `b` |
  | `brace.item_text.output` | `formatWith('{record[any key]}', named: const {'record': {'any key': 'ok'}})` | `ok` |
  | `brace.item_quote.error` | `formatWith('{record["any key"]}', named: const {'record': {'any key': 'ok'}})` | `InvalidFormatException` |
  | `brace.unicode_index.output` | `formatWith('{١}', positional: const ['zero', 'one'])` | `one` |
  | `brace.numbering.error` | `format('{} {0}', 1, 2)` | `InvalidFormatException` |
  | `brace.identifier.error` | `formatWith('{ name }', named: const {'name': 1})` | `InvalidFormatException` |
  | `brace.convert_s.output` | `format('{!s}', null)` | `null` |
  | `brace.convert_r.output` | `format('{!r}', 'x')` | `'x'` including quotes |
  | `brace.convert_a.output` | `format('{!a}', 'é')` | `'\xe9'` including quotes |
  | `brace.convert_unknown.error` | `format('{!q}', 1)` | `UnsupportedConversionException` |
  | `brace.nested.output` | `format('{:{}}', 'x', 3)` | `x` plus two spaces |
  | `brace.nested_depth.error` | `format('{:{:{}}}', 'x', 3, 1)` | `InvalidFormatException` |
  | `brace.balanced_payload.output` | `_referenceFormat.format('{:echo:a{{b}}c}', const {'value': '42'})` | `a{b}c:42` |
  | `brace.unbalanced_payload.error` | `_referenceFormat.format('{:echo:a{{b}', const {'value': '42'})` | `InvalidFormatException` |
  | `brace.missing.error` | `format('{}')` | `MissingFormatArgumentException` |
  | `brace.text.output` | `format('{:*^5.3s}', 'abcdef')` | `*abc*` |
  | `brace.sign.error` | `format('{:+s}', 'abc')` | `InvalidSpecifierException` |
  | `brace.alternate.error` | `format('{:#s}', 'abc')` | `InvalidSpecifierException` |
  | `brace.text_zero.error` | `format('{:05s}', 'abc')` | `InvalidSpecifierException` |
  | `brace.character.output` | `format('{:>3c}', 65)` | two spaces plus `A` |
  | `brace.character_precision.error` | `format('{:.1c}', 65)` | `InvalidSpecifierException` |
  | `brace.character_value.error` | `format('{:c}', 0xD800)` | `UnsupportedFormatValueException` |
  | `brace.sign_zero.output` | `format('{:+08d}', 42)` | `+0000042` |
  | `brace.alternate.output` | `format('{:#x}', 42)` | `0x2a` |
  | `brace.integer_grouping.output` | `format('{:,d}', 1234567)` | `1,234,567` |
  | `brace.radix_grouping.output` | `format('{:_x}', 0xabcdef)` | `ab_cdef` |
  | `brace.grouping.error` | `format('{:,x}', 42)` | `InvalidSpecifierException` |
  | `brace.integer_precision.error` | `format('{:.2d}', 42)` | `InvalidSpecifierException` |
  | `brace.negative_zero.error` | `format('{:zd}', 42)` | `InvalidSpecifierException` |
  | `brace.fraction_grouping.error` | `format('{:.,d}', 42)` | `InvalidSpecifierException` |
  | `brace.option_order.error` | `format('{:10+d}', 42)` | `InvalidSpecifierException` |
  | `brace.negative_zero.output` | `format('{:z.2f}', -0.001)` | `0.00` |
  | `brace.fraction_grouping.output` | `format('{:.6_f}', 1234.5678)` | `1234.567_800` |
  | `brace.fraction_default.output` | `Format(doubleFormatMode: DoubleFormatMode.compatible).format('{:.,f}', 1234.5678)` | `1234.567,800` |
  | `brace.dart_precision.error` | `format('{:.22g}', 1.0)` | `InvalidSpecifierException` |
  | `brace.compatible_precision.output` | `Format(doubleFormatMode: DoubleFormatMode.compatible).format('{:.21f}', 0.1)` | `0.100000000000000005551` |
  | `brace.compatible_precision_limit.output` | `Format(doubleFormatMode: DoubleFormatMode.compatible).format('{:.100000f}', 0.0).length.toString()` | `100002` |
  | `brace.compatible_precision_limit.error` | `Format(doubleFormatMode: DoubleFormatMode.compatible).format('{:.100001f}', 0.0)` | `InvalidSpecifierException` |
  | `brace.option_limit.output` | `format('{:100000d}', 1).length.toString()` | `100000` |
  | `brace.option_limit.error` | `format('{:100001d}', 1)` | `InvalidSpecifierException` |
  | `brace.fill_limit.output` | `Format(textUnit: TextUnit.graphemeClusters).format('{:😀>100000s}', 'x').length.toString()` | `199999` |
  | `brace.fill_limit.error` | `Format(textUnit: TextUnit.graphemeClusters).format('{:👩‍🔬>100000s}', 'x')` | `InvalidSpecifierException` |
  | `brace.index.output` | `formatWith('{1}', positional: const ['zero', 'one'])` | `one` |
  | `brace.index_max.error` | `formatWith('{9223372036854775807}')` | `MissingFormatArgumentException` |
  | `brace.index_over.error` | `formatWith('{9223372036854775808}')` | `InvalidFormatException` |
  | `brace.custom_explicit.output` | `_referenceFormat.format('{:*^10echo:tag}', const {'value': '42'})` | `**tag:42**` |
  | `brace.custom_automatic.output` | `_referenceFormat.format('{}', const {'value': '42'})` | `42` |
  | `brace.custom_value.error` | `_referenceFormat.format('{:echo}', 42)` | `UnsupportedFormatValueException` |
  | `brace.custom_align.error` | `_referenceFormat.format('{:=8echo}', const {'value': '42'})` | `InvalidSpecifierException` |
  | `brace.custom_syntax.error` | `_referenceFormat.format('{:echo!bad}', const {'value': '42'})` | `InvalidSpecifierException` |
  | `brace.custom_missing.error` | `format('{:missing}', 42)` | `InvalidSpecifierException` |
  | `brace.custom_fraction.output` | `_referenceFormat.format('{:.,echo:tag}', const {'value': '42'})` | `tag:42` |

  Brace type rows receive these positive calls and a negative call for every
  rejecting family:

  | case ids / tokens | positive expression → output | negative expression → error |
  |---|---|---|
  | `brace.type.none.output` / empty | `format('{}', true)` → `true` | no value rejection |
  | `brace.type.s.output`, `brace.type.s.error` / `s` | `format('{:s}', 'text')` → `text` | `format('{:s}', 42)` → `InvalidSpecifierException` |
  | `brace.type.c.output`, `brace.type.c.error` / `c` | `format('{:c}', BigInt.from(65))` → `A` | `format('{:c}', 'A')` → `UnsupportedFormatValueException` |
  | `brace.type.d.output`, `brace.type.d.error` / `d` | `format('{:d}', BigInt.from(42))` → `42` | `format('{:d}', '42')` → `InvalidSpecifierException` |
  | `brace.type.b.output`, `brace.type.b.error` / `b` | `format('{:b}', 42)` → `101010` | `format('{:b}', '42')` → `InvalidSpecifierException` |
  | `brace.type.o.output`, `brace.type.o.error` / `o` | `format('{:o}', 42)` → `52` | `format('{:o}', '42')` → `InvalidSpecifierException` |
  | `brace.type.x.output`, `brace.type.x.error` / `x` | `format('{:x}', 42)` → `2a` | `format('{:x}', '42')` → `InvalidSpecifierException` |
  | `brace.type.upper_x.output`, `brace.type.upper_x.error` / `X` | `format('{:X}', 42)` → `2A` | `format('{:X}', '42')` → `InvalidSpecifierException` |
  | `brace.type.n.output`, `brace.type.n.error` / `n` | `format('{:n}', 2.5)` → `2.5` | `format('{:n}', '2.5')` → `InvalidSpecifierException` |
  | `brace.type.f.output`, `brace.type.f.error` / `f` | `format('{:.1f}', 2)` → `2.0` | `format('{:f}', '2.5')` → `InvalidSpecifierException` |
  | `brace.type.upper_f.output`, `brace.type.upper_f.error` / `F` | `format('{:.1F}', 2.5)` → `2.5` | `format('{:F}', '2.5')` → `InvalidSpecifierException` |
  | `brace.type.e.output`, `brace.type.e.error` / `e` | `format('{:.1e}', BigInt.from(12))` → `1.2e+1` | `format('{:e}', '2.5')` → `InvalidSpecifierException` |
  | `brace.type.upper_e.output`, `brace.type.upper_e.error` / `E` | `format('{:E}', 2.5)` → `2.5E+0` | `format('{:E}', '2.5')` → `InvalidSpecifierException` |
  | `brace.type.g.output`, `brace.type.g.error` / `g` | `format('{:g}', 2.5)` → `2.5` | `format('{:g}', '2.5')` → `InvalidSpecifierException` |
  | `brace.type.upper_g.output`, `brace.type.upper_g.error` / `G` | `format('{:G}', 2.5)` → `2.5` | `format('{:G}', '2.5')` → `InvalidSpecifierException` |
  | `brace.type.percent.output`, `brace.type.percent.error` / `%` | `format('{:%}', 2.5)` → `250.000000%` | `format('{:%}', '2.5')` → `InvalidSpecifierException` |

  Printf grammar/options cases:

  | id | expression | expected |
  |---|---|---|
  | `printf.percent.output` | `sprintf('x%%y')` | `x%y` |
  | `printf.empty_precision.output` | `sprintf('%.f', 1.5)` | `2` |
  | `printf.repeat_precedence.output` | `sprintf('%++ d', 42)` | `+42` |
  | `printf.space.output` | `sprintf('% d', 42)` | one space plus `42` |
  | `printf.zero.output` | `sprintf('%05d', 42)` | `00042` |
  | `printf.left_zero.output` | `sprintf('%-05d', 42)` | `42` plus three spaces |
  | `printf.dynamic.output` | `vsprintf('%*.*f', const [8, 2, 1.5])` | four spaces plus `1.50` |
  | `printf.negative_width.output` | `vsprintf('%*s', const [-4, 'x'])` | `x` plus three spaces |
  | `printf.negative_precision.output` | `vsprintf('%.*s', const [-1, 'abc'])` | `abc` |
  | `printf.dynamic_missing.error` | `vsprintf('%*s', const [])` | `MissingFormatArgumentException` |
  | `printf.dynamic_type.error` | `vsprintf('%*s', const ['4', 'x'])` | `UnsupportedFormatValueException` |
  | `printf.flag.error` | `sprintf('%+u', 1)` | `InvalidSpecifierException` |
  | `printf.sign_character.error` | `sprintf('%+c', 65)` | `InvalidSpecifierException` |
  | `printf.alternate_decimal.error` | `sprintf('%#d', 1)` | `InvalidSpecifierException` |
  | `printf.zero_string.error` | `sprintf('%05s', 'x')` | `InvalidSpecifierException` |
  | `printf.precision_character.error` | `sprintf('%.1c', 65)` | `InvalidSpecifierException` |
  | `printf.grammar.error` | `sprintf('%q', 1)` | `InvalidFormatException` |
  | `printf.length.error` | `sprintf('%llx', 1)` | `InvalidFormatException` |
  | `printf.position.error` | `sprintf(r'%2$d', 1)` | `InvalidFormatException` |
  | `printf.ascii_digit.error` | `sprintf('%١d', 1)` | `InvalidFormatException` |
  | `printf.percent_option.error` | `sprintf('%1%')` | `InvalidSpecifierException` |
  | `printf.integer_precision.output` | `sprintf('%05.3d', 42)` | two spaces plus `042` |
  | `printf.alternate_octal.output` | `sprintf('%#o', 42)` | `052` |
  | `printf.alternate_hex.output` | `sprintf('%#x', 42)` | `0x2a` |
  | `printf.string_precision.output` | `sprintf('%.3s', 'abcdef')` | `abc` |
  | `printf.option_limit.output` | `sprintf('%100000d', 1).length.toString()` | `100000` |
  | `printf.option_limit.error` | `sprintf('%100001d', 1)` | `InvalidSpecifierException` |
  | `printf.precision_limit.output` | `sprintf('%.100000s', 'x')` | `x` |
  | `printf.precision_limit.error` | `sprintf('%.100001s', 'x')` | `InvalidSpecifierException` |
  | `printf.dynamic_width_limit.output` | `vsprintf('%*s', const [100000, 'x']).length.toString()` | `100000` |
  | `printf.dynamic_width_lower.output` | `vsprintf('%*s', const [-100000, 'x']).length.toString()` | `100000` |
  | `printf.dynamic_limit.error` | `vsprintf('%*s', const [100001, 'x'])` | `InvalidSpecifierException` |
  | `printf.dynamic_width_lower.error` | `vsprintf('%*s', const [-100001, 'x'])` | `InvalidSpecifierException` |
  | `printf.dynamic_precision_limit.output` | `vsprintf('%.*s', const [100000, 'x'])` | `x` |
  | `printf.dynamic_precision_limit.error` | `vsprintf('%.*s', const [100001, 'x'])` | `InvalidSpecifierException` |
  | `printf.value_missing.error` | `vsprintf('%d %s', const [1])` | `MissingFormatArgumentException` |

  Printf type evidence:

  | case ids / tokens | positive expression → output | negative boundary |
  |---|---|---|
  | `printf.type.s.output` / `s` | `sprintf('%s', true)` → `true` | accepts any value |
  | `printf.type.c.output`, `printf.type.c.error` / `c` | `sprintf('%c', BigInt.from(65))` → `A` | `sprintf('%c', 'A')` → `UnsupportedFormatValueException` |
  | `printf.type.d.output`, `printf.type.d.error` / `d` | `sprintf('%d', BigInt.from(-42))` → `-42` | `sprintf('%d', '42')` → `UnsupportedFormatValueException` |
  | `printf.type.i.output`, `printf.type.i.error` / `i` | `sprintf('%i', -42)` → `-42` | `sprintf('%i', '42')` → `UnsupportedFormatValueException` |
  | `printf.type.u.output`, `printf.type.u.error` / `u` | `sprintf('%u', 42)` → `42` | `sprintf('%u', -1)` → `UnsupportedFormatValueException` |
  | `printf.type.o.output`, `printf.type.o.error` / `o` | `sprintf('%o', 42)` → `52` | `sprintf('%o', -1)` → `UnsupportedFormatValueException` |
  | `printf.type.x.output`, `printf.type.x.error` / `x` | `sprintf('%x', 42)` → `2a` | `sprintf('%x', -1)` → `UnsupportedFormatValueException` |
  | `printf.type.upper_x.output`, `printf.type.upper_x.error` / `X` | `sprintf('%X', 42)` → `2A` | `sprintf('%X', -1)` → `UnsupportedFormatValueException` |
  | `printf.type.f.output`, `printf.type.f.error` / `f` | `sprintf('%f', 2.5)` → `2.500000` | `sprintf('%f', '2.5')` → `UnsupportedFormatValueException` |
  | `printf.type.upper_f.output`, `printf.type.upper_f.error` / `F` | `sprintf('%F', 2.5)` → `2.500000` | `sprintf('%F', '2.5')` → `UnsupportedFormatValueException` |
  | `printf.type.e.output`, `printf.type.e.error` / `e` | `sprintf('%e', 2.5)` → `2.5e+0` | `sprintf('%e', '2.5')` → `UnsupportedFormatValueException` |
  | `printf.type.upper_e.output`, `printf.type.upper_e.error` / `E` | `sprintf('%E', 2.5)` → `2.5E+0` | `sprintf('%E', '2.5')` → `UnsupportedFormatValueException` |
  | `printf.type.g.output`, `printf.type.g.error` / `g` | `sprintf('%g', 2.5)` → `2.5` | `sprintf('%g', '2.5')` → `UnsupportedFormatValueException` |
  | `printf.type.upper_g.output`, `printf.type.upper_g.error` / `G` | `sprintf('%G', 2.5)` → `2.5` | `sprintf('%G', '2.5')` → `UnsupportedFormatValueException` |
  | `printf.type.a.output`, `printf.type.a.error` / `a` | `sprintf('%a', 2.5)` → `0x1.4p+1` | `sprintf('%a', '2.5')` → `UnsupportedFormatValueException` |
  | `printf.type.upper_a.output`, `printf.type.upper_a.error` / `A` | `sprintf('%A', 2.5)` → `0X1.4P+1` | `sprintf('%A', '2.5')` → `UnsupportedFormatValueException` |
  | `printf.type.percent.output` / `%` | `sprintf('%%', 1)` → `%` without consuming `1` | `printf.percent_option.error` → `InvalidSpecifierException` |

  Every row's `RuleEvidence` names exact case ids from these tables. Cases
  reused by several semantic rows remain a single `ConformanceCase`; validator
  checks direction and existence, not one-to-one ownership. Error-class rows
  set `requiresSuccessCase: false`, `requiresFailureCase: true` and point only
  at the corresponding `ErrorOutcome`; rows without a rejecting boundary set
  `requiresFailureCase: false` explicitly.

- [ ] **Шаг 6: Реализовать validator и получить GREEN**

  Validator собирает ids в одном проходе, не бросает на первой ошибке и
  возвращает стабильный список issues в порядке каталога. Проверки token
  выполняются внутри dialect/category, а case ids — глобально.

  Run: `rtk dart test tool/test/format_reference_contract_test.dart`

  Expected: PASS; полный каталог даёт пустой список, каждая fixture-мутация —
  названную диагностику.

- [ ] **Шаг 7: Обновить статус дизайна и handoff**

  В design `[9]` заменить ожидание проверки владельца на «одобрен владельцем
  2026-08-14; implementation plan принят к исполнению». В handoff записать
  Task 1, точный результат targeted/full gate и следующий Task 2.

- [ ] **Шаг 8: Выполнить полный gate и закоммитить Task 1**

  Исключить `docs/backlog.md`, проверить staged diff и создать:

  ```sh
  rtk git add -A ':(exclude)docs/backlog.md'
  rtk git commit -m 'tool: define format reference contract'
  ```

---

### Задача 2: Детерминированный генератор, README и архивная проекция

**Файлы:**
- Создать: `tool/src/format_reference_renderer.dart`
- Создать: `tool/src/format_reference_generator.dart`
- Создать: `tool/generate_format_reference.dart`
- Создать: `tool/test/format_reference_generator_test.dart`
- Создать generated: `test/support/format_reference_cases.dart`
- Изменить generated/manual: `README.md`
- Изменить generated/manual: `README.ru.md`
- Изменить: `docs/handoff.md`

**Интерфейсы:**
- Потребляет: `const formatReferenceContract` и validator из Task 1.
- Производит:
  `RenderedReference renderFormatReference(FormatReferenceContract,
  ReferenceLanguage)`, `String replaceFormatReferenceBlock(...)`,
  `String renderFormatReferenceCases(...)` и
  `Future<List<String>> generateFormatReferenceArtifacts(...)`.

- [ ] **Шаг 1: Написать падающие renderer/generator tests**

  Закрепить чистые функции и файловую транзакцию:

  ```dart
  test('replacement preserves manual prefix and suffix', () {
    const source = 'before\n$formatReferenceStartMarker\nold\n'
        '$formatReferenceEndMarker\nafter\n';
    expect(
      replaceFormatReferenceBlock(source, 'new\n'),
      'before\n$formatReferenceStartMarker\nnew\n'
      '$formatReferenceEndMarker\nafter\n',
    );
  });

  test('both languages render the same semantic ids in the same order', () {
    final english = renderFormatReference(
      formatReferenceContract,
      ReferenceLanguage.english,
    );
    final russian = renderFormatReference(
      formatReferenceContract,
      ReferenceLanguage.russian,
    );
    expect(russian.semanticIds, english.semanticIds);
  });
  ```

  Scratch matrix обязана отдельно проверить: marker отсутствует, marker
  повторён, end идёт до start, ручной prefix/suffix сохранён, `--check`
  возвращает все stale paths и ничего не пишет, ошибка второго README не
  позволяет записать первый, ссылка на отсутствующий manual anchor отвергается,
  повторный `--write` идемпотентен, а generated Dart не меняется после
  `dart format` во временном каталоге. Инъекция writer, падающего на втором
  artifact, обязана пробросить исходную файловую ошибку; следующий обычный
  `--write` восстанавливает все три targets.

- [ ] **Шаг 2: Запустить тест и увидеть отсутствующий renderer**

  Run: `rtk dart test tool/test/format_reference_generator_test.dart`

  Expected: FAIL на отсутствующем import/function.

- [ ] **Шаг 3: Реализовать чистый rendering и markers**

  Точные интерфейсы:

  ```dart
  const formatReferenceStartMarker =
      '<!-- BEGIN GENERATED FORMAT REFERENCE -->';
  const formatReferenceEndMarker =
      '<!-- END GENERATED FORMAT REFERENCE -->';

  final class RenderedReference {
    final String markdown;
    final List<String> semanticIds;
    const RenderedReference(this.markdown, this.semanticIds);
  }

  RenderedReference renderFormatReference(
    FormatReferenceContract contract,
    ReferenceLanguage language,
  );

  String replaceFormatReferenceBlock(String source, String generated);
  String renderFormatReferenceCases(FormatReferenceContract contract);
  ```

  Markdown output имеет одинаковый порядок:

  1. `## Format reference` / `## Справочник форматов`;
  2. brace template grammar;
  3. brace format specification;
  4. brace option table;
  5. brace presentation matrix;
  6. printf grammar and dynamic options;
  7. printf flag matrix;
  8. printf conversion matrix;
  9. limits and error classes.

  Grammar печатается fenced `text`; таблицы экранируют `|` и переводы строк.
  Порядок берётся только из catalog lists. Renderer возвращает ids фактически
  посещённых строк; generator сравнивает два списка до записи.
  Dart string literals экранируют `\\`, кавычку, `$` и control characters;
  `dartExpression` вставляется как доверенный Dart-код, а выражение с
  positional `$` хранится в каталоге как raw string.

  Link validator пропускает fenced code, читает только headings `#`…`######`,
  приводит их к lower case, удаляет ASCII punctuation/backticks, заменяет
  пробелы дефисами и сохраняет Unicode letters/digits. Его unit cases обязаны
  получить `#double-formatting-profiles` из `## Double formatting profiles` и
  `#собственные-форматтеры` из `## Собственные форматтеры`; каждый `deepLink`
  каталога проверяется против полного README после подстановки блока.

- [ ] **Шаг 4: Реализовать generated Dart bridge**

  `renderFormatReferenceCases` выдаёт файл с этой стабильной поверхностью:

  ```dart
  // Generated by tool/generate_format_reference.dart. Do not edit.
  library;

  import 'package:format/format.dart';

  final class GeneratedFormatReferenceCase {
    final String id;
    final String Function() invoke;
    final String? expectedOutput;
    final Type? expectedError;

    const GeneratedFormatReferenceCase({
      required this.id,
      required this.invoke,
      this.expectedOutput,
      this.expectedError,
    }) : assert((expectedOutput == null) != (expectedError == null));
  }

  const formatReferenceBraceTypes = <String>{
    'b', 'c', 'd', 'e', 'E', 'f', 'F', 'g', 'G', 'n', 'o', 's', 'x', 'X', '%',
  };

  const formatReferencePrintfFlags = <String, Set<String>>{
    'c': {'-'},
    's': {'-'},
    'd': {'-', '+', ' ', '0'},
    'i': {'-', '+', ' ', '0'},
    'u': {'-', '0'},
    'o': {'-', '#', '0'},
    'x': {'-', '#', '0'},
    'X': {'-', '#', '0'},
    'a': {'-', '+', ' ', '#', '0'},
    'A': {'-', '+', ' ', '#', '0'},
    'e': {'-', '+', ' ', '#', '0'},
    'E': {'-', '+', ' ', '#', '0'},
    'f': {'-', '+', ' ', '#', '0'},
    'F': {'-', '+', ' ', '#', '0'},
    'g': {'-', '+', ' ', '#', '0'},
    'G': {'-', '+', ' ', '#', '0'},
    '%': {},
  };
  ```

  Затем generator объявляет `_ReferenceFormatter extends
  Formatter<Map<String, Object?>>` со specifier `echo`; callback возвращает
  `${options.payload ?? ''}${options.payload == null ? '' : ':'}${value['value']}`.
  Для automatic case при `payload == null` результат — только `value`. Все
  catalog expressions оборачиваются как `invoke: () => <expression>`, а enum
  ошибок отображается на пять concrete `Type` из публичного facade.

- [ ] **Шаг 5: Реализовать файловый слой и CLI**

  ```dart
  enum FormatReferenceGenerationMode { write, check }

  Future<List<String>> generateFormatReferenceArtifacts({
    required Directory root,
    required FormatReferenceGenerationMode mode,
    FormatReferenceContract contract = formatReferenceContract,
    Future<void> Function(File file, String contents)? writeArtifact,
  });
  ```

  Функция читает три targets, валидирует catalog/markers/semantic order/links,
  строит три полных новых содержимых в памяти и только потом пишет. В `check`
  возвращает relative stale paths и не пишет. CLI принимает ровно один из
  `--write`, `--check`; неизвестная или отсутствующая mode печатает usage и
  завершает с 64, stale `--check` — с 1. Необязательный writer существует
  только для scratch-теста межфайловой ошибки; production default вызывает
  `File.writeAsString` и не перехватывает его исключение.

- [ ] **Шаг 6: Вставить markers и сгенерировать оба README**

  В обоих README заменить прежний раздел presentation/conversion types одной
  парой markers, затем выполнить:

  Run: `rtk dart run tool/generate_format_reference.dart --write`

  Ручные правки вокруг блока точны:

  - `Text formatting`, `Character values`, `Unicode text units`, `Double
    formatting profiles`, `Number locales`, `Custom formatters` сохраняют
    примеры и получают ссылку на соответствующую reference-таблицу;
  - `sprintf` сохраняет profile/compatibility объяснение, но вместо повторного
    перечня букв ссылается на conversion matrix;
  - прежние ручные brace/printf type tables удаляются целиком;
  - русская начальная оговорка об английском нормативном оригинале остаётся;
  - generated link anchors указывают на реально существующие ручные headings
    каждого языка.

- [ ] **Шаг 7: Получить GREEN генератора и проверить идемпотентность**

  Run:

  ```sh
  rtk dart test tool/test/format_reference_contract_test.dart \
    tool/test/format_reference_generator_test.dart
  rtk dart run tool/generate_format_reference.dart --check
  rtk dart run tool/generate_format_reference.dart --write
  rtk dart run tool/generate_format_reference.dart --check
  rtk git diff --check
  ```

  Expected: тесты PASS, оба `--check` дают exit 0, повторный write оставляет
  все три artifacts актуальными и diff не содержит whitespace errors.

- [ ] **Шаг 8: Выполнить полный gate и закоммитить Task 2**

  Обновить handoff результатами и следующим Task 3, исключить backlog:

  ```sh
  rtk git add -A ':(exclude)docs/backlog.md'
  rtk git commit -m 'docs: generate complete format reference'
  ```

---

### Задача 3: Parser inventory seams и публичный conformance suite

**Файлы:**
- Изменить: `lib/src/format_spec.dart`
- Изменить: `lib/src/printf_parser.dart`
- Создать: `test/format_reference_contract_test.dart`
- Изменить: `docs/handoff.md`

**Интерфейсы:**
- Потребляет: `formatReferenceCases`, `formatReferenceBraceTypes` и
  `formatReferencePrintfFlags` из generated support.
- Производит: `debugBraceBuiltInTypes()`, `debugPrintfConversionTypes()` и
  `debugPrintfFlagTokensByConversion()` только из internal engine library.

- [ ] **Шаг 1: Написать падающий conformance test**

  ```dart
  library;

  import 'package:format/src/engine.dart';
  import 'package:test/test.dart';

  import 'support/format_reference_cases.dart';

  void main() {
    for (final entry in formatReferenceCases) {
      test(entry.id, () {
        Object? error;
        String? output;
        try {
          output = entry.invoke();
        } on Object catch (caught) {
          error = caught;
        }
        if (entry.expectedError case final expected?) {
          expect(error, isNotNull);
          expect(error?.runtimeType, expected);
        } else {
          expect(error, isNull);
          expect(output, entry.expectedOutput);
        }
      });
    }

    test('brace type inventory matches the reference', () {
      expect(debugBraceBuiltInTypes(), formatReferenceBraceTypes);
    });

    test('printf type and flag inventories match the reference', () {
      expect(
        debugPrintfConversionTypes(),
        formatReferencePrintfFlags.keys.toSet(),
      );
      expect(
        debugPrintfFlagTokensByConversion(),
        formatReferencePrintfFlags,
      );
    });
  }
  ```

- [ ] **Шаг 2: Запустить тест и увидеть отсутствующие seams**

  Run: `rtk dart test test/format_reference_contract_test.dart`

  Expected: FAIL at compile time for the three debug functions.

- [ ] **Шаг 3: Извлечь одну printf mask-функцию**

  В `printf_parser.dart` перенести существующий switch без изменения ветвей:

  ```dart
  int _allowedPrintfFlags(String type) => switch (type) {
    'c' || 's' => _PrintfFlags.left,
    'd' || 'i' =>
      _PrintfFlags.left |
      _PrintfFlags.sign |
      _PrintfFlags.space |
      _PrintfFlags.zero,
    'u' => _PrintfFlags.left | _PrintfFlags.zero,
    'o' || 'x' || 'X' =>
      _PrintfFlags.left | _PrintfFlags.alternate | _PrintfFlags.zero,
    'a' || 'A' || 'e' || 'E' || 'f' || 'F' || 'g' || 'G' =>
      _PrintfFlags.left |
      _PrintfFlags.sign |
      _PrintfFlags.space |
      _PrintfFlags.alternate |
      _PrintfFlags.zero,
    '%' => 0,
    _ => throw StateError('Unsupported printf conversion $type.'),
  };
  ```

  `_PrintfParser._validate` вызывает только эту функцию; второй switch не
  остаётся.

- [ ] **Шаг 4: Добавить read-only seams вне hot path**

  ```dart
  Set<String> debugBraceBuiltInTypes() => _builtInTypes;

  Set<String> debugPrintfConversionTypes() => _supportedTypes;

  Map<String, Set<String>> debugPrintfFlagTokensByConversion() =>
      Map<String, Set<String>>.unmodifiable({
        for (final type in _supportedTypes)
          type: Set<String>.unmodifiable({
            for (final entry in const [
              (_PrintfFlags.left, '-'),
              (_PrintfFlags.sign, '+'),
              (_PrintfFlags.space, ' '),
              (_PrintfFlags.alternate, '#'),
              (_PrintfFlags.zero, '0'),
            ])
              if ((_allowedPrintfFlags(type) & entry.$1) != 0) entry.$2,
          }),
      });
  ```

  Каждая seam получает doc comment «test seam, deliberately not exported by
  `format.dart`». Коллекции строятся только при вызове тестом; production
  форматирование не получает новую eager map.

- [ ] **Шаг 5: Получить GREEN на трёх runtime**

  ```sh
  rtk dart test test/format_reference_contract_test.dart
  rtk dart test -p node test/format_reference_contract_test.dart
  rtk dart test -p node -c dart2wasm -x no-dart2wasm \
    test/format_reference_contract_test.dart
  ```

  Expected: every generated call has exact output/runtimeType; both inventory
  comparisons PASS on VM, dart2js and dart2wasm.

- [ ] **Шаг 6: Проверить отсутствие public API drift**

  Run:

  ```sh
  rtk rg -n 'debugBraceBuiltInTypes|debugPrintfConversionTypes|debugPrintfFlagTokensByConversion' lib/format.dart
  rtk dart test test/api_test.dart test/printf_parser_test.dart \
    test/parser_test.dart test/format_reference_contract_test.dart
  ```

  Expected: `rg` не находит exports; parser/API/conformance tests PASS.

- [ ] **Шаг 7: Выполнить полный gate и закоммитить Task 3**

  В handoff записать изменение только internal seam, результаты трёх runtime и
  quick-матриц. При GREEN:

  ```sh
  rtk git add -A ':(exclude)docs/backlog.md'
  rtk git commit -m 'test: bind format reference to parser inventories'
  ```

---

### Задача 4: Общий generated-artifacts gate и завершение пункта

**Файлы:**
- Изменить: `tool/verify_generated_artifacts.dart`
- Изменить: `tool/test/format_reference_generator_test.dart`
- Изменить: `docs/handoff.md`
- Изменить рабочую копию: `docs/backlog.md`

**Интерфейсы:**
- Потребляет:
  `generateFormatReferenceArtifacts(mode: FormatReferenceGenerationMode.check)`.
- Производит: один обязательный verifier, который ловит stale README и stale
  conformance projection без записи в checkout.

- [ ] **Шаг 1: Закрепить non-writing check на scratch artifact set**

  В generator test после успешного `write` изменить только английский
  generated block на `stale`, сохранить снимки всех трёх файлов, вызвать
  `check` и проверить:

  ```dart
  expect(stale, contains('README.md'));
  expect(await english.readAsString(), englishBeforeCheck);
  expect(await russian.readAsString(), russianBeforeCheck);
  expect(await cases.readAsString(), casesBeforeCheck);
  ```

  Затем отдельно испортить `test/support/format_reference_cases.dart` и
  ожидать его relative path. Это доказывает обе стороны интеграции до правки
  общего verifier.

- [ ] **Шаг 2: Запустить targeted test**

  Run: `rtk dart test tool/test/format_reference_generator_test.dart`

  Expected: PASS для library check; общий verifier ещё не вызывает его.

- [ ] **Шаг 3: Подключить reference check к общему verifier**

  Импортировать `src/format_reference_generator.dart`, выполнить check до
  внешних Python/C++ генераторов и добавить каждый stale path в общий
  `failures` как:

  ```dart
  final staleReference = await generateFormatReferenceArtifacts(
    root: Directory.current,
    mode: FormatReferenceGenerationMode.check,
  );
  failures.addAll(
    staleReference.map(
      (path) => '$path is out of date: run '
          '`dart run tool/generate_format_reference.dart --write`.',
    ),
  );
  ```

  Верхний комментарий verifier больше не говорит «three files»: он перечисляет
  Python fixtures, identifier table, C++ fixture, два README-блока и Dart
  conformance projection. `--self-test` остаётся без внешних инструментов.

- [ ] **Шаг 4: Проверить оба entry point на чистом дереве**

  ```sh
  rtk dart run tool/generate_format_reference.dart --check
  rtk dart run tool/verify_generated_artifacts.dart
  rtk dart run tool/verify_generated_artifacts.dart --self-test
  ```

  Expected: три exit 0; ни одна команда не меняет `git status --short`.

- [ ] **Шаг 5: Закрыть документационное состояние**

  В design `[9]` поставить статус «реализован» только после всех критериев.
  В handoff записать:

  - созданные source/generated файлы;
  - число conformance cases и semantic rows из фактического каталога;
  - exact test/runtime/coverage/matrix результаты;
  - отсутствие public behavior/version/baseline change;
  - отсутствие открытого owner backlog после удаления выполненного пункта.

  Удалить второй пункт из `docs/backlog.md`. Так как он был незакоммиченным
  owner edit поверх пустого файла в `HEAD`, итоговый `rtk git diff --
  docs/backlog.md` должен быть пуст; выполнить отдельный
  `rtk git add docs/backlog.md` и убедиться, что staged diff не содержит чужой
  истории.

- [ ] **Шаг 6: Выполнить финальный полный gate**

  Выполнить весь блок «Полный gate перед каждым implementation-коммитом» после
  последней документационной правки. Дополнительно:

  ```sh
  rtk dart run tool/generate_format_reference.dart --check
  rtk git diff --check
  rtk git status --short
  ```

  Expected: всё GREEN, generated artifacts совпадают, backlog не имеет diff.

- [ ] **Шаг 7: Закоммитить интеграцию и проверить итог**

  ```sh
  rtk git add -A ':(exclude)docs/backlog.md'
  rtk git add docs/backlog.md
  rtk git diff --cached --check
  rtk git commit -m 'chore: verify generated format reference'
  rtk git status --short
  ```

  Expected: commit создан прямо в `main`; рабочее дерево чисто; в staged/commit
  нет performance baseline, версии, зависимостей или публичных exports.

---

## Финальная приёмка

- Оба README содержат полный generated reference в одинаковом semantic order.
- Ни одна старая ручная presentation/conversion matrix не осталась второй
  копией.
- Все catalog outcomes выполняются через public API на VM, dart2js и
  dart2wasm с точным runtimeType ошибки.
- Brace type set, printf conversion set и printf flag table совпадают с parser
  seams.
- `--check` и общий verifier ловят stale README и stale generated test data,
  не меняя checkout.
- Pub-архив анализируется и запускает conformance test без `/tool` и
  `README.ru.md`.
- Полный gate GREEN, coverage ≥ 94%, quick-матрицы GREEN.
- Второй owner backlog пункт удалён только после выполнения всех предыдущих
  условий; handoff указывает следующую реально открытую работу.
