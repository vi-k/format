import 'package:characters/characters.dart';
import 'package:format/format.dart';
import 'package:intl/intl.dart';
import 'package:test/test.dart';

void main() {
  group('Common use:', () {
    //setUp(() );
    test('positional arguments', () {
      const positionalArgs = [1, 2, 3];

      expect('{} {} {}'.format(positionalArgs), '1 2 3');
      expect('{2} {1} {0}'.format(positionalArgs), '3 2 1');
      expect('{} {} {} {0} {} {}'.format(positionalArgs), '1 2 3 1 2 3');
      expect(
          () => '{2} {}'.format(positionalArgs),
          throwsA(predicate((e) =>
              e is ArgumentError &&
              e.message == '{} Index #3 out of range of positional args.')));
    });

    test('named arguments', () {
      const namedArgs = {
        'test_1': 1,
        'тест_2': 2,
        'テスト_3': 3,
        'hello world': 4,
        '_': 5,
        '_0': 6,
        '0': 7,
        '+': 8,
        '"key in double quotes"': 9,
        "'key in single quotes'": 10
      };

      expect(
          '{test_1} {тест_2} {テスト_3} {"hello world"} {_} {_0}'
              .format([], namedArgs),
          '1 2 3 4 5 6');
      expect('{0} {"0"}'.format([123], namedArgs), '123 7');
      expect('{+} {"+"}'.format([], namedArgs), '{+} 8');
      expect(
          '{"""key in double quotes"""} {"\'key in single quotes\'"}'
              .format([], namedArgs),
          '9 10');
      expect(
          "{'\"key in double quotes\"'} {'''key in single quotes'''}"
              .format([], namedArgs),
          '9 10');
      expect(
          '{"""key in double quotes"""} ' "{'''key in single quotes'''}"
              .format([], namedArgs),
          '9 10');

      expect(
          () => '{a}'.format([]),
          throwsA(predicate((e) =>
              e is ArgumentError &&
              e.message == '{a} Named args is missing.')));
      expect(
          () => '{a}'.format([], namedArgs),
          throwsA(predicate((e) =>
              e is ArgumentError &&
              e.message == '{a} Key [a] is missing in named args.')));
    });
    test('width, align and fill', () {
      expect('{:0}'.format([123]), '123'); // Flag zero and zero width
      expect('{:00}'.format([123]), '123');

      const s = 'hello';

      expect('{:0}'.format([s]), 'hello');

      expect('{:9}'.format([s]), 'hello    ');
      expect('{:<9}'.format([s]), 'hello    ');
      expect('{:>9}'.format([s]), '    hello');
      expect('{:^9}'.format([s]), '  hello  ');
      expect('{:^10}'.format([s]), '  hello   ');

      expect('{:*9}'.format([s]), '{:*9}'); // align is missing
      expect('{:*<9}'.format([s]), 'hello****');
      expect('{:*>9}'.format([s]), '****hello');
      expect('{:*^9}'.format([s]), '**hello**');
      expect('{:*^10}'.format([s]), '**hello***');
    });

    test('width and precision', () {
      expect(
          () => '{:{}}'.format([0.0, -1]),
          throwsA(predicate((e) =>
              e is ArgumentError &&
              e.message == '{:{}} Width must be >= 0. Passed -1.')));

      expect(
          () => '{:.{}f}'.format([0.0, -1]),
          throwsA(predicate((e) =>
              e is ArgumentError &&
              e.message == '{:.{}f} Precision must be >= 0. Passed -1.')));

      expect(
          () => '{:.0g}'.format([0.0, 0]),
          throwsA(predicate((e) =>
              e is ArgumentError &&
              e.message == '{:.0g} Precision must be >= 1. Passed 0.')));

      expect(
          () => '{:.0}'.format([0.0, 0]),
          throwsA(predicate((e) =>
              e is ArgumentError &&
              e.message == '{:.0} Precision must be >= 1. Passed 0.')));
    });
  });

  group('Format specifier', () {
    group('c:', () {
      test('basic use', () {
        expect(
            () => '{:c}'.format(['a']),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    '{:c} Expected int or List<int>. Passed String.')));
        expect('{:c}'.format([65]), 'A');
      });

      test('surrogate pairs', () {
        expect(
            '{:c}+{:c}+{:c}+{:c}={:c}{:c}{:c}{:c}{:c}{:c}{:c}'.format([
              0x1F468,
              0x1F469,
              0x1F466,
              0x1F467,
              0x1F468,
              0x200D,
              0x1F469,
              0x200D,
              0x1F466,
              0x200D,
              0x1F467,
            ]),
            '👨+👩+👦+👧=👨‍👩‍👦‍👧');
        expect(
            '{:c}+{:c}+{:c}+{:c}={:c}'.format([
              0x1F468,
              0x1F469,
              0x1F466,
              0x1F467,
              [0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F466, 0x200D, 0x1F467],
            ]),
            '👨+👩+👦+👧=👨‍👩‍👦‍👧');
        expect(
            '{:c}={:c}'.format([
              [0x1F468, 0x2B, 0x1F469, 0x2B, 0x1F466, 0x2B, 0x1F467],
              [0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F466, 0x200D, 0x1F467],
            ]),
            '👨+👩+👦+👧=👨‍👩‍👦‍👧');
      });
    });

    group('s:', () {
      const s = 'abcdef';

      test('basic use', () {
        expect(
            () => '{:s}'.format([123]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:s} Expected String. Passed int.')));
        expect('{}'.format([s]), 'abcdef');
        expect('{:s}'.format([s]), 'abcdef');
      });

      test('align', () {
        expect('{:10s}'.format([s]), 'abcdef    ');
      });
    });

    group('b:', () {
      const n = 0xAA;

      test('basic use', () {
        expect(
            () => '{:b}'.format([123.0]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:b} Expected int. Passed double.')));

        expect('{:b}'.format([n]), '10101010');
        expect('{:b}'.format([-n]), '-10101010');

        expect('{:b}'.format([9223372036854775807]),
            '111111111111111111111111111111111111111111111111111111111111111');
        expect('{:b}'.format([-9223372036854775807]),
            '-111111111111111111111111111111111111111111111111111111111111111');
        expect('{:b}'.format([-9223372036854775808]),
            '-1000000000000000000000000000000000000000000000000000000000000000');
      });

      test('sign', () {
        expect('{:+b}'.format([n]), '+10101010');
        expect('{:-b}'.format([n]), '10101010');
        expect('{: b}'.format([n]), ' 10101010');
        expect('{:+b}'.format([-n]), '-10101010');
        expect('{:-b}'.format([-n]), '-10101010');
        expect('{: b}'.format([-n]), '-10101010');
      });

      test('align', () {
        expect('{:12b}'.format([n]), '    10101010');
        expect('{:12b}'.format([-n]), '   -10101010');
      });

      test('zero', () {
        expect('{:0b}'.format([n]), '10101010');
        expect('{:012b}'.format([n]), '000010101010');
        expect('{:012b}'.format([-n]), '-00010101010');
      });

      test('group', () {
        expect('{:_b}'.format([n]), '1010_1010');
        expect('{:14_b}'.format([n]), '     1010_1010');
        expect('{:014_b}'.format([n]), '0000_1010_1010');
        expect('{:015_b}'.format([n]), '0_0000_1010_1010');
        expect('{:016_b}'.format([n]), '0_0000_1010_1010');

        expect('{:_b}'.format([-n]), '-1010_1010');
        expect('{:14_b}'.format([-n]), '    -1010_1010');
        expect('{:014_b}'.format([-n]), '-000_1010_1010');
        expect('{:015_b}'.format([-n]), '-0000_1010_1010');
        expect('{:016_b}'.format([-n]), '-0_0000_1010_1010');

        expect(
            () => '{:,b}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:,b} Group option ',' not allowed with format specifier 'b'.")));
      });

      test('alt', () {
        expect(
            () => '{:#b}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:#b} Alternate form (#) not allowed with format specifier 'b'.")));
      });

      test('precision', () {
        expect(
            () => '{:.2b}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:.2b} Precision not allowed with format specifier 'b'.")));
      });
    });

    group('o:', () {
      const n = 2739128;

      test('basic use', () {
        expect(
            () => '{:o}'.format([123.0]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:o} Expected int. Passed double.')));

        expect('{:o}'.format([n]), '12345670');
        expect('{:o}'.format([-n]), '-12345670');

        expect('{:o}'.format([9223372036854775807]), '777777777777777777777');
        expect('{:o}'.format([-9223372036854775807]), '-777777777777777777777');
        expect(
            '{:o}'.format([-9223372036854775808]), '-1000000000000000000000');
      });

      test('sign', () {
        expect('{:+o}'.format([n]), '+12345670');
        expect('{:-o}'.format([n]), '12345670');
        expect('{: o}'.format([n]), ' 12345670');
        expect('{:+o}'.format([-n]), '-12345670');
        expect('{:-o}'.format([-n]), '-12345670');
        expect('{: o}'.format([-n]), '-12345670');
      });

      test('align', () {
        expect('{:12o}'.format([n]), '    12345670');
        expect('{:12o}'.format([-n]), '   -12345670');
      });

      test('zero', () {
        expect('{:0o}'.format([n]), '12345670');
        expect('{:012o}'.format([n]), '000012345670');
        expect('{:012o}'.format([-n]), '-00012345670');
      });

      test('group', () {
        expect('{:_o}'.format([n]), '1234_5670');
        expect('{:14_o}'.format([n]), '     1234_5670');
        expect('{:014_o}'.format([n]), '0000_1234_5670');
        expect('{:015_o}'.format([n]), '0_0000_1234_5670');
        expect('{:016_o}'.format([n]), '0_0000_1234_5670');

        expect('{:_o}'.format([-n]), '-1234_5670');
        expect('{:14_o}'.format([-n]), '    -1234_5670');
        expect('{:014_o}'.format([-n]), '-000_1234_5670');
        expect('{:015_o}'.format([-n]), '-0000_1234_5670');
        expect('{:016_o}'.format([-n]), '-0_0000_1234_5670');

        expect(
            () => '{:,o}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:,o} Group option ',' not allowed with format specifier 'o'.")));
      });

      test('alt', () {
        expect(
            () => '{:#o}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:#o} Alternate form (#) not allowed with format specifier 'o'.")));
      });

      test('precision', () {
        expect(
            () => '{:.2o}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:.2o} Precision not allowed with format specifier 'o'.")));
      });
    });

    group('x:', () {
      const n = 0x12ABCDEF;

      test('basic use', () {
        expect(
            () => '{:x}'.format([123.0]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:x} Expected int. Passed double.')));

        expect('{:x}'.format([n]), '12abcdef');
        expect('{:x}'.format([-n]), '-12abcdef');

        expect('{:x}'.format([9223372036854775807]), '7fffffffffffffff');
        expect('{:x}'.format([-9223372036854775807]), '-7fffffffffffffff');
        expect('{:x}'.format([-9223372036854775808]), '-8000000000000000');
      });

      test('sign', () {
        expect('{:+x}'.format([n]), '+12abcdef');
        expect('{:-x}'.format([n]), '12abcdef');
        expect('{: x}'.format([n]), ' 12abcdef');
        expect('{:+x}'.format([-n]), '-12abcdef');
        expect('{:-x}'.format([-n]), '-12abcdef');
        expect('{: x}'.format([-n]), '-12abcdef');
      });

      test('align', () {
        expect('{:12x}'.format([n]), '    12abcdef');
        expect('{:12x}'.format([-n]), '   -12abcdef');
      });

      test('zero', () {
        expect('{:0x}'.format([n]), '12abcdef');
        expect('{:012x}'.format([n]), '000012abcdef');
        expect('{:012x}'.format([-n]), '-00012abcdef');
      });

      test('group', () {
        expect('{:_x}'.format([n]), '12ab_cdef');
        expect('{:14_x}'.format([n]), '     12ab_cdef');
        expect('{:014_x}'.format([n]), '0000_12ab_cdef');
        expect('{:015_x}'.format([n]), '0_0000_12ab_cdef');
        expect('{:016_x}'.format([n]), '0_0000_12ab_cdef');

        expect('{:_x}'.format([-n]), '-12ab_cdef');
        expect('{:14_x}'.format([-n]), '    -12ab_cdef');
        expect('{:014_x}'.format([-n]), '-000_12ab_cdef');
        expect('{:015_x}'.format([-n]), '-0000_12ab_cdef');
        expect('{:016_x}'.format([-n]), '-0_0000_12ab_cdef');

        expect(
            () => '{:,x}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:,x} Group option ',' not allowed with format specifier 'x'.")));
      });

      test('alt', () {
        expect('{:#x}'.format([n]), '0x12abcdef');
        expect('{:#14x}'.format([n]), '    0x12abcdef');
        expect('{:#014x}'.format([n]), '0x000012abcdef');
        expect('{:#_x}'.format([n]), '0x12ab_cdef');
        expect('{:#12_x}'.format([n]), ' 0x12ab_cdef');
        expect('{:#012_x}'.format([n]), '0x0_12ab_cdef');
        expect('{:#013_x}'.format([n]), '0x0_12ab_cdef');

        expect('{:#x}'.format([-n]), '-0x12abcdef');
        expect('{:#14x}'.format([-n]), '   -0x12abcdef');
        expect('{:#014x}'.format([-n]), '-0x00012abcdef');
        expect('{:#_x}'.format([-n]), '-0x12ab_cdef');
        expect('{:#13_x}'.format([-n]), ' -0x12ab_cdef');
        expect('{:#013_x}'.format([-n]), '-0x0_12ab_cdef');
        expect('{:#014_x}'.format([-n]), '-0x0_12ab_cdef');
      });

      test('precision', () {
        expect(
            () => '{:.2x}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:.2x} Precision not allowed with format specifier 'x'.")));
      });
    });

    group('X:', () {
      const n = 0x12ABCDEF;

      test('basic use', () {
        expect(
            () => '{:X}'.format([123.0]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:X} Expected int. Passed double.')));

        expect('{:X}'.format([n]), '12ABCDEF');
        expect('{:X}'.format([n]), '12ABCDEF');

        expect('{:X}'.format([9223372036854775807]), '7FFFFFFFFFFFFFFF');
        expect('{:X}'.format([-9223372036854775807]), '-7FFFFFFFFFFFFFFF');
        expect('{:X}'.format([-9223372036854775808]), '-8000000000000000');
      });

      test('sign', () {
        expect('{:+X}'.format([n]), '+12ABCDEF');
        expect('{:-X}'.format([n]), '12ABCDEF');
        expect('{: X}'.format([n]), ' 12ABCDEF');
        expect('{:+X}'.format([-n]), '-12ABCDEF');
        expect('{:-X}'.format([-n]), '-12ABCDEF');
        expect('{: X}'.format([-n]), '-12ABCDEF');
      });

      test('align', () {
        expect('{:12X}'.format([n]), '    12ABCDEF');
      });

      test('zero', () {
        expect('{:0X}'.format([n]), '12ABCDEF');
        expect('{:012X}'.format([n]), '000012ABCDEF');
      });

      test('group', () {
        expect('{:_X}'.format([n]), '12AB_CDEF');
        expect('{:14_X}'.format([n]), '     12AB_CDEF');
        expect('{:014_X}'.format([n]), '0000_12AB_CDEF');
        expect('{:015_X}'.format([n]), '0_0000_12AB_CDEF');
        expect('{:016_X}'.format([n]), '0_0000_12AB_CDEF');
        expect(
            () => '{:,X}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:,X} Group option ',' not allowed with format specifier 'X'.")));
      });

      test('alt', () {
        expect('{:#X}'.format([n]), '0x12ABCDEF');
        expect('{:#_X}'.format([n]), '0x12AB_CDEF');
      });

      test('precision', () {
        expect(
            () => '{:.2X}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:.2X} Precision not allowed with format specifier 'X'.")));
      });
    });

    group('d:', () {
      const n = 123456789;

      test('basic use', () {
        expect(
            () => '{:d}'.format([123.0]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:d} Expected int. Passed double.')));

        expect('{}'.format([n]), '123456789');
        expect('{:d}'.format([n]), '123456789');

        expect('{}'.format([9223372036854775807]), '9223372036854775807');
        expect('{}'.format([-9223372036854775807]), '-9223372036854775807');
        expect('{}'.format([-9223372036854775808]), '-9223372036854775808');
      });

      test('sign', () {
        expect('{:+d}'.format([n]), '+123456789');
        expect('{:-d}'.format([n]), '123456789');
        expect('{: d}'.format([n]), ' 123456789');
        expect('{:+d}'.format([-n]), '-123456789');
        expect('{:-d}'.format([-n]), '-123456789');
        expect('{: d}'.format([-n]), '-123456789');
      });

      test('align', () {
        expect('{:13d}'.format([n]), '    123456789');
      });

      test('zero', () {
        expect('{:0d}'.format([n]), '123456789');
        expect('{:013d}'.format([n]), '0000123456789');
      });

      test('group', () {
        expect('{:,d}'.format([n]), '123,456,789');
        expect('{:_d}'.format([n]), '123_456_789');
        expect('{:15,d}'.format([n]), '    123,456,789');
        expect('{:15_d}'.format([n]), '    123_456_789');
        expect('{:015,d}'.format([n]), '000,123,456,789');
        expect('{:015_d}'.format([n]), '000_123_456_789');
        expect('{:016,d}'.format([n]), '0,000,123,456,789');
        expect('{:017,d}'.format([n]), '0,000,123,456,789');
      });

      test('alt', () {
        expect(
            () => '{:#d}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:#d} Alternate form (#) not allowed with format specifier 'd'.")));
      });

      test('precision', () {
        expect(
            () => '{:.2}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:.2} Precision not allowed with format specifier 'd'.")));

        expect(
            () => '{:.2d}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:.2d} Precision not allowed with format specifier 'd'.")));
      });
    });

    group('f:', () {
      const i = 1234567890;
      const d = 12345.6789;

      test('basic use', () {
        expect(
            () => '{:f}'.format(['123']),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:f} Expected num. Passed String.')));

        expect('{:f}'.format([i]), '1234567890');
        expect('{:f}'.format([-i]), '-1234567890');

        expect('{:f}'.format([d]), '12345.678900');
        expect('{:f}'.format([-d]), '-12345.678900');

        expect('{:f}'.format([9223372036854775807]), '9223372036854775807');
        expect('{:f}'.format([-9223372036854775807]), '-9223372036854775807');
        expect('{:f}'.format([-9223372036854775808]), '-9223372036854775808');
      });

      test('sign', () {
        expect('{:+f}'.format([i]), '+1234567890');
        expect('{:-f}'.format([i]), '1234567890');
        expect('{: f}'.format([i]), ' 1234567890');
        expect('{:+f}'.format([-i]), '-1234567890');
        expect('{:-f}'.format([-i]), '-1234567890');
        expect('{: f}'.format([-i]), '-1234567890');

        expect('{:+f}'.format([d]), '+12345.678900');
        expect('{:-f}'.format([d]), '12345.678900');
        expect('{: f}'.format([d]), ' 12345.678900');
        expect('{:+f}'.format([-d]), '-12345.678900');
        expect('{:-f}'.format([-d]), '-12345.678900');
        expect('{: f}'.format([-d]), '-12345.678900');
      });

      test('align', () {
        expect('{:16f}'.format([i]), '      1234567890');
        expect('{:16f}'.format([d]), '    12345.678900');
      });

      test('zero', () {
        expect('{:0f}'.format([i]), '1234567890');
        expect('{:016f}'.format([i]), '0000001234567890');
        expect('{:0f}'.format([-i]), '-1234567890');
        expect('{:016f}'.format([-i]), '-000001234567890');

        expect('{:0f}'.format([d]), '12345.678900');
        expect('{:016f}'.format([d]), '000012345.678900');
        expect('{:0f}'.format([-d]), '-12345.678900');
        expect('{:016f}'.format([-d]), '-00012345.678900');
      });

      test('group', () {
        expect('{:,f}'.format([i]), '1,234,567,890');
        expect('{:_f}'.format([i]), '1_234_567_890');
        expect('{:15,f}'.format([i]), '  1,234,567,890');
        expect('{:15_f}'.format([i]), '  1_234_567_890');
        expect('{:015,f}'.format([i]), '001,234,567,890');
        expect('{:015_f}'.format([i]), '001_234_567_890');
        expect('{:016,f}'.format([i]), '0,001,234,567,890');
        expect('{:016_f}'.format([i]), '0_001_234_567_890');
        expect('{:017,f}'.format([i]), '0,001,234,567,890');
        expect('{:017_f}'.format([i]), '0_001_234_567_890');

        expect('{:,f}'.format([d]), '12,345.678900');
        expect('{:_f}'.format([d]), '12_345.678900');
        expect('{:18,f}'.format([d]), '     12,345.678900');
        expect('{:18_f}'.format([d]), '     12_345.678900');
        expect('{:018,f}'.format([d]), '000,012,345.678900');
        expect('{:018_f}'.format([d]), '000_012_345.678900');
        expect('{:019,f}'.format([d]), '0,000,012,345.678900');
        expect('{:019_f}'.format([d]), '0_000_012_345.678900');
        expect('{:020,f}'.format([d]), '0,000,012,345.678900');
        expect('{:020_f}'.format([d]), '0_000_012_345.678900');
      });

      test('alt', () {
        expect('{:#f}'.format([i]), '1234567890.');
        expect('{:#.0f}'.format([i]), '1234567890.');

        expect('{:#f}'.format([d]), '12345.678900');
        expect('{:#.0f}'.format([d]), '12346.');
      });

      test('precision', () {
        expect('{:.0f}'.format([i]), '1234567890');
        expect('{:.1f}'.format([i]), '1234567890.0');
        expect('{:.2f}'.format([i]), '1234567890.00');
        expect('{:.3f}'.format([i]), '1234567890.000');
        expect('{:.4f}'.format([i]), '1234567890.0000');
        expect('{:.5f}'.format([i]), '1234567890.00000');

        expect('{:.0f}'.format([d]), '12346');
        expect('{:.1f}'.format([d]), '12345.7');
        expect('{:.2f}'.format([d]), '12345.68');
        expect('{:.3f}'.format([d]), '12345.679');
        expect('{:.4f}'.format([d]), '12345.6789');
        expect('{:.5f}'.format([d]), '12345.67890');
      });

      test('nan and inf', () {
        // Zero flag is ignored.
        const nan = double.nan;
        const inf = double.infinity;
        assert(-inf == double.negativeInfinity);

        expect('{:f}'.format([nan]), 'nan');
        expect('{:-f}'.format([nan]), 'nan');
        expect('{:+f}'.format([nan]), 'nan');
        expect('{: f}'.format([nan]), 'nan');
        expect('{:f}'.format([-nan]), 'nan');
        expect('{:-f}'.format([-nan]), 'nan');
        expect('{:+f}'.format([-nan]), 'nan');
        expect('{: f}'.format([-nan]), 'nan');

        expect('{:06f}'.format([nan]), '   nan');
        expect('{:-06f}'.format([nan]), '   nan');
        expect('{:+06f}'.format([nan]), '   nan');
        expect('{: 06f}'.format([nan]), '   nan');
        expect('{:06f}'.format([-nan]), '   nan');
        expect('{:-06f}'.format([-nan]), '   nan');
        expect('{:+06f}'.format([-nan]), '   nan');
        expect('{: 06f}'.format([-nan]), '   nan');

        expect('{:#,f}'.format([nan]), 'nan');
        expect('{:#06f}'.format([nan]), '   nan');

        expect('{:f}'.format([inf]), 'inf');
        expect('{:-f}'.format([inf]), 'inf');
        expect('{:+f}'.format([inf]), '+inf');
        expect('{: f}'.format([inf]), ' inf');
        expect('{:f}'.format([-inf]), '-inf');
        expect('{:-f}'.format([-inf]), '-inf');
        expect('{:+f}'.format([-inf]), '-inf');
        expect('{: f}'.format([-inf]), '-inf');

        expect('{:06f}'.format([inf]), '   inf');
        expect('{:-06f}'.format([inf]), '   inf');
        expect('{:+06f}'.format([inf]), '  +inf');
        expect('{: 06f}'.format([inf]), '   inf');
        expect('{:06f}'.format([-inf]), '  -inf');
        expect('{:-06f}'.format([-inf]), '  -inf');
        expect('{:+06f}'.format([-inf]), '  -inf');
        expect('{: 06f}'.format([-inf]), '  -inf');

        expect('{:#,f}'.format([inf]), 'inf');
        expect('{:#,f}'.format([-inf]), '-inf');
        expect('{:#06f}'.format([inf]), '   inf');
        expect('{:#06f}'.format([-inf]), '  -inf');

        expect('{:F}'.format([nan]), 'NAN');
        expect('{:+F}'.format([nan]), 'NAN');
        expect('{:F}'.format([inf]), 'INF');
        expect('{:F}'.format([-inf]), '-INF');
      });
    });

    group('e:', () {
      const i = 1234567890;
      const d1 = 0.000123456789;
      const d2 = 12345.6789;

      test('basic use', () {
        expect(
            () => '{:e}'.format(['123']),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:e} Expected num. Passed String.')));

        expect('{:e}'.format([i]), '1.234568e+9');
        expect('{:E}'.format([i]), '1.234568E+9');
        expect('{:e}'.format([-i]), '-1.234568e+9');
        expect('{:E}'.format([-i]), '-1.234568E+9');

        expect('{:e}'.format([d1]), '1.234568e-4');
        expect('{:E}'.format([d1]), '1.234568E-4');
        expect('{:e}'.format([-d1]), '-1.234568e-4');
        expect('{:E}'.format([-d1]), '-1.234568E-4');

        expect('{:e}'.format([d2]), '1.234568e+4');
        expect('{:E}'.format([d2]), '1.234568E+4');
        expect('{:e}'.format([-d2]), '-1.234568e+4');
        expect('{:E}'.format([-d2]), '-1.234568E+4');
      });

      test('sign', () {
        expect('{:+e}'.format([i]), '+1.234568e+9');
        expect('{:-e}'.format([i]), '1.234568e+9');
        expect('{: e}'.format([i]), ' 1.234568e+9');
        expect('{:+e}'.format([-i]), '-1.234568e+9');
        expect('{:-e}'.format([-i]), '-1.234568e+9');
        expect('{: e}'.format([-i]), '-1.234568e+9');

        expect('{:+e}'.format([d1]), '+1.234568e-4');
        expect('{:-e}'.format([d1]), '1.234568e-4');
        expect('{: e}'.format([d1]), ' 1.234568e-4');
        expect('{:+e}'.format([-d1]), '-1.234568e-4');
        expect('{:-e}'.format([-d1]), '-1.234568e-4');
        expect('{: e}'.format([-d1]), '-1.234568e-4');

        expect('{:+e}'.format([d2]), '+1.234568e+4');
        expect('{:-e}'.format([d2]), '1.234568e+4');
        expect('{: e}'.format([d2]), ' 1.234568e+4');
        expect('{:+e}'.format([-d2]), '-1.234568e+4');
        expect('{:-e}'.format([-d2]), '-1.234568e+4');
        expect('{: e}'.format([-d2]), '-1.234568e+4');
      });

      test('align', () {
        expect('{:15e}'.format([i]), '    1.234568e+9');
        expect('{:15e}'.format([d1]), '    1.234568e-4');
        expect('{:15e}'.format([d2]), '    1.234568e+4');
      });

      test('zero', () {
        expect('{:0e}'.format([i]), '1.234568e+9');
        expect('{:015e}'.format([i]), '00001.234568e+9');
        expect('{:0e}'.format([-i]), '-1.234568e+9');
        expect('{:015e}'.format([-i]), '-0001.234568e+9');

        expect('{:0e}'.format([d1]), '1.234568e-4');
        expect('{:015e}'.format([d1]), '00001.234568e-4');
        expect('{:0e}'.format([-d1]), '-1.234568e-4');
        expect('{:015e}'.format([-d1]), '-0001.234568e-4');

        expect('{:0e}'.format([d2]), '1.234568e+4');
        expect('{:015e}'.format([d2]), '00001.234568e+4');
        expect('{:0e}'.format([-d2]), '-1.234568e+4');
        expect('{:015e}'.format([-d2]), '-0001.234568e+4');
      });

      test('group', () {
        expect('{:,e}'.format([i]), '1.234568e+9');
        expect('{:_e}'.format([i]), '1.234568e+9');
        expect('{:17,e}'.format([i]), '      1.234568e+9');
        expect('{:17_e}'.format([i]), '      1.234568e+9');
        expect('{:017,e}'.format([i]), '000,001.234568e+9');
        expect('{:017_e}'.format([i]), '000_001.234568e+9');
        expect('{:018,e}'.format([i]), '0,000,001.234568e+9');
        expect('{:019,e}'.format([i]), '0,000,001.234568e+9');
        expect('{:012,.0e}'.format([i]), '0,000,001e+9');

        expect('{:,e}'.format([d1]), '1.234568e-4');
        expect('{:_e}'.format([d1]), '1.234568e-4');
        expect('{:17,e}'.format([d1]), '      1.234568e-4');
        expect('{:17_e}'.format([d1]), '      1.234568e-4');
        expect('{:017,e}'.format([d1]), '000,001.234568e-4');
        expect('{:017_e}'.format([d1]), '000_001.234568e-4');
        expect('{:018,e}'.format([d1]), '0,000,001.234568e-4');
        expect('{:019,e}'.format([d1]), '0,000,001.234568e-4');
        expect('{:012,.0e}'.format([d1]), '0,000,001e-4');

        expect('{:,e}'.format([d2]), '1.234568e+4');
        expect('{:_e}'.format([d2]), '1.234568e+4');
        expect('{:17,e}'.format([d2]), '      1.234568e+4');
        expect('{:17_e}'.format([d2]), '      1.234568e+4');
        expect('{:017,e}'.format([d2]), '000,001.234568e+4');
        expect('{:017_e}'.format([d2]), '000_001.234568e+4');
        expect('{:018,e}'.format([d2]), '0,000,001.234568e+4');
        expect('{:019,e}'.format([d2]), '0,000,001.234568e+4');
        expect('{:012,.0e}'.format([d2]), '0,000,001e+4');
      });

      test('alt', () {
        expect('{:#e}'.format([i]), '1.234568e+9');
        expect('{:#.0e}'.format([i]), '1.e+9');

        expect('{:#e}'.format([d1]), '1.234568e-4');
        expect('{:#.0e}'.format([d1]), '1.e-4');

        expect('{:#e}'.format([d2]), '1.234568e+4');
        expect('{:#.0e}'.format([d2]), '1.e+4');
      });

      test('precision', () {
        expect('{:.0e}'.format([i]), '1e+9');
        expect('{:.1e}'.format([i]), '1.2e+9');
        expect('{:.2e}'.format([i]), '1.23e+9');
        expect('{:.3e}'.format([i]), '1.235e+9');
        expect('{:.4e}'.format([i]), '1.2346e+9');
        expect('{:.5e}'.format([i]), '1.23457e+9');
        expect('{:.6e}'.format([i]), '1.234568e+9');
        expect('{:.7e}'.format([i]), '1.2345679e+9');
        expect('{:.8e}'.format([i]), '1.23456789e+9');
        expect('{:.9e}'.format([i]), '1.234567890e+9');

        expect('{:.0e}'.format([d1]), '1e-4');
        expect('{:.1e}'.format([d1]), '1.2e-4');
        expect('{:.2e}'.format([d1]), '1.23e-4');
        expect('{:.3e}'.format([d1]), '1.235e-4');
        expect('{:.4e}'.format([d1]), '1.2346e-4');
        expect('{:.5e}'.format([d1]), '1.23457e-4');
        expect('{:.6e}'.format([d1]), '1.234568e-4');
        expect('{:.7e}'.format([d1]), '1.2345679e-4');
        expect('{:.8e}'.format([d1]), '1.23456789e-4');
        expect('{:.9e}'.format([d1]), '1.234567890e-4');

        expect('{:.0e}'.format([d2]), '1e+4');
        expect('{:.1e}'.format([d2]), '1.2e+4');
        expect('{:.2e}'.format([d2]), '1.23e+4');
        expect('{:.3e}'.format([d2]), '1.235e+4');
        expect('{:.4e}'.format([d2]), '1.2346e+4');
        expect('{:.5e}'.format([d2]), '1.23457e+4');
        expect('{:.6e}'.format([d2]), '1.234568e+4');
        expect('{:.7e}'.format([d2]), '1.2345679e+4');
        expect('{:.8e}'.format([d2]), '1.23456789e+4');
        expect('{:.9e}'.format([d2]), '1.234567890e+4');
      });

      test('nan and inf', () {
        // В отличие от Python и C++ флаг zero для NaN и Infinity игнорирую.
        const nan = double.nan;
        const inf = double.infinity;
        assert(-inf == double.negativeInfinity);

        expect('{:e}'.format([nan]), 'nan');
        expect('{:-e}'.format([nan]), 'nan');
        expect('{:+e}'.format([nan]), 'nan');
        expect('{: e}'.format([nan]), 'nan');
        expect('{:e}'.format([-nan]), 'nan');
        expect('{:-e}'.format([-nan]), 'nan');
        expect('{:+e}'.format([-nan]), 'nan');
        expect('{: e}'.format([-nan]), 'nan');

        expect('{:06e}'.format([nan]), '   nan');
        expect('{:-06e}'.format([nan]), '   nan');
        expect('{:+06e}'.format([nan]), '   nan');
        expect('{: 06e}'.format([nan]), '   nan');
        expect('{:06e}'.format([-nan]), '   nan');
        expect('{:-06e}'.format([-nan]), '   nan');
        expect('{:+06e}'.format([-nan]), '   nan');
        expect('{: 06e}'.format([-nan]), '   nan');

        expect('{:#,e}'.format([nan]), 'nan');
        expect('{:#06e}'.format([nan]), '   nan');

        expect('{:e}'.format([inf]), 'inf');
        expect('{:-e}'.format([inf]), 'inf');
        expect('{:+e}'.format([inf]), '+inf');
        expect('{: e}'.format([inf]), ' inf');
        expect('{:e}'.format([-inf]), '-inf');
        expect('{:-e}'.format([-inf]), '-inf');
        expect('{:+e}'.format([-inf]), '-inf');
        expect('{: e}'.format([-inf]), '-inf');

        expect('{:06e}'.format([inf]), '   inf');
        expect('{:-06e}'.format([inf]), '   inf');
        expect('{:+06e}'.format([inf]), '  +inf');
        expect('{: 06e}'.format([inf]), '   inf');
        expect('{:06e}'.format([-inf]), '  -inf');
        expect('{:-06e}'.format([-inf]), '  -inf');
        expect('{:+06e}'.format([-inf]), '  -inf');
        expect('{: 06e}'.format([-inf]), '  -inf');

        expect('{:#,e}'.format([inf]), 'inf');
        expect('{:#,e}'.format([-inf]), '-inf');
        expect('{:#06e}'.format([inf]), '   inf');
        expect('{:#06e}'.format([-inf]), '  -inf');

        expect('{:E}'.format([nan]), 'NAN');
        expect('{:+E}'.format([nan]), 'NAN');
        expect('{:E}'.format([inf]), 'INF');
        expect('{:E}'.format([-inf]), '-INF');
      });
    });

    group('g:', () {
      test('basic use', () {
        expect(
            () => '{:g}'.format(['123']),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:g} Expected num. Passed String.')));
        expect('{:g}'.format([0]), '0');
        expect('{:g}'.format([9223372036854775807]), '9223372036854775807');
        expect('{:g}'.format([-9223372036854775807]), '-9223372036854775807');
        expect('{:g}'.format([-9223372036854775808]), '-9223372036854775808');
        expect('{:g}'.format([0.000001]), '0.000001');
        expect('{:g}'.format([0.0000001]), '1e-7');
        expect('{:G}'.format([0.0000001]), '1E-7');
        expect('{:g}'.format([123456.0]), '123456');
        expect('{:g}'.format([1234567.0]), '1.23457e+6');
        expect('{:G}'.format([1234567.0]), '1.23457E+6');
      });

      test('precision', () {
        expect('{:.1g}'.format([0.12]), '0.1');
        expect('{:.1g}'.format([1.2]), '1');
        expect('{:.1g}'.format([12.0]), '1e+1');
        expect('{:.1g}'.format([0.000001]), '0.000001');
        expect('{:.15g}'.format([0.000001]), '0.000001');
        expect('{:.1g}'.format([0.0000001]), '1e-7');
        expect('{:.15g}'.format([0.0000001]), '1e-7');
        expect('{:.1g}'.format([123456.0]), '1e+5');
        expect('{:.15g}'.format([123456.0]), '123456');
        expect('{:.1g}'.format([123456789012345.0]), '1e+14');
        expect('{:.15g}'.format([123456789012345.0]), '123456789012345');
        expect('{:.15g}'.format([1234567890123456.0]), '1.23456789012346e+15');
      });

      test('alt', () {
        expect('{:#g}'.format([1.0]), '1.00000');
        expect('{:#g}'.format([0.0000001]), '1.00000e-7');
        expect('{:#.1g}'.format([1.2]), '1.');
        expect('{:#.1g}'.format([12.0]), '1.e+1');
        expect('{:#.15g}'.format([123456789012345.0]), '123456789012345.');
        expect('{:#G}'.format([0.0000001]), '1.00000E-7');
        expect('{:#.1G}'.format([12.0]), '1.E+1');

        // expect('{:#03g}'.format([1.0]), '01.');
      });

      test('zero', () {
        expect('{:0g}'.format([0.000001]), '0.000001');
        expect('{:014g}'.format([0.000001]), '0000000.000001');
        expect('{:0g}'.format([0.0000001]), '1e-7');
        expect('{:014g}'.format([0.0000001]), '00000000001e-7');
      });

      test('group', () {
        expect('{:,.9g}'.format([123456789.0]), '123,456,789');
        expect('{:_.9g}'.format([123456789.0]), '123_456_789');
        expect('{:012,.9g}'.format([123456789.0]), '0,123,456,789');
        expect('{:012_.9g}'.format([123456789.0]), '0_123_456_789');
        expect('{:013,.9g}'.format([123456789.0]), '0,123,456,789');
        expect('{:013_.9g}'.format([123456789.0]), '0_123_456_789');

        expect('{:010,g}'.format([0.0000001]), '000,001e-7');
        expect('{:011,g}'.format([0.0000001]), '0,000,001e-7');
        expect('{:012,g}'.format([0.0000001]), '0,000,001e-7');

        expect('{:019,.9g}'.format([1234567890.0]), '000,001.23456789e+9');
        expect('{:020,.9g}'.format([1234567890.0]), '0,000,001.23456789e+9');
        expect('{:021,.9g}'.format([1234567890.0]), '0,000,001.23456789e+9');
      });
    });

    group('n:', () {
      const d = 123456789;
      const f = 1234567.89;
      const nan = double.nan;
      const inf = double.infinity;

      test('basic use', () {
        expect(
            () => '{:n}'.format(['123']),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:n} Expected num. Passed String.')));
        expect('{:n}'.format([d]), '123456789');
        expect('{:n}'.format([f]), '1234567.89');
      });

      void printA(String str) =>
          print('(${str.length}/${str.characters.length}) $str ');

      test('---', () {
        const f = -123456789.89;
        Intl.defaultLocale = 'ar_EG';
        print(NumberFormat().symbols.DECIMAL_PATTERN);

        final fmt = NumberFormat.decimalPattern();
        printA(fmt.format(f));

        print('14');
        printA('{:14n}'.format([f]));
        printA('{:14,n}'.format([f]));
        printA('{:014n}'.format([f]));
        printA('{:014,n}'.format([f]));

        print('15');
        printA('{:15n}'.format([f]));
        printA('{:15,n}'.format([f]));
        printA('{:015n}'.format([f]));
        printA('{:015,n}'.format([f]));

        print('16');
        printA('{:16n}'.format([f]));
        printA('{:16,n}'.format([f]));
        printA('{:016n}'.format([f]));
        printA('{:016,n}'.format([f]));

        print('17');
        printA('{:17n}'.format([f]));
        printA('{:17,n}'.format([f]));
        printA('{:017n}'.format([f]));
        printA('{:017,n}'.format([f]));

        print('18');
        printA('{:18n}'.format([f]));
        printA('{:18,n}'.format([f]));
        printA('{:018n}'.format([f]));
        printA('{:018,n}'.format([f]));
      });

      // void testLocale(String locale, List<String> results) {
      //   test(locale, () {
      //     Intl.defaultLocale = locale;
      //     var i = 0;
      //     expect('{:n}'.format([d]), results[i++]);
      //     expect('{:n}'.format([f]), results[i++]);
      //     expect('{:.1n}'.format([f]), results[i++]);
      //     expect('{:014.1n}'.format([f]), results[i++]);

      //     expect('{:,n}'.format([d]), results[i++]);
      //     expect('{:,n}'.format([f]), results[i++]);
      //     expect('{:,.1n}'.format([f]), results[i++]);
      //     expect('{:n}'.format([nan]), results[i++]);
      //     expect('{:n}'.format([inf]), results[i++]);
      //     expect('{:n}'.format([-inf]), results[i++]);
      //   });
      // }

      test('en_US', () {
        Intl.defaultLocale = 'en_US';
        expect('{:n}'.format([d]), '123456789');
        expect('{:n}'.format([f]), '1234567.89');
        expect('{:n}'.format([nan]), 'NaN');
        expect('{:n}'.format([inf]), '∞');
        expect('{:n}'.format([-inf]), '-∞');

        expect('{:.1n}'.format([f]), '1234567.9');
        expect('{:014.1n}'.format([f]), '000001234567.9');

        expect('{:,n}'.format([d]), '123,456,789');
        expect('{:,n}'.format([f]), '1,234,567.89');
        expect('{:,.1n}'.format([f]), '1,234,567.9');
      });

      // testLocale('ru_RU', [
      //   '123456789',
      //   '1234567,890000',
      //   '1234567,9',
      //   '123\u00a0456\u00a0789',
      //   '1\u00a0234\u00a0567,890000',
      //   '1\u00a0234\u00a0567,9',
      //   'не\u00a0число',
      //   '∞',
      //   '-∞',
      // ]);

      // testLocale('bn', [
      //   '১২৩৪৫৬৭৮৯',
      //   '১২৩৪৫৬৭.৮৯০০০০',
      //   '১২৩৪৫৬৭.৯',
      //   '১২,৩৪,৫৬,৭৮৯',
      //   '১২,৩৪,৫৬৭.৮৯০০০০',
      //   '১২,৩৪,৫৬৭.৯',
      //   'NaN',
      //   '∞',
      //   '-∞',
      // ]);

      // testLocale('en_IN', [
      //   '123456789',
      //   '1234567.890000',
      //   '1234567.9',
      //   '12,34,56,789',
      //   '12,34,567.890000',
      //   '12,34,567.9',
      //   'NaN',
      //   '∞',
      //   '-∞',
      // ]);

      // testLocale('ar', [
      //   '123456789',
      //   '1234567.890000',
      //   '1234567.9',
      //   '123,456,789',
      //   '1,234,567.890000',
      //   '1,234,567.9',
      //   'ليس\u00a0رقمًا',
      //   '∞',
      //   '\u200e-∞',
      // ]);
    });
  });

  // Describe("Строки (s)", function () {
  //   It("без параметров", function () {
  //     var s = "abcdef";

  //     Assert.StrictEqual("{}"  .format(s), "abcdef");
  //     Assert.StrictEqual("{:}" .format(s), "abcdef");
  //     Assert.StrictEqual("{:s}".format(s), "abcdef");

  //     Assert.StrictEqual("{}"  .format(new String(s)), "abcdef");
  //     Assert.StrictEqual("{:s}".format(new String(s)), "abcdef");

  //     Assert.StrictEqual("{:s}".format(123), "123");
  //     Assert.StrictEqual("{:s}".format(true), "true");
  //     Assert.StrictEqual("{:s}".format(undefined), "undefined");
  //     Assert.StrictEqual("{:s}".format({}), "object {\n}");
  //   });

  // Describe("Строки для SQL (S)", function () {
  //   It("без параметров", function () {
  //     var s = "l'amour";
  //     Assert.StrictEqual("{:S}".format(s), "'l''amour'");
  //     Assert.StrictEqual("{:S}".format(new String(s)), "'l''amour'");
  //   });

  //   It("размер", function () {
  //     var s = "l'amour";
  //     Assert.StrictEqual("{:.0S}" .format(s), "''");

  //     Assert.StrictEqual("{:.1S}" .format(s), "'l'");
  //     Assert.StrictEqual("{:#.1S}".format(s), "'…'");

  //     Assert.StrictEqual("{:.4S}" .format(s), "'l''am'");
  //     Assert.StrictEqual("{:#.4S}".format(s), "'l''a…'");

  //     Assert.StrictEqual("{:.7S}" .format(s), "'l''amour'");
  //     Assert.StrictEqual("{:#.7S}".format(s), "'l''amour'");

  //     Assert.StrictEqual("{:.8S}" .format(s), "'l''amour'");
  //     Assert.StrictEqual("{:#.8S}".format(s), "'l''amour'");
  //   });

  //   It("ширина", function () {
  //     var s = "l'amour";
  //     Assert.StrictEqual("{:9S}"    .format(s), "*********");
  //     Assert.StrictEqual("{:10S}"   .format(s), "'l''amour'");
  //     Assert.StrictEqual("{:#10S}"  .format(s), "'l''amour'");
  //     Assert.StrictEqual("{:13S}"   .format(s), "'l''amour'   ");
  //     Assert.StrictEqual("{:#13S}"  .format(s), "'l''amour'   ");
  //     Assert.StrictEqual("{:6.4S}"  .format(s), "******");
  //     Assert.StrictEqual("{:7.4S}"  .format(s), "'l''am'");
  //     Assert.StrictEqual("{:#7.4S}" .format(s), "'l''a…'");
  //     Assert.StrictEqual("{:10.4S}" .format(s), "'l''am'   ");
  //     Assert.StrictEqual("{:#10.4S}".format(s), "'l''a…'   ");
  //   });

  //   It("выравнивание и заполнение", function () {
  //     var s = "l'amour";
  //     Assert.StrictEqual("{:<13S}" .format(s), "'l''amour'   ");
  //     Assert.StrictEqual("{:.<13S}".format(s), "'l''amour'...");

  //     Assert.StrictEqual("{:>13S}" .format(s), "   'l''amour'");
  //     Assert.StrictEqual("{:.>13S}".format(s), "...'l''amour'");

  //     Assert.StrictEqual("{:^13S}" .format(s), " 'l''amour'  ");
  //     Assert.StrictEqual("{:.^13S}".format(s), ".'l''amour'..");
  //   });
  // });

  // Describe("Дата и время (d,t,D,T,q,p)", function () {
  //   It("автораспознавание", function () {
  //     Assert.StrictEqual("{}".format( EncodeDate(9, 1, 2020) ),          "09.01.2020");
  //     Assert.StrictEqual("{}".format( new Date(2020, 0, 9) ),            "09.01.2020");
  //     Assert.StrictEqual("{}".format( Datetime({d: 9, m: 1, y: 2020}) ), "09.01.2020");

  //     Assert.StrictEqual("{}".format( EncodeTime(10, 20, 30, 500) ),                "10:20:30.500");
  //     Assert.StrictEqual("{}".format( new Date(1899, 11, 30, 10, 20, 30, 500) ),    "10:20:30.500");
  //     Assert.StrictEqual("{}".format( Datetime({h: 10, min: 20, s: 30, ms: 500}) ), "10:20:30.500");

  //     Assert.StrictEqual("{}".format( EncodeDate(Double(EncodeDate(9, 1, 2020)) + Double(EncodeTime(10, 20, 30, 500))) ), "09.01.2020 10:20:30.500");
  //     Assert.StrictEqual("{}".format( new Date(2020, 0, 9, 10, 20, 30, 500) ),                                            "09.01.2020 10:20:30.500");
  //     Assert.StrictEqual("{}".format( Datetime("09.01.2020 10:20:30.500") ),                                              "09.01.2020 10:20:30.500");
  //   });

  //   It("с указанием типа, разные типы даты/времени", function () {
  //     Assert.StrictEqual("{:T}".format( Datetime("09.01.2020 10:20:30.500") ),                             "09.01.2020 10:20:30.500");
  //     Assert.StrictEqual("{:T}".format( Datetime({d: 9, m: 1, y: 2020, h: 10, min: 20, s: 30, ms: 500}) ), "09.01.2020 10:20:30.500");
  //     Assert.StrictEqual("{:T}".format("09.01.2020 10:20:30.500"),                                         "09.01.2020 10:20:30.500");
  //     Assert.StrictEqual("{:T}".format({d: 9, m: 1, y: 2020, h: 10, min: 20, s: 30, ms: 500}),             "09.01.2020 10:20:30.500");
  //     Assert.StrictEqual("{:T}".format(43839.4309085648),                                                  "09.01.2020 10:20:30.500");
  //   });

  //   It("дата (d)", function () {
  //     Assert.StrictEqual("{:d}".format("09.01.2020 10:20:30.500"), "09.01.2020");
  //     Assert.StrictEqual("{:d}".format("09.01.2020"),              "09.01.2020");
  //     Assert.StrictEqual("{:d}".format("10:20:30.500"),            "30.12.1899");

  //     Assert.StrictEqual("{:d}".format(null), "null");
  //     Assert.StrictEqual("{:d}".format(), "null");
  //   });

  //   It("время (t)", function () {
  //     Assert.StrictEqual("{:t}".format("09.01.2020 10:20:30.500"), "10:20:30.500");
  //     Assert.StrictEqual("{:t}".format("09.01.2020 10:20:30"),     "10:20:30");
  //     Assert.StrictEqual("{:t}".format("09.01.2020 10:20"),        "10:20");
  //     Assert.StrictEqual("{:t}".format("09.01.2020"),              "00:00");
  //     Assert.StrictEqual("{:t}".format("10:20:30.500"),            "10:20:30.500");

  //     Assert.StrictEqual("{:t}".format(null), "null");
  //     Assert.StrictEqual("{:t}".format(), "null");
  //   });

  //   It("дата (D)", function () {
  //     Assert.StrictEqual("{:D}".format("09.01.2020 10:20:30.500"), "9 января 2020");
  //     Assert.StrictEqual("{:D}".format("09.01.2020"),              "9 января 2020");
  //     Assert.StrictEqual("{:D}".format("10:20:30.500"),            "30 декабря 1899");

  //     Assert.StrictEqual("{:D}".format(null), "null");
  //     Assert.StrictEqual("{:D}".format(), "null");
  //   });

  //   It("дата/время (T)", function () {
  //     Assert.StrictEqual("{:T}".format("09.01.2020 10:20:30.500"), "09.01.2020 10:20:30.500");
  //     Assert.StrictEqual("{:T}".format("09.01.2020 10:20:30"),     "09.01.2020 10:20:30");
  //     Assert.StrictEqual("{:T}".format("09.01.2020 10:20"),        "09.01.2020 10:20");
  //     Assert.StrictEqual("{:T}".format("09.01.2020"),              "09.01.2020");
  //     Assert.StrictEqual("{:T}".format("10:20:30.500"),            "10:20:30.500");
  //     Assert.StrictEqual("{:T}".format("10:20:30"),                "10:20:30");
  //     Assert.StrictEqual("{:T}".format("10:20"),                   "10:20");
  //     Assert.StrictEqual("{:T}".format(null),                      "null");
  //     Assert.StrictEqual("{:T}".format(),                          "null");
  //   });

  //   It("дата/время для SQL (q)", function () {
  //     Assert.StrictEqual("{:q}".format("09.01.2020 10:20:30.500"), "{ts'2020-01-09 10:20:30.500'}");
  //     Assert.StrictEqual("{:q}".format("09.01.2020 10:20:30"),     "{ts'2020-01-09 10:20:30'}");
  //     Assert.StrictEqual("{:q}".format("09.01.2020 10:20"),        "{ts'2020-01-09 10:20:00'}");
  //     Assert.StrictEqual("{:q}".format("09.01.2020"),              "{d'2020-01-09'}");
  //     Assert.StrictEqual("{:q}".format("10:20:30.500"),            "{t'10:20:30.500'}");
  //     Assert.StrictEqual("{:q}".format("10:20:30"),                "{t'10:20:30'}");
  //     Assert.StrictEqual("{:q}".format("10:20"),                   "{t'10:20:00'}");
  //     Assert.StrictEqual("{:q}".format(null),                      "null");
  //     Assert.StrictEqual("{:q}".format(),                          "null");
  //   });

  //   It("месяц и год (p)", function () {
  //     var dt1 = Datetime("09.01.2020");
  //     var dt2 = EncodeDate(9, 1, 2020);
  //     var p1 = dt1.GetYear() * 12 + dt1.GetMonth();
  //     var p2 = GetYear(dt2) * 12 + GetMonth(dt2);

  //     Assert.StrictEqual("{:p}".format(p1),              "Январь 2020");
  //     Assert.StrictEqual("{:p}".format(p2),              "Январь 2020");
  //     Assert.StrictEqual("{:p}".format(dt1),             "Январь 2020");
  //     Assert.StrictEqual("{:p}".format(dt2),             "Январь 2020");
  //     Assert.StrictEqual("{:p}".format("09.01.2020"),    "Январь 2020");
  //     Assert.StrictEqual("{:p}".format({m: 1, y: 2020}), "Январь 2020");
  //     Assert.StrictEqual("{:p}".format(null),            "null");
  //     Assert.StrictEqual("{:p}".format(),                "null");
  //   });

  //   It("формат пользователя", function () {
  //     var dt = "28.04.2020 12:46:49.500";
  //     Assert.StrictEqual("{:d'd month y г. h ч n мин s сек ms мс (weekday)'}".format(dt), "28 апреля 2020 г. 12 ч 46 мин 49 сек 500 мс (вторник)");
  //     Assert.StrictEqual("{:t'd mon y hh:nn (wd)'}".format(dt), "28 апр 2020 12:46 (вт)");
  //     Assert.StrictEqual("{:d'Weekday, d mon y'}".format(dt), "Вторник, 28 апр 2020");
  //     Assert.StrictEqual("{:t'Wd, d mon y'}".format(dt), "Вт, 28 апр 2020");
  //     Assert.StrictEqual("{:d'Monthname y'}".format(dt), "Апрель 2020");
  //     Assert.StrictEqual("{:t'p'}".format(dt), "Апрель 2020");
  //     Assert.StrictEqual("{:d'monthname'}".format(dt), "апрель");
  //     Assert.StrictEqual("{:t'dd.mm.yyyy hh:nn:ss.ms'}".format(dt), "28.04.2020 12:46:49.500");
  //     Assert.StrictEqual("{:d'yyyy-mm-dd hh:nn:ss.ms'}".format(dt), "2020-04-28 12:46:49.500");
  //     Assert.StrictEqual("{:t'yyyy-mm-dd hh:nn:ss.ms TZD'}".format(dt), "2020-04-28 12:46:49.500 +10:00");
  //     Assert.StrictEqual("{:d'dd.mm.yyyy'}".format(dt), "28.04.2020");
  //     Assert.StrictEqual("{:t'dd.mm.yy'}".format(dt), "28.04.20");
  //     Assert.StrictEqual("{:d'hh:nn:ss.ms'}".format(dt), "12:46:49.500");

  //     Assert.StrictEqual("{:t'n'' = n мин'}"    .format({min: 1}), "1' = 1 мин");
  //     Assert.StrictEqual('{:t"n\' = n мин"}'    .format({min: 1}), "1' = 1 мин");
  //     Assert.StrictEqual("{:t\"n' = n мин\"}"   .format({min: 1}), "1' = 1 мин");
  //     Assert.StrictEqual('{:t\'n\'\' = n мин\'}'.format({min: 1}), "1' = 1 мин");

  //     Assert.StrictEqual('{:t"s"" = s сек"}'    .format({s: 1}), '1" = 1 сек');
  //     Assert.StrictEqual("{:t's\" = s сек'}"    .format({s: 1}), '1" = 1 сек');
  //     Assert.StrictEqual('{:t\'s" = s сек\'}'   .format({s: 1}), '1" = 1 сек');
  //     Assert.StrictEqual("{:t\"s\"\" = s сек\"}".format({s: 1}), '1" = 1 сек');
  //   });
  // });

  // Describe("Выравнивание текста", function () {
  //   It("вставка на этой же строке", function () {
  //     var sql =
  //       #sql
  //       select *
  //       from t {from:|}
  //       where {where:|}
  //       #endsql

  //     var result =
  //       #sql
  //       select *
  //       from t
  //       where
  //       #endsql

  //     Assert.StrictEqual( sql.format({from: "", where: ""}).trimIndent(), result.trimIndent());

  //     result =
  //       #sql
  //       select *
  //       from t join t2
  //       where 1=1
  //       #endsql

  //     Assert.StrictEqual( sql.format({from: "join t2", where: "1=1"}).trimIndent(), result.trimIndent());

  //     result =
  //       #sql
  //       select *
  //       from t join t2
  //              join t3
  //              join t4
  //       where 1=1
  //             and n>2
  //             and m=3
  //       #endsql

  //       Assert.StrictEqual(
  //         sql.format({from: "join t2\r\njoin t3\r\njoin t4", where: "1=1\r\nand n>2\r\nand m=3"}).trimIndent(),
  //         result.trimIndent());
  //   });

  //   It("на этой же строке с фиксированным отступом", function () {
  //     var sql =
  //       #sql
  //       select *
  //       from t {from:|2}
  //       where {where:|2}
  //       #endsql

  //     var result =
  //       #sql
  //       select *
  //       from t
  //       where
  //       #endsql

  //     Assert.StrictEqual( sql.format({from: "", where: ""}).trimIndent(), result.trimIndent());

  //     result =
  //       #sql
  //       select *
  //       from t join t2
  //       where 1=1
  //       #endsql

  //     Assert.StrictEqual( sql.format({from: "join t2", where: "1=1"}).trimIndent(), result.trimIndent());

  //     result =
  //       #sql
  //       select *
  //       from t join t2
  //         join t3
  //         join t4
  //       where 1=1
  //         and n>2
  //         and m=3
  //       #endsql

  //     Assert.StrictEqual(
  //         sql.format({from: "join t2\r\njoin t3\r\njoin t4", where: "1=1\r\nand n>2\r\nand m=3"}).trimIndent(),
  //         result.trimIndent());
  //   });

  //   It("на отдельной строке", function () {
  //     var sql =
  //       #sql
  //       select *
  //       from t
  //         {from:|}
  //       where
  //         {where:|}
  //       #endsql

  //     var result =
  //       #sql
  //       select *
  //       from t
  //       where
  //       #endsql

  //     Assert.StrictEqual( sql.format({from: "", where: ""}).trimIndent(), result.trimIndent());

  //     result =
  //       #sql
  //       select *
  //       from t
  //         join t2
  //       where
  //         1=1
  //       #endsql

  //     Assert.StrictEqual( sql.format({from: "join t2", where: "1=1"}).trimIndent(), result.trimIndent());

  //     result =
  //       #sql
  //       select *
  //       from t
  //         join t2
  //         join t3
  //         join t4
  //       where
  //         1=1
  //         and n>2
  //         and m=3
  //       #endsql

  //     Assert.StrictEqual(
  //         sql.format({from: "join t2\r\njoin t3\r\njoin t4", where: "1=1\r\nand n>2\r\nand m=3"}).trimIndent(),
  //         result.trimIndent());
  //   });

  //   It("на отдельной строке с дополнительным отступом", function () {
  //     var sql =
  //       #sql
  //       select *
  //       from t
  //         {from:|2}
  //       where
  //         {where:|2}
  //       #endsql

  //     var result =
  //       #sql
  //       select *
  //       from t
  //       where
  //       #endsql

  //     Assert.StrictEqual( sql.format({from: "", where: ""}).trimIndent(), result.trimIndent());

  //     result =
  //       #sql
  //       select *
  //       from t
  //         join t2
  //       where
  //         1=1
  //       #endsql

  //     Assert.StrictEqual( sql.format({from: "join t2", where: "1=1"}).trimIndent(), result.trimIndent());

  //     result =
  //       #sql
  //       select *
  //       from t
  //         join t2
  //           join t3
  //           join t4
  //       where
  //         1=1
  //           and n>2
  //           and m=3
  //       #endsql

  //     Assert.StrictEqual(
  //         sql.format({from: "join t2\r\njoin t3\r\njoin t4", where: "1=1\r\nand n>2\r\nand m=3"}).trimIndent(),
  //         result.trimIndent());
  //   });
  // });

  // Describe("Пустые строки", function () {

  //   It("строка обрезается", function () {
  //     var str =
  //       #text
  //       111
  //       ...  {:|}
  //       222
  //       #endtext

  //     var result =
  //       #text
  //       111
  //       ...
  //       222
  //       #endtext

  //     Assert.StrictEqual( str.trimIndent().format(""), result.trimIndent() );
  //   });

  //   It("строка посередине - удаляется", function () {
  //     var str =
  //       #text
  //       111
  //         {:|}
  //       222
  //       #endtext

  //     var result =
  //       #text
  //       111
  //       222
  //       #endtext

  //     Assert.StrictEqual( str.trimIndent().format(""), result.trimIndent() );
  //   });

  //   It("строка посередине, прижата к верху - удаляется", function () {
  //     var str =
  //       #text
  //       111
  //         {:|}

  //       222
  //       #endtext

  //     var result =
  //       #text
  //       111

  //       222
  //       #endtext

  //     Assert.StrictEqual( str.trimIndent().format(""), result.trimIndent() );
  //   });

  //   It("строка посередине, прижата к низу - удаляется", function () {
  //     var str =
  //       #text
  //       111

  //         {:|}
  //       222
  //       #endtext

  //     var result =
  //       #text
  //       111

  //       222
  //       #endtext

  //     Assert.StrictEqual( str.trimIndent().format(""), result.trimIndent() );
  //   });

  //   It("строка сверху - удаляется", function () {
  //     var str =
  //       #text
  //         {:|}
  //       222
  //       #endtext

  //       var result =
  //       #text
  //       222
  //       #endtext

  //     Assert.StrictEqual( str.trimIndent().format(""), result.trimIndent() );
  //   });

  //   It("строка снизу - удаляется", function () {
  //     var str =
  //       #text
  //       111
  //         {:|}
  //       #endtext

  //       var result =
  //       #text
  //       111
  //       #endtext

  //     Assert.StrictEqual( str.trimIndent().format(""), result.trimIndent() );
  //   });

  //   It("строка посередине, не прижата - удаляются все строки снизу", function () {
  //     var str =
  //       #text
  //       111

  //         {:|}

  //       222
  //       #endtext

  //     var result =
  //       #text
  //       111

  //       222
  //       #endtext

  //     Assert.StrictEqual( str.trimIndent().format(""), result.trimIndent() );
  //   });

  //   It("строка сверху - удаляются все строки снизу", function () {
  //     var str =
  //       #text
  //         {:|}

  //       222
  //       #endtext

  //     var result =
  //       #text
  //       222
  //       #endtext

  //     Assert.StrictEqual( str.trimIndent().format(""), result.trimIndent() );
  //   });

  //   It("строка снизу - удаляются все строки сверху", function () {
  //     // Если удаляемая строка внизу, удаляем также пустые строки сверху
  //     var str =
  //       #text
  //       111

  //         {:|}
  //       #endtext

  //     var result =
  //       #text
  //       111
  //       #endtext

  //       Assert.StrictEqual( str.trimIndent().format(""), result.trimIndent() );
  //   });
  // });
}
