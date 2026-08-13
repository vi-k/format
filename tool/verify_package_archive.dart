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
//
// Reconstruction sees only tracked files, and pub ships untracked ones too, so
// a second check refuses by name anything in the checkout that is neither
// tracked nor excluded. That is the gap through which `coverage/lcov.info`
// reached a 235 KB upload while this tool called the archive clean.

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
  _rejectUntrackedShippables(root, exclusions, tracked.toSet());

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

/// Whether pub drops [path] on its own, whatever the ignore files say.
///
/// Measured rather than assumed: an untracked `stray_probe.txt` placed in the
/// checkout appears in `dart pub publish --dry-run`, and the untracked
/// `.superpowers/` beside it does not. Pub skips an entry whose name begins
/// with a dot, at any depth, and ships everything else it is not told to
/// exclude — which is why the check below is about the files that are *not*
/// hidden.
bool _isHidden(String path) =>
    path.split('/').any((segment) => segment.startsWith('.')) ||
    _pubDropsByName.contains(path);

/// What pub leaves out by name rather than by dot.
///
/// Measured the same way: `pubspec.lock` was tracked and still did not appear
/// in the archive tree, so pub drops it for a package whatever the checkout
/// says. Listed here so untracking it does not make this check report it as
/// something that would ship.
const _pubDropsByName = {'pubspec.lock'};

/// Fails on any working-tree file that `.pubignore` lets through and git does
/// not track.
///
/// The check above reconstructs the archive from tracked files, so a file that
/// is untracked is invisible to it — and invisible is exactly what pub is not:
/// with a `.pubignore` present pub stops reading `.gitignore` altogether, so a
/// local build output or coverage report ships unless `.pubignore` names it
/// too. That is how `coverage/lcov.info` reached the published archive, 30 KB
/// of a 235 KB upload, while this tool reported the archive clean.
///
/// Stated as "untracked never ships" rather than as a list of what to exclude:
/// a package is its tracked sources, and anything else in the checkout is a
/// measurement of it or an output from it.
void _rejectUntrackedShippables(
  Directory root,
  List<String> exclusions,
  Set<String> tracked,
) {
  final prefix = '${root.path}/';
  final stray = <String>[];
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final path =
        entity.path.startsWith(prefix)
            ? entity.path.substring(prefix.length)
            : entity.path;
    if (_isHidden(path)) continue;
    if (_isExcluded(path, exclusions) || tracked.contains(path)) continue;
    stray.add(path);
  }
  if (stray.isEmpty) return;
  stray.sort();
  _fail(
    'These files are untracked and not excluded by .pubignore, so pub would '
    'publish them:\n  ${stray.join('\n  ')}\n'
    'Add them to .pubignore, or track them if they belong to the package.',
  );
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
