// Tests the fixture verifier itself: a gate is only worth having if it is
// known to go red. It lives beside the tool rather than in `test/`, because
// `tool/` is excluded from the published archive and a shipped test may not
// depend on anything the archive drops.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
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
