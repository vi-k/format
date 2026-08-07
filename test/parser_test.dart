import 'package:format/src/engine.dart';
import 'package:test/test.dart';

void main() {
  test('parses nested fields and lookup chains', () {
    final debug = debugParseBraceTemplate('{user.items[0].name!r:{width}}');

    expect(debug, contains('root=user'));
    expect(debug, contains('attribute=items'));
    expect(debug, contains('item=0'));
    expect(debug, contains('conversion=r'));
    expect(debug, contains('nested=width'));
  });

  test('accepts a padded index and rejects one past the 64-bit range', () {
    expect(formatWith('{0000000005}', positional: [0, 1, 2, 3, 4, 5]), '5');
    // 9223372036854775807 is the last index that fits; the next one, and
    // any longer run of digits, must be rejected.
    expect(
      () => formatWith('{9223372036854775807}'),
      throwsA(isA<MissingFormatArgumentException>()),
    );
    for (final index in ['9223372036854775808', '12345678901234567890']) {
      expect(
        () => formatWith('{$index}'),
        throwsA(isA<InvalidFormatException>()),
        reason: index,
      );
    }
  });

  test('rejects an unbounded digit run without parsing it as a number', () {
    // A template is untrusted input, so the cost of rejecting it must not
    // scale with the size of the number it spells.
    for (final length in [1000, 100000]) {
      expect(
        () => formatWith('{${'9' * length}}'),
        throwsA(isA<InvalidFormatException>()),
        reason: '$length digits',
      );
      expect(
        () => formatWith('{0[${'9' * length}]}', positional: const [<int>[]]),
        throwsA(isA<InvalidFormatException>()),
        reason: '$length digits in an item key',
      );
    }
  });

  test('preserves an unknown conversion for typed processing errors', () {
    final debug = debugParseBraceTemplate('{value!q}');

    expect(debug, contains('conversion=q'));
  });

  test('parses escaped braces and Unicode names', () {
    final debug = debugParseBraceTemplate(
      '{{{\u0438\u043c\u044f.\u03b4[\u043a\u043b\u044e\u0447]}}}',
    );

    expect(debug, contains('literal={'));
    expect(debug, contains('root=\u0438\u043c\u044f'));
    expect(debug, contains('attribute=\u03b4'));
    expect(debug, contains('item=\u043a\u043b\u044e\u0447'));
    expect(debug, contains('literal=}'));
  });

  test('accepts decimal digits from the Python identifier tables', () {
    final debug = debugParseBraceTemplate('{\u0661\u0662\u0663[\u0664]}');

    expect(debug, contains('root=123'));
    expect(debug, contains('item=4'));
  });

  test('allows arbitrary unquoted item keys and named nested fields', () {
    final debug = debugParseBraceTemplate(
      '{record[any key]:{width}.{precision}}',
    );

    expect(debug, contains('root=record'));
    expect(debug, contains('item=any key'));
    expect(debug, contains('nested=width'));
    expect(debug, contains('nested=precision'));
  });

  test('uses the first closing brace to close a nested specification', () {
    final debug = debugParseBraceTemplate('{0:{1:}}');

    expect(debug, contains('root=0'));
    expect(debug, contains('nested=1'));
  });

  test('parses escaped braces in a specification', () {
    final debug = debugParseBraceTemplate('{0:{{}}}');

    expect(debug, contains('root=0'));
    expect(debug, contains('literal={}'));
  });

  test('parses escaped braces beside a nested specification', () {
    final debug = debugParseBraceTemplate('{0:{{{width}}}}');

    expect(debug, contains('literal={'));
    expect(debug, contains('nested=width'));
    expect(debug, contains('literal=}'));
  });

  test('reports each parser failure with template offset and fragment', () {
    try {
      debugParseBraceTemplate('{ name }');
      fail('expected invalid format');
    } on InvalidFormatException catch (error) {
      expect(error.context.template, '{ name }');
      expect(error.context.offset, 1);
      expect(error.context.fragment, ' name ');
    }
  });

  for (final template in [
    '{0} {}',
    '{} {1}',
    '{:{0}}',
    '{:{:{}}}',
    '{ name }',
    "{'name'}",
    '{user["name"]}',
    '{user..name}',
    '{0[]}',
    '{0:{{}',
    '{0:}}x}',
    '{user[missing}',
    '{user!}',
    '{user!qq}',
    '{user',
    'user}',
  ]) {
    test('rejects invalid field grammar: $template', () {
      expect(
        () => debugParseBraceTemplate(template),
        throwsA(isA<InvalidFormatException>()),
      );
    });
  }
}
