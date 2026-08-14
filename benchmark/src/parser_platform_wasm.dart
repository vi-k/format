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

/// The runner arguments arrive through `main`, not through `process.argv`.
///
/// The dart2js build has to read them off the process, because node calls its
/// script with `main` empty. Both wasm hosts instead pass only the runner
/// arguments to `invokeMain`: the committed host removes its module path
/// first, while the generated host always loads a fixed module. Reading
/// `process.argv` here would therefore disagree with the loader contract.
List<String> effectiveArguments(List<String> mainArguments) => mainArguments;

String detectedRuntime() => 'wasm';

Map<String, String> environmentInfo() => nodeEnvironmentInfo('dart2wasm');

Map<String, String> runtimeProvenance() => nodeRuntimeProvenance('dart2wasm');
