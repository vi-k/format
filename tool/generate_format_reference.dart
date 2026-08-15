import 'dart:io';

import 'src/format_reference_generator.dart';

Future<void> main(List<String> arguments) async {
  final mode = switch (arguments) {
    ['--write'] => FormatReferenceGenerationMode.write,
    ['--check'] => FormatReferenceGenerationMode.check,
    _ => null,
  };
  if (mode == null) {
    stderr.writeln(
      'usage: dart run tool/generate_format_reference.dart --write|--check',
    );
    exitCode = 64;
    return;
  }

  final stale = await generateFormatReferenceArtifacts(
    root: Directory.current,
    mode: mode,
  );
  if (mode == FormatReferenceGenerationMode.check && stale.isNotEmpty) {
    for (final path in stale) {
      stderr.writeln('$path is out of date');
    }
    exitCode = 1;
    return;
  }
  if (mode == FormatReferenceGenerationMode.write) {
    for (final path in stale) {
      stdout.writeln('updated $path');
    }
  }
}
