/// The one IR-versus-legacy case that cannot be written anywhere else: the
/// minimum 64-bit integer.
///
/// `-9223372036854775808` is the value with no positive counterpart, so every
/// piece of integer layout that works by taking a magnitude and prefixing a
/// sign has to special-case it — and each path (the compiled int op, the legacy
/// one, the printf conversions) special-cases it separately. Comparing them
/// against each other, rather than against a literal, is what makes a
/// divergence visible.
///
/// It lives apart from the rest of the parity suite because the literal does
/// not compile under dart2js, where integers are doubles; on that platform the
/// value simply does not exist. Same reason as `integer_format_test.dart` and
/// `sprintf_integer_test.dart` — see the VM-only note in `docs/handoff.md`.
@TestOn('vm')
library;

import 'package:format/src/engine.dart';
import 'package:test/test.dart';

void main() {
  setUp(debugClearTemplateCaches);

  const minInt = -9223372036854775808;

  // Six brace specifications covering the ways the sign and the digits are
  // produced — decimal, padded decimal, three radixes with and without the
  // alternate prefix, and the default — each compared against the legacy
  // result rather than a written-out string, so the expectation cannot be
  // wrong in the same way the code is.
  //
  // The printf half is compared the same way but has to account for a throw:
  // see the note below.
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
