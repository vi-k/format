// Summarizes an LCOV report and holds line coverage to a floor.
//
// 518 tests look like a lot, and that is the problem: nothing in a green run
// says which branches never executed. This reads the report `dart test
// --coverage` produces and prints the number, per file, worst first — so the
// gaps are visible rather than assumed away — and fails when the total drops
// below a floor.
//
// The floor is one-sided, like the performance gate: rising above it never
// fails, so it goes stale rather than wrong. Raising it is a deliberate edit,
// and the printed total is what tells you it is worth making.
//
// It is measured on the VM only. `dart test --coverage` collects through the
// VM service, which dart2js output does not have, so the web-only branches
// (`_isWeb`, `_isWebInt`) cannot be reached here at all — they are dead code on
// this platform by construction, and they are what most of the remaining gap
// consists of. Their behaviour is pinned by the node run instead, which
// produces no coverage of its own. A floor of 100% is therefore not a target
// this measurement could ever express.
//
// Usage:
//   dart run tool/check_coverage.dart --lcov=FILE [--minimum=PERCENT]
//   dart run tool/check_coverage.dart --self-test

import 'dart:io';

/// The line coverage the VM suite is expected to keep.
///
/// Measured at 95.1% when this was introduced. The floor sits below that on
/// purpose: a single new web-only branch legitimately lowers the number, and a
/// gate that fails on a change it cannot object to is a gate people learn to
/// override.
const _defaultMinimum = 94.0;

void main(List<String> arguments) {
  String? lcov;
  var minimum = _defaultMinimum;
  var selfTest = false;
  for (final argument in arguments) {
    if (argument == '--self-test') {
      selfTest = true;
    } else if (argument.startsWith('--lcov=')) {
      lcov = argument.substring('--lcov='.length);
    } else if (argument.startsWith('--minimum=')) {
      final value = double.tryParse(argument.substring('--minimum='.length));
      if (value == null) {
        _usage('not a percentage: $argument');
        return;
      }
      minimum = value;
    } else {
      _usage('unknown argument: $argument');
      return;
    }
  }

  if (selfTest) {
    _runSelfTest();
    return;
  }
  if (lcov == null) {
    _usage('--lcov is required');
    return;
  }

  final file = File(lcov);
  if (!file.existsSync()) {
    stderr.writeln('no coverage report at $lcov: run dart test --coverage');
    exitCode = 1;
    return;
  }

  final report = parseLcov(file.readAsStringSync());
  if (report.lines == 0) {
    stderr.writeln('$lcov records no lines at all');
    exitCode = 1;
    return;
  }

  // Worst first: the head of this list is the whole reason to measure.
  final files =
      report.files.entries.toList()
        ..sort((a, b) => a.value.percent.compareTo(b.value.percent));
  for (final entry in files) {
    final counts = entry.value;
    stdout.writeln(
      '${counts.percent.toStringAsFixed(2).padLeft(6)}%  '
      '${counts.covered.toString().padLeft(5)}/'
      '${counts.lines.toString().padRight(5)}  ${entry.key}',
    );
  }
  stdout.writeln(
    'total ${report.percent.toStringAsFixed(2)}% '
    '(${report.covered}/${report.lines} lines), floor $minimum%',
  );

  if (report.percent < minimum) {
    stderr.writeln(
      'line coverage ${report.percent.toStringAsFixed(2)}% is below the '
      '$minimum% floor',
    );
    exitCode = 1;
  }
}

void _usage(String message) {
  stderr
    ..writeln(message)
    ..writeln(
      'usage: dart run tool/check_coverage.dart --lcov=FILE '
      '[--minimum=PERCENT] | --self-test',
    );
  exitCode = 64;
}

/// Line counts for one file, or for a whole report.
final class CoverageCounts {
  final int lines;
  final int covered;

  const CoverageCounts(this.lines, this.covered);

  double get percent => lines == 0 ? 100 : covered * 100 / lines;
}

/// A parsed LCOV report: the total, and the same counts per file.
final class CoverageReport {
  final Map<String, CoverageCounts> files;
  final int lines;
  final int covered;

  const CoverageReport(this.files, this.lines, this.covered);

  double get percent => lines == 0 ? 100 : covered * 100 / lines;
}

/// Reads the two LCOV records that matter here: `SF:` names a file and `DA:`
/// gives a line number and how many times it ran.
///
/// Everything else in the format — functions, branches, checksums — is either
/// absent from what `format_coverage` emits or measures something this floor
/// does not claim to cover.
CoverageReport parseLcov(String text) {
  final files = <String, CoverageCounts>{};
  var lines = 0;
  var covered = 0;
  var currentLines = 0;
  var currentCovered = 0;
  String? current;

  void flush() {
    final file = current;
    if (file == null) return;
    files[file] = CoverageCounts(currentLines, currentCovered);
    currentLines = 0;
    currentCovered = 0;
  }

  for (final line in text.split('\n')) {
    if (line.startsWith('SF:')) {
      flush();
      current = line.substring(3).trim();
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).trim().split(',');
      if (parts.length < 2) continue;
      final count = int.tryParse(parts[1]);
      if (count == null) continue;
      currentLines++;
      lines++;
      if (count > 0) {
        currentCovered++;
        covered++;
      }
    }
  }
  flush();

  return CoverageReport(files, lines, covered);
}

/// Checks the parser and the verdict without needing a coverage run.
void _runSelfTest() {
  final failures = <String>[];

  void check(String what, bool condition) {
    if (!condition) failures.add('self-test: $what');
  }

  const report = '''
SF:lib/a.dart
DA:1,1
DA:2,0
DA:3,4
end_of_record
SF:lib/b.dart
DA:1,0
end_of_record
''';
  final parsed = parseLcov(report);
  check('every file is read', parsed.files.length == 2);
  check('lines are counted across files', parsed.lines == 4);
  check(
    'an executed line counts once, however often it ran',
    parsed.covered == 2,
  );
  check('the total is the ratio of the two', parsed.percent == 50);
  check(
    'per-file counts are kept apart',
    parsed.files['lib/a.dart']!.covered == 2 &&
        parsed.files['lib/b.dart']!.covered == 0,
  );
  check(
    'a file with nothing executed reports zero',
    parsed.files['lib/b.dart']!.percent == 0,
  );
  check('an empty report is not silently perfect', parseLcov('').lines == 0);
  check(
    'a malformed count is skipped rather than counted as covered',
    parseLcov('SF:lib/a.dart\nDA:1,x\n').lines == 0,
  );

  if (failures.isNotEmpty) {
    failures.forEach(stderr.writeln);
    exitCode = 1;
    return;
  }
  stdout.writeln('Coverage report self-test passed.');
}
