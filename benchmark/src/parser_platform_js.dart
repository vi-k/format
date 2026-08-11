/// The dart2js half of the node platform adapter.
///
/// Everything that talks to node lives in `parser_platform_node.dart` and is
/// shared with dart2wasm; what stays here is the pair of answers that must not
/// be shared, because the whole point of provenance is that a report says which
/// backend produced it. Declaring that in one place per backend keeps a wasm
/// run from being labelled `js` by a copy nobody updated.
library;

import 'parser_platform_node.dart';

export 'parser_platform_node.dart'
    show
        effectiveArguments,
        executableSizeBytes,
        readTextFile,
        sourceRevision,
        writeTextFile;

String detectedRuntime() => 'js';

Map<String, String> environmentInfo() => nodeEnvironmentInfo('dart2js');

Map<String, String> runtimeProvenance() => nodeRuntimeProvenance('dart2js');
