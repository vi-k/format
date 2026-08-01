import 'package:format/format.dart';
import 'package:test/test.dart';

final class _ProbeFormatter extends Formatter<Object?> {
  @override
  String get specifier => 'json';

  @override
  bool canFormat(Object? value) => value is int;

  @override
  String format(Object? value, FormatOptions options) =>
      '${options.payload}:$value';
}

final class _OptionsFormatter extends Formatter<int> {
  @override
  String get specifier => 'options';

  @override
  bool canFormat(Object? value) => value is int;

  @override
  String format(int value, FormatOptions options) => [
    options.sign,
    options.normalizeNegativeZero,
    options.alternate,
    options.zero,
    options.grouping,
    options.precision,
    options.payload,
  ].join('|');
}

final class _AutomaticFormatter extends Formatter<_Value> {
  @override
  String get specifier => 'auto';

  @override
  bool canFormat(Object? value) => value is _Value;

  @override
  String format(_Value value, FormatOptions options) => 'auto:${value.name}';
}

final class _NamedFormatter extends Formatter<Object?> {
  @override
  final String specifier;

  _NamedFormatter(this.specifier);

  @override
  bool canFormat(Object? value) => true;

  @override
  String format(Object? value, FormatOptions options) => '$specifier:$value';
}

final class _ThrowingCanFormat extends Formatter<_Value> {
  @override
  String get specifier => 'throwsCan';

  @override
  bool canFormat(Object? value) => throw StateError('canFormat failed');

  @override
  String format(_Value value, FormatOptions options) => 'unreachable';
}

final class _ThrowingFormat extends Formatter<_Value> {
  @override
  String get specifier => 'throwsFormat';

  @override
  bool canFormat(Object? value) => value is _Value;

  @override
  String format(_Value value, FormatOptions options) =>
      throw StateError('format failed');
}

final class _FormattingErrorFormatter extends Formatter<_Value> {
  @override
  String get specifier => 'typed';

  @override
  bool canFormat(Object? value) => value is _Value;

  @override
  String format(_Value value, FormatOptions options) =>
      throw UnsupportedFormatValueException(
        const FormatExceptionContext(specifier: 'inner'),
        value,
      );
}

final class _Value {
  final String name;

  const _Value(this.name);

  @override
  String toString() => 'value:$name';
}

final class _ThrowingToString {
  @override
  String toString() => throw StateError('toString failed');
}

void main() {
  test(
    'passes resolved payload and options to an explicit custom formatter',
    () {
      final engine = Format(formatters: [_ProbeFormatter()]);

      expect(
        engine.formatWith(
          '{value:*^12json:{mode}}',
          named: const {'value': 42, 'mode': 'pretty'},
        ),
        '*pretty:42**',
      );
    },
  );

  test('keeps empty custom payload distinct from no payload', () {
    final engine = Format(formatters: [_ProbeFormatter()]);

    expect(engine.format('{:json}', 42), 'null:42');
    expect(engine.format('{:json:}', 42), ':42');
    expect(engine.format('{:json:a:b}', 42), 'a:b:42');
  });

  test('passes every non-layout option through to a custom formatter', () {
    final engine = Format(formatters: [_OptionsFormatter()]);

    expect(
      engine.format('{:+z#08_.3options:data}', 7),
      '+|true|true|true|_|3|data',
    );
  });

  test('custom formatter owns zero while core owns width and alignment', () {
    final engine = Format(formatters: [_ProbeFormatter()]);

    expect(engine.format('{:0>12json:x}', 42), '00000000x:42');
    expect(engine.format('{:012json:x}', 42), 'x:42        ');
  });

  test('empty specifications select one automatic formatter', () {
    final engine = Format(formatters: [_AutomaticFormatter()]);

    expect(engine.format('{}', const _Value('ok')), 'auto:ok');
  });

  test('empty specifications give built-in values precedence', () {
    final engine = Format(formatters: [_NamedFormatter('custom')]);

    expect(engine.format('{}', 42), '42');
    expect(engine.format('{}', 'text'), 'text');
    expect(engine.format('{}', true), 'true');
    expect(engine.format('{}', null), 'null');
    expect(engine.format('{:custom}', 42), 'custom:42');
  });

  test('ordinary objects fall back to toString when no formatter matches', () {
    expect(format('{}', const _Value('plain')), 'value:plain');
  });

  test(
    'ambiguous automatic formatter matches report stable specifier names',
    () {
      final engine = Format(
        formatters: [_NamedFormatter('first'), _NamedFormatter('second')],
      );

      expect(
        () => engine.format('{}', const _Value('x')),
        throwsA(
          isA<AmbiguousFormatterException>().having(
            (error) => error.specifiers,
            'specifiers',
            ['first', 'second'],
          ),
        ),
      );
    },
  );

  test('explicit custom formatter rejects unknown names and values', () {
    final engine = Format(formatters: [_ProbeFormatter()]);

    expect(
      () => engine.format('{:missing}', 42),
      throwsA(isA<InvalidSpecifierException>()),
    );
    expect(
      () => engine.format('{:json}', 'text'),
      throwsA(isA<UnsupportedFormatValueException>()),
    );
  });

  test('custom syntax rejects non-payload trailing text', () {
    final engine = Format(formatters: [_ProbeFormatter()]);

    expect(
      () => engine.format('{:json!bad}', 42),
      throwsA(isA<InvalidSpecifierException>()),
    );
  });

  test('bool and null use Dart tokens but reject numeric specifications', () {
    expect(format('{}', true), 'true');
    expect(format('{}', null), 'null');
    expect(
      () => format('{:d}', true),
      throwsA(isA<UnsupportedFormatValueException>()),
    );
    expect(
      () => format('{:f}', null),
      throwsA(isA<UnsupportedFormatValueException>()),
    );
  });

  test('custom formatter callback failures retain formatting context', () {
    final canFail = Format(formatters: [_ThrowingCanFormat()]);
    final formatFail = Format(formatters: [_ThrowingFormat()]);

    expect(
      () => canFail.format('{:throwsCan}', const _Value('x')),
      throwsA(
        isA<FormatExtensionException>()
            .having((error) => error.extension, 'extension', 'throwsCan')
            .having(
              (error) => error.context.specifier,
              'specifier',
              'throwsCan',
            )
            .having((error) => error.error, 'error', isA<StateError>()),
      ),
    );
    expect(
      () => formatFail.format('{:throwsFormat}', const _Value('x')),
      throwsA(
        isA<FormatExtensionException>()
            .having((error) => error.extension, 'extension', 'throwsFormat')
            .having((error) => error.error, 'error', isA<StateError>()),
      ),
    );
  });

  test(
    'custom numeric alignment is rejected before invoking its formatter',
    () {
      final engine = Format(formatters: [_ThrowingFormat()]);

      expect(
        () => engine.format('{:=4throwsFormat}', const _Value('x')),
        throwsA(isA<InvalidSpecifierException>()),
      );
    },
  );

  test('custom numeric alignment is rejected before calling canFormat', () {
    final engine = Format(formatters: [_ThrowingCanFormat()]);

    expect(
      () => engine.format('{:=4throwsCan}', const _Value('x')),
      throwsA(isA<InvalidSpecifierException>()),
    );
  });

  test('custom formatter preserves typed formatting errors', () {
    final engine = Format(formatters: [_FormattingErrorFormatter()]);

    expect(
      () => engine.format('{:typed}', const _Value('x')),
      throwsA(isA<UnsupportedFormatValueException>()),
    );
  });

  test('fallback toString errors are wrapped as formatting errors', () {
    expect(
      () => format('{}', _ThrowingToString()),
      throwsA(
        isA<FormatExtensionException>().having(
          (error) => error.error,
          'error',
          isA<StateError>(),
        ),
      ),
    );
  });

  test('nested fields share automatic numbering with outer fields', () {
    expect(format('{:{}} {}', 'value', 8, 'tail'), 'value    tail');
  });
}
