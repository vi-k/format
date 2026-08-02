import 'package:format/format.dart';
import 'package:test/test.dart';

final class _ClearsSourceValues {
  final List<Object?> values;

  _ClearsSourceValues(this.values);

  @override
  String toString() {
    values.clear();
    return 'first';
  }
}

final class _BrokenToString {
  @override
  String toString() => throw StateError('broken');
}

void main() {
  test('exports sprintf and vsprintf at both API levels', () {
    expect(sprintf('%d %s', 42, 'answer'), '42 answer');
    expect(vsprintf('%s:%d', ['items', 3]), 'items:3');

    final engine = Format(textUnit: TextUnit.graphemeClusters);
    final appSprintf = engine.sprintf;
    final appVSprintf = engine.vsprintf;
    expect(appSprintf('%s', null), 'null');
    expect(appVSprintf('%%', const []), '%');
  });

  test('sprintf accepts zero and ten supplied arguments', () {
    expect(sprintf('literal'), 'literal');
    expect(
      sprintf('%d%d%d%d%d%d%d%d%d%d', 1, 2, 3, 4, 5, 6, 7, 8, 9, 10),
      '12345678910',
    );
  });

  test(
    'sprintf preserves an explicit null before the missing-value sentinel',
    () {
      expect(sprintf('%s', null), 'null');
      expect(
        () => sprintf('%s %s', null),
        throwsA(
          isA<MissingFormatArgumentException>().having(
            (error) => error.context.argumentIndex,
            'argument index',
            1,
          ),
        ),
      );
    },
  );

  test('sprintf treats List and Map as individual values', () {
    expect(
      sprintf('%s %s', const ['item'], const {'answer': 42}),
      '[item] {answer: 42}',
    );
  });

  test('vsprintf ignores values beyond the consumed tokens', () {
    expect(vsprintf('%s', const ['used', 'ignored']), 'used');
  });

  test('vsprintf snapshots its input before formatting values', () {
    final values = <Object?>[];
    final clearingValue = _ClearsSourceValues(values);
    values.addAll([clearingValue, 'second']);

    expect(vsprintf('%s %s', values), 'first second');
  });

  test('sprintf reports unsupported syntax with typed context', () {
    try {
      sprintf('%5s', 'value');
      fail('Expected InvalidFormatException.');
    } on InvalidFormatException catch (error) {
      expect(error.context.template, '%5s');
      expect(error.context.offset, 0);
      expect(error.context.fragment, '%5');
      expect(error.context.specifier, '5');
    }
  });

  test('sprintf keeps unsupported conversions typed', () {
    try {
      sprintf('%f', 1);
      fail('Expected InvalidFormatException.');
    } on InvalidFormatException catch (error) {
      expect(error.context.template, '%f');
      expect(error.context.offset, 0);
      expect(error.context.fragment, '%f');
      expect(error.context.specifier, 'f');
    }
  });

  test('sprintf reports a dangling percent with typed context', () {
    try {
      sprintf('value %');
      fail('Expected InvalidFormatException.');
    } on InvalidFormatException catch (error) {
      expect(error.context.template, 'value %');
      expect(error.context.offset, 6);
      expect(error.context.fragment, '%');
      expect(error.context.specifier, isNull);
    }
  });

  test('sprintf reports a missing argument with typed context', () {
    try {
      sprintf('%d');
      fail('Expected MissingFormatArgumentException.');
    } on MissingFormatArgumentException catch (error) {
      expect(error.key, 0);
      expect(error.context.template, '%d');
      expect(error.context.offset, 0);
      expect(error.context.fragment, '%d');
      expect(error.context.specifier, 'd');
      expect(error.context.argumentIndex, 0);
    }
  });

  test('sprintf formats integer and BigInt decimal values', () {
    expect(sprintf('%d', 42), '42');
    expect(sprintf('%d', BigInt.parse('9007199254740993')), '9007199254740993');
  });

  test('sprintf canonicalizes integral doubles only on JavaScript', () {
    const integralDouble = 42.0;
    if (identical(1, 1.0)) {
      expect(sprintf('%d', integralDouble), '42');
    } else {
      expect(
        () => sprintf('%d', integralDouble),
        throwsA(isA<UnsupportedConversionException>()),
      );
    }
  });

  test('sprintf reports incompatible decimal values as typed errors', () {
    try {
      sprintf('%d', '42');
      fail('Expected UnsupportedConversionException.');
    } on UnsupportedConversionException catch (error) {
      expect(error.context.template, '%d');
      expect(error.context.offset, 0);
      expect(error.context.fragment, '%d');
      expect(error.context.specifier, 'd');
      expect(error.context.argumentIndex, 0);
    }
  });

  test('sprintf contains toString failures in a typed error', () {
    try {
      sprintf('%s', _BrokenToString());
      fail('Expected UnsupportedConversionException.');
    } on UnsupportedConversionException catch (error) {
      expect(error.context.template, '%s');
      expect(error.context.offset, 0);
      expect(error.context.fragment, '%s');
      expect(error.context.specifier, 's');
      expect(error.context.argumentIndex, 0);
    }
  });
}
