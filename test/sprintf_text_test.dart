import 'package:format/format.dart';
import 'package:test/test.dart';

void main() {
  test('consumes dynamic width then precision then value', () {
    expect(vsprintf('%*.*s', [6, 3, 'abcdef']), '   abc');
    expect(vsprintf('%*s', [-5, 'x']), 'x    ');
    expect(vsprintf('%.*s', [-1, 'abcdef']), 'abcdef');
  });

  test('reports missing arguments in dynamic consumption order', () {
    for (final entry in [
      (values: const <Object?>[], index: 0, specifier: 'width'),
      (values: const <Object?>[6], index: 1, specifier: 'precision'),
      (values: const <Object?>[6, 3], index: 2, specifier: 's'),
    ]) {
      expect(
        () => vsprintf('%*.*s', entry.values),
        throwsA(
          isA<MissingFormatArgumentException>()
              .having((error) => error.key, 'key', entry.index)
              .having(
                (error) => error.context.argumentIndex,
                'argument index',
                entry.index,
              )
              .having((error) => error.context.fragment, 'fragment', '%*.*s')
              .having(
                (error) => error.context.specifier,
                'specifier',
                entry.specifier,
              )
              .having((error) => error.context.conversion, 'conversion', 's'),
        ),
      );
    }
  });

  test('dynamic options require int values', () {
    for (final entry in [
      (values: const <Object?>['6', 3, 'abcdef'], index: 0, specifier: 'width'),
      (
        values: <Object?>[6, BigInt.one, 'abcdef'],
        index: 1,
        specifier: 'precision',
      ),
    ]) {
      expect(
        () => vsprintf('%*.*s', entry.values),
        throwsA(
          isA<UnsupportedFormatValueException>()
              .having((error) => error.context.fragment, 'fragment', '%*.*s')
              .having(
                (error) => error.context.argumentIndex,
                'argument index',
                entry.index,
              )
              .having(
                (error) => error.context.specifier,
                'specifier',
                entry.specifier,
              )
              .having((error) => error.context.conversion, 'conversion', 's'),
        ),
      );
    }
  });

  test('rejects unsafe static and dynamic option sizes as typed errors', () {
    for (final entry in [
      (
        template: '%100001s',
        values: const <Object?>['x'],
        specifier: 'width',
        argument: null,
      ),
      (
        template: '%.100001s',
        values: const <Object?>['x'],
        specifier: 'precision',
        argument: null,
      ),
      (
        template: '%*s',
        values: const <Object?>[100001, 'x'],
        specifier: 'width',
        argument: 0,
      ),
      (
        template: '%*s',
        values: const <Object?>[-100001, 'x'],
        specifier: 'width',
        argument: 0,
      ),
      (
        template: '%.*s',
        values: const <Object?>[100001, 'x'],
        specifier: 'precision',
        argument: 0,
      ),
    ]) {
      expect(
        () => vsprintf(entry.template, entry.values),
        throwsA(
          isA<InvalidSpecifierException>()
              .having(
                (error) => error.context.specifier,
                'specifier',
                entry.specifier,
              )
              .having((error) => error.context.conversion, 'conversion', 's')
              .having(
                (error) => error.context.argumentIndex,
                'argument index',
                entry.argument,
              ),
        ),
      );
    }
  });

  test('uses TextUnit for printf strings and width', () {
    expect(sprintf('%.1s', 'e\u0301'), 'e');
    expect(sprintf('%4s', 'é'), '   é');
    expect(sprintf('%-4s', 'é'), 'é   ');

    final graphemes = Format(textUnit: TextUnit.graphemeClusters);
    expect(graphemes.sprintf('%.1s', 'e\u0301'), 'e\u0301');
    expect(graphemes.sprintf('%3s', '👩‍🔬'), '  👩‍🔬');
  });

  test('formats Unicode scalar values with c', () {
    expect(sprintf('%c', 0x1f44b), '👋');
    expect(sprintf('%c', BigInt.from(65)), 'A');
    expect(sprintf('%4c', 0x1f44b), '   👋');
    expect(sprintf('%-4c', 65), 'A   ');
  });

  test('rejects invalid Unicode scalar values with typed context', () {
    for (final value in [-1, 0x110000, 0xd800, 'A']) {
      expect(
        () => sprintf('%c', value),
        throwsA(
          isA<UnsupportedFormatValueException>()
              .having((error) => error.context.template, 'template', '%c')
              .having((error) => error.context.offset, 'offset', 0)
              .having((error) => error.context.fragment, 'fragment', '%c')
              .having((error) => error.context.specifier, 'specifier', 'c')
              .having((error) => error.context.conversion, 'conversion', 'c')
              .having((error) => error.context.argumentIndex, 'argument', 0),
        ),
      );
    }
  });

  test('ignores values beyond the final conversion', () {
    expect(vsprintf('%s', const ['used', 'ignored']), 'used');
    expect(vsprintf('%%', const ['ignored']), '%');
  });
}
