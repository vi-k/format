import 'dart:convert';
import 'dart:io';

import 'package:format/format.dart';
import 'package:test/test.dart';

import 'support/fixture_value.dart';
import 'support/markdown_anchors.dart';

void main() {
  final compatibleFormat = Format(
    doubleFormatMode: DoubleFormatMode.compatible,
  );
  final suite = PythonFixtureSuite.load('test/fixtures/python_format.json');

  test('fixture metadata pins CPython 3.14', () {
    expect(suite.implementation, 'CPython');
    expect(suite.version, '3.14');
  });

  group('committed Python 3.14 fixtures', () {
    // One test per fixture: a regression in one case does not hide the
    // remaining disagreements behind the first failing expect.
    for (final fixture in suite.cases) {
      test(fixture.id, () {
        expect(
          () => compatibleFormat.formatWith(
            fixture.template,
            positional: fixture.positional,
            named: fixture.named,
          ),
          fixture.matcher,
        );
      });
    }
  });

  test('decodes every typed fixture value without JSON ambiguity', () {
    expect(decodeFixtureValue({'type': 'null', 'value': null}), isNull);
    expect(decodeFixtureValue({'type': 'bool', 'value': true}), isTrue);
    expect(decodeFixtureValue({'type': 'string', 'value': 'x'}), 'x');
    expect(decodeFixtureValue({'type': 'int', 'value': 42}), 42);
    expect(
      decodeFixtureValue({
        'type': 'bigint',
        'value': '123456789012345678901234567890',
      }),
      BigInt.parse('123456789012345678901234567890'),
    );
    expect(
      decodeFixtureValue({'type': 'double', 'value': '-0'}),
      predicate<double>(
        (value) => value == 0 && value.isNegative,
        'negative zero',
      ),
    );
    expect(
      decodeFixtureValue({'type': 'double', 'value': 'nan'}),
      predicate<double>((value) => value.isNaN, 'NaN'),
    );
    expect(
      decodeFixtureValue({'type': 'double', 'value': 'inf'}),
      double.infinity,
    );
    expect(
      decodeFixtureValue({'type': 'double', 'value': '-inf'}),
      double.negativeInfinity,
    );
    expect(
      decodeFixtureValue({
        'type': 'list',
        'value': [
          {'type': 'int', 'value': 1},
        ],
      }),
      [1],
    );
    expect(
      decodeFixtureValue({
        'type': 'map',
        'value': [
          {
            'key': {'type': 'string', 'value': 'key'},
            'value': {'type': 'int', 'value': 1},
          },
        ],
      }),
      {'key': 1},
    );
    expect(
      decodeFixtureValue({
        'type': 'set',
        'value': [
          {'type': 'string', 'value': 'x'},
          {'type': 'string', 'value': 'y'},
        ],
      }),
      {'x', 'y'},
    );
  });

  test('rejects malformed fixture values defensively', () {
    expect(
      () => decodeFixtureValue({'type': 'double', 'value': '1.5'}),
      throwsFormatException,
    );
    expect(
      () => decodeFixtureValue({'type': 'unknown', 'value': null}),
      throwsFormatException,
    );
    expect(
      () => decodeFixtureValue({
        'type': 'set',
        'value': [
          {'type': 'int', 'value': 1},
          {'type': 'int', 'value': 1},
        ],
      }),
      throwsFormatException,
    );
  });

  test('rejects a fixture expected value with both outcome keys', () async {
    final directory = await Directory.systemTemp.createTemp('format-fixture-');
    final file = File('${directory.path}/python_format.json');
    try {
      await file.writeAsString(
        jsonEncode({
          'generator': {'implementation': 'CPython', 'version': '3.14'},
          'cases': [
            {
              'id': 'invalid-outcome',
              'template': '{}',
              'positional': <Object?>[],
              'named': <String, Object?>{},
              'expected': {'output': null, 'error': 'KeyError'},
            },
          ],
        }),
      );

      expect(() => PythonFixtureSuite.load(file.path), throwsFormatException);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  final divergences = PythonDivergenceSuite.load(
    'test/fixtures/python_divergences.json',
  );

  test('points every divergence at a README section that exists', () async {
    // The registry tells a user "we differ from Python here, read the
    // README". An anchor that resolves to nothing breaks that promise
    // silently, so resolve each one against the headings themselves.
    final anchors = markdownAnchors(await File('README.md').readAsString());
    for (final entry in divergences.anchors.entries) {
      expect(anchors, contains(entry.value), reason: entry.key);
    }
  });

  test('keeps intentional divergences sorted and executable', () {
    // Every registry entry must ship an executable exemplar below (or a
    // documented platform exemption), so the documented Dart behavior
    // cannot rot silently.
    expect(divergences.ids.toSet(), {
      ..._executableDivergences.keys,
      ..._platformDivergences,
    });
  });

  group('intentional divergences hold', () {
    for (final entry in _executableDivergences.entries) {
      test(entry.key, entry.value);
    }
  });
}

/// Entries whose Dart side only exists on another platform. The JS
/// canonicalization entry is pinned by test/js_number_dispatch_test.dart
/// in the node run; this suite is VM-only (dart:io).
const _platformDivergences = {'dart-js-integral-number-canonicalization'};

/// One executable exemplar per registry entry, pinning the documented
/// Dart outcome.
final _executableDivergences = <String, void Function()>{
  'dart-ascii-spec-digits':
      () => expect(
        () => format('{:٥d}', 1),
        throwsA(isA<InvalidSpecifierException>()),
      ),
  'dart-bool-null-tokens':
      () => expect(format('{} {} {}', true, false, null), 'true false null'),
  'dart-container-representation-order':
      () => expect(format('{!r}', {'b': 1, 'a': 2}), "{'b': 1, 'a': 2}"),
  'dart-custom-formatter-payload':
      () => expect(
        Format(formatters: [_PayloadFormatter()]).format('{:json:pretty}', 42),
        '42/pretty',
      ),
  'dart-custom-lookup-hooks':
      () => expect(
        Format(
          lookups: [_NameLookup()],
        ).formatWith('{value.name}', named: {'value': const _Named('Ada')}),
        'Ada',
      ),
  'dart-format-intl-locale-extensions':
      () => expect(
        Format(numberLocale: const SpacedNumberLocale()).format('{:n}', 1234),
        '1 234',
      ),
  'dart-map-dot-key':
      () => expect(
        formatWith(
          '{value.name}',
          named: {
            'value': {'name': 'Ada'},
          },
        ),
        'Ada',
      ),
  'dart-repr-ascii-policy':
      () => expect(
        format('{0!r} {0!a}', 'строка'),
        "'строка' "
        r"'\u0441\u0442\u0440\u043e\u043a\u0430'",
      ),
  'dart-strict-character-scalars':
      () => expect(
        () => format('{:c}', 0xd800),
        throwsA(isA<UnsupportedFormatValueException>()),
      ),
  'dart-strict-character-zero-padding':
      () => expect(
        () => format('{:05c}', 65),
        throwsA(isA<InvalidSpecifierException>()),
      ),
  'dart-strict-text-zero-padding':
      () => expect(
        () => format('{:05s}', 'x'),
        throwsA(isA<InvalidSpecifierException>()),
      ),
  // The combining-accent form 'e\u0301': one grapheme cluster of two
  // scalars, kept whole by the grapheme engine where Python (and the
  // scalar default) would cut after 'e'.
  'dart-text-grapheme-mode':
      () => expect(
        Format(textUnit: TextUnit.graphemeClusters).format('{:.1s}', 'e\u0301'),
        'e\u0301',
      ),
};

final class _PayloadFormatter extends Formatter<int> {
  @override
  String get specifier => 'json';

  @override
  bool canFormat(Object? value) => value is int;

  @override
  String format(int value, FormatOptions options) =>
      '$value/${options.payload}';
}

final class _Named {
  final String name;

  const _Named(this.name);
}

final class _NameLookup extends AttributeLookup<_Named> {
  @override
  bool canLookup(Object? value) => value is _Named;

  @override
  Object? lookup(_Named value, String attribute) =>
      attribute == 'name' ? value.name : null;
}
