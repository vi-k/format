/// The dart2wasm half of the node platform adapter. See
/// `parser_platform_js.dart` for why the split is exactly here.
///
/// dart2wasm is web-shaped in how it reaches the host — the same
/// `dart:js_interop`, the same node underneath — and unlike dart2js in what it
/// computes with: its integers are real 64-bit ones. Measuring it as a fourth
/// runtime rather than assuming it behaves like one of the other three is the
/// point; a defect that needed exactly that combination went unseen until the
/// suite was first started here.
library;

import 'parser_platform_node.dart';

export 'parser_platform_node.dart'
    show executableSizeBytes, readTextFile, sourceRevision, writeTextFile;

/// The arguments arrive through `main`, not through `process.argv`.
///
/// The dart2js build has to read them off the process, because node calls its
/// script with `main` empty. The wasm loader instead passes whatever the host
/// handed `invoke` straight into `main` — and the host also passes the module
/// path, which is not the runner's business, so reading `process.argv` here
/// would feed it the path as an option and abort on it.
List<String> effectiveArguments(List<String> mainArguments) => mainArguments;

String detectedRuntime() => 'wasm';

Map<String, String> environmentInfo() => nodeEnvironmentInfo('dart2wasm');

Map<String, String> runtimeProvenance() => nodeRuntimeProvenance('dart2wasm');
