import 'package:format/format.dart';
import 'package:test/test.dart';

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
  test(
    'format accepts separate nullable values and formatWith accepts both maps',
    () {
      expect(format('{} {}', 'a', null), 'a null');
      expect(
        formatWith(
          '{0} {name}',
          positional: const ['hello'],
          named: const {'name': 'world'},
        ),
        'hello world',
      );
    },
  );

  test('format treats a List as one positional value', () {
    expect(format('{}', const ['value']), '[value]');
  });

  test('a custom Format exposes reusable method tear-offs', () {
    final configured = Format(textUnit: TextUnit.graphemeClusters);
    final appFormat = configured.format;
    final appFormatWith = configured.formatWith;

    expect(appFormat('{}', 'ok'), 'ok');
    expect(appFormatWith('{name}', named: const {'name': 'ok'}), 'ok');
  });

  test('Format exposes immutable double formatting profiles', () {
    final defaults = Format();
    final compatible = Format(
      doubleFormatMode: DoubleFormatMode.compatible,
      doubleSpecialValueSpelling: DoubleSpecialValueSpelling.short,
    );

    expect(defaults.doubleFormatMode, DoubleFormatMode.dartSdk);
    expect(
      defaults.doubleSpecialValueSpelling,
      DoubleSpecialValueSpelling.dartSdk,
    );
    expect(compatible.doubleFormatMode, DoubleFormatMode.compatible);
    expect(
      compatible.doubleSpecialValueSpelling,
      DoubleSpecialValueSpelling.short,
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
