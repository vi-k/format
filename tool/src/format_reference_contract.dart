import 'format_reference_model.dart';

const formatReferenceContract = FormatReferenceContract(
  brace: DialectContract(
    dialect: ReferenceDialect.brace,
    title: LocalizedText('Brace format reference', 'Справочник brace-формата'),
    grammar: [
      GrammarRule(
        id: 'brace.template',
        syntax: 'template = (literal | "{{" | "}}" | replacement_field)*',
        text: LocalizedText(
          'Doubled braces emit literals.',
          'Удвоенные скобки дают литералы.',
        ),
        evidence: RuleEvidence(successCaseIds: ['brace.escape.output']),
      ),
      GrammarRule(
        id: 'brace.field',
        syntax:
            'replacement_field = "{" field_name? lookup* conversion? '
            'format_spec? "}"',
        text: LocalizedText(
          'Field parts have this order.',
          'Части поля идут только в этом порядке.',
        ),
        evidence: RuleEvidence(
          successCaseIds: ['brace.positional.output'],
          failureCaseIds: ['brace.identifier.error'],
          requiresFailureCase: true,
        ),
      ),
      GrammarRule(
        id: 'brace.root',
        syntax: 'field_name = decimal_index | python_identifier',
        text: LocalizedText(
          'Empty is automatic; Python Unicode decimal digits are positional; '
              'an identifier is named.',
          'Пустое имя автоматическое; десятичные Unicode-цифры Python '
              'позиционные; identifier именованный.',
        ),
        evidence: RuleEvidence(
          successCaseIds: [
            'brace.positional.output',
            'brace.unicode_index.output',
          ],
          failureCaseIds: ['brace.identifier.error'],
          requiresFailureCase: true,
        ),
      ),
      GrammarRule(
        id: 'brace.lookup',
        syntax: 'lookup = "." python_identifier | "[" item_key "]"',
        text: LocalizedText(
          'Unicode identifier attributes and non-empty unquoted item chains.',
          'Unicode-identifier атрибуты и цепочки непустых некавыченных ключей.',
        ),
        evidence: RuleEvidence(
          successCaseIds: ['brace.lookup.output', 'brace.item_text.output'],
          failureCaseIds: ['brace.item_quote.error'],
          requiresFailureCase: true,
        ),
      ),
      GrammarRule(
        id: 'brace.numbering',
        syntax: 'automatic xor manual positional numbering',
        text: LocalizedText(
          'Automatic and numeric roots never mix.',
          'Автоматическая и числовая ручная нумерация не смешиваются.',
        ),
        evidence: RuleEvidence(
          successCaseIds: ['brace.positional.output'],
          failureCaseIds: ['brace.numbering.error'],
          requiresFailureCase: true,
        ),
      ),
      GrammarRule(
        id: 'brace.conversion',
        syntax: 'conversion = "!" ("s" | "r" | "a")',
        text: LocalizedText(
          'Conversion precedes the specification.',
          'Конверсия стоит до спецификации.',
        ),
        evidence: RuleEvidence(
          successCaseIds: [
            'brace.convert_s.output',
            'brace.convert_r.output',
            'brace.convert_a.output',
          ],
          failureCaseIds: ['brace.convert_unknown.error'],
          requiresFailureCase: true,
        ),
      ),
      GrammarRule(
        id: 'brace.nesting',
        syntax: 'format_spec may contain replacement_field at depth 1',
        text: LocalizedText(
          'One nested level; nested specifications cannot nest again.',
          'Один вложенный уровень без следующего.',
        ),
        evidence: RuleEvidence(
          successCaseIds: ['brace.nested.output'],
          failureCaseIds: ['brace.nested_depth.error'],
          requiresFailureCase: true,
        ),
      ),
      GrammarRule(
        id: 'brace.specification',
        syntax:
            '[[fill]align][sign]["z"]["#"]["0"][width][grouping]'
            '["." (precision [grouping] | '
            'grouping)][type | custom_name [":" payload]]',
        text: LocalizedText('Exact option order.', 'Точный порядок опций.'),
        evidence: RuleEvidence(
          successCaseIds: ['brace.sign_zero.output'],
          failureCaseIds: ['brace.option_order.error'],
          requiresFailureCase: true,
        ),
      ),
      GrammarRule(
        id: 'brace.custom',
        syntax:
            'custom_name = ASCII_LETTER (ASCII_LETTER | ASCII_DIGIT | "_")*',
        text: LocalizedText(
          'Built-ins reserved, payload follows colon.',
          'Встроенные имена зарезервированы, payload идёт после двоеточия.',
        ),
        evidence: RuleEvidence(
          successCaseIds: ['brace.custom_explicit.output'],
          failureCaseIds: ['brace.custom_syntax.error'],
          requiresFailureCase: true,
        ),
      ),
    ],
    options: [
      OptionContract(
        id: 'brace.fill_align',
        tokens: ['<', '>', '^', '='],
        order: 1,
        meaning: LocalizedText(
          'Fill with one text unit and align left, right, center, or after '
              'the sign.',
          'Заполнить одной текстовой единицей и выровнять влево, '
              'вправо, по центру или после знака.',
        ),
        defaultValue: LocalizedText(
          'Text and custom output align left; numbers align right. Zero '
              'implies sign-aware alignment when align is absent.',
          'Текст и собственный результат выравниваются влево, числа '
              'вправо; `0` без align включает выравнивание после знака.',
        ),
        appliesTo: [
          ValueCategory.text,
          ValueCategory.integer,
          ValueCategory.floating,
          ValueCategory.custom,
        ],
        evidence: RuleEvidence(
          successCaseIds: [
            'brace.text.output',
            'brace.sign_zero.output',
            'brace.custom_explicit.output',
          ],
          failureCaseIds: ['brace.custom_align.error'],
          requiresFailureCase: true,
        ),
      ),
      OptionContract(
        id: 'brace.sign',
        tokens: ['+', '-', ' '],
        order: 2,
        meaning: LocalizedText(
          'Select the sign for numeric output.',
          'Выбрать знак числового результата.',
        ),
        defaultValue: LocalizedText('Minus only.', 'Только минус.'),
        appliesTo: [
          ValueCategory.integer,
          ValueCategory.floating,
          ValueCategory.custom,
        ],
        evidence: RuleEvidence(
          successCaseIds: ['brace.sign_zero.output'],
          failureCaseIds: ['brace.sign.error'],
          requiresFailureCase: true,
        ),
      ),
      OptionContract(
        id: 'brace.negative_zero',
        tokens: ['z'],
        order: 3,
        meaning: LocalizedText(
          'Remove the minus when rounding produces zero.',
          'Убрать минус, когда округление даёт ноль.',
        ),
        defaultValue: LocalizedText(
          'Off; clears a sign only after rounding to zero.',
          'Выключено; убирает знак только после округления до нуля.',
        ),
        appliesTo: [ValueCategory.floating, ValueCategory.custom],
        evidence: RuleEvidence(
          successCaseIds: ['brace.negative_zero.output'],
          failureCaseIds: ['brace.negative_zero.error'],
          requiresFailureCase: true,
        ),
      ),
      OptionContract(
        id: 'brace.alternate',
        tokens: ['#'],
        order: 4,
        meaning: LocalizedText(
          'Request a radix prefix or decimal point.',
          'Запросить префикс системы счисления или десятичную точку.',
        ),
        defaultValue: LocalizedText(
          'Off; a radix prefix or forced decimal point, with no visible '
              'prefix for decimal integers.',
          'Выключено; префикс системы счисления или обязательная '
              'десятичная точка, без видимого префикса у десятичного целого.',
        ),
        appliesTo: [
          ValueCategory.integer,
          ValueCategory.floating,
          ValueCategory.custom,
        ],
        evidence: RuleEvidence(
          successCaseIds: ['brace.alternate.output'],
          failureCaseIds: ['brace.alternate.error'],
          requiresFailureCase: true,
        ),
      ),
      OptionContract(
        id: 'brace.zero',
        tokens: ['0'],
        order: 5,
        meaning: LocalizedText(
          'Request sign-aware numeric zero padding.',
          'Запросить числовое дополнение нулями после знака.',
        ),
        defaultValue: LocalizedText(
          'Off; numeric sign-aware zero padding, passed through to a custom '
              'formatter.',
          'Выключено; числовое дополнение нулями после знака '
              'передаётся собственному форматтеру.',
        ),
        appliesTo: [
          ValueCategory.integer,
          ValueCategory.floating,
          ValueCategory.custom,
        ],
        evidence: RuleEvidence(
          successCaseIds: ['brace.sign_zero.output'],
          failureCaseIds: ['brace.text_zero.error'],
          requiresFailureCase: true,
        ),
      ),
      OptionContract(
        id: 'brace.width',
        tokens: ['ASCII_DIGIT+'],
        order: 6,
        meaning: LocalizedText(
          'Set the minimum field width.',
          'Задать минимальную ширину поля.',
        ),
        defaultValue: LocalizedText(
          'Absent; range 0…100000.',
          'Не задана; диапазон 0…100000.',
        ),
        appliesTo: [
          ValueCategory.text,
          ValueCategory.integer,
          ValueCategory.floating,
          ValueCategory.custom,
        ],
        evidence: RuleEvidence(
          successCaseIds: ['brace.option_limit.output'],
          failureCaseIds: ['brace.option_limit.error'],
          requiresFailureCase: true,
        ),
      ),
      OptionContract(
        id: 'brace.integer_grouping',
        tokens: [',', '_'],
        order: 7,
        meaning: LocalizedText(
          'Group integer digits with comma or underscore.',
          'Группировать целые цифры запятой или подчёркиванием.',
        ),
        defaultValue: LocalizedText(
          'Absent; comma is decimal-only, underscore supports every '
              'non-locale radix, and custom formatters '
              'receive only this separator.',
          'Не задана; запятая только для десятичного целого, подчёркивание '
              'для всех нелокальных систем счисления; собственный форматтер '
              'получает только этот разделитель.',
        ),
        appliesTo: [
          ValueCategory.integer,
          ValueCategory.floating,
          ValueCategory.custom,
        ],
        evidence: RuleEvidence(
          successCaseIds: [
            'brace.integer_grouping.output',
            'brace.radix_grouping.output',
          ],
          failureCaseIds: ['brace.grouping.error'],
          requiresFailureCase: true,
        ),
      ),
      OptionContract(
        id: 'brace.precision',
        tokens: ['.ASCII_DIGIT+'],
        order: 8,
        meaning: LocalizedText(
          'Truncate text or control numeric precision.',
          'Обрезать текст или задать точность числа.',
        ),
        defaultValue: LocalizedText(
          'Absent; truncates text, controls numeric digits, and passes an '
              'integer value to a custom formatter.',
          'Не задана; обрезает текст, управляет цифрами числа и передаёт '
              'целое значение собственному форматтеру.',
        ),
        appliesTo: [
          ValueCategory.text,
          ValueCategory.floating,
          ValueCategory.custom,
        ],
        evidence: RuleEvidence(
          successCaseIds: ['brace.text.output'],
          failureCaseIds: ['brace.integer_precision.error'],
          requiresFailureCase: true,
        ),
      ),
      OptionContract(
        id: 'brace.fraction_grouping',
        tokens: ['.,', '._', 'precision suffix ,', 'precision suffix _'],
        order: 9,
        meaning: LocalizedText(
          'Group fractional digits after rounding.',
          'Группировать дробные цифры после округления.',
        ),
        defaultValue: LocalizedText(
          'Absent; accepted syntactically but not exposed to custom '
              'formatters.',
          'Не задана; синтаксически принимается, но не передаётся '
              'собственному форматтеру.',
        ),
        appliesTo: [ValueCategory.floating],
        evidence: RuleEvidence(
          successCaseIds: [
            'brace.fraction_grouping.output',
            'brace.fraction_default.output',
          ],
          failureCaseIds: ['brace.fraction_grouping.error'],
          requiresFailureCase: true,
        ),
      ),
      OptionContract(
        id: 'brace.type',
        tokens: ['built-in letter', 'custom_name'],
        order: 10,
        meaning: LocalizedText(
          'Select a built-in presentation or custom formatter.',
          'Выбрать встроенное представление или собственный форматтер.',
        ),
        defaultValue: LocalizedText(
          'Inferred from the value when empty.',
          'При пустом значении выводится из типа значения.',
        ),
        appliesTo: [ValueCategory.any],
        evidence: RuleEvidence(
          successCaseIds: ['brace.type.none.output', 'brace.type.d.output'],
        ),
      ),
      OptionContract(
        id: 'brace.payload',
        tokens: [':balanced specification text'],
        order: 11,
        meaning: LocalizedText(
          'Pass resolved text after the custom formatter name.',
          'Передать разрешённый текст после имени собственного форматтера.',
        ),
        defaultValue: LocalizedText(
          'Absent differs from empty; nested fields resolve before the '
              'callback.',
          'Отсутствие отличается от пустого текста; вложенные поля '
              'разрешаются до callback.',
        ),
        appliesTo: [ValueCategory.custom],
        evidence: RuleEvidence(
          successCaseIds: [
            'brace.balanced_payload.output',
            'brace.custom_explicit.output',
          ],
          failureCaseIds: ['brace.unbalanced_payload.error'],
          requiresFailureCase: true,
        ),
      ),
    ],
    types: _braceTypes,
  ),
  printf: DialectContract(
    dialect: ReferenceDialect.printf,
    title: LocalizedText(
      'Printf format reference',
      'Справочник printf-формата',
    ),
    grammar: _printfGrammar,
    options: _printfOptions,
    types: _printfTypes,
  ),
  limits: _limits,
  errors: _errors,
  cases: _cases,
);

const _braceLayoutOptions = ['brace.fill_align', 'brace.width', 'brace.type'];

const _excludeSignAlignment = {
  'brace.fill_align': ['='],
};

const _excludeCommaGrouping = {
  'brace.integer_grouping': [','],
};

const _integerAndFloating = [ValueCategory.integer, ValueCategory.floating];

const _emptyPresentationOptionAppliesTo = {
  'brace.fill_align': [
    ValueCategory.text,
    ValueCategory.integer,
    ValueCategory.floating,
  ],
  'brace.sign': _integerAndFloating,
  'brace.negative_zero': [ValueCategory.floating],
  'brace.alternate': _integerAndFloating,
  'brace.zero': _integerAndFloating,
  'brace.width': [
    ValueCategory.text,
    ValueCategory.integer,
    ValueCategory.floating,
  ],
  'brace.integer_grouping': _integerAndFloating,
  'brace.precision': [ValueCategory.text, ValueCategory.floating],
  'brace.fraction_grouping': [ValueCategory.floating],
};

const _emptyPresentationTokenAppliesTo = {'=': _integerAndFloating};

const _promotedFloatingOptionAppliesTo = {
  'brace.negative_zero': _integerAndFloating,
  'brace.precision': _integerAndFloating,
  'brace.fraction_grouping': _integerAndFloating,
};

const _braceNumericOptions = [
  'brace.fill_align',
  'brace.sign',
  'brace.alternate',
  'brace.zero',
  'brace.width',
  'brace.integer_grouping',
  'brace.type',
];

const _braceFloatingOptions = [
  'brace.fill_align',
  'brace.sign',
  'brace.negative_zero',
  'brace.alternate',
  'brace.zero',
  'brace.width',
  'brace.integer_grouping',
  'brace.precision',
  'brace.fraction_grouping',
  'brace.type',
];

const _braceTypes = <TypeContract>[
  TypeContract(
    id: 'brace.none',
    tokens: [''],
    accepts: [ValueCategory.any],
    optionIds: [
      'brace.fill_align',
      'brace.sign',
      'brace.negative_zero',
      'brace.alternate',
      'brace.zero',
      'brace.width',
      'brace.integer_grouping',
      'brace.precision',
      'brace.fraction_grouping',
      'brace.type',
    ],
    optionAppliesTo: _emptyPresentationOptionAppliesTo,
    tokenAppliesTo: _emptyPresentationTokenAppliesTo,
    result: LocalizedText(
      'Value-default text or one matching custom formatter.',
      'Текст значения по умолчанию или единственный подходящий форматтер.',
    ),
    defaultPrecision: LocalizedText(
      'Depends on the value type.',
      'зависит от типа значения',
    ),
    evidence: RuleEvidence(successCaseIds: ['brace.type.none.output']),
  ),
  TypeContract(
    id: 'brace.string',
    tokens: ['s'],
    accepts: [ValueCategory.text],
    optionIds: [
      'brace.fill_align',
      'brace.width',
      'brace.precision',
      'brace.type',
    ],
    excludedOptionTokens: _excludeSignAlignment,
    result: LocalizedText(
      'Text, optionally truncated.',
      'Текст, при необходимости обрезанный.',
    ),
    defaultPrecision: LocalizedText('Not specified.', 'не задана'),
    deepLink: LocalizedText('#text-formatting', '#форматирование-текста'),
    evidence: RuleEvidence(
      successCaseIds: ['brace.type.s.output'],
      failureCaseIds: ['brace.type.s.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'brace.character',
    tokens: ['c'],
    accepts: [ValueCategory.integer],
    optionIds: _braceLayoutOptions,
    excludedOptionTokens: _excludeSignAlignment,
    result: LocalizedText('One Unicode scalar.', 'Один скаляр Unicode.'),
    defaultPrecision: LocalizedText('Not specified.', 'не задана'),
    deepLink: LocalizedText('#character-values', '#символьные-значения'),
    evidence: RuleEvidence(
      successCaseIds: ['brace.type.c.output'],
      failureCaseIds: ['brace.type.c.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'brace.decimal',
    tokens: ['d'],
    accepts: [ValueCategory.integer],
    optionIds: _braceNumericOptions,
    result: LocalizedText('Exact decimal integer.', 'Точное десятичное целое.'),
    defaultPrecision: LocalizedText('Not specified.', 'не задана'),
    evidence: RuleEvidence(
      successCaseIds: ['brace.type.d.output'],
      failureCaseIds: ['brace.type.d.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'brace.binary',
    tokens: ['b'],
    accepts: [ValueCategory.integer],
    optionIds: _braceNumericOptions,
    excludedOptionTokens: _excludeCommaGrouping,
    result: LocalizedText('Exact binary integer.', 'Точное двоичное целое.'),
    defaultPrecision: LocalizedText('Not specified.', 'не задана'),
    evidence: RuleEvidence(
      successCaseIds: ['brace.type.b.output'],
      failureCaseIds: ['brace.type.b.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'brace.octal',
    tokens: ['o'],
    accepts: [ValueCategory.integer],
    optionIds: _braceNumericOptions,
    excludedOptionTokens: _excludeCommaGrouping,
    result: LocalizedText('Exact octal integer.', 'Точное восьмеричное целое.'),
    defaultPrecision: LocalizedText('Not specified.', 'не задана'),
    evidence: RuleEvidence(
      successCaseIds: ['brace.type.o.output'],
      failureCaseIds: ['brace.type.o.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'brace.hex',
    tokens: ['x', 'X'],
    accepts: [ValueCategory.integer],
    optionIds: _braceNumericOptions,
    excludedOptionTokens: _excludeCommaGrouping,
    result: LocalizedText(
      'Exact lower- or uppercase hexadecimal integer.',
      'Точное шестнадцатеричное целое в нижнем или верхнем регистре.',
    ),
    defaultPrecision: LocalizedText('Not specified.', 'не задана'),
    evidence: RuleEvidence(
      successCaseIds: ['brace.type.x.output', 'brace.type.upper_x.output'],
      failureCaseIds: ['brace.type.x.error', 'brace.type.upper_x.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'brace.locale_number',
    tokens: ['n'],
    accepts: [ValueCategory.integer, ValueCategory.floating],
    optionIds: [
      'brace.fill_align',
      'brace.sign',
      'brace.negative_zero',
      'brace.alternate',
      'brace.zero',
      'brace.width',
      'brace.precision',
      'brace.type',
    ],
    result: LocalizedText(
      'Locale-aware decimal or general number.',
      'Десятичное или общее число с учётом локали.',
    ),
    defaultPrecision: LocalizedText(
      'Floating values use the general default.',
      'Для плавающих значений действует точность общего формата.',
    ),
    deepLink: LocalizedText('#number-locales', '#числовые-локали'),
    evidence: RuleEvidence(
      successCaseIds: ['brace.type.n.output'],
      failureCaseIds: ['brace.type.n.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'brace.fixed',
    tokens: ['f', 'F'],
    accepts: [ValueCategory.integer, ValueCategory.floating],
    optionIds: _braceFloatingOptions,
    optionAppliesTo: _promotedFloatingOptionAppliesTo,
    result: LocalizedText(
      'Fixed-point number.',
      'Число с фиксированной точкой.',
    ),
    defaultPrecision: LocalizedText('6 fractional digits', '6 дробных цифр'),
    deepLink: LocalizedText(
      '#double-formatting-profiles',
      '#профили-форматирования-double',
    ),
    evidence: RuleEvidence(
      successCaseIds: ['brace.type.f.output', 'brace.type.upper_f.output'],
      failureCaseIds: ['brace.type.f.error', 'brace.type.upper_f.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'brace.scientific',
    tokens: ['e', 'E'],
    accepts: [ValueCategory.integer, ValueCategory.floating],
    optionIds: _braceFloatingOptions,
    optionAppliesTo: _promotedFloatingOptionAppliesTo,
    result: LocalizedText('Scientific notation.', 'Научная запись.'),
    defaultPrecision: LocalizedText(
      'SDK shortest exponent or compatible precision 6',
      'кратчайшая экспонента SDK или точность 6 в compatible-профиле',
    ),
    deepLink: LocalizedText(
      '#double-formatting-profiles',
      '#профили-форматирования-double',
    ),
    evidence: RuleEvidence(
      successCaseIds: ['brace.type.e.output', 'brace.type.upper_e.output'],
      failureCaseIds: ['brace.type.e.error', 'brace.type.upper_e.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'brace.general',
    tokens: ['g', 'G'],
    accepts: [ValueCategory.integer, ValueCategory.floating],
    optionIds: _braceFloatingOptions,
    optionAppliesTo: _promotedFloatingOptionAppliesTo,
    result: LocalizedText(
      'General decimal notation.',
      'Общая десятичная запись.',
    ),
    defaultPrecision: LocalizedText(
      'SDK shortest or compatible significant precision 6',
      'кратчайшая запись SDK или 6 значащих цифр в compatible-профиле',
    ),
    deepLink: LocalizedText(
      '#double-formatting-profiles',
      '#профили-форматирования-double',
    ),
    evidence: RuleEvidence(
      successCaseIds: ['brace.type.g.output', 'brace.type.upper_g.output'],
      failureCaseIds: ['brace.type.g.error', 'brace.type.upper_g.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'brace.percent',
    tokens: ['%'],
    accepts: [ValueCategory.integer, ValueCategory.floating],
    optionIds: _braceFloatingOptions,
    optionAppliesTo: _promotedFloatingOptionAppliesTo,
    result: LocalizedText(
      'Value multiplied by 100 with a percent suffix.',
      'Значение, умноженное на 100, со знаком процента.',
    ),
    defaultPrecision: LocalizedText('6 fractional digits', '6 дробных цифр'),
    deepLink: LocalizedText(
      '#double-formatting-profiles',
      '#профили-форматирования-double',
    ),
    evidence: RuleEvidence(
      successCaseIds: ['brace.type.percent.output'],
      failureCaseIds: ['brace.type.percent.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'brace.custom_type',
    tokens: ['ASCII name'],
    accepts: [ValueCategory.custom],
    optionIds: [
      'brace.fill_align',
      'brace.sign',
      'brace.negative_zero',
      'brace.alternate',
      'brace.zero',
      'brace.width',
      'brace.integer_grouping',
      'brace.precision',
      'brace.type',
      'brace.payload',
    ],
    excludedOptionTokens: _excludeSignAlignment,
    result: LocalizedText(
      'Custom callback output with engine-applied layout.',
      'Результат callback с раскладкой, применённой движком.',
    ),
    defaultPrecision: LocalizedText('Not specified.', 'не задана'),
    deepLink: LocalizedText('#custom-formatters', '#собственные-форматтеры'),
    evidence: RuleEvidence(
      successCaseIds: [
        'brace.custom_explicit.output',
        'brace.custom_automatic.output',
      ],
      failureCaseIds: ['brace.custom_value.error'],
      requiresFailureCase: true,
    ),
  ),
];

const _printfGrammar = <GrammarRule>[
  GrammarRule(
    id: 'printf.template',
    syntax: 'template = (literal | conversion)*',
    text: LocalizedText(
      'Percent begins every conversion.',
      'Процент начинает каждую конверсию.',
    ),
    evidence: RuleEvidence(
      successCaseIds: ['printf.percent.output'],
      failureCaseIds: ['printf.grammar.error'],
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'printf.conversion',
    syntax: 'conversion = "%" flags width? precision? type',
    text: LocalizedText('Fixed order.', 'Фиксированный порядок.'),
    evidence: RuleEvidence(
      successCaseIds: ['printf.dynamic.output'],
      failureCaseIds: ['printf.grammar.error'],
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'printf.flags',
    syntax: 'flags = ("-" | "+" | " " | "#" | "0")*',
    text: LocalizedText(
      'Repeats collapse; `+` beats space, `-` beats zero.',
      'Повторы схлопываются; `+` сильнее пробела, `-` сильнее нуля.',
    ),
    evidence: RuleEvidence(
      successCaseIds: [
        'printf.repeat_precedence.output',
        'printf.left_zero.output',
      ],
      failureCaseIds: ['printf.flag.error'],
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'printf.width',
    syntax: 'width = ASCII_DIGIT+ | "*"',
    text: LocalizedText(
      'Dynamic width is consumed before precision and value.',
      'Динамическая ширина потребляется до точности и значения.',
    ),
    evidence: RuleEvidence(
      successCaseIds: ['printf.dynamic.output'],
      failureCaseIds: ['printf.dynamic_missing.error'],
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'printf.precision',
    syntax: 'precision = "." (ASCII_DIGIT* | "*")',
    text: LocalizedText(
      'Empty is zero; negative dynamic precision is absent.',
      'Пустая равна нулю, отрицательная динамическая отсутствует.',
    ),
    evidence: RuleEvidence(
      successCaseIds: [
        'printf.empty_precision.output',
        'printf.negative_precision.output',
      ],
      failureCaseIds: ['printf.precision_character.error'],
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'printf.omissions',
    syntax: r'no "$" positions; no h/l/j/z/t/L modifiers',
    text: LocalizedText(
      'Unsupported C/POSIX syntax is rejected.',
      'Неподдержанный синтаксис C/POSIX отвергается.',
    ),
    evidence: RuleEvidence(
      successCaseIds: ['printf.type.d.output'],
      failureCaseIds: ['printf.length.error', 'printf.position.error'],
      requiresFailureCase: true,
    ),
  ),
];

const _printfOptions = <OptionContract>[
  OptionContract(
    id: 'printf.left',
    tokens: ['-'],
    order: 1,
    meaning: LocalizedText(
      'Left-align the converted value.',
      'Выровнять преобразованное значение влево.',
    ),
    defaultValue: LocalizedText(
      'Right alignment for every value conversion.',
      'Выравнивание вправо для всех конверсий значения.',
    ),
    appliesTo: [ValueCategory.any],
    evidence: RuleEvidence(
      successCaseIds: ['printf.left_zero.output'],
      failureCaseIds: ['printf.percent_option.error'],
      requiresFailureCase: true,
    ),
  ),
  OptionContract(
    id: 'printf.sign',
    tokens: ['+'],
    order: 2,
    meaning: LocalizedText(
      'Show a plus sign for a non-negative signed value.',
      'Показывать плюс у неотрицательного знакового значения.',
    ),
    defaultValue: LocalizedText('Minus only.', 'Только минус.'),
    appliesTo: [ValueCategory.integer, ValueCategory.floating],
    evidence: RuleEvidence(
      successCaseIds: ['printf.repeat_precedence.output'],
      failureCaseIds: ['printf.sign_character.error'],
      requiresFailureCase: true,
    ),
  ),
  OptionContract(
    id: 'printf.space',
    tokens: [' '],
    order: 3,
    meaning: LocalizedText(
      'Prefix a non-negative signed value with a space.',
      'Ставить пробел перед неотрицательным знаковым значением.',
    ),
    defaultValue: LocalizedText(
      'Off; ignored when `+` exists.',
      'Выключено; игнорируется при наличии `+`.',
    ),
    appliesTo: [ValueCategory.integer, ValueCategory.floating],
    evidence: RuleEvidence(
      successCaseIds: [
        'printf.space.output',
        'printf.repeat_precedence.output',
      ],
      failureCaseIds: ['printf.sign_character.error'],
      requiresFailureCase: true,
    ),
  ),
  OptionContract(
    id: 'printf.alternate',
    tokens: ['#'],
    order: 4,
    meaning: LocalizedText(
      "Request the conversion's alternate form.",
      'Запросить альтернативную форму конверсии.',
    ),
    defaultValue: LocalizedText('Off.', 'Выключено.'),
    appliesTo: [ValueCategory.integer, ValueCategory.floating],
    evidence: RuleEvidence(
      successCaseIds: [
        'printf.alternate_octal.output',
        'printf.alternate_hex.output',
      ],
      failureCaseIds: ['printf.alternate_decimal.error'],
      requiresFailureCase: true,
    ),
  ),
  OptionContract(
    id: 'printf.zero',
    tokens: ['0'],
    order: 5,
    meaning: LocalizedText(
      'Pad a numeric conversion with zeros.',
      'Дополнить числовую конверсию нулями.',
    ),
    defaultValue: LocalizedText(
      'Off; disabled by `-`, and for integers by precision.',
      'Выключено; отключается `-`, а для целых ещё и точностью.',
    ),
    appliesTo: [ValueCategory.integer, ValueCategory.floating],
    evidence: RuleEvidence(
      successCaseIds: ['printf.zero.output', 'printf.left_zero.output'],
      failureCaseIds: ['printf.zero_string.error'],
      requiresFailureCase: true,
    ),
  ),
  OptionContract(
    id: 'printf.width',
    tokens: ['ASCII_DIGIT+', '*'],
    order: 6,
    meaning: LocalizedText(
      'Set literal or argument-supplied minimum width.',
      'Задать литеральную или полученную из аргумента минимальную ширину.',
    ),
    defaultValue: LocalizedText(
      'Absent for every value conversion; `%%` forbids it.',
      'Не задана для всех конверсий значения; `%%` её запрещает.',
    ),
    appliesTo: [ValueCategory.any],
    evidence: RuleEvidence(
      successCaseIds: ['printf.dynamic.output'],
      failureCaseIds: ['printf.percent_option.error'],
      requiresFailureCase: true,
    ),
  ),
  OptionContract(
    id: 'printf.precision',
    tokens: ['.ASCII_DIGIT*', '.*'],
    order: 7,
    meaning: LocalizedText(
      'Set literal or argument-supplied precision.',
      'Задать литеральную или полученную из аргумента точность.',
    ),
    defaultValue: LocalizedText(
      'Absent for text, integer, and floating conversions; `%c` and `%%` '
          'forbid it.',
      'Не задана для текстовых, целочисленных и плавающих '
          'конверсий; `%c` и `%%` её запрещают.',
    ),
    appliesTo: [
      ValueCategory.text,
      ValueCategory.integer,
      ValueCategory.floating,
    ],
    evidence: RuleEvidence(
      successCaseIds: [
        'printf.string_precision.output',
        'printf.integer_precision.output',
      ],
      failureCaseIds: ['printf.precision_character.error'],
      requiresFailureCase: true,
    ),
  ),
];

const _printfLayoutOptions = ['printf.left', 'printf.width'];

const _printfSignedOptions = [
  'printf.left',
  'printf.sign',
  'printf.space',
  'printf.zero',
  'printf.width',
  'printf.precision',
];

const _printfRadixOptions = [
  'printf.left',
  'printf.alternate',
  'printf.zero',
  'printf.width',
  'printf.precision',
];

const _printfFloatingOptions = [
  'printf.left',
  'printf.sign',
  'printf.space',
  'printf.alternate',
  'printf.zero',
  'printf.width',
  'printf.precision',
];

const _printfTypes = <TypeContract>[
  TypeContract(
    id: 'printf.string',
    tokens: ['s'],
    accepts: [ValueCategory.any],
    optionIds: ['printf.left', 'printf.width', 'printf.precision'],
    result: LocalizedText(
      '`toString()` text, optionally truncated.',
      'Текст `toString()`, при необходимости обрезанный.',
    ),
    defaultPrecision: LocalizedText('Not specified.', 'не задана'),
    deepLink: LocalizedText(
      '#unicode-text-units',
      '#единицы-измерения-текста-в-unicode',
    ),
    evidence: RuleEvidence(successCaseIds: ['printf.type.s.output']),
  ),
  TypeContract(
    id: 'printf.character',
    tokens: ['c'],
    accepts: [ValueCategory.integer],
    optionIds: _printfLayoutOptions,
    result: LocalizedText('One Unicode scalar.', 'Один скаляр Unicode.'),
    defaultPrecision: LocalizedText('Not specified.', 'не задана'),
    deepLink: LocalizedText('#character-values', '#символьные-значения'),
    evidence: RuleEvidence(
      successCaseIds: ['printf.type.c.output'],
      failureCaseIds: ['printf.type.c.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'printf.signed',
    tokens: ['d', 'i'],
    accepts: [ValueCategory.integer],
    optionIds: _printfSignedOptions,
    result: LocalizedText(
      'Signed decimal integer.',
      'Знаковое десятичное целое.',
    ),
    defaultPrecision: LocalizedText(
      'No leading precision zeros.',
      'Без ведущих нулей точности.',
    ),
    deepLink: LocalizedText('#sprintf', '#sprintf'),
    evidence: RuleEvidence(
      successCaseIds: ['printf.type.d.output', 'printf.type.i.output'],
      failureCaseIds: ['printf.type.d.error', 'printf.type.i.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'printf.unsigned_decimal',
    tokens: ['u'],
    accepts: [ValueCategory.nonNegativeInteger],
    optionIds: [
      'printf.left',
      'printf.zero',
      'printf.width',
      'printf.precision',
    ],
    result: LocalizedText(
      'Non-negative decimal integer.',
      'Неотрицательное десятичное целое.',
    ),
    defaultPrecision: LocalizedText(
      'No leading precision zeros.',
      'Без ведущих нулей точности.',
    ),
    deepLink: LocalizedText('#sprintf', '#sprintf'),
    evidence: RuleEvidence(
      successCaseIds: ['printf.type.u.output'],
      failureCaseIds: ['printf.type.u.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'printf.octal',
    tokens: ['o'],
    accepts: [ValueCategory.nonNegativeInteger],
    optionIds: _printfRadixOptions,
    result: LocalizedText(
      'Non-negative octal integer.',
      'Неотрицательное восьмеричное целое.',
    ),
    defaultPrecision: LocalizedText(
      'No leading precision zeros.',
      'Без ведущих нулей точности.',
    ),
    deepLink: LocalizedText('#sprintf', '#sprintf'),
    evidence: RuleEvidence(
      successCaseIds: ['printf.type.o.output'],
      failureCaseIds: ['printf.type.o.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'printf.hex',
    tokens: ['x', 'X'],
    accepts: [ValueCategory.nonNegativeInteger],
    optionIds: _printfRadixOptions,
    result: LocalizedText(
      'Non-negative hexadecimal integer.',
      'Неотрицательное шестнадцатеричное целое.',
    ),
    defaultPrecision: LocalizedText(
      'No leading precision zeros.',
      'Без ведущих нулей точности.',
    ),
    deepLink: LocalizedText('#sprintf', '#sprintf'),
    evidence: RuleEvidence(
      successCaseIds: ['printf.type.x.output', 'printf.type.upper_x.output'],
      failureCaseIds: ['printf.type.x.error', 'printf.type.upper_x.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'printf.fixed',
    tokens: ['f', 'F'],
    accepts: [ValueCategory.floating],
    optionIds: _printfFloatingOptions,
    result: LocalizedText(
      'Fixed-point double.',
      '`double` с фиксированной точкой.',
    ),
    defaultPrecision: LocalizedText('6 fractional digits', '6 дробных цифр'),
    deepLink: LocalizedText(
      '#double-formatting-profiles',
      '#профили-форматирования-double',
    ),
    evidence: RuleEvidence(
      successCaseIds: ['printf.type.f.output', 'printf.type.upper_f.output'],
      failureCaseIds: ['printf.type.f.error', 'printf.type.upper_f.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'printf.scientific',
    tokens: ['e', 'E'],
    accepts: [ValueCategory.floating],
    optionIds: _printfFloatingOptions,
    result: LocalizedText('Scientific double.', '`double` в научной записи.'),
    defaultPrecision: LocalizedText(
      'SDK exponent spelling when absent, otherwise requested; compatible '
          'default 6',
      'Без точности запись экспоненты SDK, иначе запрошенная; '
          'в compatible-профиле по умолчанию 6',
    ),
    deepLink: LocalizedText(
      '#double-formatting-profiles',
      '#профили-форматирования-double',
    ),
    evidence: RuleEvidence(
      successCaseIds: ['printf.type.e.output', 'printf.type.upper_e.output'],
      failureCaseIds: ['printf.type.e.error', 'printf.type.upper_e.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'printf.general',
    tokens: ['g', 'G'],
    accepts: [ValueCategory.floating],
    optionIds: _printfFloatingOptions,
    result: LocalizedText(
      'General decimal double.',
      '`double` в общей десятичной записи.',
    ),
    defaultPrecision: LocalizedText(
      'SDK `toString` when absent; compatible significant precision 6',
      'Без точности `toString` SDK; в compatible-профиле 6 значащих цифр',
    ),
    deepLink: LocalizedText(
      '#double-formatting-profiles',
      '#профили-форматирования-double',
    ),
    evidence: RuleEvidence(
      successCaseIds: ['printf.type.g.output', 'printf.type.upper_g.output'],
      failureCaseIds: ['printf.type.g.error', 'printf.type.upper_g.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'printf.hex_float',
    tokens: ['a', 'A'],
    accepts: [ValueCategory.floating],
    optionIds: _printfFloatingOptions,
    result: LocalizedText(
      'Exact hexadecimal binary64 notation.',
      'Точная шестнадцатеричная запись binary64.',
    ),
    defaultPrecision: LocalizedText(
      'Exact trimmed notation',
      'точная сокращённая запись',
    ),
    deepLink: LocalizedText(
      '#double-formatting-profiles',
      '#профили-форматирования-double',
    ),
    evidence: RuleEvidence(
      successCaseIds: ['printf.type.a.output', 'printf.type.upper_a.output'],
      failureCaseIds: ['printf.type.a.error', 'printf.type.upper_a.error'],
      requiresFailureCase: true,
    ),
  ),
  TypeContract(
    id: 'printf.percent',
    tokens: ['%'],
    accepts: [ValueCategory.none],
    optionIds: [],
    result: LocalizedText(
      'Literal percent; no value consumed.',
      'Литеральный процент; значение не потребляется.',
    ),
    defaultPrecision: LocalizedText('Not specified.', 'не задана'),
    deepLink: LocalizedText('#sprintf', '#sprintf'),
    evidence: RuleEvidence(
      successCaseIds: ['printf.type.percent.output'],
      failureCaseIds: ['printf.percent_option.error'],
      requiresFailureCase: true,
    ),
  ),
];

const _limits = <GrammarRule>[
  GrammarRule(
    id: 'limit.option',
    syntax: 'brace and printf literal width/precision ≤ 100000',
    text: LocalizedText('Safe option size', 'Безопасный размер опции'),
    evidence: RuleEvidence(
      successCaseIds: [
        'brace.option_limit.output',
        'printf.option_limit.output',
        'printf.precision_limit.output',
      ],
      failureCaseIds: [
        'brace.option_limit.error',
        'printf.option_limit.error',
        'printf.precision_limit.error',
      ],
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'limit.dynamic_width',
    syntax:
        'printf dynamic width −100000…100000; negative means left alignment',
    text: LocalizedText('Dynamic width', 'Динамическая ширина'),
    evidence: RuleEvidence(
      successCaseIds: [
        'printf.dynamic_width_limit.output',
        'printf.dynamic_width_lower.output',
      ],
      failureCaseIds: [
        'printf.dynamic_limit.error',
        'printf.dynamic_width_lower.error',
      ],
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'limit.dynamic_precision',
    syntax:
        'printf dynamic precision ≤ 100000; every negative value means absent',
    text: LocalizedText('Dynamic precision', 'Динамическая точность'),
    evidence: RuleEvidence(
      successCaseIds: [
        'printf.dynamic_precision_limit.output',
        'printf.negative_precision.output',
      ],
      failureCaseIds: ['printf.dynamic_precision_limit.error'],
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'limit.fill_units',
    syntax: 'width * fill.length ≤ 200000 UTF-16 code units',
    text: LocalizedText('Fill expansion', 'Расширение заполнителя'),
    evidence: RuleEvidence(
      successCaseIds: ['brace.fill_limit.output'],
      failureCaseIds: ['brace.fill_limit.error'],
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'limit.index',
    syntax: 'brace positional and numeric item index ≤ 9223372036854775807',
    text: LocalizedText('Field indexes', 'Индексы полей'),
    evidence: RuleEvidence(
      successCaseIds: ['brace.index.output'],
      failureCaseIds: ['brace.index_max.error', 'brace.index_over.error'],
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'limit.nesting',
    syntax: 'one nested replacement-field level',
    text: LocalizedText('Nesting depth', 'Глубина вложенности'),
    evidence: RuleEvidence(
      successCaseIds: ['brace.nested.output'],
      failureCaseIds: ['brace.nested_depth.error'],
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'limit.dart_precision',
    syntax: 'Dart profile: general/empty/`n` 1…21; `f`/`e`/`%` 0…20',
    text: LocalizedText('Dart-profile precision', 'Точность Dart-профиля'),
    evidence: RuleEvidence(
      successCaseIds: ['brace.type.g.output'],
      failureCaseIds: ['brace.dart_precision.error'],
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'limit.compatible_precision',
    syntax: 'compatible profile accepts 0…100000; `g` precision 0 behaves as 1',
    text: LocalizedText(
      'Compatible-profile precision',
      'Точность compatible-профиля',
    ),
    evidence: RuleEvidence(
      successCaseIds: [
        'brace.compatible_precision.output',
        'brace.compatible_precision_limit.output',
      ],
      failureCaseIds: ['brace.compatible_precision_limit.error'],
      requiresFailureCase: true,
    ),
  ),
];

const _errors = <GrammarRule>[
  GrammarRule(
    id: 'error.grammar',
    syntax: 'InvalidFormatException',
    text: LocalizedText('Malformed template', 'Неправильный шаблон'),
    evidence: RuleEvidence(
      successCaseIds: [],
      failureCaseIds: ['brace.numbering.error', 'printf.grammar.error'],
      requiresSuccessCase: false,
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'error.options',
    syntax: 'InvalidSpecifierException',
    text: LocalizedText('Inapplicable options', 'Неприменимые опции'),
    evidence: RuleEvidence(
      successCaseIds: [],
      failureCaseIds: ['brace.sign.error', 'printf.flag.error'],
      requiresSuccessCase: false,
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'error.value',
    syntax: 'UnsupportedFormatValueException',
    text: LocalizedText('Unsupported value', 'Неподдержанное значение'),
    evidence: RuleEvidence(
      successCaseIds: [],
      failureCaseIds: [
        'brace.character_value.error',
        'printf.dynamic_type.error',
      ],
      requiresSuccessCase: false,
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'error.conversion',
    syntax: 'UnsupportedConversionException',
    text: LocalizedText(
      'Unsupported brace conversion',
      'Неподдержанная brace-конверсия',
    ),
    evidence: RuleEvidence(
      successCaseIds: [],
      failureCaseIds: ['brace.convert_unknown.error'],
      requiresSuccessCase: false,
      requiresFailureCase: true,
    ),
  ),
  GrammarRule(
    id: 'error.argument',
    syntax: 'MissingFormatArgumentException',
    text: LocalizedText('Missing argument', 'Отсутствующий аргумент'),
    evidence: RuleEvidence(
      successCaseIds: [],
      failureCaseIds: ['brace.missing.error', 'printf.value_missing.error'],
      requiresSuccessCase: false,
      requiresFailureCase: true,
    ),
  ),
];

const _cases = <ConformanceCase>[
  ConformanceCase(
    id: 'brace.escape.output',
    call: PublicCall.format,
    dartExpression: "format('{{x}}')",
    expected: OutputOutcome('{x}'),
  ),
  ConformanceCase(
    id: 'brace.positional.output',
    call: PublicCall.format,
    dartExpression: "format('{1}/{0}', 'a', 'b')",
    expected: OutputOutcome('b/a'),
  ),
  ConformanceCase(
    id: 'brace.lookup.output',
    call: PublicCall.formatWith,
    dartExpression:
        "formatWith('{user.items[1]}', named: const "
        "{'user': {'items': ['a', 'b']}})",
    expected: OutputOutcome('b'),
  ),
  ConformanceCase(
    id: 'brace.item_text.output',
    call: PublicCall.formatWith,
    dartExpression:
        "formatWith('{record[any key]}', named: const "
        "{'record': {'any key': 'ok'}})",
    expected: OutputOutcome('ok'),
  ),
  ConformanceCase(
    id: 'brace.item_quote.error',
    call: PublicCall.formatWith,
    dartExpression:
        "formatWith('{record[\"any key\"]}', named: const "
        "{'record': {'any key': 'ok'}})",
    expected: ErrorOutcome(FormattingErrorKind.invalidFormat),
  ),
  ConformanceCase(
    id: 'brace.unicode_index.output',
    call: PublicCall.formatWith,
    dartExpression: "formatWith('{١}', positional: const ['zero', 'one'])",
    expected: OutputOutcome('one'),
  ),
  ConformanceCase(
    id: 'brace.numbering.error',
    call: PublicCall.format,
    dartExpression: "format('{} {0}', 1, 2)",
    expected: ErrorOutcome(FormattingErrorKind.invalidFormat),
  ),
  ConformanceCase(
    id: 'brace.identifier.error',
    call: PublicCall.formatWith,
    dartExpression: "formatWith('{ name }', named: const {'name': 1})",
    expected: ErrorOutcome(FormattingErrorKind.invalidFormat),
  ),
  ConformanceCase(
    id: 'brace.convert_s.output',
    call: PublicCall.format,
    dartExpression: "format('{!s}', null)",
    expected: OutputOutcome('null'),
  ),
  ConformanceCase(
    id: 'brace.convert_r.output',
    call: PublicCall.format,
    dartExpression: "format('{!r}', 'x')",
    expected: OutputOutcome("'x'"),
  ),
  ConformanceCase(
    id: 'brace.convert_a.output',
    call: PublicCall.format,
    dartExpression: "format('{!a}', 'é')",
    expected: OutputOutcome(r"'\xe9'"),
  ),
  ConformanceCase(
    id: 'brace.convert_unknown.error',
    call: PublicCall.format,
    dartExpression: "format('{!q}', 1)",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedConversion),
  ),
  ConformanceCase(
    id: 'brace.nested.output',
    call: PublicCall.format,
    dartExpression: "format('{:{}}', 'x', 3)",
    expected: OutputOutcome('x  '),
  ),
  ConformanceCase(
    id: 'brace.nested_depth.error',
    call: PublicCall.format,
    dartExpression: "format('{:{:{}}}', 'x', 3, 1)",
    expected: ErrorOutcome(FormattingErrorKind.invalidFormat),
  ),
  ConformanceCase(
    id: 'brace.balanced_payload.output',
    call: PublicCall.configuredFormat,
    dartExpression:
        "_referenceFormat.format('{:echo:a{{b}}c}', const {'value': '42'})",
    expected: OutputOutcome('a{b}c:42'),
  ),
  ConformanceCase(
    id: 'brace.unbalanced_payload.error',
    call: PublicCall.configuredFormat,
    dartExpression:
        "_referenceFormat.format('{:echo:a{{b}', const {'value': '42'})",
    expected: ErrorOutcome(FormattingErrorKind.invalidFormat),
  ),
  ConformanceCase(
    id: 'brace.missing.error',
    call: PublicCall.format,
    dartExpression: "format('{}')",
    expected: ErrorOutcome(FormattingErrorKind.missingArgument),
  ),
  ConformanceCase(
    id: 'brace.text.output',
    call: PublicCall.format,
    dartExpression: "format('{:*^5.3s}', 'abcdef')",
    expected: OutputOutcome('*abc*'),
  ),
  ConformanceCase(
    id: 'brace.sign.error',
    call: PublicCall.format,
    dartExpression: "format('{:+s}', 'abc')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.alternate.error',
    call: PublicCall.format,
    dartExpression: "format('{:#s}', 'abc')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.text_zero.error',
    call: PublicCall.format,
    dartExpression: "format('{:05s}', 'abc')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.character.output',
    call: PublicCall.format,
    dartExpression: "format('{:>3c}', 65)",
    expected: OutputOutcome('  A'),
  ),
  ConformanceCase(
    id: 'brace.character_precision.error',
    call: PublicCall.format,
    dartExpression: "format('{:.1c}', 65)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.character_value.error',
    call: PublicCall.format,
    dartExpression: "format('{:c}', 0xD800)",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'brace.sign_zero.output',
    call: PublicCall.format,
    dartExpression: "format('{:+08d}', 42)",
    expected: OutputOutcome('+0000042'),
  ),
  ConformanceCase(
    id: 'brace.alternate.output',
    call: PublicCall.format,
    dartExpression: "format('{:#x}', 42)",
    expected: OutputOutcome('0x2a'),
  ),
  ConformanceCase(
    id: 'brace.integer_grouping.output',
    call: PublicCall.format,
    dartExpression: "format('{:,d}', 1234567)",
    expected: OutputOutcome('1,234,567'),
  ),
  ConformanceCase(
    id: 'brace.radix_grouping.output',
    call: PublicCall.format,
    dartExpression: "format('{:_x}', 0xabcdef)",
    expected: OutputOutcome('ab_cdef'),
  ),
  ConformanceCase(
    id: 'brace.grouping.error',
    call: PublicCall.format,
    dartExpression: "format('{:,x}', 42)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.integer_precision.error',
    call: PublicCall.format,
    dartExpression: "format('{:.2d}', 42)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.negative_zero.error',
    call: PublicCall.format,
    dartExpression: "format('{:zd}', 42)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.fraction_grouping.error',
    call: PublicCall.format,
    dartExpression: "format('{:.,d}', 42)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.option_order.error',
    call: PublicCall.format,
    dartExpression: "format('{:10+d}', 42)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.negative_zero.output',
    call: PublicCall.format,
    dartExpression: "format('{:z.2f}', -0.001)",
    expected: OutputOutcome('0.00'),
  ),
  ConformanceCase(
    id: 'brace.fraction_grouping.output',
    call: PublicCall.format,
    dartExpression: "format('{:.6_f}', 1234.5678)",
    expected: OutputOutcome('1234.567_800'),
  ),
  ConformanceCase(
    id: 'brace.fraction_default.output',
    call: PublicCall.configuredFormat,
    dartExpression:
        'Format(doubleFormatMode: '
        "DoubleFormatMode.compatible).format('{:.,f}', 1234.5678)",
    expected: OutputOutcome('1234.567,800'),
  ),
  ConformanceCase(
    id: 'brace.dart_precision.error',
    call: PublicCall.format,
    dartExpression: "format('{:.22g}', 1.0)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.compatible_precision.output',
    call: PublicCall.configuredFormat,
    dartExpression:
        'Format(doubleFormatMode: '
        "DoubleFormatMode.compatible).format('{:.21f}', 0.1)",
    expected: OutputOutcome('0.100000000000000005551'),
  ),
  ConformanceCase(
    id: 'brace.compatible_precision_limit.output',
    call: PublicCall.configuredFormat,
    dartExpression:
        'Format(doubleFormatMode: '
        "DoubleFormatMode.compatible).format('{:.100000f}', "
        '0.0).length.toString()',
    expected: OutputOutcome('100002'),
  ),
  ConformanceCase(
    id: 'brace.compatible_precision_limit.error',
    call: PublicCall.configuredFormat,
    dartExpression:
        'Format(doubleFormatMode: '
        "DoubleFormatMode.compatible).format('{:.100001f}', 0.0)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.option_limit.output',
    call: PublicCall.format,
    dartExpression: "format('{:100000d}', 1).length.toString()",
    expected: OutputOutcome('100000'),
  ),
  ConformanceCase(
    id: 'brace.option_limit.error',
    call: PublicCall.format,
    dartExpression: "format('{:100001d}', 1)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.fill_limit.output',
    call: PublicCall.configuredFormat,
    dartExpression:
        'Format(textUnit: '
        "TextUnit.graphemeClusters).format('{:😀>100000s}', "
        "'x').length.toString()",
    expected: OutputOutcome('199999'),
  ),
  ConformanceCase(
    id: 'brace.fill_limit.error',
    call: PublicCall.configuredFormat,
    dartExpression:
        'Format(textUnit: '
        "TextUnit.graphemeClusters).format('{:👩‍🔬>100000s}', 'x')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.index.output',
    call: PublicCall.formatWith,
    dartExpression: "formatWith('{1}', positional: const ['zero', 'one'])",
    expected: OutputOutcome('one'),
  ),
  ConformanceCase(
    id: 'brace.index_max.error',
    call: PublicCall.formatWith,
    dartExpression: "formatWith('{9223372036854775807}')",
    expected: ErrorOutcome(FormattingErrorKind.missingArgument),
  ),
  ConformanceCase(
    id: 'brace.index_over.error',
    call: PublicCall.formatWith,
    dartExpression: "formatWith('{9223372036854775808}')",
    expected: ErrorOutcome(FormattingErrorKind.invalidFormat),
  ),
  ConformanceCase(
    id: 'brace.custom_explicit.output',
    call: PublicCall.configuredFormat,
    dartExpression:
        "_referenceFormat.format('{:*^10echo:tag}', const {'value': '42'})",
    expected: OutputOutcome('**tag:42**'),
  ),
  ConformanceCase(
    id: 'brace.custom_automatic.output',
    call: PublicCall.configuredFormat,
    dartExpression: "_referenceFormat.format('{}', const {'value': '42'})",
    expected: OutputOutcome('42'),
  ),
  ConformanceCase(
    id: 'brace.custom_value.error',
    call: PublicCall.configuredFormat,
    dartExpression: "_referenceFormat.format('{:echo}', 42)",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'brace.custom_align.error',
    call: PublicCall.configuredFormat,
    dartExpression:
        "_referenceFormat.format('{:=8echo}', const {'value': '42'})",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.custom_syntax.error',
    call: PublicCall.configuredFormat,
    dartExpression:
        "_referenceFormat.format('{:echo!bad}', const {'value': '42'})",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.custom_missing.error',
    call: PublicCall.format,
    dartExpression: "format('{:missing}', 42)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.custom_fraction.output',
    call: PublicCall.configuredFormat,
    dartExpression:
        "_referenceFormat.format('{:.,echo:tag}', const {'value': '42'})",
    expected: OutputOutcome('tag:42'),
  ),
  ConformanceCase(
    id: 'brace.type.none.output',
    call: PublicCall.format,
    dartExpression: "format('{}', true)",
    expected: OutputOutcome('true'),
  ),
  ConformanceCase(
    id: 'brace.type.s.output',
    call: PublicCall.format,
    dartExpression: "format('{:s}', 'text')",
    expected: OutputOutcome('text'),
  ),
  ConformanceCase(
    id: 'brace.type.s.error',
    call: PublicCall.format,
    dartExpression: "format('{:s}', 42)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.type.c.output',
    call: PublicCall.format,
    dartExpression: "format('{:c}', BigInt.from(65))",
    expected: OutputOutcome('A'),
  ),
  ConformanceCase(
    id: 'brace.type.c.error',
    call: PublicCall.format,
    dartExpression: "format('{:c}', 'A')",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'brace.type.d.output',
    call: PublicCall.format,
    dartExpression: "format('{:d}', BigInt.from(42))",
    expected: OutputOutcome('42'),
  ),
  ConformanceCase(
    id: 'brace.type.d.error',
    call: PublicCall.format,
    dartExpression: "format('{:d}', '42')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.type.b.output',
    call: PublicCall.format,
    dartExpression: "format('{:b}', 42)",
    expected: OutputOutcome('101010'),
  ),
  ConformanceCase(
    id: 'brace.type.b.error',
    call: PublicCall.format,
    dartExpression: "format('{:b}', '42')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.type.o.output',
    call: PublicCall.format,
    dartExpression: "format('{:o}', 42)",
    expected: OutputOutcome('52'),
  ),
  ConformanceCase(
    id: 'brace.type.o.error',
    call: PublicCall.format,
    dartExpression: "format('{:o}', '42')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.type.x.output',
    call: PublicCall.format,
    dartExpression: "format('{:x}', 42)",
    expected: OutputOutcome('2a'),
  ),
  ConformanceCase(
    id: 'brace.type.x.error',
    call: PublicCall.format,
    dartExpression: "format('{:x}', '42')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.type.upper_x.output',
    call: PublicCall.format,
    dartExpression: "format('{:X}', 42)",
    expected: OutputOutcome('2A'),
  ),
  ConformanceCase(
    id: 'brace.type.upper_x.error',
    call: PublicCall.format,
    dartExpression: "format('{:X}', '42')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.type.n.output',
    call: PublicCall.format,
    dartExpression: "format('{:n}', 2.5)",
    expected: OutputOutcome('2.5'),
  ),
  ConformanceCase(
    id: 'brace.type.n.error',
    call: PublicCall.format,
    dartExpression: "format('{:n}', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.type.f.output',
    call: PublicCall.format,
    dartExpression: "format('{:.1f}', 2)",
    expected: OutputOutcome('2.0'),
  ),
  ConformanceCase(
    id: 'brace.type.f.error',
    call: PublicCall.format,
    dartExpression: "format('{:f}', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.type.upper_f.output',
    call: PublicCall.format,
    dartExpression: "format('{:.1F}', 2.5)",
    expected: OutputOutcome('2.5'),
  ),
  ConformanceCase(
    id: 'brace.type.upper_f.error',
    call: PublicCall.format,
    dartExpression: "format('{:F}', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.type.e.output',
    call: PublicCall.format,
    dartExpression: "format('{:.1e}', BigInt.from(12))",
    expected: OutputOutcome('1.2e+1'),
  ),
  ConformanceCase(
    id: 'brace.type.e.error',
    call: PublicCall.format,
    dartExpression: "format('{:e}', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.type.upper_e.output',
    call: PublicCall.format,
    dartExpression: "format('{:E}', 2.5)",
    expected: OutputOutcome('2.5E+0'),
  ),
  ConformanceCase(
    id: 'brace.type.upper_e.error',
    call: PublicCall.format,
    dartExpression: "format('{:E}', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.type.g.output',
    call: PublicCall.format,
    dartExpression: "format('{:g}', 2.5)",
    expected: OutputOutcome('2.5'),
  ),
  ConformanceCase(
    id: 'brace.type.g.error',
    call: PublicCall.format,
    dartExpression: "format('{:g}', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.type.upper_g.output',
    call: PublicCall.format,
    dartExpression: "format('{:G}', 2.5)",
    expected: OutputOutcome('2.5'),
  ),
  ConformanceCase(
    id: 'brace.type.upper_g.error',
    call: PublicCall.format,
    dartExpression: "format('{:G}', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'brace.type.percent.output',
    call: PublicCall.format,
    dartExpression: "format('{:%}', 2.5)",
    expected: OutputOutcome('250.000000%'),
  ),
  ConformanceCase(
    id: 'brace.type.percent.error',
    call: PublicCall.format,
    dartExpression: "format('{:%}', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'printf.percent.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('x%%y')",
    expected: OutputOutcome('x%y'),
  ),
  ConformanceCase(
    id: 'printf.empty_precision.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%.f', 1.5)",
    expected: OutputOutcome('2'),
  ),
  ConformanceCase(
    id: 'printf.repeat_precedence.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%++ d', 42)",
    expected: OutputOutcome('+42'),
  ),
  ConformanceCase(
    id: 'printf.space.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('% d', 42)",
    expected: OutputOutcome(' 42'),
  ),
  ConformanceCase(
    id: 'printf.zero.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%05d', 42)",
    expected: OutputOutcome('00042'),
  ),
  ConformanceCase(
    id: 'printf.left_zero.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%-05d', 42)",
    expected: OutputOutcome('42   '),
  ),
  ConformanceCase(
    id: 'printf.dynamic.output',
    call: PublicCall.vsprintf,
    dartExpression: "vsprintf('%*.*f', const [8, 2, 1.5])",
    expected: OutputOutcome('    1.50'),
  ),
  ConformanceCase(
    id: 'printf.negative_width.output',
    call: PublicCall.vsprintf,
    dartExpression: "vsprintf('%*s', const [-4, 'x'])",
    expected: OutputOutcome('x   '),
  ),
  ConformanceCase(
    id: 'printf.negative_precision.output',
    call: PublicCall.vsprintf,
    dartExpression: "vsprintf('%.*s', const [-1, 'abc'])",
    expected: OutputOutcome('abc'),
  ),
  ConformanceCase(
    id: 'printf.dynamic_missing.error',
    call: PublicCall.vsprintf,
    dartExpression: "vsprintf('%*s', const [])",
    expected: ErrorOutcome(FormattingErrorKind.missingArgument),
  ),
  ConformanceCase(
    id: 'printf.dynamic_type.error',
    call: PublicCall.vsprintf,
    dartExpression: "vsprintf('%*s', const ['4', 'x'])",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.flag.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%+u', 1)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'printf.sign_character.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%+c', 65)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'printf.alternate_decimal.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%#d', 1)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'printf.zero_string.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%05s', 'x')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'printf.precision_character.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%.1c', 65)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'printf.grammar.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%q', 1)",
    expected: ErrorOutcome(FormattingErrorKind.invalidFormat),
  ),
  ConformanceCase(
    id: 'printf.length.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%llx', 1)",
    expected: ErrorOutcome(FormattingErrorKind.invalidFormat),
  ),
  ConformanceCase(
    id: 'printf.position.error',
    call: PublicCall.sprintf,
    dartExpression: r"sprintf(r'%2$d', 1)",
    expected: ErrorOutcome(FormattingErrorKind.invalidFormat),
  ),
  ConformanceCase(
    id: 'printf.ascii_digit.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%١d', 1)",
    expected: ErrorOutcome(FormattingErrorKind.invalidFormat),
  ),
  ConformanceCase(
    id: 'printf.percent_option.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%1%')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'printf.integer_precision.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%05.3d', 42)",
    expected: OutputOutcome('  042'),
  ),
  ConformanceCase(
    id: 'printf.alternate_octal.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%#o', 42)",
    expected: OutputOutcome('052'),
  ),
  ConformanceCase(
    id: 'printf.alternate_hex.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%#x', 42)",
    expected: OutputOutcome('0x2a'),
  ),
  ConformanceCase(
    id: 'printf.string_precision.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%.3s', 'abcdef')",
    expected: OutputOutcome('abc'),
  ),
  ConformanceCase(
    id: 'printf.option_limit.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%100000d', 1).length.toString()",
    expected: OutputOutcome('100000'),
  ),
  ConformanceCase(
    id: 'printf.option_limit.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%100001d', 1)",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'printf.precision_limit.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%.100000s', 'x')",
    expected: OutputOutcome('x'),
  ),
  ConformanceCase(
    id: 'printf.precision_limit.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%.100001s', 'x')",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'printf.dynamic_width_limit.output',
    call: PublicCall.vsprintf,
    dartExpression: "vsprintf('%*s', const [100000, 'x']).length.toString()",
    expected: OutputOutcome('100000'),
  ),
  ConformanceCase(
    id: 'printf.dynamic_width_lower.output',
    call: PublicCall.vsprintf,
    dartExpression: "vsprintf('%*s', const [-100000, 'x']).length.toString()",
    expected: OutputOutcome('100000'),
  ),
  ConformanceCase(
    id: 'printf.dynamic_limit.error',
    call: PublicCall.vsprintf,
    dartExpression: "vsprintf('%*s', const [100001, 'x'])",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'printf.dynamic_width_lower.error',
    call: PublicCall.vsprintf,
    dartExpression: "vsprintf('%*s', const [-100001, 'x'])",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'printf.dynamic_precision_limit.output',
    call: PublicCall.vsprintf,
    dartExpression: "vsprintf('%.*s', const [100000, 'x'])",
    expected: OutputOutcome('x'),
  ),
  ConformanceCase(
    id: 'printf.dynamic_precision_limit.error',
    call: PublicCall.vsprintf,
    dartExpression: "vsprintf('%.*s', const [100001, 'x'])",
    expected: ErrorOutcome(FormattingErrorKind.invalidSpecifier),
  ),
  ConformanceCase(
    id: 'printf.value_missing.error',
    call: PublicCall.vsprintf,
    dartExpression: "vsprintf('%d %s', const [1])",
    expected: ErrorOutcome(FormattingErrorKind.missingArgument),
  ),
  ConformanceCase(
    id: 'printf.type.s.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%s', true)",
    expected: OutputOutcome('true'),
  ),
  ConformanceCase(
    id: 'printf.type.c.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%c', BigInt.from(65))",
    expected: OutputOutcome('A'),
  ),
  ConformanceCase(
    id: 'printf.type.c.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%c', 'A')",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.d.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%d', BigInt.from(-42))",
    expected: OutputOutcome('-42'),
  ),
  ConformanceCase(
    id: 'printf.type.d.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%d', '42')",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.i.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%i', -42)",
    expected: OutputOutcome('-42'),
  ),
  ConformanceCase(
    id: 'printf.type.i.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%i', '42')",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.u.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%u', 42)",
    expected: OutputOutcome('42'),
  ),
  ConformanceCase(
    id: 'printf.type.u.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%u', -1)",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.o.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%o', 42)",
    expected: OutputOutcome('52'),
  ),
  ConformanceCase(
    id: 'printf.type.o.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%o', -1)",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.x.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%x', 42)",
    expected: OutputOutcome('2a'),
  ),
  ConformanceCase(
    id: 'printf.type.x.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%x', -1)",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.upper_x.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%X', 42)",
    expected: OutputOutcome('2A'),
  ),
  ConformanceCase(
    id: 'printf.type.upper_x.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%X', -1)",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.f.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%f', 2.5)",
    expected: OutputOutcome('2.500000'),
  ),
  ConformanceCase(
    id: 'printf.type.f.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%f', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.upper_f.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%F', 2.5)",
    expected: OutputOutcome('2.500000'),
  ),
  ConformanceCase(
    id: 'printf.type.upper_f.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%F', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.e.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%e', 2.5)",
    expected: OutputOutcome('2.5e+0'),
  ),
  ConformanceCase(
    id: 'printf.type.e.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%e', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.upper_e.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%E', 2.5)",
    expected: OutputOutcome('2.5E+0'),
  ),
  ConformanceCase(
    id: 'printf.type.upper_e.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%E', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.g.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%g', 2.5)",
    expected: OutputOutcome('2.5'),
  ),
  ConformanceCase(
    id: 'printf.type.g.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%g', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.upper_g.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%G', 2.5)",
    expected: OutputOutcome('2.5'),
  ),
  ConformanceCase(
    id: 'printf.type.upper_g.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%G', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.a.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%a', 2.5)",
    expected: OutputOutcome('0x1.4p+1'),
  ),
  ConformanceCase(
    id: 'printf.type.a.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%a', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.upper_a.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%A', 2.5)",
    expected: OutputOutcome('0X1.4P+1'),
  ),
  ConformanceCase(
    id: 'printf.type.upper_a.error',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%A', '2.5')",
    expected: ErrorOutcome(FormattingErrorKind.unsupportedValue),
  ),
  ConformanceCase(
    id: 'printf.type.percent.output',
    call: PublicCall.sprintf,
    dartExpression: "sprintf('%%', 1)",
    expected: OutputOutcome('%'),
  ),
];
