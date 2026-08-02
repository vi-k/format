import 'dart:io';

const _isAot = bool.fromEnvironment('dart.vm.product');

List<String> effectiveArguments(List<String> mainArguments) => mainArguments;

void writeTextFile(String path, String contents) {
  File(path).writeAsStringSync(contents);
}

String readTextFile(String path) => File(path).readAsStringSync();

String detectedRuntime() => _isAot ? 'aot' : 'jit';

Map<String, String> runtimeProvenance() => <String, String>{
  'detector': 'dart.vm.product',
  'value': '$_isAot',
};

int? executableSizeBytes() {
  if (!_isAot) return null;
  final executable = File(Platform.resolvedExecutable);
  return executable.existsSync() ? executable.lengthSync() : null;
}

Map<String, String> environmentInfo() => <String, String>{
  'dartVersion': Platform.version,
  'os': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
  'cpu': _cpuDescription(),
};

String _cpuDescription() {
  if (Platform.isMacOS) {
    final result = Process.runSync('/usr/sbin/sysctl', const [
      '-n',
      'machdep.cpu.brand_string',
    ]);
    if (result.exitCode == 0) {
      final value = result.stdout.toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
  }
  if (Platform.isLinux) {
    final cpuInfo = File('/proc/cpuinfo');
    if (cpuInfo.existsSync()) {
      for (final line in cpuInfo.readAsLinesSync()) {
        if (line.startsWith('model name') || line.startsWith('Hardware')) {
          final separator = line.indexOf(':');
          if (separator >= 0) {
            return line.substring(separator + 1).trim();
          }
        }
      }
    }
  }
  return Platform.environment['PROCESSOR_IDENTIFIER'] ??
      '${Platform.operatingSystem} CPU';
}
