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
        '_6': 6,
        '0': 7,
        '+': 8,
      };

      expect(
          '{test_1} {тест_2} {テスト_3} {[hello world]} {_} {_6}'
              .format([], namedArgs),
          '1 2 3 4 5 6');
      expect('{0} {[0]}'.format([123], namedArgs), '123 7');
      expect('{+} {[+]}'.format([123], namedArgs), '{+} 8');
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
      expect('{:00}'.format([123]), '123'); // Flag zero and zero width

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
          () => '{:.2}'.format([0]),
          throwsA(predicate((e) =>
              e is ArgumentError &&
              e.message == '{:.2} Precision not allowed for int.')));

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

    group('b:', () {
      const n = 0xAA;

      test('basic use', () {
        expect(
            () => '{:b}'.format([123.0]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:b} Expected int. Passed double.')));
        expect('{:b}'.format([n]), '10101010');
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
      });

      test('zero', () {
        expect('{:012b}'.format([n]), '000010101010');
      });

      test('group', () {
        expect('{:_b}'.format([n]), '1010_1010');
        expect('{:14_b}'.format([n]), '     1010_1010');
        expect('{:014_b}'.format([n]), '0000_1010_1010');
        expect('{:015_b}'.format([n]), '0_0000_1010_1010');
        expect('{:016_b}'.format([n]), '0_0000_1010_1010');
        expect(
            () => '{:,b}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:,b} Option ',' not allowed with format specifier 'b'.")));
      });

      test('alt', () {
        expect(
            () => '{:#b}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:#b} Alternate form (#) not allowed with format specifier 'b'.")));
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
      });

      test('zero', () {
        expect('{:012o}'.format([n]), '000012345670');
      });

      test('group', () {
        expect('{:_o}'.format([n]), '1234_5670');
        expect('{:14_o}'.format([n]), '     1234_5670');
        expect('{:014_o}'.format([n]), '0000_1234_5670');
        expect('{:015_o}'.format([n]), '0_0000_1234_5670');
        expect('{:016_o}'.format([n]), '0_0000_1234_5670');
        expect(
            () => '{:,o}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:,o} Option ',' not allowed with format specifier 'o'.")));
      });

      test('alt', () {
        expect(
            () => '{:#o}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:#o} Alternate form (#) not allowed with format specifier 'o'.")));
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
      });

      test('zero', () {
        expect('{:012x}'.format([n]), '000012abcdef');
      });

      test('group', () {
        expect('{:_x}'.format([n]), '12ab_cdef');
        expect('{:14_x}'.format([n]), '     12ab_cdef');
        expect('{:014_x}'.format([n]), '0000_12ab_cdef');
        expect('{:015_x}'.format([n]), '0_0000_12ab_cdef');
        expect('{:016_x}'.format([n]), '0_0000_12ab_cdef');
        expect(
            () => '{:,x}'.format([n]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message ==
                    "{:,x} Option ',' not allowed with format specifier 'x'.")));
      });

      test('alt', () {
        expect('{:#x}'.format([n]), '0x12abcdef');
        expect('{:#x}'.format([-n]), '-0x12abcdef');
        expect('{:#_x}'.format([n]), '0x12ab_cdef');
        expect('{:#_x}'.format([-n]), '-0x12ab_cdef');
      });
    });

    group('x:', () {
      const n = 0x12ABCDEF;

      test('basic use', () {
        expect(
            () => '{:X}'.format([123.0]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:X} Expected int. Passed double.')));
        expect('{:X}'.format([n]), '12ABCDEF');
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
                    "{:,X} Option ',' not allowed with format specifier 'X'.")));
      });

      test('alt', () {
        expect('{:#X}'.format([n]), '0x12ABCDEF');
        expect('{:#_X}'.format([n]), '0x12AB_CDEF');
      });
    });

    group('d:', () {
      const n = 123456789;

      test('basic use', () {
        expect('{}'.format([n]), '123456789');
        expect('{:d}'.format([n]), '123456789');
        expect(
            () => '{:d}'.format([123.0]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:d} Expected int. Passed double.')));
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
    });

    group('f:', () {
      const n = 12345.6789;

      test('basic use', () {
        expect(
            () => '{:f}'.format([123]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:f} Expected double. Passed int.')));
        expect('{:f}'.format([0.0]), '0.000000');
        expect('{:f}'.format([-0.0]), '-0.000000');
        expect('{:f}'.format([n]), '12345.678900');
      });

      test('sign', () {
        expect('{:+f}'.format([n]), '+12345.678900');
        expect('{:-f}'.format([n]), '12345.678900');
        expect('{: f}'.format([n]), ' 12345.678900');
        expect('{:+f}'.format([-n]), '-12345.678900');
        expect('{:-f}'.format([-n]), '-12345.678900');
        expect('{: f}'.format([-n]), '-12345.678900');
      });

      test('align', () {
        expect('{:16f}'.format([n]), '    12345.678900');
      });

      test('zero', () {
        expect('{:016f}'.format([n]), '000012345.678900');
      });

      test('group', () {
        expect('{:,f}'.format([n]), '12,345.678900');
        expect('{:_f}'.format([n]), '12_345.678900');
        expect('{:18,f}'.format([n]), '     12,345.678900');
        expect('{:18_f}'.format([n]), '     12_345.678900');
        expect('{:018,f}'.format([n]), '000,012,345.678900');
        expect('{:018_f}'.format([n]), '000_012_345.678900');
        expect('{:019,f}'.format([n]), '0,000,012,345.678900');
        expect('{:020,f}'.format([n]), '0,000,012,345.678900');
      });

      test('alt', () {
        expect('{:#f}'.format([n]), '12345.678900');
        expect('{:#.0f}'.format([n]), '12346.');
      });

      test('precision', () {
        expect('{:.0f}'.format([n]), '12346');
        expect('{:.1f}'.format([n]), '12345.7');
        expect('{:.2f}'.format([n]), '12345.68');
        expect('{:.3f}'.format([n]), '12345.679');
        expect('{:.4f}'.format([n]), '12345.6789');
        expect('{:.5f}'.format([n]), '12345.67890');
      });

      test('nan and inf', () {
        // Zero flag is ignored.
        const nan = double.nan;
        const inf = double.infinity;
        assert(-inf == double.negativeInfinity);

        expect('{:f}'.format([nan]), 'nan');
        expect('{:-f}'.format([nan]), 'nan');
        expect('{:+f}'.format([nan]), '+nan');
        expect('{: f}'.format([nan]), ' nan');
        expect('{:f}'.format([-nan]), 'nan');
        expect('{:-f}'.format([-nan]), 'nan');
        expect('{:+f}'.format([-nan]), '+nan');
        expect('{: f}'.format([-nan]), ' nan');

        expect('{:06f}'.format([nan]), '   nan');
        expect('{:-06f}'.format([nan]), '   nan');
        expect('{:+06f}'.format([nan]), '  +nan');
        expect('{: 06f}'.format([nan]), '   nan');
        expect('{:06f}'.format([-nan]), '   nan');
        expect('{:-06f}'.format([-nan]), '   nan');
        expect('{:+06f}'.format([-nan]), '  +nan');
        expect('{: 06f}'.format([-nan]), '   nan');

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

        expect('{:F}'.format([nan]), 'NAN');
        expect('{:+F}'.format([nan]), '+NAN');
        expect('{:F}'.format([inf]), 'INF');
        expect('{:F}'.format([-inf]), '-INF');
      });
    });

    group('e:', () {
      const n = 12345.6789;

      test('basic use', () {
        expect(
            () => '{:e}'.format([123]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:e} Expected double. Passed int.')));
        expect('{:e}'.format([0.0]), '0.000000e+0');
        expect('{:e}'.format([-0.0]), '-0.000000e+0');
        expect('{:e}'.format([n]), '1.234568e+4');
        expect('{:E}'.format([n]), '1.234568E+4');
      });

      test('sign', () {
        expect('{:+e}'.format([n]), '+1.234568e+4');
        expect('{:-e}'.format([n]), '1.234568e+4');
        expect('{: e}'.format([n]), ' 1.234568e+4');
        expect('{:+e}'.format([-n]), '-1.234568e+4');
        expect('{:-e}'.format([-n]), '-1.234568e+4');
        expect('{: e}'.format([-n]), '-1.234568e+4');
      });

      test('align', () {
        expect('{:15e}'.format([n]), '    1.234568e+4');
      });

      test('zero', () {
        expect('{:015e}'.format([n]), '00001.234568e+4');
      });

      test('group', () {
        expect('{:,e}'.format([n]), '1.234568e+4');
        expect('{:_e}'.format([n]), '1.234568e+4');
        expect('{:17,e}'.format([n]), '      1.234568e+4');
        expect('{:17_e}'.format([n]), '      1.234568e+4');
        expect('{:017,e}'.format([n]), '000,001.234568e+4');
        expect('{:017_e}'.format([n]), '000_001.234568e+4');
        expect('{:018,e}'.format([n]), '0,000,001.234568e+4');
        expect('{:019,e}'.format([n]), '0,000,001.234568e+4');
        expect('{:012,.0e}'.format([n]), '0,000,001e+4');
      });

      test('alt', () {
        expect('{:#e}'.format([n]), '1.234568e+4');
        expect('{:#.0e}'.format([n]), '1.e+4');
      });

      test('precision', () {
        expect('{:.0e}'.format([n]), '1e+4');
        expect('{:.1e}'.format([n]), '1.2e+4');
        expect('{:.2e}'.format([n]), '1.23e+4');
        expect('{:.3e}'.format([n]), '1.235e+4');
        expect('{:.4e}'.format([n]), '1.2346e+4');
        expect('{:.5e}'.format([n]), '1.23457e+4');
        expect('{:.6e}'.format([n]), '1.234568e+4');
        expect('{:.7e}'.format([n]), '1.2345679e+4');
        expect('{:.8e}'.format([n]), '1.23456789e+4');
        expect('{:.9e}'.format([n]), '1.234567890e+4');
      });

      test('nan and inf', () {
        // В отличие от Python и C++ флаг zero для NaN и Infinity игнорирую.
        const nan = double.nan;
        const inf = double.infinity;
        assert(-inf == double.negativeInfinity);

        expect('{:e}'.format([nan]), 'nan');
        expect('{:-e}'.format([nan]), 'nan');
        expect('{:+e}'.format([nan]), '+nan');
        expect('{: e}'.format([nan]), ' nan');
        expect('{:e}'.format([-nan]), 'nan');
        expect('{:-e}'.format([-nan]), 'nan');
        expect('{:+e}'.format([-nan]), '+nan');
        expect('{: e}'.format([-nan]), ' nan');

        expect('{:06e}'.format([nan]), '   nan');
        expect('{:-06e}'.format([nan]), '   nan');
        expect('{:+06e}'.format([nan]), '  +nan');
        expect('{: 06e}'.format([nan]), '   nan');
        expect('{:06e}'.format([-nan]), '   nan');
        expect('{:-06e}'.format([-nan]), '   nan');
        expect('{:+06e}'.format([-nan]), '  +nan');
        expect('{: 06e}'.format([-nan]), '   nan');

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

        expect('{:E}'.format([nan]), 'NAN');
        expect('{:+E}'.format([nan]), '+NAN');
        expect('{:E}'.format([inf]), 'INF');
        expect('{:E}'.format([-inf]), '-INF');
      });
    });

    group('g:', () {
      test('basic use', () {
        expect(
            () => '{:g}'.format([123]),
            throwsA(predicate((e) =>
                e is ArgumentError &&
                e.message == '{:g} Expected double. Passed int.')));

        expect('{:g}'.format([0.000001]), '0.000001');
        expect('{:g}'.format([0.0000001]), '1e-7');
        expect('{:G}'.format([0.0000001]), '1E-7');
        expect('{:#g}'.format([0.0000001]), '1.e-7');
        expect('{:#G}'.format([0.0000001]), '1.E-7');
        expect('{:g}'.format([123456.0]), '123456');
        expect('{:#g}'.format([123456.0]), '123456.');
        expect('{:g}'.format([1234567.0]), '1.23457e+6');
        expect('{:G}'.format([1234567.0]), '1.23457E+6');

        expect('{:.15g}'.format([0.000001]), '0.000001');
        expect('{:.15g}'.format([0.0000001]), '1e-7');
        expect('{:#.15g}'.format([0.0000001]), '1.e-7');
        expect('{:.15g}'.format([123456.0]), '123456');
        expect('{:.15g}'.format([1234567.0]), '1234567');
        expect('{:.15g}'.format([123456789012345.0]), '123456789012345');
        expect('{:#.15g}'.format([123456789012345.0]), '123456789012345.');
        expect('{:.15g}'.format([1234567890123456.0]), '1.23456789012346e+15');

        expect('{:.1g}'.format([0.000001]), '0.000001');
        expect('{:.1g}'.format([0.0000001]), '1e-7');
        expect('{:#.1g}'.format([0.0000001]), '1.e-7');
        expect('{:.1g}'.format([123456.0]), '1e+5');
        expect('{:#.1g}'.format([123456.0]), '1.e+5');
        expect('{:.1g}'.format([1234567.0]), '1e+6');
        expect('{:#.1g}'.format([1234567.0]), '1.e+6');
        expect('{:.1g}'.format([1.0]), '1');
        expect('{:#.1g}'.format([1.0]), '1.');
        expect('{:.1g}'.format([12.0]), '1e+1');
        expect('{:#.1g}'.format([12.0]), '1.e+1');
      });

      // test('zero', () {
      //   expect('{:015e}'.format([n]), '00001.234568e+4');
      // });

      // test('group', () {
      //   expect('{:,e}'.format([n]), '1.234568e+4');
      //   expect('{:_e}'.format([n]), '1.234568e+4');
      //   expect('{:17,e}'.format([n]), '      1.234568e+4');
      //   expect('{:17_e}'.format([n]), '      1.234568e+4');
      //   expect('{:017,e}'.format([n]), '000,001.234568e+4');
      //   expect('{:017_e}'.format([n]), '000_001.234568e+4');
      //   expect('{:018,e}'.format([n]), '0,000,001.234568e+4');
      //   expect('{:019,e}'.format([n]), '0,000,001.234568e+4');
      //   expect('{:012,.0e}'.format([n]), '0,000,001e+4');
      // });
    });

    group('n:', () {
      const d = 123456789;
      const f = 1234567.89;
      const nan = double.nan;
      const inf = double.infinity;

      void localeTest(String locale, List<String> results) {
        test(locale, () {
          Intl.defaultLocale = locale;
          var i = 0;
          expect('{:n}'.format([d]), results[i++]);
          expect('{:n}'.format([f]), results[i++]);
          expect('{:.1n}'.format([f]), results[i++]);
          // expect('{:14.1n}'.format([f]), results[i++]);

          expect('{:,n}'.format([d]), results[i++]);
          expect('{:,n}'.format([f]), results[i++]);
          expect('{:,.1n}'.format([f]), results[i++]);
          expect('{:n}'.format([nan]), results[i++]);
          expect('{:n}'.format([inf]), results[i++]);
          expect('{:n}'.format([-inf]), results[i++]);
        });
      }

      localeTest('en_US', [
        '123456789',
        '1234567.890000',
        '1234567.9',
        // '000001234567.9',
        '123,456,789',
        '1,234,567.890000',
        '1,234,567.9',
        'NaN',
        '∞',
        '-∞',
      ]);

      localeTest('ru_RU', [
        '123456789',
        '1234567,890000',
        '1234567,9',
        '123\u00a0456\u00a0789',
        '1\u00a0234\u00a0567,890000',
        '1\u00a0234\u00a0567,9',
        'не\u00a0число',
        '∞',
        '-∞',
      ]);

      localeTest('bn', [
        '১২৩৪৫৬৭৮৯',
        '১২৩৪৫৬৭.৮৯০০০০',
        '১২৩৪৫৬৭.৯',
        '১২,৩৪,৫৬,৭৮৯',
        '১২,৩৪,৫৬৭.৮৯০০০০',
        '১২,৩৪,৫৬৭.৯',
        'NaN',
        '∞',
        '-∞',
      ]);

      localeTest('en_IN', [
        '123456789',
        '1234567.890000',
        '1234567.9',
        '12,34,56,789',
        '12,34,567.890000',
        '12,34,567.9',
        'NaN',
        '∞',
        '-∞',
      ]);

      localeTest('ar', [
        '123456789',
        '1234567.890000',
        '1234567.9',
        '123,456,789',
        '1,234,567.890000',
        '1,234,567.9',
        'ليس\u00a0رقمًا',
        '∞',
        '\u200e-∞',
      ]);
    });
  });

  group('без флагов', () {
    test('s', () {
      expect('{}'.format(['123']), '123');
      expect('{:s}'.format(['123']), '123');
      expect(
          () => '{:s}'.format([123]),
          throwsA(predicate((e) =>
              e is ArgumentError &&
              e.message == '{:s} Expected String. Passed int.')));
    });

    test('разделение на группы - ,', () {
      expect('{:,f}'.format([123456789.012]), '123,456,789.012000');
      expect('{:,f}'.format([12345678.9012]), '12,345,678.901200');
      expect('{:,f}'.format([1234567.89012]), '1,234,567.890120');
      expect('{:,f}'.format([123456.789012]), '123,456.789012');
    });


    //   It("ширина - положительные значения", function () {
    //     var n = 12345.6789;
    //     Assert.StrictEqual("{:00}" .format(n), ""); // Первый нуль - для заполнения нулями слева, второй - размер результирующей строки
    //     Assert.StrictEqual("{:00f}".format(n), "");
    //     Assert.StrictEqual("{:00n}".format(n), "");
    //     Assert.StrictEqual("{:00m}".format(n), "");

    //     Assert.StrictEqual("{:4}" .format(n), "****");
    //     Assert.StrictEqual("{:4f}".format(n), "****");
    //     Assert.StrictEqual("{:4n}".format(n), "****");
    //     Assert.StrictEqual("{:4m}".format(n), "****");

    //     Assert.StrictEqual("{:5}"   .format(n), "*****"); // Дробная часть не отбрасывается, поэтому число не вмещается
    //     Assert.StrictEqual("{:5f}"  .format(n), "*****");
    //     Assert.StrictEqual("{:5.0f}".format(n), "12346"); // Дробная часть отброшена, число вмещается
    //     Assert.StrictEqual("{:5n}"  .format(n), "12346");
    //     Assert.StrictEqual("{:5m}"  .format(n), "12345");
    //     Assert.StrictEqual("{:-5}"  .format(n), "*****");
    //     Assert.StrictEqual("{:-5f}" .format(n), "*****");
    //     Assert.StrictEqual("{:-5n}" .format(n), "12346");
    //     Assert.StrictEqual("{:-5m}" .format(n), "12345");
    //     Assert.StrictEqual("{: 5}"  .format(n), "*****");
    //     Assert.StrictEqual("{: 5f}" .format(n), "*****");
    //     Assert.StrictEqual("{: 5n}" .format(n), "*****");
    //     Assert.StrictEqual("{: 5m}" .format(n), "*****");
    //     Assert.StrictEqual("{:+5}"  .format(n), "*****");
    //     Assert.StrictEqual("{:+5f}" .format(n), "*****");
    //     Assert.StrictEqual("{:+5n}" .format(n), "*****");
    //     Assert.StrictEqual("{:+5m}" .format(n), "*****");

    //     Assert.StrictEqual("{:6}"    .format(n), "******");
    //     Assert.StrictEqual("{:6f}"   .format(n), "******");
    //     Assert.StrictEqual("{:6.0f}" .format(n), " 12346");
    //     Assert.StrictEqual("{:6n}"   .format(n), " 12346");
    //     Assert.StrictEqual("{:6m}"   .format(n), " 12345");
    //     Assert.StrictEqual("{:-6}"   .format(n), "******");
    //     Assert.StrictEqual("{:-6f}"  .format(n), "******");
    //     Assert.StrictEqual("{:-6.0f}".format(n), " 12346");
    //     Assert.StrictEqual("{:-6n}"  .format(n), " 12346");
    //     Assert.StrictEqual("{:-6m}"  .format(n), " 12345");
    //     Assert.StrictEqual("{: 6}"   .format(n), "******");
    //     Assert.StrictEqual("{: 6f}"  .format(n), "******");
    //     Assert.StrictEqual("{: 6.0f}".format(n), " 12346");
    //     Assert.StrictEqual("{: 6n}"  .format(n), " 12346");
    //     Assert.StrictEqual("{: 6m}"  .format(n), " 12345");
    //     Assert.StrictEqual("{:+6}"   .format(n), "******");
    //     Assert.StrictEqual("{:+6f}"  .format(n), "******");
    //     Assert.StrictEqual("{:+6.0f}".format(n), "+12346");
    //     Assert.StrictEqual("{:+6n}"  .format(n), "+12346");
    //     Assert.StrictEqual("{:+6m}"  .format(n), "+12345");
    //   });

    //   It("ширина - отрицательные значения", function () {
    //     var n = -12345.6789;
    //     Assert.StrictEqual("{:00}" .format(n), ""); // Первый нуль - для заполнения нулями слева, второй - размер результирующей строки
    //     Assert.StrictEqual("{:00f}".format(n), "");
    //     Assert.StrictEqual("{:00n}".format(n), "");
    //     Assert.StrictEqual("{:00m}".format(n), "");

    //     Assert.StrictEqual("{:5}" .format(n), "*****");
    //     Assert.StrictEqual("{:5f}".format(n), "*****");
    //     Assert.StrictEqual("{:5n}".format(n), "*****");
    //     Assert.StrictEqual("{:5m}".format(n), "*****");

    //     Assert.StrictEqual("{:6}"    .format(n), "******");
    //     Assert.StrictEqual("{:6f}"   .format(n), "******");
    //     Assert.StrictEqual("{:6.0f}" .format(n), "-12346");
    //     Assert.StrictEqual("{:6n}"   .format(n), "-12346");
    //     Assert.StrictEqual("{:6m}"   .format(n), "-12345");
    //     Assert.StrictEqual("{:-6}"   .format(n), "******");
    //     Assert.StrictEqual("{:-6f}"  .format(n), "******");
    //     Assert.StrictEqual("{:-6.0f}".format(n), "-12346");
    //     Assert.StrictEqual("{:-6n}"  .format(n), "-12346");
    //     Assert.StrictEqual("{:-6m}"  .format(n), "-12345");
    //     Assert.StrictEqual("{: 6}"   .format(n), "******");
    //     Assert.StrictEqual("{: 6f}"  .format(n), "******");
    //     Assert.StrictEqual("{: 6.0f}".format(n), "-12346");
    //     Assert.StrictEqual("{: 6n}"  .format(n), "-12346");
    //     Assert.StrictEqual("{: 6m}"  .format(n), "-12345");
    //     Assert.StrictEqual("{:+6}"   .format(n), "******");
    //     Assert.StrictEqual("{:+6f}"  .format(n), "******");
    //     Assert.StrictEqual("{:+6.0f}".format(n), "-12346");
    //     Assert.StrictEqual("{:+6n}"  .format(n), "-12346");
    //     Assert.StrictEqual("{:+6m}"  .format(n), "-12345");

    //     Assert.StrictEqual("{:7}"    .format(n), "*******");
    //     Assert.StrictEqual("{:7f}"   .format(n), "*******");
    //     Assert.StrictEqual("{:7.0f}" .format(n), " -12346");
    //     Assert.StrictEqual("{:7n}"   .format(n), " -12346");
    //     Assert.StrictEqual("{:7m}"   .format(n), " -12345");
    //     Assert.StrictEqual("{:-7}"   .format(n), "*******");
    //     Assert.StrictEqual("{:-7f}"  .format(n), "*******");
    //     Assert.StrictEqual("{:-7.0f}".format(n), " -12346");
    //     Assert.StrictEqual("{:-7n}"  .format(n), " -12346");
    //     Assert.StrictEqual("{:-7m}"  .format(n), " -12345");
    //     Assert.StrictEqual("{: 7}"   .format(n), "*******");
    //     Assert.StrictEqual("{: 7f}"  .format(n), "*******");
    //     Assert.StrictEqual("{: 7.0f}".format(n), " -12346");
    //     Assert.StrictEqual("{: 7n}"  .format(n), " -12346");
    //     Assert.StrictEqual("{: 7m}"  .format(n), " -12345");
    //     Assert.StrictEqual("{:+7}"   .format(n), "*******");
    //     Assert.StrictEqual("{:+7f}"  .format(n), "*******");
    //     Assert.StrictEqual("{:+7.0f}".format(n), " -12346");
    //     Assert.StrictEqual("{:+7n}"  .format(n), " -12346");
    //     Assert.StrictEqual("{:+7m}"  .format(n), " -12345");
    //   });

    //   It("заполнение нулями - положительные значения", function () {
    //     var n = 12345.6789;
    //     Assert.StrictEqual("{:0}" .format(n), "12345.6789"); // Если ширина не указана, нулями заполнять нечего
    //     Assert.StrictEqual("{:0f}".format(n), "12345.6789");
    //     Assert.StrictEqual("{:0n}".format(n), "12346");
    //     Assert.StrictEqual("{:0m}".format(n), "12345");

    //     Assert.StrictEqual("{:010}" .format(n), "12345.6789");
    //     Assert.StrictEqual("{:010f}".format(n), "12345.6789");
    //     Assert.StrictEqual("{:05n}" .format(n), "12346");
    //     Assert.StrictEqual("{:05m}" .format(n), "12345");

    //     Assert.StrictEqual("{:011}" .format(n), "012345.6789");
    //     Assert.StrictEqual("{:011f}".format(n), "012345.6789");
    //     Assert.StrictEqual("{:06n}" .format(n), "012346");
    //     Assert.StrictEqual("{:06m}" .format(n), "012345");

    //     Assert.StrictEqual("{:014}" .format(n), "000012345.6789");
    //     Assert.StrictEqual("{:014f}".format(n), "000012345.6789");
    //     Assert.StrictEqual("{:09n}" .format(n), "000012346");
    //     Assert.StrictEqual("{:09m}" .format(n), "000012345");
    //   });

    //   It("заполнение нулями - отрицательные значения", function () {
    //     var n = -12345.6789;
    //     Assert.StrictEqual("{:0}" .format(n), "-12345.6789"); // Если ширина не указана, нулями заполнять нечего
    //     Assert.StrictEqual("{:0f}".format(n), "-12345.6789");
    //     Assert.StrictEqual("{:0n}".format(n), "-12346");
    //     Assert.StrictEqual("{:0m}".format(n), "-12345");

    //     Assert.StrictEqual("{:011}" .format(n), "-12345.6789");
    //     Assert.StrictEqual("{:011f}".format(n), "-12345.6789");
    //     Assert.StrictEqual("{:06n}" .format(n), "-12346");
    //     Assert.StrictEqual("{:06m}" .format(n), "-12345");

    //     Assert.StrictEqual("{:012}" .format(n), "-012345.6789");
    //     Assert.StrictEqual("{:012f}".format(n), "-012345.6789");
    //     Assert.StrictEqual("{:07n}" .format(n), "-012346");
    //     Assert.StrictEqual("{:07m}" .format(n), "-012345");

    //     Assert.StrictEqual("{:015}" .format(n), "-000012345.6789");
    //     Assert.StrictEqual("{:015f}".format(n), "-000012345.6789");
    //     Assert.StrictEqual("{:010n}".format(n), "-000012346");
    //     Assert.StrictEqual("{:010m}".format(n), "-000012345");
    //   });

    //   It("разделение на тройки - положительные значения", function () {
    //     var n = 12345.6789;
    //     Assert.StrictEqual("{:#}" .format(n), "12'345.6789");
    //     Assert.StrictEqual("{:#f}".format(n), "12'345.6789");
    //     Assert.StrictEqual("{:#n}".format(n), "12'346");
    //     Assert.StrictEqual("{:#m}".format(n), "12'345");

    //     Assert.StrictEqual("{:#10}" .format(n), "**********");
    //     Assert.StrictEqual("{:#10f}".format(n), "**********");
    //     Assert.StrictEqual("{:#5n}" .format(n), "*****");
    //     Assert.StrictEqual("{:#5m}" .format(n), "*****");

    //     Assert.StrictEqual("{:#11}" .format(n), "12'345.6789");
    //     Assert.StrictEqual("{:#11f}".format(n), "12'345.6789");
    //     Assert.StrictEqual("{:#6n}" .format(n), "12'346");
    //     Assert.StrictEqual("{:#6m}" .format(n), "12'345");

    //     Assert.StrictEqual("{:#.4}" .format(n), "12'345.6789");
    //     Assert.StrictEqual("{:#.4n}".format(n), "12'345.6789");
    //     Assert.StrictEqual("{:#.4m}".format(n), "12'345.6789");

    //     Assert.StrictEqual("{:#11.4}" .format(n), "12'345.6789");
    //     Assert.StrictEqual("{:#11.4f}".format(n), "12'345.6789");
    //     Assert.StrictEqual("{:#11.4n}".format(n), "12'345.6789");
    //     Assert.StrictEqual("{:#11.4m}".format(n), "12'345.6789");

    //     Assert.StrictEqual("{:#012.4}" .format(n), "012'345.6789");
    //     Assert.StrictEqual("{:#012.4f}".format(n), "012'345.6789");
    //     Assert.StrictEqual("{:#012.4n}".format(n), "012'345.6789");
    //     Assert.StrictEqual("{:#012.4m}".format(n), "012'345.6789");

    //     Assert.StrictEqual("{:#013.4}" .format(n), " 012'345.6789");
    //     Assert.StrictEqual("{:#013.4f}".format(n), " 012'345.6789");
    //     Assert.StrictEqual("{:#013.4n}".format(n), " 012'345.6789");
    //     Assert.StrictEqual("{:#013.4m}".format(n), " 012'345.6789");

    //     Assert.StrictEqual("{:#014.4}" .format(n), "0'012'345.6789");
    //     Assert.StrictEqual("{:#014.4f}".format(n), "0'012'345.6789");
    //     Assert.StrictEqual("{:#014.4n}".format(n), "0'012'345.6789");
    //     Assert.StrictEqual("{:#014.4m}".format(n), "0'012'345.6789");
    //   });

    //   It("разделение на тройки - отрицательные значения", function () {
    //     var n = -12345.6789;
    //     Assert.StrictEqual("{:#}" .format(n), "-12'345.6789");
    //     Assert.StrictEqual("{:#f}".format(n), "-12'345.6789");
    //     Assert.StrictEqual("{:#n}".format(n), "-12'346");
    //     Assert.StrictEqual("{:#m}".format(n), "-12'345");

    //     Assert.StrictEqual("{:#11}" .format(n), "***********");
    //     Assert.StrictEqual("{:#11f}".format(n), "***********");
    //     Assert.StrictEqual("{:#6n}" .format(n), "******");
    //     Assert.StrictEqual("{:#6m}" .format(n), "******");

    //     Assert.StrictEqual("{:#12}" .format(n), "-12'345.6789");
    //     Assert.StrictEqual("{:#12f}".format(n), "-12'345.6789");
    //     Assert.StrictEqual("{:#7n}" .format(n), "-12'346");
    //     Assert.StrictEqual("{:#7m}" .format(n), "-12'345");

    //     Assert.StrictEqual("{:#.4}" .format(n), "-12'345.6789");
    //     Assert.StrictEqual("{:#.4f}".format(n), "-12'345.6789");
    //     Assert.StrictEqual("{:#.4n}".format(n), "-12'345.6789");
    //     Assert.StrictEqual("{:#.4m}".format(n), "-12'345.6789");

    //     Assert.StrictEqual("{:#12.4}" .format(n), "-12'345.6789");
    //     Assert.StrictEqual("{:#12.4f}".format(n), "-12'345.6789");
    //     Assert.StrictEqual("{:#12.4n}".format(n), "-12'345.6789");
    //     Assert.StrictEqual("{:#12.4m}".format(n), "-12'345.6789");

    //     Assert.StrictEqual("{:#013.4}" .format(n), "-012'345.6789");
    //     Assert.StrictEqual("{:#013.4f}".format(n), "-012'345.6789");
    //     Assert.StrictEqual("{:#013.4n}".format(n), "-012'345.6789");
    //     Assert.StrictEqual("{:#013.4m}".format(n), "-012'345.6789");

    //     Assert.StrictEqual("{:#014.4}" .format(n), " -012'345.6789");
    //     Assert.StrictEqual("{:#014.4f}".format(n), " -012'345.6789");
    //     Assert.StrictEqual("{:#014.4n}".format(n), " -012'345.6789");
    //     Assert.StrictEqual("{:#014.4m}".format(n), " -012'345.6789");

    //     Assert.StrictEqual("{:#015.4}" .format(n), "-0'012'345.6789");
    //     Assert.StrictEqual("{:#015.4f}".format(n), "-0'012'345.6789");
    //     Assert.StrictEqual("{:#015.4n}".format(n), "-0'012'345.6789");
    //     Assert.StrictEqual("{:#015.4m}".format(n), "-0'012'345.6789");
    //   });

    //   It("выравнивание и заполнение", function () {
    //     var n = 5;
    //     Assert.StrictEqual("{:6}"    .format(n), "     5"); // По умолчанию числа выравниваются по правой границе
    //     Assert.StrictEqual("{:6f}"   .format(n), "     5");
    //     Assert.StrictEqual("{:6n}"   .format(n), "     5");
    //     Assert.StrictEqual("{:6m}"   .format(n), "     5");

    //     Assert.StrictEqual("{:>6}"   .format(n), "     5");
    //     Assert.StrictEqual("{:>6f}"  .format(n), "     5");
    //     Assert.StrictEqual("{:>6n}"  .format(n), "     5");
    //     Assert.StrictEqual("{:>6m}"  .format(n), "     5");
    //     Assert.StrictEqual("{:.>6}"  .format(n), ".....5");
    //     Assert.StrictEqual("{:.>6f}" .format(n), ".....5");
    //     Assert.StrictEqual("{:.>6n}" .format(n), ".....5");
    //     Assert.StrictEqual("{:.>6m}" .format(n), ".....5");
    //     Assert.StrictEqual("{:.> 6}" .format(n), ".... 5");
    //     Assert.StrictEqual("{:.> 6f}".format(n), ".... 5");
    //     Assert.StrictEqual("{:.> 6n}".format(n), ".... 5");
    //     Assert.StrictEqual("{:.> 6m}".format(n), ".... 5");
    //     Assert.StrictEqual("{:.>+6}" .format(n), "....+5");
    //     Assert.StrictEqual("{:.>+6f}".format(n), "....+5");
    //     Assert.StrictEqual("{:.>+6n}".format(n), "....+5");
    //     Assert.StrictEqual("{:.>+6m}".format(n), "....+5");

    //     Assert.StrictEqual("{:<6}"   .format(n), "5     ");
    //     Assert.StrictEqual("{:<6f}"  .format(n), "5     ");
    //     Assert.StrictEqual("{:<6n}"  .format(n), "5     ");
    //     Assert.StrictEqual("{:<6m}"  .format(n), "5     ");
    //     Assert.StrictEqual("{:.<6}"  .format(n), "5.....");
    //     Assert.StrictEqual("{:.<6f}" .format(n), "5.....");
    //     Assert.StrictEqual("{:.<6n}" .format(n), "5.....");
    //     Assert.StrictEqual("{:.<6m}" .format(n), "5.....");
    //     Assert.StrictEqual("{:.< 6}" .format(n), " 5....");
    //     Assert.StrictEqual("{:.< 6f}".format(n), " 5....");
    //     Assert.StrictEqual("{:.< 6n}".format(n), " 5....");
    //     Assert.StrictEqual("{:.< 6m}".format(n), " 5....");
    //     Assert.StrictEqual("{:.<+6}" .format(n), "+5....");
    //     Assert.StrictEqual("{:.<+6f}".format(n), "+5....");
    //     Assert.StrictEqual("{:.<+6n}".format(n), "+5....");
    //     Assert.StrictEqual("{:.<+6m}".format(n), "+5....");

    //     Assert.StrictEqual("{:^6}"   .format(n), "  5   ");
    //     Assert.StrictEqual("{:^6f}"  .format(n), "  5   ");
    //     Assert.StrictEqual("{:^6n}"  .format(n), "  5   ");
    //     Assert.StrictEqual("{:^6m}"  .format(n), "  5   ");
    //     Assert.StrictEqual("{:.^6}"  .format(n), "..5...");
    //     Assert.StrictEqual("{:.^6f}" .format(n), "..5...");
    //     Assert.StrictEqual("{:.^6n}" .format(n), "..5...");
    //     Assert.StrictEqual("{:.^6m}" .format(n), "..5...");
    //     Assert.StrictEqual("{:.^ 6}" .format(n), ".. 5..");
    //     Assert.StrictEqual("{:.^ 6f}".format(n), ".. 5..");
    //     Assert.StrictEqual("{:.^ 6n}".format(n), ".. 5..");
    //     Assert.StrictEqual("{:.^ 6m}".format(n), ".. 5..");
    //     Assert.StrictEqual("{:.^+6}" .format(n), "..+5..");
    //     Assert.StrictEqual("{:.^+6f}".format(n), "..+5..");
    //     Assert.StrictEqual("{:.^+6n}".format(n), "..+5..");
    //     Assert.StrictEqual("{:.^+6m}".format(n), "..+5..");
    //   });

    //   It("f - отбрасывание нулей", function () {
    //     Assert.StrictEqual("{:f}".format(12345.6789), "12345.6789");
    //     Assert.StrictEqual("{:f}".format(12345.0009), "12345.0009");
    //     Assert.StrictEqual("{:f}".format(12345.6780), "12345.678");
    //     Assert.StrictEqual("{:f}".format(12345.0080), "12345.008");
    //     Assert.StrictEqual("{:f}".format(12345.6700), "12345.67");
    //     Assert.StrictEqual("{:f}".format(12345.0700), "12345.07");
    //     Assert.StrictEqual("{:f}".format(12345.6000), "12345.6");
    //     Assert.StrictEqual("{:f}".format(12345.0000), "12345");
    //     Assert.StrictEqual("{:f}".format(12340.0000), "12340");
    //     Assert.StrictEqual("{:f}".format(12300.0000), "12300");
    //     Assert.StrictEqual("{:f}".format(12000.0000), "12000");
    //     Assert.StrictEqual("{:f}".format(10000.0000), "10000");
    //   });
  });

  // Describe("Шестнадцатиричные числа (x,X)", function () {
  //   It("положительные значения", function () {
  //     var n = 0xabcde;
  //     Assert.StrictEqual("{:x}"    .format(n), "abcde");
  //     Assert.StrictEqual("{:X}"    .format(n), "ABCDE");
  //     Assert.StrictEqual("{:#x}"   .format(n), "0xabcde");
  //     Assert.StrictEqual("{:#X}"   .format(n), "0xABCDE");

  //     Assert.StrictEqual("{:x}"    .format(new Number(n)), "abcde");
  //     Assert.StrictEqual("{:X}"    .format(new Number(n)), "ABCDE");

  //     Assert.StrictEqual("{:-x}"   .format(n), "abcde");
  //     Assert.StrictEqual("{:-X}"   .format(n), "ABCDE");
  //     Assert.StrictEqual("{:-#x}"  .format(n), "0xabcde");
  //     Assert.StrictEqual("{:-#X}"  .format(n), "0xABCDE");

  //     Assert.StrictEqual("{: x}"   .format(n), " abcde");
  //     Assert.StrictEqual("{: X}"   .format(n), " ABCDE");
  //     Assert.StrictEqual("{: #x}"  .format(n), " 0xabcde");
  //     Assert.StrictEqual("{: #X}"  .format(n), " 0xABCDE");

  //     Assert.StrictEqual("{:+x}"   .format(n), "+abcde");
  //     Assert.StrictEqual("{:+X}"   .format(n), "+ABCDE");
  //     Assert.StrictEqual("{:+#x}"  .format(n), "+0xabcde");
  //     Assert.StrictEqual("{:+#X}"  .format(n), "+0xABCDE");

  //     Assert.StrictEqual("{:4x}"   .format(n), "****");
  //     Assert.StrictEqual("{:4X}"   .format(n), "****");
  //     Assert.StrictEqual("{:#6x}"  .format(n), "******");
  //     Assert.StrictEqual("{:#6X}"  .format(n), "******");

  //     Assert.StrictEqual("{:5x}"   .format(n), "abcde");
  //     Assert.StrictEqual("{:5X}"   .format(n), "ABCDE");
  //     Assert.StrictEqual("{:#7x}"  .format(n), "0xabcde");
  //     Assert.StrictEqual("{:#7X}"  .format(n), "0xABCDE");

  //     Assert.StrictEqual("{:8x}"   .format(n), "   abcde");
  //     Assert.StrictEqual("{:8X}"   .format(n), "   ABCDE");
  //     Assert.StrictEqual("{:#10x}" .format(n), "   0xabcde");
  //     Assert.StrictEqual("{:#10X}" .format(n), "   0xABCDE");

  //     Assert.StrictEqual("{:08x}"  .format(n), "000abcde");
  //     Assert.StrictEqual("{:08X}"  .format(n), "000ABCDE");
  //     Assert.StrictEqual("{:#010x}".format(n), "0x000abcde");
  //     Assert.StrictEqual("{:#010X}".format(n), "0x000ABCDE");
  //   });

  //   It("отрицательные значения", function () {
  //     var n = -0xabcde;
  //     Assert.StrictEqual("{:x}"    .format(n), "-abcde");
  //     Assert.StrictEqual("{:X}"    .format(n), "-ABCDE");
  //     Assert.StrictEqual("{:#x}"   .format(n), "-0xabcde");
  //     Assert.StrictEqual("{:#X}"   .format(n), "-0xABCDE");

  //     Assert.StrictEqual("{:-x}"   .format(n), "-abcde");
  //     Assert.StrictEqual("{:-X}"   .format(n), "-ABCDE");
  //     Assert.StrictEqual("{:-#x}"  .format(n), "-0xabcde");
  //     Assert.StrictEqual("{:-#X}"  .format(n), "-0xABCDE");

  //     Assert.StrictEqual("{: x}"   .format(n), "-abcde");
  //     Assert.StrictEqual("{: X}"   .format(n), "-ABCDE");
  //     Assert.StrictEqual("{: #x}"  .format(n), "-0xabcde");
  //     Assert.StrictEqual("{: #X}"  .format(n), "-0xABCDE");

  //     Assert.StrictEqual("{:+x}"   .format(n), "-abcde");
  //     Assert.StrictEqual("{:+X}"   .format(n), "-ABCDE");
  //     Assert.StrictEqual("{:+#x}"  .format(n), "-0xabcde");
  //     Assert.StrictEqual("{:+#X}"  .format(n), "-0xABCDE");

  //     Assert.StrictEqual("{:5x}"   .format(n), "*****");
  //     Assert.StrictEqual("{:5X}"   .format(n), "*****");
  //     Assert.StrictEqual("{:#7x}"  .format(n), "*******");
  //     Assert.StrictEqual("{:#7X}"  .format(n), "*******");

  //     Assert.StrictEqual("{:6x}"   .format(n), "-abcde");
  //     Assert.StrictEqual("{:6X}"   .format(n), "-ABCDE");
  //     Assert.StrictEqual("{:#8x}"  .format(n), "-0xabcde");
  //     Assert.StrictEqual("{:#8X}"  .format(n), "-0xABCDE");

  //     Assert.StrictEqual("{:9x}"   .format(n), "   -abcde");
  //     Assert.StrictEqual("{:9X}"   .format(n), "   -ABCDE");
  //     Assert.StrictEqual("{:#11x}" .format(n), "   -0xabcde");
  //     Assert.StrictEqual("{:#11X}" .format(n), "   -0xABCDE");

  //     Assert.StrictEqual("{:09x}"  .format(n), "-000abcde");
  //     Assert.StrictEqual("{:09X}"  .format(n), "-000ABCDE");
  //     Assert.StrictEqual("{:#011x}".format(n), "-0x000abcde");
  //     Assert.StrictEqual("{:#011X}".format(n), "-0x000ABCDE");
  //   });
  // });

  // Describe("Символы (c)", function () {
  //   It("в виде числа", function () {
  //     Assert.StrictEqual("{:c}".format(33), "!");
  //     Assert.StrictEqual("{:c}".format(new Number(33)), "!");
  //   });

  //   It("в виде строки", function () {
  //     Assert.StrictEqual("{:c}".format("asdf"), "a");
  //     Assert.StrictEqual("{:c}".format(new String("asdf")), "a");
  //   });

  //   It("неверный тип", function () {
  //     Assert.Throws( function () {
  //       "{:c}".format(true);
  //     }, "Неверное значение параметра для формата {:c}: ожидался символ или код символа, получено true");

  //     Assert.Throws( function () {
  //       "{:c}".format({});
  //     }, "Неверное значение параметра для формата {:c}: ожидался символ или код символа, получено {}");
  //   });

  //   It("ширина, выравнивание и заполнение", function () {
  //     var s = "abcde";
  //     Assert.StrictEqual("{:c}"   .format(s), "a");

  //     Assert.StrictEqual("{:4c}"  .format(s), "a   "); // Строки по-умолчанию выравниваются по левой границе
  //     Assert.StrictEqual("{:<4c}" .format(s), "a   ");
  //     Assert.StrictEqual("{:.<4c}".format(s), "a...");

  //     Assert.StrictEqual("{:>4c}" .format(s), "   a");
  //     Assert.StrictEqual("{:.>4c}".format(s), "...a");

  //     Assert.StrictEqual("{:^4c}" .format(s), " a  ");
  //     Assert.StrictEqual("{:.^4c}".format(s), ".a..");
  //   });
  // });

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

  //   It("размер", function () {
  //     var s = "abcdef";

  //     Assert.StrictEqual("{:.0}"  .format(s), "");
  //     Assert.StrictEqual("{:.0s}" .format(s), "");

  //     Assert.StrictEqual("{:.1}"  .format(s), "a");
  //     Assert.StrictEqual("{:.1s}" .format(s), "a");
  //     Assert.StrictEqual("{:#.1}" .format(s), "…");
  //     Assert.StrictEqual("{:#.1s}".format(s), "…");

  //     Assert.StrictEqual("{:.4}"  .format(s), "abcd");
  //     Assert.StrictEqual("{:.4s}" .format(s), "abcd");
  //     Assert.StrictEqual("{:#.4}" .format(s), "abc…");
  //     Assert.StrictEqual("{:#.4s}".format(s), "abc…");

  //     Assert.StrictEqual("{:.6}"  .format(s), "abcdef");
  //     Assert.StrictEqual("{:.6s}" .format(s), "abcdef");
  //     Assert.StrictEqual("{:#.6}" .format(s), "abcdef");
  //     Assert.StrictEqual("{:#.6s}".format(s), "abcdef");

  //     Assert.StrictEqual("{:.7}"  .format(s), "abcdef");
  //     Assert.StrictEqual("{:.7s}" .format(s), "abcdef");
  //     Assert.StrictEqual("{:#.7}" .format(s), "abcdef");
  //     Assert.StrictEqual("{:#.7s}".format(s), "abcdef");
  //   });

  //   It("ширина", function () {
  //     var s = "abcdef";

  //     Assert.StrictEqual("{:4}"  .format(s), "****");
  //     Assert.StrictEqual("{:4s}" .format(s), "****");

  //     Assert.StrictEqual("{:6}"  .format(s), "abcdef");
  //     Assert.StrictEqual("{:6s}" .format(s), "abcdef");

  //     Assert.StrictEqual("{:9}"  .format(s), "abcdef   "); // Строки по-умолчанию выравниваются по левой границе
  //     Assert.StrictEqual("{:9s}" .format(s), "abcdef   ");

  //     Assert.StrictEqual("{:6.4}"  .format(s), "abcd  ");
  //     Assert.StrictEqual("{:6.4s}" .format(s), "abcd  ");

  //     Assert.StrictEqual("{:#6.4}"  .format(s), "abc…  ");
  //     Assert.StrictEqual("{:#6.4s}" .format(s), "abc…  ");
  //   });

  //   It("выравнивание и заполнение", function () {
  //     var s = "abcdef";
  //     Assert.StrictEqual("{:<9}"  .format(s), "abcdef   ");
  //     Assert.StrictEqual("{:<9s}" .format(s), "abcdef   ");
  //     Assert.StrictEqual("{:.<9}" .format(s), "abcdef...");
  //     Assert.StrictEqual("{:.<9s}".format(s), "abcdef...");

  //     Assert.StrictEqual("{:>9}"  .format(s), "   abcdef");
  //     Assert.StrictEqual("{:>9s}" .format(s), "   abcdef");
  //     Assert.StrictEqual("{:.>9}" .format(s), "...abcdef");
  //     Assert.StrictEqual("{:.>9s}".format(s), "...abcdef");

  //     Assert.StrictEqual("{:^9}"  .format(s), " abcdef  ");
  //     Assert.StrictEqual("{:^9s}" .format(s), " abcdef  ");
  //     Assert.StrictEqual("{:.^9}" .format(s), ".abcdef..");
  //     Assert.StrictEqual("{:.^9s}".format(s), ".abcdef..");
  //   });
  // });

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

  // Describe("Несколько параметров", function () {
  //   It("нумерованные параметры", function () {
  //     Assert.StrictEqual("{0},{1},{2}".format(1, 2, 3), "1,2,3");
  //     Assert.StrictEqual("{1},{2},{0}".format(1, 2, 3), "2,3,1");
  //     Assert.StrictEqual("{2},{1},{0}".format(1, 2, 3), "3,2,1");
  //   });

  //   It("именованные параметры", function () {
  //     var params = {first: 1, second: 2, third: 3};
  //     Assert.StrictEqual("{first},{second},{third}".format(params), "1,2,3");
  //     Assert.StrictEqual("{second},{third},{first}".format(params), "2,3,1");
  //     Assert.StrictEqual("{third},{second},{first}".format(params), "3,2,1");
  //   });

  //   It("параметры с одинаковыми именами - вставляется первый встретившийся", function () {
  //     // Из одинаковых берётся первый попавшийся
  //     var params1 = {first: 1, second: 2, third: 3};
  //     var params2 = {first: 4, second: 5, third: 6};
  //     // 7, 8, 9 - для примера, что они не влияют
  //     Assert.StrictEqual("{first},{second},{third}".format(7, 8, 9, params1, params2), "1,2,3");
  //     Assert.StrictEqual("{second},{third},{first}".format(7, 8, 9, params1, params2), "2,3,1");
  //     Assert.StrictEqual("{third},{second},{first}".format(7, 8, 9, params1, params2), "3,2,1");
  //     Assert.StrictEqual("{first},{second},{third}".format(params2, 7, 8, 9, params1), "4,5,6");
  //     Assert.StrictEqual("{second},{third},{first}".format(params2, 7, 8, 9, params1), "5,6,4");
  //     Assert.StrictEqual("{third},{second},{first}".format(params2, 7, 8, 9, params1), "6,5,4");
  //   });

  //   It("нестандартные символы", function () {
  //     var params = {"русские буквы и пробел": 1, "L'amour": 2, "25\"30'": 3};
  //     Assert.StrictEqual(
  //       "{'русские буквы и пробел'},{'L''amour'},{\"L'amour\"},{\"25\"\"30'\"},{'25\"30'''}".format(params)
  //       , "1,2,2,3,3");
  //     Assert.StrictEqual(
  //       "{'L''amour'},{\"L'amour\"},{\"25\"\"30'\"},{'25\"30'''},{'русские буквы и пробел'}".format(params)
  //       , "2,2,3,3,1");
  //     Assert.StrictEqual(
  //       "{\"25\"\"30'\"},{'25\"30'''},{'L''amour'},{\"L'amour\"},{'русские буквы и пробел'}".format(params)
  //       , "3,3,2,2,1");
  //   });

  //   It("порядковые параметры вместе с нумерованными - выбирается следующий после нумерованного", function () {
  //     Assert.StrictEqual("{0},{},{};{1},{},{};{2},{},{}".format(1, 2, 3, 4), "1,2,3;2,3,4;3,4,undefined");
  //     Assert.StrictEqual("{2},{},{};{1},{},{};{0},{},{}".format(1, 2, 3, 4), "3,4,undefined;2,3,4;1,2,3");
  //   });

  //   It("порядковые параметры вместе с именованными - именованные не влияют", function () {
  //     var params = {first: "first", second: "second", third: "third"}
  //     Assert.StrictEqual("{first},{},{},{};{second},{},{};{third},{}".format(1, 2, 3, 4, 5, 6, params), "first,1,2,3;second,4,5;third,6");
  //   });
  // });
}
