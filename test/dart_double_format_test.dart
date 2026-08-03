import 'package:format/format.dart';
import 'package:test/test.dart';

void main() {
  test('default brace formatting uses Dart SDK number spelling', () {
    expect(format('{}', 1e-7), '1e-7');
    expect(format('{:.0f}', 2.5), '3');
    expect(format('{:.2f}', 1e21), '1e+21');
    expect(format('{:e}', 1.0), '1e+0');
    expect(format('{:.2e}', 12.5), '1.25e+1');
    expect(format('{:g}', 1.0), '1.0');
    expect(format('{:.3g}', 1.0), '1.00');
    expect(format('{:.1%}', 0.125), '12.5%');
  });

  test('compatible brace formatting preserves exact legacy results', () {
    final compatible = Format(doubleFormatMode: DoubleFormatMode.compatible);

    expect(compatible.format('{:.0f}', 2.5), '2');
    expect(compatible.format('{:e}', 1.0), '1.000000e+00');
    expect(compatible.format('{:.3g}', 1.0), '1');
    expect(compatible.format('{:.21f}', 0.1), '0.100000000000000005551');
  });

  test('Dart brace formatting keeps common numeric layout', () {
    expect(format('{:.2f}', -0.0), '-0.00');
    expect(format('{:z.2f}', -0.0), '0.00');
    expect(format('{:#.0f}', 1.0), '1.');
    expect(format('{:#.0e}', 1.0), '1.e+0');
    expect(format('{:.1E}', 12.5), '1.3E+1');
    expect(format('{:,.2f}', 1234.5), '1,234.50');
    expect(format('{:.3n}', 1234.5), '1.23e+3');
  });

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

  test('default sprintf uses Dart SDK decimal conversions', () {
    expect(sprintf('%.0f', 2.5), '3');
    expect(sprintf('%e', 1.0), '1e+0');
    expect(sprintf('%.3g', 1.0), '1.00');
  });

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
