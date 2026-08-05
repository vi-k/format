import 'package:format/format.dart';

/// A custom formatter: `{:json}` renders a `Map` through its own logic.
final class JsonFormatter extends Formatter<Map<String, Object?>> {
  @override
  String get specifier => 'json';

  @override
  bool canFormat(Object? value) => value is Map<String, Object?>;

  @override
  String format(Map<String, Object?> value, FormatOptions options) =>
      value.toString();
}

void main() {
  // --- Python-style braces -------------------------------------------------

  print(format('{} {}!', 'hello', 'world')); // hello world!
  print(format('{1} {0}', 'world', 'hello')); // hello world
  print(
    formatWith('{name}: {value}', named: {'name': 'answer', 'value': 42}),
  ); // answer: 42

  // Alignment, fill, and width.
  print(format('[{:<10}]', 'left')); // [left      ]
  print(format('[{:^10}]', 'center')); // [  center  ]
  print(format('[{:*>10}]', 'right')); // [*****right]

  // Integers: bases, alternate form, grouping, zero padding.
  print(format('{:#x} {:#o} {:b}', 255, 8, 5)); // 0xff 0o10 101
  print(format('{:,d}', 1234567)); // 1,234,567
  print(format('{:010,d}', 1234)); // 00,001,234
  print(format('{:+08.3f}', 3.14159)); // +003.142

  // Doubles: fixed, scientific, percent.
  print(format('{:.2f}', 12345.678)); // 12345.68
  print(format('{:.2e}', 12345.678)); // 1.23e+4
  print(format('{:.1%}', 0.756)); // 75.6%

  // Width and precision can come from arguments (nested fields).
  print(format('[{:{}.{}f}]', 3.14159, 8, 2)); // [    3.14]

  // --- printf --------------------------------------------------------------

  print(sprintf('%s: %#08x', 'answer', 42)); // answer: 0x00002a
  print(vsprintf('%*.*f', [8, 2, 1.5])); //     1.50

  // --- Configured Format instances -----------------------------------------

  // Python/C++-compatible decimal doubles instead of the Dart SDK default.
  final compatible = Format(doubleFormatMode: DoubleFormatMode.compatible);
  print(compatible.format('{:.0f} {:e}', 2.5, 1.0)); // 2 1.000000e+00

  // Short spellings for non-finite values in Dart SDK mode.
  final shortSpecials = Format(
    doubleSpecialValueSpelling: DoubleSpecialValueSpelling.short,
  );
  print(shortSpecials.format('{} {}', double.nan, double.infinity)); // nan inf

  // Grapheme clusters: emoji and combined characters align as one visible
  // character.
  final graphemes = Format(textUnit: TextUnit.graphemeClusters);
  print(graphemes.format('[{:🇺🇦^8}]', 'peace')); // [🇺🇦peace🇺🇦🇺🇦]

  // A custom formatter joins the mini-language under its own specifier.
  final jsonFormat = Format(formatters: [JsonFormatter()]);
  print(jsonFormat.format('{:json}', {'answer': 42})); // {answer: 42}

  // --- Typed errors --------------------------------------------------------

  // Every formatting failure is a FormattingException whose toString()
  // carries the reason and the exact template fragment.
  try {
    format('{:d}', 'not a number');
  } on FormattingException catch (error) {
    print(error);
  }
}
