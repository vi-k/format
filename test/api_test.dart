/// The public surface of `package:format/format.dart`, used the way a consumer
/// uses it: the entry points, the configured [Format] object, and the contracts
/// an extension implements.
///
/// Nothing here reaches into `src/`, and that is the point. These tests fail
/// when a symbol stops being exported, when a documented default changes, or
/// when an extension contract stops being implementable from outside the
/// package — none of which the engine's own tests would notice, since they
/// import the engine directly. What the engine *produces* is pinned elsewhere;
/// this file pins that the door is open and the handles are where the README
/// says they are.
library;

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
  // The two entry points differ in shape, not in engine: `format` takes values
  // as arguments and must accept a null among them rather than treat it as an
  // absent one, and `formatWith` is the only way to pass named values at all.
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

  // A variadic signature makes a single List argument ambiguous: it could be
  // spread into the positional values, or be one of them. It is one of them —
  // spreading would make `format('{}', someList)` unable to print a list.
  test('format treats a List as one positional value', () {
    expect(format('{}', const ['value']), '[value]');
  });

  // The mirror of `vsprintf snapshots its input` in `sprintf_api_test.dart`.
  // Formatting calls `toString` on the caller's objects, and one of those can
  // reach back and mutate the very collection being formatted: here the first
  // value's `toString` clears the list, and without a snapshot the second
  // value would be gone before it is read. The printf dialect has always
  // taken the snapshot; the brace dialect did not, and the same call failed
  // with a missing argument for a value that was there when it started.
  test('formatWith snapshots its collections before formatting values', () {
    final positional = <Object?>[];
    positional.addAll([_ClearsSourceValues(positional), 'second']);
    expect(formatWith('{0} {1}', positional: positional), 'first second');

    final named = <String, Object?>{};
    named['a'] = _ClearsSourceEntries(named);
    named['b'] = 'second';
    expect(
      formatWith('{a} {b}', named: named),
      'first second',
      reason: 'карта обязана сниматься так же, как список',
    );
  });

  // The pattern the README recommends for an app-wide configuration is to tear
  // the methods off a configured instance once and call them like the
  // top-level ones. That only works while they stay instance methods with the
  // same signature; a getter returning a closure would read the same at the
  // call site and break this.
  test('a custom Format exposes reusable method tear-offs', () {
    final configured = Format(textUnit: TextUnit.graphemeClusters);
    final appFormat = configured.format;
    final appFormatWith = configured.formatWith;

    expect(appFormat('{}', 'ok'), 'ok');
    expect(appFormatWith('{name}', named: const {'name': 'ok'}), 'ok');
  });

  // Which double profile is the default is a compatibility promise, not an
  // implementation detail: `dartSdk` spells doubles the way Dart does, and
  // switching the default would silently change every unconfigured caller's
  // output. The profile is also fixed at construction — read back, never set.
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

  // Everything 3.0 added to the public surface, named once so that dropping an
  // export is a compile error here rather than a user's bug report: the option
  // record an extension receives, the locale interface, and the text units.
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

  test('canonicalizes a C locale argument', () {
    // The compiled printf path recognizes the default locale by identity, so
    // `CNumberLocale()` written without `const` would silently take the
    // uncompiled path — same output, several times the cost, nothing to see.
    expect(
      // ignore: prefer_const_constructors
      Format(numberLocale: CNumberLocale()).numberLocale,
      same(const CNumberLocale()),
      reason: 'a non-const C locale must not be a distinct instance',
    );
    expect(Format().numberLocale, same(const CNumberLocale()));

    const other = _PassThroughLocale();
    expect(Format(numberLocale: other).numberLocale, same(other));
  });

  // Extending `AttributeLookup` and `Representation` from outside the package
  // has to compile and run: their type parameters, the `canX`/`x` pairing and
  // the classes' openness are all part of the contract, and a `base`/`final`
  // modifier added in passing would take it away.
  test('public import permits extension contracts', () {
    final lookup = MapAttributeLookup();
    final representation = MapRepresentation();
    const value = {'answer': 42};

    expect(lookup.canLookup(value), isTrue);
    expect(lookup.lookup(value, 'answer'), 42);
    expect(representation.canRepresent(value), isTrue);
    expect(representation.represent(value), '{answer: 42}');
  });

  // `TextUnit` is what width and precision count in, so its three operations
  // are user-visible arithmetic, not a helper. The value is a ZWJ sequence,
  // where the two units genuinely disagree: four scalars, one cluster — and
  // truncating between them would split a person in half.
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

/// A locale that is not [CNumberLocale], to pin that only that class is
/// canonicalized.
final class _PassThroughLocale implements NumberLocale {
  const _PassThroughLocale();

  @override
  String get decimalSeparator => '.';

  @override
  String get groupSeparator => ',';

  @override
  String get plusSign => '+';

  @override
  String get minusSign => '-';

  @override
  String get exponentSeparator => 'e';

  @override
  bool get groupingEnabled => false;

  @override
  List<int> get grouping => const [3];

  @override
  String localizeDigits(String asciiDigits) => asciiDigits;
}

/// Clears the list it was taken from when asked for its string, so that a
/// formatter reading its arguments one by one loses the rest mid-call.
final class _ClearsSourceValues {
  final List<Object?> values;

  _ClearsSourceValues(this.values);

  @override
  String toString() {
    values.clear();
    return 'first';
  }
}

/// The map counterpart of [_ClearsSourceValues]: named arguments are just as
/// reachable from a value's own `toString`.
final class _ClearsSourceEntries {
  final Map<String, Object?> entries;

  _ClearsSourceEntries(this.entries);

  @override
  String toString() {
    entries.clear();
    return 'first';
  }
}
