import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) async {
  try {
    final options = _Options.parse(arguments);
    final reference = _ReferenceSuite.decode(
      jsonDecode(await File(options.reference).readAsString()),
    );
    final actual = _ActualSuite.decode(
      jsonDecode(await File(options.actual).readAsString()),
    );
    final failures = _verify(reference, actual);
    if (failures.isNotEmpty) {
      failures.forEach(stderr.writeln);
      exitCode = 1;
      return;
    }
    stdout.writeln(
      'Verified ${reference.cases.length} sprintf fixtures against '
      '${actual.generator.compiler} on ${actual.generator.os}.',
    );
  } on _UsageException catch (error) {
    stderr
      ..writeln(error.message)
      ..writeln(
        'usage: dart run tool/verify_sprintf_fixtures.dart '
        '--reference=FILE --actual=FILE',
      );
    exitCode = 64;
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

List<String> _verify(_ReferenceSuite reference, _ActualSuite actual) {
  final failures = <String>[];
  final referenceIds = reference.cases.keys.toSet();
  final actualIds = actual.cases.keys.toSet();
  for (final id in (referenceIds.difference(actualIds).toList()..sort())) {
    failures.add('missing actual case: $id');
  }
  for (final id in (actualIds.difference(referenceIds).toList()..sort())) {
    failures.add('unexpected actual case: $id');
  }
  for (final id in (referenceIds.intersection(actualIds).toList()..sort())) {
    final expected = reference.cases[id]!;
    final observed = actual.cases[id]!;
    if (expected.template != observed.template) {
      failures.add(
        '$id: template differs: expected ${jsonEncode(expected.template)}, '
        'actual ${jsonEncode(observed.template)}',
      );
      continue;
    }
    if (!expected.outputs.contains(observed.output)) {
      failures.add(
        '$id: unexplained output ${jsonEncode(observed.output)}; expected '
        '${expected.outputs.map(jsonEncode).join(' or ')}',
      );
    }
  }
  return failures;
}

final class _Options {
  final String reference;
  final String actual;

  const _Options({required this.reference, required this.actual});

  factory _Options.parse(List<String> arguments) {
    String? reference;
    String? actual;
    for (final argument in arguments) {
      if (argument.startsWith('--reference=')) {
        if (reference != null) {
          throw const _UsageException('--reference may only be provided once.');
        }
        reference = argument.substring('--reference='.length);
      } else if (argument.startsWith('--actual=')) {
        if (actual != null) {
          throw const _UsageException('--actual may only be provided once.');
        }
        actual = argument.substring('--actual='.length);
      } else {
        throw _UsageException('unknown argument: $argument');
      }
    }
    if (reference == null ||
        reference.isEmpty ||
        actual == null ||
        actual.isEmpty) {
      throw const _UsageException('--reference and --actual are required.');
    }
    return _Options(reference: reference, actual: actual);
  }
}

final class _ReferenceSuite {
  final Map<String, _ReferenceCase> cases;

  const _ReferenceSuite(this.cases);

  factory _ReferenceSuite.decode(Object? encoded) {
    final document = _object(encoded, r'$');
    _schema(document, r'$');
    final metadata = _object(document['reference'], r'$.reference');
    if (_string(metadata['standard'], r'$.reference.standard') != 'C++23') {
      throw const FormatException(r'$.reference.standard must be C++23.');
    }
    if (_string(metadata['locale'], r'$.reference.locale') != 'C') {
      throw const FormatException(r'$.reference.locale must be C.');
    }
    final cases = <String, _ReferenceCase>{};
    final values = _list(document['cases'], r'$.cases');
    var previousId = '';
    for (var index = 0; index < values.length; index++) {
      final path = '\$.cases[$index]';
      final value = _object(values[index], path);
      final id = _string(value['id'], '$path.id');
      if (id.compareTo(previousId) <= 0) {
        throw FormatException('$path.id is duplicate or out of order.');
      }
      previousId = id;
      final expected = _object(value['expected'], '$path.expected');
      final hasOutput = expected.containsKey('output');
      final hasAllowed = expected.containsKey('allowed');
      if (hasOutput == hasAllowed) {
        throw FormatException(
          '$path.expected must contain exactly one of output or allowed.',
        );
      }
      final outputs =
          hasOutput
              ? [_string(expected['output'], '$path.expected.output')]
              : _strings(expected['allowed'], '$path.expected.allowed');
      if (outputs.isEmpty || outputs.toSet().length != outputs.length) {
        throw FormatException(
          '$path.expected outputs must be non-empty and unique.',
        );
      }
      final sortedOutputs = [...outputs]..sort();
      if (!_sameValues(outputs, sortedOutputs)) {
        throw FormatException('$path.expected.allowed must be sorted.');
      }
      cases[id] = _ReferenceCase(
        template: _string(value['template'], '$path.template'),
        outputs: List.unmodifiable(outputs),
      );
    }
    return _ReferenceSuite(Map.unmodifiable(cases));
  }
}

final class _ActualSuite {
  final _Generator generator;
  final Map<String, _ActualCase> cases;

  const _ActualSuite({required this.generator, required this.cases});

  factory _ActualSuite.decode(Object? encoded) {
    final document = _object(encoded, r'$');
    _schema(document, r'$');
    final generator = _Generator.decode(document['generator']);
    final cases = <String, _ActualCase>{};
    final values = _list(document['cases'], r'$.cases');
    var previousId = '';
    for (var index = 0; index < values.length; index++) {
      final path = '\$.cases[$index]';
      final value = _object(values[index], path);
      final id = _string(value['id'], '$path.id');
      if (id.compareTo(previousId) <= 0) {
        throw FormatException('$path.id is duplicate or out of order.');
      }
      previousId = id;
      cases[id] = _ActualCase(
        template: _string(value['template'], '$path.template'),
        output: _string(value['output'], '$path.output'),
      );
    }
    return _ActualSuite(generator: generator, cases: Map.unmodifiable(cases));
  }
}

final class _Generator {
  final String compiler;
  final String os;

  const _Generator({required this.compiler, required this.os});

  factory _Generator.decode(Object? encoded) {
    final value = _object(encoded, r'$.generator');
    final compiler = _nonEmpty(value['compiler'], r'$.generator.compiler');
    _nonEmpty(value['standard_library'], r'$.generator.standard_library');
    _nonEmpty(value['c_library'], r'$.generator.c_library');
    final os = _nonEmpty(value['os'], r'$.generator.os');
    if (_string(value['locale'], r'$.generator.locale') != 'C') {
      throw const FormatException(r'$.generator.locale must be C.');
    }
    if (_string(value['standard'], r'$.generator.standard') != 'C++23') {
      throw const FormatException(r'$.generator.standard must be C++23.');
    }
    return _Generator(compiler: compiler, os: os);
  }
}

final class _ReferenceCase {
  final String template;
  final List<String> outputs;

  const _ReferenceCase({required this.template, required this.outputs});
}

final class _ActualCase {
  final String template;
  final String output;

  const _ActualCase({required this.template, required this.output});
}

final class _UsageException implements Exception {
  final String message;

  const _UsageException(this.message);
}

void _schema(Map<String, Object?> document, String path) {
  if (document['schema'] != 1) {
    throw FormatException('$path.schema must be 1.');
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

String _nonEmpty(Object? value, String path) {
  final string = _string(value, path);
  if (string.isEmpty) throw FormatException('$path must not be empty.');
  return string;
}

List<String> _strings(Object? value, String path) {
  final values = _list(value, path);
  return [
    for (var index = 0; index < values.length; index++)
      _string(values[index], '$path[$index]'),
  ];
}

bool _sameValues(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
