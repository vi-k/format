/// Runs a suite benchmark on the Dart VM, on dart2js, or on dart2wasm.
///
/// The suite's numbers used to mean "on the Dart VM" and nothing else, because
/// that was the only way to start it. The three runtimes disagree by more than
/// noise — parsing is dearer under dart2js while formatting is cheaper, and
/// dart2wasm sits with the VM on integers but not on much else — so a claim
/// about the package's speed is incomplete until it names one.
///
/// Compilation goes to a temporary directory, not into the repository: the
/// artifacts are large, uninteresting, and stale the moment `lib/` changes.
///
/// ```console
/// dart run tool/run.dart --runtime=wasm
/// dart run tool/run.dart --runtime=js --bin=double_modes
/// dart run tool/run.dart --runtime=vm -- --full
/// ```
library;

import 'dart:io';

/// The four entry points, by the short name this tool accepts.
const _bins = {
  'comparison': 'bin/benchmark.dart',
  'template_ir': 'bin/template_ir_benchmark.dart',
  'double_modes': 'bin/double_modes_benchmark.dart',
  'list_snapshot': 'bin/list_snapshot_benchmark.dart',
};

const _runtimes = ['vm', 'js', 'wasm'];

Future<void> main(List<String> arguments) async {
  final _Options options;
  try {
    options = _Options.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }

  final entryPoint = _bins[options.bin]!;
  if (!File(entryPoint).existsSync()) {
    stderr.writeln(
      'Run this from benchmark/suite: $entryPoint is not here. '
      'The working directory is ${Directory.current.path}.',
    );
    exitCode = 66;
    return;
  }

  final code = switch (options.runtime) {
    'vm' => await _runProcess('dart', [
      'run',
      entryPoint,
      ...options.forwarded,
    ]),
    'js' => await _runCompiled(options, entryPoint, _compileJs),
    _ => await _runCompiled(options, entryPoint, _compileWasm),
  };
  exitCode = code;
}

typedef _Compile =
    Future<List<String>> Function(Directory directory, String entryPoint);

/// Compiles into a scratch directory, runs, and removes it either way.
Future<int> _runCompiled(
  _Options options,
  String entryPoint,
  _Compile compile,
) async {
  final directory = await Directory.systemTemp.createTemp('format-suite-');
  try {
    stderr.writeln('Compiling $entryPoint for ${options.runtime}...');
    final command = await compile(directory, entryPoint);

    return await _runProcess(command.first, [
      ...command.skip(1),
      ...options.forwarded,
    ]);
  } on _CompileFailure catch (failure) {
    stderr.writeln(failure.message);

    return 70;
  } finally {
    await directory.delete(recursive: true);
  }
}

Future<List<String>> _compileJs(Directory directory, String entryPoint) async {
  final output = '${directory.path}/benchmark.js';
  await _compile('js', ['compile', 'js', '-O2', entryPoint, '-o', output]);

  return ['node', output];
}

/// dart2wasm emits a module plus a JavaScript loader, and neither starts on
/// its own: something has to read the bytes, instantiate, and call `main`.
/// That host is written here rather than committed, because it is three lines
/// that must match the loader the compiler just generated.
Future<List<String>> _compileWasm(
  Directory directory,
  String entryPoint,
) async {
  final output = '${directory.path}/benchmark.wasm';
  await _compile('wasm', ['compile', 'wasm', '-O2', entryPoint, '-o', output]);
  final host = File('${directory.path}/host.mjs');
  await host.writeAsString('''
import { readFile } from 'node:fs/promises';
import { compile, instantiate, invoke } from './benchmark.mjs';

const bytes = await readFile(new URL('./benchmark.wasm', import.meta.url));
const instance = await instantiate(await compile(bytes), {});
invoke(instance, ...process.argv.slice(2));
''');

  return ['node', host.path];
}

Future<void> _compile(String label, List<String> arguments) async {
  final result = await Process.run('dart', arguments);
  if (result.exitCode != 0) {
    throw _CompileFailure(
      'Compiling for $label failed:\n${result.stdout}${result.stderr}',
    );
  }
}

Future<int> _runProcess(String executable, List<String> arguments) async {
  final process = await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.inheritStdio,
  );

  return process.exitCode;
}

final class _CompileFailure implements Exception {
  final String message;

  _CompileFailure(this.message);
}

final class _Options {
  final String runtime;
  final String bin;
  final List<String> forwarded;
  final bool help;

  const _Options({
    required this.runtime,
    required this.bin,
    required this.forwarded,
    required this.help,
  });

  /// Everything after a bare `--` goes to the benchmark, so its own options
  /// (`--full`, say) do not have to be known here.
  factory _Options.parse(List<String> arguments) {
    var runtime = 'vm';
    var bin = 'comparison';
    var help = false;
    final forwarded = <String>[];
    var passingThrough = false;

    for (final argument in arguments) {
      if (passingThrough) {
        forwarded.add(argument);
        continue;
      }
      if (argument == '--') {
        passingThrough = true;
        continue;
      }
      if (argument == '--help' || argument == '-h') {
        help = true;
        continue;
      }
      final separator = argument.indexOf('=');
      if (!argument.startsWith('--') || separator < 3) {
        throw FormatException('Expected --name=value, got "$argument".');
      }
      final name = argument.substring(2, separator);
      final value = argument.substring(separator + 1);
      switch (name) {
        case 'runtime':
          if (!_runtimes.contains(value)) {
            throw FormatException(
              'Unknown runtime "$value". Expected one of '
              '${_runtimes.join(', ')}.',
            );
          }
          runtime = value;
        case 'bin':
          if (!_bins.containsKey(value)) {
            throw FormatException(
              'Unknown benchmark "$value". Expected one of '
              '${_bins.keys.join(', ')}.',
            );
          }
          bin = value;
        default:
          throw FormatException('Unknown option "--$name".');
      }
    }

    return _Options(
      runtime: runtime,
      bin: bin,
      forwarded: forwarded,
      help: help,
    );
  }
}

const _usage = '''
Usage: dart run tool/run.dart [--runtime=vm|js|wasm] [--bin=NAME] [-- ARGS]

  --runtime  Where to run. Defaults to vm.
             js compiles with dart2js and runs it under node; wasm compiles
             with dart2wasm and runs the module under node through a generated
             host script. Both need node on PATH.
  --bin      Which benchmark. Defaults to comparison.
             comparison     the four-engine matrix (bin/benchmark.dart)
             template_ir    IR against the legacy path
             double_modes   the two double profiles
             list_snapshot  argument-list snapshot strategies
  --         Everything after this goes to the benchmark itself.

Numbers are not comparable across runtimes measured on different machines,
and the operations per round are calibrated to each runtime's clock: under
dart2js it advances in whole milliseconds, so a count tuned on the VM would
print multiples of 50 ns and nothing else.''';
