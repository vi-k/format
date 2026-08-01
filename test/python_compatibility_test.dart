import 'dart:convert';
import 'dart:io';

import 'package:format/format.dart';
import 'package:test/test.dart';

import 'support/fixture_value.dart';

void main() {
  test('matches committed Python 3.14 fixtures', () async {
    final suite = await PythonFixtureSuite.load(
      'test/fixtures/python_format.json',
    );
    expect(suite.implementation, 'CPython');
    expect(suite.version, '3.14');

    for (final fixture in suite.cases) {
      expect(
        () => formatWith(
          fixture.template,
          positional: fixture.positional,
          named: fixture.named,
        ),
        fixture.matcher,
        reason: fixture.id,
      );
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

      expect(PythonFixtureSuite.load(file.path), throwsFormatException);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('keeps intentional divergences sorted and reviewable', () async {
    final suite = await PythonDivergenceSuite.load(
      'test/fixtures/python_divergences.json',
    );

    expect(suite.ids, hasLength(9));
  });
}
