// The `dartSdk` double profile — the default one — against `compatible`.
//
// The package can spell doubles two ways, and the choice is not cosmetic. In
// `dartSdk` mode the digits come from the SDK's own conversions, so a number
// prints the way the rest of a Dart program prints it, and rounding follows the
// SDK (`{:.0f}` of 2.5 is 3). In `compatible` mode the digits come from the
// package's own layout, matching C and Python instead (the same 2.5 is 2, on
// banker's rounding).
//
// Both are correct; what must not happen is drift between the documented
// profile and the actual one, or one profile leaking into the other. So the two
// are asserted side by side on the values where they disagree, over both
// dialects — the profile is a property of the engine, not of the brace path,
// and the printf path has to inherit it.
//
// The SDK conversions also carry a precision range the package does not choose,
// and it has to surface as a specifier rejection rather than as an SDK error
// escaping the package. That range is checked in both dialects and, separately,
// on infinities and NaN — where the digits are never produced, so an
// implementation that validated late would accept a specification it rejects
// for every finite value.

import 'package:format/format.dart';
import 'package:test/test.dart';

void main() {
  // Where the default profile follows Dart and not C: the shortest round-trip
  // spelling for a bare `{}`, SDK rounding at `.0f`, the SDK's own switch to
  // exponential for huge values even under `f`, an exponent without the
  // two-digit padding C insists on, and `g` keeping trailing zeros to the
  // requested precision. `{:g}` is compared against `1.0.toString()` rather
  // than a literal — the point is that it *is* the SDK's answer.
  test('default brace formatting uses Dart SDK number spelling', () {
    expect(format('{}', 1e-7), '1e-7');
    expect(format('{:.0f}', 2.5), '3');
    expect(format('{:.2f}', 1e21), '1e+21');
    expect(format('{:e}', 1.0), '1e+0');
    expect(format('{:.2e}', 12.5), '1.25e+1');
    expect(format('{:g}', 1.0), 1.0.toString());
    expect(format('{:.3g}', 1.0), '1.00');
    expect(format('{:.1%}', 0.125), '12.5%');
  });

  // The same four questions answered the other way, which is the whole reason
  // the profile exists: banker's rounding, a padded two-digit exponent with six
  // default digits, `g` stripping trailing zeros, and a precision past what the
  // SDK offers — `{:.21f}` of 0.1 exposes the actual binary value, which is
  // what C prints and what an upgrade from an older version must keep printing.
  test('compatible brace formatting preserves exact legacy results', () {
    final compatible = Format(doubleFormatMode: DoubleFormatMode.compatible);

    expect(compatible.format('{:.0f}', 2.5), '2');
    expect(compatible.format('{:e}', 1.0), '1.000000e+00');
    expect(compatible.format('{:.3g}', 1.0), '1');
    expect(compatible.format('{:.21f}', 0.1), '0.100000000000000005551');
  });

  // Everything the layout does *around* the digits stays the same in Dart mode
  // — only the digits come from the SDK. Negative zero keeps its sign unless
  // `z` normalizes it away, `#` keeps a point that has no digits after it,
  // rounding applies before the case of `E` is chosen, and grouping and the
  // locale-aware `n` still work on SDK-produced digits.
  test('Dart brace formatting keeps common numeric layout', () {
    expect(format('{:.2f}', -0.0), '-0.00');
    expect(format('{:z.2f}', -0.0), '0.00');
    expect(format('{:#.0f}', 1.0), '1.');
    expect(format('{:#.0e}', 1.0), '1.e+0');
    expect(format('{:.1E}', 12.5), '1.3E+1');
    expect(format('{:,.2f}', 1234.5), '1,234.50');
    expect(format('{:.3n}', 1234.5), '1.23e+3');
  });

  // The SDK's conversions accept 0–20 digits for `f` and `e` and 1–21 for `g`,
  // and the package cannot widen that range without producing the digits
  // itself. Each boundary is crossed by exactly one: 21 is too many for `f` and
  // `e`, 0 too few for `g`, 22 too many. The rejection has to name the
  // specifier — otherwise the message points at a range the user never chose
  // and cannot find in their template.
  for (final template in ['{:.21f}', '{:.21e}', '{:.0g}', '{:.22g}']) {
    test('Dart brace formatting rejects SDK precision range: $template', () {
      expect(
        () => format(template, 1.0),
        throwsA(
          isA<InvalidSpecifierException>().having(
            (error) => error.context.specifier,
            'specifier',
            template.substring(2, template.length - 1),
          ),
        ),
      );
    });
  }

  // Infinity and NaN never reach the SDK conversion — they are spelled from a
  // table — so a validation written where the digits are produced would let
  // `{:.21f}` through for them and reject it for every finite value. The
  // precision is checked before the value is looked at, and this is the pair of
  // cases that says so. The order is a contract; see the note in `write`.
  test('Dart brace precision validation also applies to special values', () {
    expect(
      () => format('{:.21f}', double.infinity),
      throwsA(isA<InvalidSpecifierException>()),
    );
    expect(
      () => format('{:.0g}', double.nan),
      throwsA(isA<InvalidSpecifierException>()),
    );
  });

  // The profile belongs to the engine, so the printf dialect inherits it: the
  // same three answers as the brace path, through `%`. A printf implementation
  // that reached for C semantics because the syntax is C's would give 2,
  // `1.000000e+00` and `1`.
  test('default sprintf uses Dart SDK decimal conversions', () {
    expect(sprintf('%.0f', 2.5), '3');
    expect(sprintf('%e', 1.0), '1e+0');
    expect(sprintf('%.3g', 1.0), '1.00');
  });

  // The same four boundaries in the printf dialect. It is a separate parser
  // reaching the same conversions, so the range has to be enforced separately —
  // and the reported specifier is a single letter here, not a whole brace
  // specification, which is the shape a printf user can look for.
  for (final template in ['%.21f', '%.21e', '%.0g', '%.22g']) {
    test('Dart sprintf rejects SDK precision range: $template', () {
      expect(
        () => sprintf(template, 1.0),
        throwsA(
          isA<InvalidSpecifierException>()
              .having((error) => error.context.template, 'template', template)
              .having(
                (error) => error.context.specifier,
                'specifier',
                template[template.length - 1],
              ),
        ),
      );
    });
  }

  // And the same early-validation contract on the printf side: the two paths
  // are separate code, so a fix applied to one of them leaves the other free to
  // regress.
  test('Dart sprintf precision validation also applies to special values', () {
    expect(
      () => sprintf('%.21f', double.infinity),
      throwsA(isA<InvalidSpecifierException>()),
    );
    expect(
      () => sprintf('%.0g', double.nan),
      throwsA(isA<InvalidSpecifierException>()),
    );
  });

  // How infinities and NaN are spelled is a separate axis from how digits are
  // produced, and the two must not be welded together: `dartSdk` digits with
  // `short` spelling is a legal combination, and choosing `compatible` implies
  // its own spelling. All three spellings appear here, in both dialects, with
  // the case following the conversion's — `%F` gives `INF` and `%G` gives
  // `NAN`, the way C does.
  test('special value spelling is configurable in Dart mode', () {
    final short = Format(
      doubleSpecialValueSpelling: DoubleSpecialValueSpelling.short,
    );
    final compatible = Format(doubleFormatMode: DoubleFormatMode.compatible);

    expect(format('{}', double.nan), 'NaN');
    expect(format('{}', double.infinity), 'Infinity');
    expect(format('{}', double.negativeInfinity), '-Infinity');
    expect(short.format('{}', double.nan), 'nan');
    expect(short.sprintf('%F', double.infinity), 'INF');
    expect(compatible.format('{}', double.infinity), 'inf');
    expect(compatible.sprintf('%G', double.nan), 'NAN');
  });
}
