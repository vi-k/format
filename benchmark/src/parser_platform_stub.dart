List<String> effectiveArguments(List<String> mainArguments) => mainArguments;

void writeTextFile(String path, String contents) {
  throw UnsupportedError('No file-system platform adapter');
}

String readTextFile(String path) {
  throw UnsupportedError('No file-system platform adapter');
}

int? executableSizeBytes() => null;

String detectedRuntime() => 'unsupported';

Map<String, String> runtimeProvenance() => const <String, String>{
  'detector': 'unsupported',
};

String sourceRevision() => '';

Map<String, String> environmentInfo() => const <String, String>{
  'dartVersion': 'unsupported',
  'os': 'unsupported',
  'cpu': 'unsupported',
};
