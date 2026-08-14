/// Transient parser memory, measured in a child process so the assertion sees
/// the parser's heap rather than the test runner and its concurrent tests.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

const _maximumParserAmplification = 20 * 1024 * 1024;

void main() {
  // A numeric item key used to become both a substring and one list element
  // per digit before the 64-bit boundary was checked. Five million zeroes are
  // intentionally valid and resolve to index zero, so rejecting the token is
  // not an acceptable way to satisfy this memory boundary. Restoring the
  // eager list raises the child process by about 114 MiB on the reference VM.
  test(
    'a numeric item key does not amplify its source into a digit list',
    () async {
      final result = await _probe('item');

      expect(result.outcome, 'value');
      expect(result.maxRssDelta, lessThan(_maximumParserAmplification));
    },
  );

  // The general format-specification parser used to split the whole source
  // into one String reference per unit before it inspected a width. The same
  // five-million-zero spelling is a valid width of zero, so it must keep
  // formatting while staying under the memory boundary. Restoring the eager
  // list raises the reference VM's previous maximum by about 29 MiB.
  test(
    'a numeric width does not amplify its source into a unit list',
    () async {
      final result = await _probe('width');

      expect(result.outcome, '1');
      expect(result.maxRssDelta, lessThan(_maximumParserAmplification));
    },
  );
}

Future<({int maxRssDelta, String outcome})> _probe(String kind) async {
  final root = Directory.current.absolute.path;
  final result = await Process.run(Platform.resolvedExecutable, [
    '--packages=$root/.dart_tool/package_config.json',
    '$root/test/fixtures/parser_memory_probe.dart',
    kind,
  ]);
  expect(result.exitCode, 0, reason: result.stderr as String);
  final report = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  return (
    maxRssDelta: report['maxRssDelta'] as int,
    outcome: report['outcome'] as String,
  );
}
