import 'dart:convert';
import 'dart:io';

import 'package:format/format.dart';
import 'package:test/test.dart';

final class PythonFixtureSuite {
  final String implementation;
  final String version;
  final List<PythonFixture> cases;

  const PythonFixtureSuite({
    required this.implementation,
    required this.version,
    required this.cases,
  });

  /// Synchronous so callers can register one `test()` per fixture.
  factory PythonFixtureSuite.load(String path) {
    final document = _object(jsonDecode(File(path).readAsStringSync()), r'$');
    final generator = _object(document['generator'], r'$.generator');
    final implementation = _string(
      generator['implementation'],
      r'$.generator.implementation',
    );
    final version = _string(generator['version'], r'$.generator.version');
    final encodedCases = _list(document['cases'], r'$.cases');
    final cases = <PythonFixture>[];
    for (var index = 0; index < encodedCases.length; index++) {
      cases.add(PythonFixture._decode(encodedCases[index], r'$.cases[$index]'));
    }
    final ids = cases.map((fixture) => fixture.id).toList();
    final sortedIds = [...ids]..sort();
    if (!_sameValues(ids, sortedIds)) {
      throw const FormatException('Fixture case IDs must be sorted.');
    }
    if (ids.toSet().length != ids.length) {
      throw const FormatException('Fixture case IDs must be unique.');
    }
    return PythonFixtureSuite(
      implementation: implementation,
      version: version,
      cases: List.unmodifiable(cases),
    );
  }
}

final class PythonFixture {
  final String id;
  final String template;
  final List<Object?> positional;
  final Map<String, Object?> named;
  final Matcher matcher;

  const PythonFixture._({
    required this.id,
    required this.template,
    required this.positional,
    required this.named,
    required this.matcher,
  });

  factory PythonFixture._decode(Object? encoded, String path) {
    final object = _object(encoded, path);
    final positionalValues = _list(object['positional'], '$path.positional');
    final namedValues = _object(object['named'], '$path.named');
    final expected = _object(object['expected'], '$path.expected');
    final hasOutput = expected.containsKey('output');
    final hasError = expected.containsKey('error');
    final output = expected['output'];
    final error = expected['error'];
    if (hasOutput == hasError) {
      throw FormatException(
        '$path.expected must contain exactly one of output or error.',
      );
    }
    return PythonFixture._(
      id: _string(object['id'], '$path.id'),
      template: _string(object['template'], '$path.template'),
      positional: List.unmodifiable([
        for (var index = 0; index < positionalValues.length; index++)
          decodeFixtureValue(
            positionalValues[index],
            '$path.positional[$index]',
          ),
      ]),
      named: Map.unmodifiable({
        for (final entry in namedValues.entries)
          entry.key: decodeFixtureValue(
            entry.value,
            '$path.named.${entry.key}',
          ),
      }),
      matcher:
          hasOutput
              ? _ReturnsFixtureOutput(_string(output, '$path.expected.output'))
              : _ThrowsPythonCategory(_string(error, '$path.expected.error')),
    );
  }
}

final class PythonDivergenceSuite {
  final List<String> ids;

  /// The README anchor each entry points at, by entry ID. Whether an anchor
  /// resolves is the caller's test: the loader only reads the file it was
  /// given.
  final Map<String, String> anchors;

  const PythonDivergenceSuite._(this.ids, this.anchors);

  /// Synchronous so callers can register one `test()` per entry.
  factory PythonDivergenceSuite.load(String path) {
    final document = _object(jsonDecode(File(path).readAsStringSync()), r'$');
    if (document['schema'] != 1) {
      throw const FormatException('Unsupported divergence schema.');
    }
    final divergences = _list(document['divergences'], r'$.divergences');
    final ids = <String>[];
    final anchors = <String, String>{};
    for (var index = 0; index < divergences.length; index++) {
      final path = '\$.divergences[$index]';
      final divergence = _object(divergences[index], path);
      ids.add(_string(divergence['id'], '$path.id'));
      _object(divergence['input'], '$path.input');
      _outcome(divergence['python'], '$path.python');
      _outcome(divergence['dart'], '$path.dart');
      if (_string(divergence['reason'], '$path.reason').trim().isEmpty) {
        throw FormatException('$path.reason cannot be empty.');
      }
      final anchor = _string(
        divergence['readme_anchor'],
        '$path.readme_anchor',
      );
      if (!anchor.startsWith('#')) {
        throw FormatException('$path.readme_anchor must be an anchor.');
      }
      anchors[ids.last] = anchor;
    }
    final sortedIds = [...ids]..sort();
    if (!_sameValues(ids, sortedIds)) {
      throw const FormatException('Divergence IDs must be sorted.');
    }
    if (ids.toSet().length != ids.length) {
      throw const FormatException('Divergence IDs must be unique.');
    }
    return PythonDivergenceSuite._(
      List.unmodifiable(ids),
      Map.unmodifiable(anchors),
    );
  }
}

/// A deterministic non-C test locale shared by the divergence exemplars:
/// space grouping (enabled), comma decimal, U+2212 minus.
final class SpacedNumberLocale implements NumberLocale {
  const SpacedNumberLocale();

  @override
  String get decimalSeparator => ',';

  @override
  String get groupSeparator => ' ';

  @override
  String get plusSign => '+';

  @override
  String get minusSign => '−';

  @override
  String get exponentSeparator => 'e';

  @override
  bool get groupingEnabled => true;

  @override
  List<int> get grouping => const [3];

  @override
  String localizeDigits(String asciiDigits) => asciiDigits;
}

Object? decodeFixtureValue(Object? encoded, [String path = r'$']) {
  final object = _object(encoded, path);
  final type = _string(object['type'], '$path.type');
  if (!object.containsKey('value')) {
    throw FormatException('$path.value is required.');
  }
  final value = object['value'];
  return switch (type) {
    'null' => value == null ? null : _invalid(path, type),
    'bool' => value is bool ? value : _invalid(path, type),
    'string' => value is String ? value : _invalid(path, type),
    'int' => value is int ? value : _invalid(path, type),
    'bigint' => BigInt.parse(_string(value, '$path.value')),
    'double' => _double(value, '$path.value'),
    'list' => _decodeList(value, '$path.value'),
    'map' => _decodeMap(value, '$path.value'),
    'set' => _decodeSet(value, '$path.value'),
    _ => throw FormatException('Unknown fixture value type "$type" at $path.'),
  };
}

Never _invalid(String path, String type) =>
    throw FormatException('Invalid $type fixture value at $path.');

double _double(Object? value, String path) => switch (value) {
  int() => value.toDouble(),
  double() => value,
  '-0' => -0.0,
  'nan' => double.nan,
  'inf' => double.infinity,
  '-inf' => double.negativeInfinity,
  _ => throw FormatException('Invalid double fixture token at $path.'),
};

List<Object?> _decodeList(Object? value, String path) {
  final values = _list(value, path);
  return List.unmodifiable([
    for (var index = 0; index < values.length; index++)
      decodeFixtureValue(values[index], '$path[$index]'),
  ]);
}

Map<Object?, Object?> _decodeMap(Object? value, String path) {
  final entries = _list(value, path);
  final result = <Object?, Object?>{};
  for (var index = 0; index < entries.length; index++) {
    final entry = _object(entries[index], '$path[$index]');
    final key = decodeFixtureValue(entry['key'], '$path[$index].key');
    if (result.containsKey(key)) {
      throw FormatException('Duplicate map key at $path[$index].key.');
    }
    result[key] = decodeFixtureValue(entry['value'], '$path[$index].value');
  }
  return Map.unmodifiable(result);
}

Set<Object?> _decodeSet(Object? value, String path) {
  final values = _list(value, path);
  final result = <Object?>{};
  for (var index = 0; index < values.length; index++) {
    final decoded = decodeFixtureValue(values[index], '$path[$index]');
    if (!result.add(decoded)) {
      throw FormatException('Duplicate set value at $path[$index].');
    }
  }
  return Set.unmodifiable(result);
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

void _outcome(Object? value, String path) {
  final outcome = _object(value, path);
  final hasResult = outcome.containsKey('result');
  final hasError = outcome.containsKey('error');
  if (hasResult == hasError) {
    throw FormatException('$path must contain exactly one result or error.');
  }
  _string(outcome[hasResult ? 'result' : 'error'], path);
}

bool _sameValues(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

final class _ReturnsFixtureOutput extends Matcher {
  final String expected;

  const _ReturnsFixtureOutput(this.expected);

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

final class _ThrowsPythonCategory extends Matcher {
  final String category;

  const _ThrowsPythonCategory(this.category);

  @override
  Description describe(Description description) =>
      description.add('throws the Dart equivalent of $category');

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! String Function()) return false;
    try {
      matchState['output'] = item();
      return false;
    } on Object catch (error) {
      matchState['error'] = error;
      return switch (category) {
        'ValueError' =>
          error is InvalidFormatException ||
              error is InvalidSpecifierException ||
              error is UnsupportedConversionException ||
              error is UnsupportedFormatValueException,
        'IndexError' =>
          error is MissingFormatArgumentException && error.key is int ||
              error is FormatLookupException &&
                  error.segment is int &&
                  error.value is List<Object?>,
        'KeyError' =>
          error is MissingFormatArgumentException && error.key is String ||
              error is FormatLookupException &&
                  error.value is Map<Object?, Object?>,
        _ => false,
      };
    }
  }
}
