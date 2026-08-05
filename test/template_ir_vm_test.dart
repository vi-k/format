@TestOn('vm')
library;

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

void main() {
  setUp(debugClearTemplateCaches);

  const minInt = -9223372036854775808;

  test('int op handles the minimum int like the legacy path', () {
    for (final spec in ['{:d}', '{:30d}', '{:x}', '{:b}', '{:#o}', '{}']) {
      expect(
        formatWith(spec, positional: [minInt]),
        debugFormatBraceWithoutIr(spec, defaultFormat, positional: [minInt]),
        reason: spec,
      );
    }
    // %x/%o reject negative operands by design (see 'rejects negative
    // unsigned values without wrapping' in sprintf_integer_test.dart), and
    // minInt is negative, so `sprintf` throws before returning a string.
    // Compare the raised exceptions instead of the (unreachable) result,
    // same as expectBraceParity does for the brace path.
    Object? irError;
    String? ir;
    try {
      ir = sprintf('%d|%x|%o', minInt, minInt, minInt);
    } on FormattingException catch (error) {
      irError = error;
    }
    Object? legacyError;
    String? legacy;
    try {
      legacy = debugFormatPrintfWithoutIr('%d|%x|%o', defaultFormat, [
        minInt,
        minInt,
        minInt,
      ]);
    } on FormattingException catch (error) {
      legacyError = error;
    }
    expect(ir, legacy);
    expect(irError?.runtimeType, legacyError?.runtimeType);
  });
}
