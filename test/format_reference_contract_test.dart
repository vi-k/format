/// The generated format reference executed through the public API, plus the
/// parser inventories that keep its finite type and flag matrices complete.
///
/// The generated cases pin exact output and error classes independently of
/// the engine, while the internal seams catch a parser conversion or flag
/// being added without a corresponding reference row.
library;

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

import 'support/format_reference_cases.dart';

void main() {
  // Each expectation comes from the generated catalog projection rather than
  // from the formatter under test, so a wrong output or error branch cannot
  // compute its own expected result.
  for (final entry in formatReferenceCases) {
    test(entry.id, () {
      Object? error;
      String? output;
      try {
        output = entry.invoke();
      } on Object catch (caught) {
        error = caught;
      }
      if (entry.expectedError case final expected?) {
        expect(error, isNotNull);
        expect(error?.runtimeType, expected);
      } else {
        expect(error, isNull);
        expect(output, entry.expectedOutput);
      }
    });
  }

  // A built-in brace type added only to the parser would leave the generated
  // reference incomplete unless this exact inventory comparison failed.
  test('brace type inventory matches the reference', () {
    expect(debugBraceBuiltInTypes(), formatReferenceBraceTypes);
  });

  // Checking both conversion keys and their accepted tokens catches a missing
  // conversion row as well as a flag accidentally admitted or rejected.
  test('printf type and flag inventories match the reference', () {
    expect(
      debugPrintfConversionTypes(),
      formatReferencePrintfFlags.keys.toSet(),
    );
    expect(debugPrintfFlagTokensByConversion(), formatReferencePrintfFlags);
  });
}
