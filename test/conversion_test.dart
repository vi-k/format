import 'package:format/format.dart';
import 'package:test/test.dart';

final class _Token {
  final String value;

  const _Token(this.value);
}

final class _TokenRepresentation extends Representation<_Token> {
  @override
  bool canRepresent(Object? value) => value is _Token;

  @override
  String represent(_Token value) => '<${value.value}>';
}

final class _NamedTokenRepresentation extends Representation<_Token> {
  final String name;

  _NamedTokenRepresentation(this.name);

  @override
  bool canRepresent(Object? value) => value is _Token;

  @override
  String represent(_Token value) => name;
}

final class _ThrowingCanRepresent extends Representation<_Token> {
  @override
  bool canRepresent(Object? value) => throw StateError('can represent failed');

  @override
  String represent(_Token value) => 'unreachable';
}

final class _ThrowingRepresent extends Representation<_Token> {
  @override
  bool canRepresent(Object? value) => value is _Token;

  @override
  String represent(_Token value) => throw StateError('represent failed');
}

final class _ThrowingToString {
  @override
  String toString() => throw StateError('to string failed');
}

final class _FormattingToString {
  static const error = InvalidSpecifierException(
    FormatExceptionContext(specifier: 'inner'),
    'inner failure',
  );

  @override
  String toString() => throw error;
}

void main() {
  test('s conversion uses Dart toString and preserves null', () {
    expect(format('{!s}', 42), '42');
    expect(format('{!s}', null), 'null');
  });

  test('r conversion follows Python quote selection', () {
    expect(format('{!r}', "a\n'b"), r'''"a\n'b"''');
    expect(format('{!r}', 'a"b'), "'a\"b'");
    expect(format('{!r}', 'a\'\'\'b"c'), "'a\\'\\'\\'b\"c'");
    expect(format('{!r}', 'plain'), "'plain'");
  });

  test('r conversion escapes Python non-printable scalars exactly', () {
    expect(
      format('{!r}', '\\\t\n\r\u0000\u001f\u007f'),
      r"'\\\t\n\r\x00\x1f\x7f'",
    );
    expect(format('{!r}', '\u2028\u200b\u00ad'), r"'\u2028\u200b\xad'");
  });

  test('r conversion represents built-in scalars deterministically', () {
    expect(format('{!r}', true), 'true');
    expect(format('{!r}', false), 'false');
    expect(format('{!r}', null), 'null');
    expect(format('{!r}', double.nan), 'nan');
    expect(format('{!r}', double.infinity), 'inf');
    expect(format('{!r}', double.negativeInfinity), '-inf');
    expect(format('{!r}', -0.0), '-0.0');
  });

  test('r and a conversions use Python shortest double spelling', () {
    expect(format('{!r}', 1e20), '1e+20');
    expect(format('{!r}', 1e-7), '1e-07');
    expect(format('{!a}', 1e20), '1e+20');
    expect(format('{!a}', 1e-7), '1e-07');
  });

  test('r conversion represents positive and negative BigInt values', () {
    expect(
      format('{!r}', BigInt.parse('123456789012345678901234567890')),
      '123456789012345678901234567890',
    );
    expect(format('{!r}', BigInt.parse('-42')), '-42');
  });

  test('a conversion keeps BigInt decimal output ASCII', () {
    expect(
      format('{!a}', BigInt.parse('-123456789012345678901234567890')),
      '-123456789012345678901234567890',
    );
  });

  test('r conversion preserves built-in container iteration order', () {
    expect(format('{!r}', [true, null, 'x']), "[true, null, 'x']");
    expect(
      format('{!r}', <String, Object?>{'second': 2, 'first': 1}),
      "{'second': 2, 'first': 1}",
    );
    expect(format('{!r}', <Object?>{'x', 2}), "{'x', 2}");
    expect(format('{!r}', <Object?>{}), 'set()');
  });

  test('r conversion dispatches custom Iterable values as extensions', () {
    final value = _OrderedValues([1, 'x']);
    final configured = Format(
      representations: [_OrderedValuesRepresentation()],
    );

    expect(
      () => format('{!r}', value),
      throwsA(isA<UnsupportedConversionException>()),
    );
    expect(configured.format('{!r}', value), '<ordered>');
  });

  test('r conversion does not iterate unsupported recursive Iterables', () {
    expect(
      () => format('{!r}', _RecursiveIterable()),
      throwsA(isA<UnsupportedConversionException>()),
    );
  });

  test('r conversion marks recursive list map set and mutual containers', () {
    final list = <Object?>[];
    list.add(list);
    final map = <String, Object?>{};
    map['self'] = map;
    final set = <Object?>{};
    set.add(set);
    final parent = <Object?>[];
    final child = <String, Object?>{'parent': parent};
    parent.add(child);

    expect(format('{!r}', list), '[[...]]');
    expect(format('{!r}', map), "{'self': {...}}");
    expect(format('{!r}', set), '{{...}}');
    expect(format('{!r}', parent), "[{'parent': [...]}]");
  });

  test('a conversion applies fixed ascii escaping after representation', () {
    expect(format('{!a}', 'Привет'), r"'\u041f\u0440\u0438\u0432\u0435\u0442'");
    expect(format('{!a}', 'é😀'), r"'\xe9\U0001f600'");
  });

  test('s conversion wraps toString failures with full field context', () {
    try {
      formatWith('prefix {item!s}', named: {'item': _ThrowingToString()});
      fail('expected extension failure');
    } on FormatExtensionException catch (error) {
      expect(error.extension, '_ThrowingToString');
      expect(error.error, isA<StateError>());
      expect(error.stackTrace, isNot(StackTrace.empty));
      expect(error.context.template, 'prefix {item!s}');
      expect(error.context.offset, 7);
      expect(error.context.fragment, '{item!s}');
      expect(error.context.conversion, 's');
    }
  });

  test('s conversion does not double-wrap FormattingException', () {
    expect(
      () => format('{!s}', _FormattingToString()),
      throwsA(same(_FormattingToString.error)),
    );
  });

  test('unknown conversion is a typed unsupported conversion error', () {
    expect(
      () => format('{!q}', 1),
      throwsA(
        isA<UnsupportedConversionException>()
            .having((error) => error.value, 'value', 1)
            .having((error) => error.context.template, 'template', '{!q}')
            .having((error) => error.context.offset, 'offset', 0)
            .having((error) => error.context.fragment, 'fragment', '{!q}')
            .having((error) => error.context.conversion, 'conversion', 'q'),
      ),
    );
  });

  for (final template in ['{!}', '{!qq}']) {
    test('missing or malformed conversion remains invalid: $template', () {
      expect(() => format(template, 1), throwsA(isA<InvalidFormatException>()));
    });
  }

  test('r conversion uses exactly one matching custom representation', () {
    final configured = Format(representations: [_TokenRepresentation()]);

    expect(configured.format('{!r}', const _Token('ok')), '<ok>');
  });

  test(
    'r conversion gives built-ins precedence over custom representations',
    () {
      final configured = Format(representations: [_MapRepresentation()]);

      expect(configured.format('{!r}', <String, int>{'x': 1}), "{'x': 1}");
    },
  );

  test('r conversion gives BigInt precedence over custom representations', () {
    final configured = Format(representations: [_BigIntRepresentation()]);

    expect(configured.format('{!r}', BigInt.from(42)), '42');
  });

  test('r conversion rejects unsupported objects', () {
    expect(
      () => formatWith('{item!r}', named: {'item': const _Token('missing')}),
      throwsA(isA<UnsupportedConversionException>()),
    );
  });

  test('r conversion rejects ambiguously represented objects stably', () {
    final configured = Format(
      representations: [
        _NamedTokenRepresentation('first'),
        _NamedTokenRepresentation('second'),
      ],
    );

    expect(
      () =>
          configured.formatWith('{item!r}', named: {'item': const _Token('x')}),
      throwsA(
        isA<AmbiguousFormatterException>().having(
          (error) => error.matches,
          'matches',
          ['_NamedTokenRepresentation', '_NamedTokenRepresentation'],
        ),
      ),
    );
  });

  test('r conversion wraps failures from custom representation callbacks', () {
    final failedCanRepresent = Format(
      representations: [_ThrowingCanRepresent()],
    );
    final failedRepresent = Format(representations: [_ThrowingRepresent()]);

    expect(
      () => failedCanRepresent.formatWith(
        '{item!r}',
        named: {'item': const _Token('x')},
      ),
      throwsA(
        isA<FormatExtensionException>()
            .having((error) => error.context.conversion, 'conversion', 'r')
            .having((error) => error.error, 'error', isA<StateError>()),
      ),
    );
    expect(
      () => failedRepresent.formatWith(
        '{item!r}',
        named: {'item': const _Token('x')},
      ),
      throwsA(
        isA<FormatExtensionException>()
            .having((error) => error.context.fragment, 'fragment', '{item!r}')
            .having((error) => error.error, 'error', isA<StateError>()),
      ),
    );
  });
}

final class _OrderedValues extends Iterable<Object?> {
  final Iterable<Object?> values;

  _OrderedValues(this.values);

  @override
  Iterator<Object?> get iterator => values.iterator;
}

final class _RecursiveIterable extends Iterable<Object?> {
  @override
  Iterator<Object?> get iterator => throw StateError('must not iterate');
}

final class _OrderedValuesRepresentation
    extends Representation<_OrderedValues> {
  @override
  bool canRepresent(Object? value) => value is _OrderedValues;

  @override
  String represent(_OrderedValues value) => '<ordered>';
}

final class _MapRepresentation extends Representation<Map<Object?, Object?>> {
  @override
  bool canRepresent(Object? value) => value is Map<Object?, Object?>;

  @override
  String represent(Map<Object?, Object?> value) => 'custom-map';
}

final class _BigIntRepresentation extends Representation<BigInt> {
  @override
  bool canRepresent(Object? value) => value is BigInt;

  @override
  String represent(BigInt value) => 'custom-big-int';
}
