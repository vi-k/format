/// Frozen, benchmark-local subset of Format 2 from commit 86febb4.
///
/// This library deliberately exposes only [legacyFormat]. It is not part of
/// package:format's public API and must only be imported by benchmarks/tests.
library;

import 'package:characters/characters.dart';

part 'src/options.dart';
part 'src/formatters.dart';
part 'src/processor.dart';

/// Formats positional values with the selected Format 2 behavior.
String legacyFormat(String template, List<Object?> values) =>
    _Format2Processor(template, values).format();
