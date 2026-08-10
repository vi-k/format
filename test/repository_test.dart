/// The lookup that lets the fixture-reading tests run from anywhere.
///
/// Three files read committed data — the CPython fixtures, the C++ fixtures
/// and their divergence registries, `README.md` for the anchors, and
/// `lib/format.dart` for the export check — and every one of them used to
/// spell its path from the repository root, which quietly required the runner
/// to have been started there. Started one directory down they did not say so:
/// they reported a `FileSystemException` for a fixture that was present all
/// along.
///
/// What is pinned here is the part that is easy to get subtly wrong. Stopping
/// at the first `pubspec.yaml` would look correct from the root and resolve to
/// the wrong directory from `benchmark/suite`, which is a package in its own
/// right — and the fixtures are not under it, so the failure would be the same
/// confusing missing-file report this replaced.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/repository.dart';

void main() {
  // The root itself, a directory below it, and one several levels down: the
  // walk has to terminate on the first, and climb from the others.
  test('finds the repository root from anywhere inside it', () {
    final root = repositoryRoot.path;

    expect(findRepositoryRoot(repositoryRoot).path, root);
    expect(
      findRepositoryRoot(
        Directory.fromUri(repositoryRoot.uri.resolve('test')),
      ).path,
      root,
    );
    expect(
      findRepositoryRoot(
        Directory.fromUri(repositoryRoot.uri.resolve('test/fixtures')),
      ).path,
      root,
    );
  });

  // The case a first-pubspec-wins walk gets wrong. This repository has such a
  // nesting — `benchmark/suite` is a package of its own — but the pair is
  // built in a temporary directory rather than pointed at, because
  // `benchmark/` is excluded from the published archive and a test that
  // reached for it would pass here and vanish there.
  test('walks past a nested package with its own pubspec', () async {
    final outer = await Directory.systemTemp.createTemp('format-root-');
    try {
      final inner = Directory.fromUri(outer.uri.resolve('suite'));
      await inner.create();
      await File.fromUri(
        outer.uri.resolve('pubspec.yaml'),
      ).writeAsString('name: format\n');
      await File.fromUri(
        inner.uri.resolve('pubspec.yaml'),
      ).writeAsString('name: format_benchmarks\n');

      expect(
        findRepositoryRoot(inner).uri,
        outer.uri,
        reason: 'остановка на первом pubspec дала бы вложенный пакет',
      );
    } finally {
      await outer.delete(recursive: true);
    }
  });

  // Outside the repository there is no answer, and saying so beats resolving
  // to something arbitrary: the message names the directory that was searched
  // from, which is the one fact needed to fix the invocation.
  test('refuses to guess outside the repository', () {
    expect(
      () => findRepositoryRoot(Directory.systemTemp),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(Directory.systemTemp.absolute.path),
        ),
      ),
    );
  });

  // The point of all of the above: the files the other suites read are found,
  // whatever the working directory was.
  test('resolves the files the fixture suites read', () {
    for (final relative in [
      'README.md',
      'lib/format.dart',
      'test/fixtures/python_format.json',
      'test/fixtures/python_divergences.json',
      'test/fixtures/sprintf_common.json',
      'test/fixtures/sprintf_divergences.json',
    ]) {
      expect(repositoryFile(relative).existsSync(), isTrue, reason: relative);
    }
  });
}
