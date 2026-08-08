// Checks that every committed generated artifact still matches its generator.
//
// Three files in this repository are produced by tools rather than written:
// the Python reference fixtures, the Python identifier tables, and the C++
// sprintf reference. Nothing about them announces that they are stale — a
// generator edited without regenerating, or an artifact edited by hand, leaves
// a repository where the tests pass and the fixtures no longer describe what
// the generator produces.
//
// So this tool regenerates each one into a scratch directory and compares. The
// artifacts are never overwritten: a checker that writes to the working tree
// cannot be run on a dirty checkout, and its failure and its fix would look the
// same in `git status`.
//
// The Python generators need CPython 3.14 and the C++ one needs a C++23
// compiler. A missing tool is a failure, not a skip — a check that quietly
// passes when it cannot run is worse than no check.
//
// Usage:
//   dart run tool/verify_generated_artifacts.dart [--python=CMD] [--cxx=CMD]
//   dart run tool/verify_generated_artifacts.dart --self-test

import 'dart:io';

Future<void> main(List<String> arguments) async {
  var python = 'python3.14';
  var cxx = 'c++';
  var selfTest = false;
  for (final argument in arguments) {
    if (argument == '--self-test') {
      selfTest = true;
    } else if (argument.startsWith('--python=')) {
      python = argument.substring('--python='.length);
    } else if (argument.startsWith('--cxx=')) {
      cxx = argument.substring('--cxx='.length);
    } else {
      stderr
        ..writeln('unknown argument: $argument')
        ..writeln(
          'usage: dart run tool/verify_generated_artifacts.dart '
          '[--python=CMD] [--cxx=CMD] | --self-test',
        );
      exitCode = 64;
      return;
    }
  }

  if (selfTest) {
    _runSelfTest();
    return;
  }

  final scratch = await Directory.systemTemp.createTemp('format-artifacts-');
  final failures = <String>[];
  try {
    failures
      ..addAll(await _checkPythonFixtures(python, scratch))
      ..addAll(await _checkPythonIdentifiers(python, scratch))
      ..addAll(await _checkSprintfFixtures(cxx, scratch));
  } finally {
    await scratch.delete(recursive: true);
  }

  if (failures.isNotEmpty) {
    failures.forEach(stderr.writeln);
    exitCode = 1;
    return;
  }
  stdout.writeln('Every generated artifact matches its generator.');
}

Future<List<String>> _checkPythonFixtures(
  String python,
  Directory scratch,
) async {
  const artifact = 'test/fixtures/python_format.json';
  final regenerated = '${scratch.path}/python_format.json';
  final run = await _run(python, [
    'tool/generate_python_fixtures.py',
    '--output=$regenerated',
  ]);
  if (run != null) return [run];
  return _compare(artifact, regenerated, normalize: (text) => text);
}

Future<List<String>> _checkPythonIdentifiers(
  String python,
  Directory scratch,
) async {
  const artifact = 'lib/src/python_identifier.dart';
  final regenerated = '${scratch.path}/python_identifier.dart';
  final run = await _run(python, [
    'tool/generate_python_identifiers.py',
    '--output=$regenerated',
  ]);
  if (run != null) return [run];
  return _compare(artifact, regenerated, normalize: normalizeInterpreterPatch);
}

Future<List<String>> _checkSprintfFixtures(
  String cxx,
  Directory scratch,
) async {
  const reference = 'test/fixtures/sprintf_common.json';
  final binary = '${scratch.path}/generate_sprintf_fixtures';
  final regenerated = '${scratch.path}/sprintf_actual.json';

  final compiled = await _run(cxx, [
    '-std=c++23',
    '-O2',
    '-o',
    binary,
    'tool/generate_sprintf_fixtures.cpp',
  ]);
  if (compiled != null) return [compiled];

  final generated = await _run(binary, [regenerated]);
  if (generated != null) return [generated];

  // The C++ fixtures are not compared byte for byte: the file records the
  // compiler, the standard library and the operating system that produced it,
  // and documented cases carry several allowed spellings. The verifier that
  // already knows those rules does the comparison.
  final verified = await _run(Platform.resolvedExecutable, [
    'run',
    'tool/verify_sprintf_fixtures.dart',
    '--reference=$reference',
    '--actual=$regenerated',
  ]);
  return verified == null ? const [] : [verified];
}

/// Runs [executable], returning null on success and a report on failure.
Future<String?> _run(String executable, List<String> arguments) async {
  final ProcessResult result;
  try {
    result = await Process.run(executable, arguments);
  } on ProcessException catch (error) {
    return '$executable is required and could not be run: ${error.message}';
  }
  if (result.exitCode == 0) return null;
  final output = '${result.stdout}${result.stderr}'.trim();
  return '$executable ${arguments.join(' ')} failed '
      '(exit ${result.exitCode})${output.isEmpty ? '' : ':\n$output'}';
}

/// Compares a committed artifact against a freshly generated one.
List<String> _compare(
  String artifact,
  String regenerated, {
  required String Function(String) normalize,
}) {
  final committed = File(artifact).readAsStringSync();
  final produced = File(regenerated).readAsStringSync();
  return describeDifference(
    artifact: artifact,
    committed: normalize(committed),
    produced: normalize(produced),
  );
}

/// Drops the patch component of the interpreter version recorded in a
/// generated header.
///
/// The identifier tables come from the Unicode database, so what has to match
/// is the Unicode version — which stays in the line. A patch release of the
/// interpreter changes the stamp and nothing else, and failing on that would
/// turn the check red for a reason nobody in this repository chose.
String normalizeInterpreterPatch(String text) =>
    text.replaceAllMapped(_interpreterVersion, (match) => 'Python ${match[1]}');

final _interpreterVersion = RegExp(r'Python (\d+\.\d+)\.\d+');

/// Reports the first line on which two versions of an artifact differ.
///
/// A whole-file diff of a generated table is unreadable, and the useful part of
/// the report is where it starts to differ and what to run to fix it.
List<String> describeDifference({
  required String artifact,
  required String committed,
  required String produced,
}) {
  if (committed == produced) return const [];
  final committedLines = committed.split('\n');
  final producedLines = produced.split('\n');
  var line = 0;
  while (line < committedLines.length &&
      line < producedLines.length &&
      committedLines[line] == producedLines[line]) {
    line++;
  }
  return [
    '$artifact is out of date: regenerate it with its tool in tool/.',
    '  first difference at line ${line + 1}',
    '  committed: ${_excerpt(committedLines, line)}',
    '  generated: ${_excerpt(producedLines, line)}',
  ];
}

String _excerpt(List<String> lines, int index) {
  if (index >= lines.length) return '<end of file>';
  final line = lines[index];
  return line.length <= 100 ? line : '${line.substring(0, 100)}…';
}

/// Checks the comparison itself, without needing either generator installed.
///
/// The rest of this tool is plumbing around one decision — do these two files
/// say the same thing — and that decision is what would fail silently. A run
/// that reported success because it compared a file with itself, or because the
/// normalization erased a real difference, would look exactly like a clean
/// repository.
void _runSelfTest() {
  final failures = <String>[];

  void check(String what, bool condition) {
    if (!condition) failures.add('self-test: $what');
  }

  check(
    'identical content reports no difference',
    describeDifference(
      artifact: 'x',
      committed: 'a\nb\n',
      produced: 'a\nb\n',
    ).isEmpty,
  );
  check(
    'differing content is reported',
    describeDifference(
      artifact: 'x',
      committed: 'a\nb\n',
      produced: 'a\nc\n',
    ).isNotEmpty,
  );
  check(
    'the reported line is where the difference starts',
    describeDifference(
      artifact: 'x',
      committed: 'a\nb\n',
      produced: 'a\nc\n',
    ).any((line) => line.contains('line 2')),
  );
  check(
    'truncation is reported rather than passed over',
    describeDifference(
      artifact: 'x',
      committed: 'a\nb\n',
      produced: 'a\n',
    ).isNotEmpty,
  );

  const stamp = '// with Python 3.14.6 and Unicode 16.0.0.';
  check(
    'a patch release of the interpreter is not a difference',
    normalizeInterpreterPatch(stamp) ==
        normalizeInterpreterPatch('// with Python 3.14.7 and Unicode 16.0.0.'),
  );
  check(
    'a different Unicode database is a difference',
    normalizeInterpreterPatch(stamp) !=
        normalizeInterpreterPatch('// with Python 3.14.6 and Unicode 17.0.0.'),
  );
  check(
    'a different interpreter minor version is a difference',
    normalizeInterpreterPatch(stamp) !=
        normalizeInterpreterPatch('// with Python 3.15.0 and Unicode 16.0.0.'),
  );

  if (failures.isNotEmpty) {
    failures.forEach(stderr.writeln);
    exitCode = 1;
    return;
  }
  stdout.writeln('Artifact comparison self-test passed.');
}
