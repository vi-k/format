import 'dart:js_interop';

const _dartCompilerVersion = String.fromEnvironment(
  'format.benchmark.dartCompilerVersion',
);
const _sourceRevision = String.fromEnvironment(
  'format.benchmark.sourceRevision',
);

@JS('process')
external _NodeProcess get _process;

extension type _NodeProcess._(JSObject _) implements JSObject {
  external JSArray<JSString> get argv;
  external String get arch;
  external String get platform;
  external String get version;
  external JSObject getBuiltinModule(String module);
}

extension type _NodeFileSystem._(JSObject _) implements JSObject {
  external String readFileSync(String path, String encoding);
  external void writeFileSync(String path, String contents);
  external _NodeFileStat statSync(String path);
}

extension type _NodeFileStat._(JSObject _) implements JSObject {
  external num get size;
}

extension type _NodeOs._(JSObject _) implements JSObject {
  external JSArray<_NodeCpu> cpus();
  external String release();
}

extension type _NodeCpu._(JSObject _) implements JSObject {
  external String get model;
}

/// Node hands the arguments after the script, and does so identically whether
/// the script is dart2js output or the loader that instantiates a wasm module.
/// Everything in this file is shared by both backends for that reason: the two
/// differ in what they call themselves, not in how they reach the host.
List<String> effectiveArguments(List<String> mainArguments) =>
    _process.argv.toDart.skip(2).map((argument) => argument.toDart).toList();

void writeTextFile(String path, String contents) {
  _NodeFileSystem._(
    _process.getBuiltinModule('fs'),
  ).writeFileSync(path, contents);
}

String readTextFile(String path) => _NodeFileSystem._(
  _process.getBuiltinModule('fs'),
).readFileSync(path, 'utf8');

int? executableSizeBytes() =>
    _NodeFileSystem._(
      _process.getBuiltinModule('fs'),
    ).statSync(_process.argv.toDart[1].toDart).size.toInt();

Map<String, String> nodeEnvironmentInfo(String compiler) {
  final os = _NodeOs._(_process.getBuiltinModule('os'));
  final cpus = os.cpus().toDart;
  return <String, String>{
    'dartVersion':
        _dartCompilerVersion.isEmpty
            ? 'Dart SDK ($compiler version unavailable)'
            : 'Dart $_dartCompilerVersion',
    'os':
        '${_process.platform} ${os.release()} (${_process.arch}); '
        'Node ${_process.version}',
    'cpu': cpus.isEmpty ? '${_process.arch} CPU' : cpus.first.model,
  };
}

Map<String, String> nodeRuntimeProvenance(String compiler) => <String, String>{
  'detector': '$compiler.compile-time-define',
  'dartCompilerVersion': _dartCompilerVersion,
  'nodeVersion': _process.version,
};

String sourceRevision() => _sourceRevision;
