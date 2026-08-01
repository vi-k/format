import 'package:format/format.dart';
import 'package:format/src/text_unit.dart' show TextUnitOperations;
import 'package:test/test.dart';

final class JsonFormatter extends Formatter<Map<String, Object?>> {
  @override
  String get specifier => 'json';

  @override
  bool canFormat(Object? value) => value is Map<String, Object?>;

  @override
  String format(Map<String, Object?> value, FormatOptions options) =>
      value.toString();
}

final class MapAttributeLookup extends AttributeLookup<Map<String, Object?>> {
  @override
  bool canLookup(Object? value) => value is Map<String, Object?>;

  @override
  Object? lookup(Map<String, Object?> value, String attribute) =>
      value[attribute];
}

final class MapRepresentation extends Representation<Map<String, Object?>> {
  @override
  bool canRepresent(Object? value) => value is Map<String, Object?>;

  @override
  String represent(Map<String, Object?> value) => value.toString();
}

void main() {
  test('public formatting functions have the 2.0 signatures', () {
    expect(format('{}', const ['value']), 'value');
    expect(formatNamed('{key}', const {'key': 'value'}), 'value');
  });

  test('public import exposes formatter extension types', () {
    final formatter = JsonFormatter();
    expect(formatter.specifier, 'json');
    expect(
      formatter.format(const {'answer': 42}, const FormatOptions()),
      '{answer: 42}',
    );
  });

  test('exports Format 3 extension and locale contracts', () {
    const options = FormatOptions(
      sign: '+',
      normalizeNegativeZero: true,
      alternate: true,
      zero: true,
      grouping: '_',
      precision: 3,
      payload: 'pretty',
    );
    expect(options.payload, 'pretty');
    expect(const CNumberLocale().decimalSeparator, '.');
    expect(TextUnit.values, [
      TextUnit.unicodeScalars,
      TextUnit.graphemeClusters,
    ]);
  });

  test('public import permits extension contracts', () {
    final lookup = MapAttributeLookup();
    final representation = MapRepresentation();
    const value = {'answer': 42};

    expect(lookup.canLookup(value), isTrue);
    expect(lookup.lookup(value, 'answer'), 42);
    expect(representation.canRepresent(value), isTrue);
    expect(representation.represent(value), '{answer: 42}');
  });

  test('TextUnit operations preserve scalar and grapheme boundaries', () {
    const value = 'a👩‍🔬';

    expect(TextUnit.unicodeScalars.length(value), 4);
    expect(TextUnit.unicodeScalars.take(value, 2), 'a👩');
    expect(TextUnit.unicodeScalars.split(value), ['a', '👩', '\u200d', '🔬']);
    expect(TextUnit.unicodeScalars.take(value, 0), '');
    expect(TextUnit.unicodeScalars.take(value, 99), value);
    expect(TextUnit.graphemeClusters.length(value), 2);
    expect(TextUnit.graphemeClusters.take(value, 2), value);
    expect(TextUnit.graphemeClusters.split(value), ['a', '👩‍🔬']);
  });
}
