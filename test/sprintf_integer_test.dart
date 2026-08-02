import 'package:format/format.dart';
import 'package:test/test.dart';

void main() {
  test('formats signed and unsigned integer conversions', () {
    expect(sprintf('%d', -42), '-42');
    expect(sprintf('%i', BigInt.parse('9007199254740993')), '9007199254740993');
    expect(sprintf('%u', 42), '42');
    expect(sprintf('%o', 42), '52');
    expect(sprintf('%x', 0x2af), '2af');
    expect(sprintf('%X', 0x2af), '2AF');
  });

  test('formats C integer precision and alternate prefixes', () {
    expect(sprintf('%.5d', 42), '00042');
    expect(sprintf('%.0d', 0), '');
    expect(sprintf('%#.0o', 0), '0');
    expect(sprintf('%#o', 42), '052');
    expect(sprintf('%#x', 42), '0x2a');
    expect(sprintf('%#X', 42), '0X2A');
    expect(sprintf('%#.0x', 0), '');
    expect(sprintf('%#x', 0), '0');
  });

  test('applies printf sign width and flag precedence', () {
    expect(sprintf('% +d', 42), '+42');
    expect(sprintf('% 5d', 42), '   42');
    expect(sprintf('%08d', -42), '-0000042');
    expect(sprintf('%#08x', 42), '0x00002a');
    expect(sprintf('%-05d', 42), '42   ');
    expect(sprintf('%08.3d', 42), '     042');
  });

  test('consumes dynamic integer options before the value', () {
    expect(vsprintf('%*d', [-5, 42]), '42   ');
    expect(vsprintf('%.*d', [-1, 42]), '42');
    expect(vsprintf('%*.*x', [8, 4, 42]), '    002a');
  });

  test('rejects negative unsigned values without wrapping', () {
    for (final template in ['%u', '%o', '%x', '%X']) {
      expect(
        () => sprintf(template, -1),
        throwsA(
          isA<UnsupportedFormatValueException>()
              .having((error) => error.context.template, 'template', template)
              .having((error) => error.context.argumentIndex, 'argument', 0),
        ),
      );
    }
  });

  test('integer conversions require int or BigInt', () {
    for (final value in ['42', true, 42.5]) {
      expect(
        () => sprintf('%d', value),
        throwsA(
          isA<UnsupportedFormatValueException>()
              .having((error) => error.context.fragment, 'fragment', '%d')
              .having((error) => error.context.specifier, 'specifier', 'd')
              .having((error) => error.context.conversion, 'conversion', 'd')
              .having((error) => error.context.argumentIndex, 'argument', 0),
        ),
      );
    }
  });

  test('reports a missing integer argument with full context', () {
    expect(
      () => vsprintf('%d %s', const [1]),
      throwsA(
        isA<MissingFormatArgumentException>()
            .having((error) => error.key, 'key', 1)
            .having((error) => error.context.template, 'template', '%d %s')
            .having((error) => error.context.offset, 'offset', 3)
            .having((error) => error.context.fragment, 'fragment', '%s')
            .having((error) => error.context.conversion, 'conversion', 's')
            .having((error) => error.context.argumentIndex, 'argument', 1),
      ),
    );
  });
}
