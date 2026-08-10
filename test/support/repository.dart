/// Locating the repository's own files from a test, without depending on the
/// directory the test was started from.
///
/// Fixtures, the divergence registries and `README.md` are all read by tests,
/// and reading them through a path like `test/fixtures/...` silently requires
/// the runner to have been started at the repository root. Started anywhere
/// else the test does not fail with "run this from the root" — it fails with a
/// `FileSystemException` naming a path that does not exist, which reads like a
/// missing fixture.
///
/// `Platform.script` is the obvious remedy and the wrong one: `dart test`
/// compiles each suite into a temporary kernel file, so the script is
/// something like `/tmp/dart_test.kernel.XXXX/test.dart_1.dill` and knows
/// nothing about where the sources live. The working directory does know,
/// indirectly but reliably — the runner resolves its package configuration
/// from it, so it is always inside the package — and the root is the nearest
/// ancestor whose `pubspec.yaml` names this package.
///
/// The search is deliberately not satisfied by *any* `pubspec.yaml`:
/// `benchmark/suite` is a package of its own, and a walk that stopped there
/// would resolve fixture paths against a directory that has no fixtures.
library;

import 'dart:io';

/// The repository root.
final Directory repositoryRoot = findRepositoryRoot(Directory.current);

/// [relative], a path written with forward slashes from the repository root,
/// as a [File] on this platform.
File repositoryFile(String relative) =>
    File.fromUri(repositoryRoot.uri.resolve(relative));

const _packageName = 'format';

/// The nearest ancestor of [start], or [start] itself, whose `pubspec.yaml`
/// names this package.
///
/// Takes its starting point rather than reading [Directory.current] so that
/// the walk can be tested without moving the process — the working directory
/// is global, and a test that changed it would change it for every other test
/// sharing the isolate.
Directory findRepositoryRoot(Directory start) {
  var directory = start.absolute;
  while (true) {
    final pubspec = File.fromUri(directory.uri.resolve('pubspec.yaml'));
    if (pubspec.existsSync() && _declaresPackage(pubspec)) return directory;
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError(
        'No pubspec.yaml naming "$_packageName" above ${start.absolute.path}. '
        'These tests read committed fixtures, so they have to run from '
        'inside the repository.',
      );
    }
    directory = parent;
  }
}

/// Whether [pubspec] declares this package, read as text rather than parsed:
/// the tests already depend on nothing but the SDK and `package:test`, and one
/// `name:` line does not justify a YAML parser.
bool _declaresPackage(File pubspec) {
  for (final line in pubspec.readAsLinesSync()) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('name:')) continue;
    return trimmed.substring('name:'.length).trim() == _packageName;
  }

  return false;
}
