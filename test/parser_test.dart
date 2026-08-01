import 'package:format/format.dart';
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
    '{user[missing}',
    '{user!q}',
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
