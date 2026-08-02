import 'package:format/format.dart';
import 'package:format/src/engine.dart';
import 'package:test/test.dart';

void main() {
  test('parses flags and dynamic options in consumption order', () {
    final debug = debugParsePrintfTemplate('%-+#0*.*f');

    expect(debug, contains('flags=-+#0'));
    expect(debug, contains('width=dynamic'));
    expect(debug, contains('precision=dynamic'));
    expect(debug, contains('type=f'));
  });

  test('parses every supported conversion type and case', () {
    final debug = debugParsePrintfTemplate(
      '%c %s %d %i %u %o %x %X %a %A %e %E %f %F %g %G %%',
    );

    for (final type in [
      'c',
      's',
      'd',
      'i',
      'u',
      'o',
      'x',
      'X',
      'a',
      'A',
      'e',
      'E',
      'f',
      'F',
      'g',
      'G',
      '%',
    ]) {
      expect(debug, contains('type=$type'));
    }
  });

  test('preserves UTF-16 offsets fragments and coalesced literals', () {
    final debug = debugParsePrintfTemplate('\ud83d\ude00a%%b%d');

    expect(
      debug,
      contains('literal(offset=0,fragment=\ud83d\ude00a,text=\ud83d\ude00a)'),
    );
    expect(debug, contains('conversion(offset=3,fragment=%%'));
    expect(debug, contains('literal(offset=5,fragment=b,text=b)'));
    expect(debug, contains('conversion(offset=6,fragment=%d'));
  });

  test('parses static and empty precision as literal options', () {
    final debug = debugParsePrintfTemplate('%12.34f %.f');

    expect(debug, contains('width=12'));
    expect(debug, contains('precision=34'));
    expect(debug, contains('precision=0'));
  });

  test('collapses repeated legal flags', () {
    final debug = debugParsePrintfTemplate('%000---++dd');

    expect(debug, contains('flags=-+0'));
    expect(debug, contains('type=d'));
  });

  test('keeps AST collections immutable', () {
    expect(
      () => debugClearPrintfTemplateNodes('%--d'),
      throwsA(isA<UnsupportedError>()),
    );
    expect(
      () => debugClearPrintfConversionFlags('%--d'),
      throwsA(isA<UnsupportedError>()),
    );
  });

  group('accepts the exact conversion option table', () {
    for (final template in [
      '%-5c',
      '%-5.2s',
      '%-+ 05.2d',
      '%-05.2i',
      '%-05.2u',
      '%-#05.2o',
      '%-#05.2x',
      '%-#05.2X',
      '%-+ #05.2a',
      '%-+ #05.2A',
      '%-+ #05.2e',
      '%-+ #05.2E',
      '%-+ #05.2f',
      '%-+ #05.2F',
      '%-+ #05.2g',
      '%-+ #05.2G',
      '%%',
    ]) {
      test(
        template,
        () => expect(debugParsePrintfTemplate(template), isNotEmpty),
      );
    }
  });

  group('rejects syntactically valid but inapplicable options', () {
    for (final template in [
      '%+c',
      '%.1c',
      '%#s',
      '%#d',
      '%+u',
      '% u',
      '%#u',
      '%+x',
      '%1%',
      '%05s',
      '%.*c',
      '%*%',
    ]) {
      test(template, () {
        expect(
          () => debugParsePrintfTemplate(template),
          throwsA(isA<InvalidSpecifierException>()),
        );
      });
    }
  });

  group('rejects invalid printf grammar', () {
    for (final template in [
      '%',
      '%q',
      '%n',
      '%p',
      '%llx',
      r'%2$d',
      '%b',
      '%B',
      '%-+5',
      '%.',
      r'%-5$d',
      '%١d',
      '%１２d',
    ]) {
      test(template, () {
        expect(
          () => debugParsePrintfTemplate(template),
          throwsA(isA<InvalidFormatException>()),
        );
      });
    }
  });

  test('reports complete typed context for invalid grammar', () {
    try {
      debugParsePrintfTemplate('x%llx');
      fail('Expected InvalidFormatException.');
    } on InvalidFormatException catch (error) {
      expect(error.context.template, 'x%llx');
      expect(error.context.offset, 1);
      expect(error.context.fragment, '%llx');
      expect(error.context.specifier, 'l');
      expect(error.context.conversion, 'x');
    }
  });

  test('reports complete typed context for invalid specifiers', () {
    try {
      debugParsePrintfTemplate('x%+u');
      fail('Expected InvalidSpecifierException.');
    } on InvalidSpecifierException catch (error) {
      expect(error.context.template, 'x%+u');
      expect(error.context.offset, 1);
      expect(error.context.fragment, '%+u');
      expect(error.context.specifier, 'u');
      expect(error.context.conversion, 'u');
    }
  });

  test('rejects overflowing numeric options as typed invalid formats', () {
    final enormous = '9' * 2000;
    for (final template in ['%${enormous}d', '%.${enormous}d']) {
      try {
        debugParsePrintfTemplate(template);
        fail('Expected InvalidFormatException.');
      } on InvalidFormatException catch (error) {
        expect(error.context.template, template);
        expect(error.context.offset, 0);
        expect(error.context.fragment, template);
        expect(error.context.specifier, 'd');
        expect(error.context.conversion, 'd');
      }
    }
  });

  test('reports full invalid fragments and known terminal conversions', () {
    for (final entry in [
      (
        template: r'x%2$d',
        offset: 1,
        fragment: r'%2$d',
        specifier: r'$',
        conversion: 'd',
      ),
      (
        template: 'x%q',
        offset: 1,
        fragment: '%q',
        specifier: 'q',
        conversion: 'q',
      ),
      (
        template: 'x%',
        offset: 1,
        fragment: '%',
        specifier: null,
        conversion: null,
      ),
      (
        template: '\ud83d\ude00%llx',
        offset: 2,
        fragment: '%llx',
        specifier: 'l',
        conversion: 'x',
      ),
      (
        template: '%l\ud83d\ude00d',
        offset: 0,
        fragment: '%l\ud83d\ude00d',
        specifier: 'l',
        conversion: 'd',
      ),
      (
        template:
            r'%2$'
            '\ud83d\ude00d',
        offset: 0,
        fragment:
            r'%2$'
            '\ud83d\ude00d',
        specifier: r'$',
        conversion: 'd',
      ),
    ]) {
      try {
        debugParsePrintfTemplate(entry.template);
        fail('Expected InvalidFormatException for ${entry.template}.');
      } on InvalidFormatException catch (error) {
        expect(error.context.template, entry.template);
        expect(error.context.offset, entry.offset);
        expect(error.context.fragment, entry.fragment);
        expect(error.context.specifier, entry.specifier);
        expect(error.context.conversion, entry.conversion);
      }
    }
  });
}
