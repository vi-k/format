// Materializes the format 1.6.0 baseline from the pub cache.
//
// The implementation file is deliberately not committed: pub is the
// source of truth (and verifies the archive hash on download). Run
// this once per clone before using the benchmark suite:
//
//   dart run benchmark/baselines/format16/fetch.dart
import 'dart:io';

const _version = '1.6.0';

void main() {
  final add = Process.runSync('dart', [
    'pub',
    'cache',
    'add',
    'format',
    '-v',
    _version,
  ]);
  if (add.exitCode != 0) {
    stderr
      ..write(add.stdout)
      ..write(add.stderr);
    exit(1);
  }

  final environment = Platform.environment;
  final pubCache =
      environment['PUB_CACHE'] ??
      (Platform.isWindows
          ? '${environment['LOCALAPPDATA']}\\Pub\\Cache'
          : '${environment['HOME']}/.pub-cache');
  final source = File(
    '$pubCache/hosted/pub.dev/format-$_version/lib/src/format_base.dart',
  );
  if (!source.existsSync()) {
    stderr.writeln('pub cache copy not found: ${source.path}');
    exit(1);
  }

  final scriptDirectory = File.fromUri(Platform.script).parent.path;
  final target = File('$scriptDirectory/lib/src/format_base.dart')
    ..createSync(recursive: true);
  source.copySync(target.path);
  print('format $_version baseline materialized: ${target.path}');
}
