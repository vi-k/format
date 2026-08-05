import 'dart:convert';
import 'dart:io';

import 'package:format/format.dart';
import 'package:test/test.dart';

import 'support/fixture_value.dart';

void main() {
  final compatibleFormat = Format(
    doubleFormatMode: DoubleFormatMode.compatible,
  );
  final suite = SprintfFixtureSuite.load('test/fixtures/sprintf_common.json');

  group('committed std::sprintf C++23 fixtures', () {
    // One test per fixture: a regression in one case does not hide the
    // remaining disagreements behind the first failing expect.
    for (final fixture in suite.cases) {
      test(fixture.id, () {
        expect(
          () => compatibleFormat.vsprintf(fixture.template, fixture.arguments),
          fixture.matcher,
        );
      });
    }
  });

  group('documented result divergences hold', () {
    for (final entry in _executableResults.entries) {
      test(entry.key, () => expect(entry.value.run(), entry.value.output));
    }
  });

  test('keeps intentional sprintf divergences sorted and reviewable', () async {
    final document = _object(
      jsonDecode(
        await File('test/fixtures/sprintf_divergences.json').readAsString(),
      ),
      r'$',
    );
    expect(document['schema'], 1);
    final records = _list(document['divergences'], r'$.divergences');
    final ids = <String>[];
    final anchors = <String>{};
    final documentedDartErrors = <String, String>{};
    final documentedDartResults = <String>{};
    for (var index = 0; index < records.length; index++) {
      final path = '\$.divergences[$index]';
      final record = _object(records[index], path);
      ids.add(_string(record['id'], '$path.id'));
      _object(record['input'], '$path.input');
      _outcome(record['cpp'], '$path.cpp');
      final dartOutcome = _object(record['dart'], '$path.dart');
      _outcome(dartOutcome, '$path.dart');
      if (dartOutcome.containsKey('error')) {
        documentedDartErrors[ids.last] = _string(
          dartOutcome['error'],
          '$path.dart.error',
        );
      } else {
        documentedDartResults.add(ids.last);
      }
      expect(_string(record['reason'], '$path.reason').trim(), isNotEmpty);
      anchors.add(_string(record['readme_anchor'], '$path.readme_anchor'));
    }
    // Every result-divergence must ship an executable exemplar (run in
    // the group above), so the documented Dart behavior cannot rot.
    expect(documentedDartResults, unorderedEquals(_executableResults.keys));
    expect(ids, orderedEquals([...ids]..sort()));
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, containsAll(_requiredDivergenceIds));
    expect(anchors, {'#sprintf'});
    expect(await File('README.md').readAsString(), contains('\n## sprintf\n'));

    expect(documentedDartErrors.keys, unorderedEquals(_executableErrors.keys));
    for (final entry in _executableErrors.entries) {
      final fixture = entry.value;
      expect(documentedDartErrors[entry.key], fixture.type);
      expect(
        () => vsprintf(fixture.template, fixture.arguments),
        throwsA(fixture.matcher),
        reason: entry.key,
      );
    }
  });

  test(
    'fixture verifier rejects unexplained extra and missing cases',
    () async {
      final directory = await Directory.systemTemp.createTemp('sprintf-gate-');
      final reference = File('${directory.path}/reference.json');
      final actual = File('${directory.path}/actual.json');
      try {
        await reference.writeAsString(
          jsonEncode({
            'schema': 1,
            'reference': {'standard': 'C++23', 'locale': 'C'},
            'cases': [
              {
                'id': 'base',
                'template': '%d',
                'arguments': [
                  {'type': 'int', 'value': 1},
                ],
                'expected': {'output': '1'},
              },
            ],
          }),
        );
        final generator = {
          'compiler': 'test compiler',
          'standard_library': 'test standard library',
          'c_library': 'test C library',
          'os': 'test OS',
          'locale': 'C',
          'standard': 'C++23',
        };
        await actual.writeAsString(
          jsonEncode({
            'schema': 1,
            'generator': generator,
            'cases': [
              {'id': 'base', 'template': '%d', 'output': '2'},
              {'id': 'extra', 'template': '%s', 'output': 'extra'},
            ],
          }),
        );
        final unexplained = await _runFixtureVerifier(reference, actual);
        expect(unexplained.exitCode, 1);
        expect(unexplained.stderr, contains('base: unexplained output'));
        expect(unexplained.stderr, contains('unexpected actual case: extra'));

        await actual.writeAsString(
          jsonEncode({
            'schema': 1,
            'generator': generator,
            'cases': <Object?>[],
          }),
        );
        final missing = await _runFixtureVerifier(reference, actual);
        expect(missing.exitCode, 1);
        expect(missing.stderr, contains('missing actual case: base'));
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}

Future<ProcessResult> _runFixtureVerifier(File reference, File actual) =>
    Process.run(Platform.resolvedExecutable, [
      'tool/verify_sprintf_fixtures.dart',
      '--reference=${reference.path}',
      '--actual=${actual.path}',
    ]);

const _requiredDivergenceIds = {
  'arbitrary-tostring-for-s',
  'canonical-special-values',
  'dartsdk-default-double-profile',
  'fixed-rounding-mode',
  'format-intl-locale-extensions',
  'negative-unsigned-error',
  'unsupported-cpp26-binary',
  'unsupported-length-modifiers',
  'unsupported-pointer-conversion',
  'subnormal-hexadecimal-spelling',
  'unsupported-posix-indexing',
  'typed-invalid-format-error',
  'unicode-character-scalar',
  'unicode-string-text-units',
  'wide-dart-integers',
};

/// One executable exemplar per result-divergence in the registry,
/// pinning the documented Dart outcome.
final _executableResults = <String, ({String output, String Function() run})>{
  'arbitrary-tostring-for-s': (
    output: '0:00:01.000000',
    run: () => vsprintf('%s', [const Duration(seconds: 1)]),
  ),
  'canonical-special-values': (
    output: 'inf NAN',
    run:
        () => Format(
          doubleFormatMode: DoubleFormatMode.compatible,
        ).vsprintf('%f %F', [double.infinity, double.nan]),
  ),
  'dartsdk-default-double-profile': (
    output: '1.25e+1',
    run: () => vsprintf('%e', [12.5]),
  ),
  'fixed-rounding-mode': (
    output: '2 4',
    run:
        () => Format(
          doubleFormatMode: DoubleFormatMode.compatible,
        ).vsprintf('%.0f %.0f', [2.5, 3.5]),
  ),
  'format-intl-locale-extensions': (
    output: '−1,5',
    run:
        () => Format(
          numberLocale: const SpacedNumberLocale(),
        ).vsprintf('%.1f', [-1.5]),
  ),
  'subnormal-hexadecimal-spelling': (
    output: '0x0.0000000000001p-1022',
    run: () => vsprintf('%a', [5e-324]),
  ),
  'unicode-character-scalar': (
    output: '😀',
    run: () => vsprintf('%c', [0x1F600]),
  ),
  // The combining-accent form 'e\u0301': one grapheme cluster of two
  // scalars, kept whole where C's byte/wchar semantics have no analogue.
  'unicode-string-text-units': (
    output: 'e\u0301',
    run:
        () => Format(
          textUnit: TextUnit.graphemeClusters,
        ).vsprintf('%.1s', ['e\u0301x']),
  ),
  'wide-dart-integers': (
    output: '9223372036854775808',
    run: () => vsprintf('%d', [BigInt.two.pow(63)]),
  ),
};

final _executableErrors = <
  String,
  ({String template, List<Object?> arguments, String type, Matcher matcher})
>{
  'negative-unsigned-error': (
    template: '%u',
    arguments: [-1],
    type: 'UnsupportedFormatValueException',
    matcher: isA<UnsupportedFormatValueException>(),
  ),
  'typed-invalid-format-error': (
    template: '%q',
    arguments: const [],
    type: 'InvalidFormatException',
    matcher: isA<InvalidFormatException>(),
  ),
  'unsupported-cpp26-binary': (
    template: '%b',
    arguments: [5],
    type: 'InvalidFormatException',
    matcher: isA<InvalidFormatException>(),
  ),
  'unsupported-length-modifiers': (
    template: '%lld',
    arguments: [42],
    type: 'InvalidFormatException',
    matcher: isA<InvalidFormatException>(),
  ),
  'unsupported-pointer-conversion': (
    template: '%p',
    arguments: const [null],
    type: 'InvalidFormatException',
    matcher: isA<InvalidFormatException>(),
  ),
  'unsupported-posix-indexing': (
    template: r'%2$d',
    arguments: [1, 2],
    type: 'InvalidFormatException',
    matcher: isA<InvalidFormatException>(),
  ),
};

final class SprintfFixtureSuite {
  final List<SprintfFixture> cases;

  const SprintfFixtureSuite._(this.cases);

  /// Synchronous so callers can register one `test()` per fixture.
  factory SprintfFixtureSuite.load(String path) {
    final document = _object(jsonDecode(File(path).readAsStringSync()), r'$');
    if (document['schema'] != 1) {
      throw const FormatException('Unsupported sprintf fixture schema.');
    }
    final reference = _object(document['reference'], r'$.reference');
    if (_string(reference['standard'], r'$.reference.standard') != 'C++23') {
      throw const FormatException('Sprintf fixtures must reference C++23.');
    }
    if (_string(reference['locale'], r'$.reference.locale') != 'C') {
      throw const FormatException('Sprintf fixtures must use the C locale.');
    }
    final encodedCases = _list(document['cases'], r'$.cases');
    final cases = <SprintfFixture>[];
    for (var index = 0; index < encodedCases.length; index++) {
      cases.add(
        SprintfFixture._decode(encodedCases[index], '\$.cases[$index]'),
      );
    }
    final ids = cases.map((fixture) => fixture.id).toList();
    final sortedIds = [...ids]..sort();
    if (!_sameValues(ids, sortedIds)) {
      final mismatch = List.generate(
        ids.length,
        (index) => index,
      ).firstWhere((index) => ids[index] != sortedIds[index]);
      throw FormatException(
        'Sprintf fixture case IDs must be sorted: '
        '${ids[mismatch]} should be ${sortedIds[mismatch]}.',
      );
    }
    if (ids.toSet().length != ids.length) {
      throw const FormatException('Sprintf fixture case IDs must be unique.');
    }
    return SprintfFixtureSuite._(List.unmodifiable(cases));
  }
}

final class SprintfFixture {
  final String id;
  final String template;
  final List<Object?> arguments;
  final Matcher matcher;

  const SprintfFixture._({
    required this.id,
    required this.template,
    required this.arguments,
    required this.matcher,
  });

  factory SprintfFixture._decode(Object? encoded, String path) {
    final object = _object(encoded, path);
    final encodedArguments = _list(object['arguments'], '$path.arguments');
    final expected = _object(object['expected'], '$path.expected');
    final outcomeKeys =
        {'output', 'allowed', 'error'}.where(expected.containsKey).toList();
    if (outcomeKeys.length != 1) {
      throw FormatException('$path.expected must contain exactly one outcome.');
    }
    final matcher = switch (outcomeKeys.single) {
      'output' => _ReturnsExact(
        _string(expected['output'], '$path.expected.output'),
      ),
      'allowed' => _ReturnsAllowed(
        _stringList(expected['allowed'], '$path.allowed'),
      ),
      'error' => _ThrowsFormattingError(
        _string(expected['error'], '$path.error'),
      ),
      _ => throw StateError('Unreachable fixture outcome.'),
    };
    return SprintfFixture._(
      id: _string(object['id'], '$path.id'),
      template: _string(object['template'], '$path.template'),
      arguments: List.unmodifiable([
        for (var index = 0; index < encodedArguments.length; index++)
          decodeFixtureValue(
            encodedArguments[index],
            '$path.arguments[$index]',
          ),
      ]),
      matcher: matcher,
    );
  }
}

final class _ReturnsExact extends Matcher {
  final String expected;

  const _ReturnsExact(this.expected);

  @override
  Description describe(Description description) =>
      description.add('returns ').addDescriptionOf(expected);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! String Function()) return false;
    try {
      final actual = item();
      matchState['actual'] = actual;
      return actual == expected;
    } on Object catch (error) {
      matchState['error'] = error;
      return false;
    }
  }
}

final class _ReturnsAllowed extends Matcher {
  final List<String> allowed;

  const _ReturnsAllowed(this.allowed);

  @override
  Description describe(Description description) =>
      description.add('returns one of ').addDescriptionOf(allowed);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! String Function()) return false;
    try {
      final actual = item();
      matchState['actual'] = actual;
      return allowed.contains(actual);
    } on Object catch (error) {
      matchState['error'] = error;
      return false;
    }
  }
}

final class _ThrowsFormattingError extends Matcher {
  final String expectedType;

  const _ThrowsFormattingError(this.expectedType);

  @override
  Description describe(Description description) =>
      description.add('throws $expectedType');

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! String Function()) return false;
    try {
      matchState['output'] = item();
      return false;
    } on FormattingException catch (error) {
      matchState['error'] = error;
      return error.runtimeType.toString() == expectedType;
    } on Object catch (error) {
      matchState['error'] = error;
      return false;
    }
  }
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map<String, Object?>) {
    throw FormatException('Expected an object at $path.');
  }
  return value;
}

List<Object?> _list(Object? value, String path) {
  if (value is! List<Object?>) {
    throw FormatException('Expected a list at $path.');
  }
  return value;
}

String _string(Object? value, String path) {
  if (value is! String) throw FormatException('Expected a string at $path.');
  return value;
}

List<String> _stringList(Object? value, String path) {
  final values = _list(value, path);
  final strings = [
    for (var index = 0; index < values.length; index++)
      _string(values[index], '$path[$index]'),
  ];
  if (strings.isEmpty || strings.toSet().length != strings.length) {
    throw FormatException('$path must contain unique allowed outputs.');
  }
  final sorted = [...strings]..sort();
  if (!_sameValues(strings, sorted)) {
    throw FormatException('$path must be sorted.');
  }
  return List.unmodifiable(strings);
}

void _outcome(Object? value, String path) {
  final outcome = _object(value, path);
  final keys = {'result', 'error'}.where(outcome.containsKey).toList();
  if (keys.length != 1) {
    throw FormatException('$path must contain exactly one outcome.');
  }
  _string(outcome[keys.single], '$path.${keys.single}');
}

bool _sameValues(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
