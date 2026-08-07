// Materializes the package the way `dart pub publish` would and checks that
// the result stands on its own.
//
// The failure this exists to catch: `.pubignore` drops a directory that the
// shipped sources still reference. A local `dart analyze` cannot see it,
// because locally the dropped directory is still there.
//
// The file set is reconstructed from `git ls-files` minus `.pubignore`, which
// is how pub itself picks files inside a git checkout. Only the simple
// leading-slash patterns this project uses are understood; anything else is a
// hard error, so the check can never silently under-approximate the archive.

import 'dart:io';

void main(List<String> arguments) {
  final root = Directory.current;
  final exclusions = _readExclusions(File('${root.path}/.pubignore'));
  final tracked = _trackedFiles(root);
  final shipped = [
    for (final path in tracked)
      if (!_isExcluded(path, exclusions)) path,
  ];

  if (shipped.isEmpty) {
    _fail('Reconstructed an empty archive; is this a git checkout?');
  }

  final staging = Directory.systemTemp.createTempSync('format-archive-');
  try {
    for (final path in shipped) {
      final target = File('${staging.path}/$path')
        ..parent.createSync(recursive: true);
      File('${root.path}/$path').copySync(target.path);
    }
    stdout.writeln(
      'Reconstructed ${shipped.length} files '
      '(${tracked.length - shipped.length} excluded by .pubignore).',
    );

    _run('dart', ['pub', 'get'], staging.path);
    _run('dart', ['analyze', '--fatal-infos'], staging.path);
    _run('dart', ['test'], staging.path);
    stdout.writeln('The published archive analyzes and tests on its own.');
  } finally {
    staging.deleteSync(recursive: true);
  }
}

List<String> _readExclusions(File pubignore) {
  if (!pubignore.existsSync()) return const [];
  final exclusions = <String>[];
  for (final line in pubignore.readAsLinesSync()) {
    final entry = line.trim();
    if (entry.isEmpty || entry.startsWith('#')) continue;
    if (!entry.startsWith('/') || entry.contains('*') || entry.contains('?')) {
      _fail(
        'Unsupported .pubignore pattern "$entry". This check only models '
        'anchored literal paths; teach it the new pattern before using one.',
      );
    }
    exclusions.add(entry.substring(1));
  }

  return exclusions;
}

List<String> _trackedFiles(Directory root) {
  final result = Process.runSync('git', [
    'ls-files',
  ], workingDirectory: root.path);
  if (result.exitCode != 0) {
    _fail('git ls-files failed: ${result.stderr}');
  }
  return (result.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

bool _isExcluded(String path, List<String> exclusions) => exclusions.any(
  (exclusion) =>
      exclusion.endsWith('/') ? path.startsWith(exclusion) : path == exclusion,
);

void _run(String executable, List<String> arguments, String directory) {
  stdout.writeln('\$ $executable ${arguments.join(' ')}');
  final result = Process.runSync(
    executable,
    arguments,
    workingDirectory: directory,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    _fail('$executable ${arguments.join(' ')} failed in the archive.');
  }
}

Never _fail(String message) {
  stderr.writeln('verify_package_archive: $message');
  exit(1);
}
