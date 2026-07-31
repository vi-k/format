import 'package:format/format.dart';
import 'package:intl/intl.dart';
import 'package:test/test.dart';

void main() {
  group('Common use:', () {
    //setUp(() );
    test('escaping', () {
      expect(format('{{0}}->{0}', [9]), '{0}->9');
    });

    test('auto and manual numeration of arguments', () {
      expect(format('{0} {} {} {5} {}', [0, 1, 2, 3, 4, 5, 6]), '0 1 2 5 6');
    });

    test('positional arguments', () {
      const positionalArgs = [1, 2, 3];

      expect(format('{} {} {}', positionalArgs), '1 2 3');
      expect(format('{2} {1} {0}', positionalArgs), '3 2 1');
      expect(format('{} {} {} {0} {} {}', positionalArgs), '1 2 3 1 2 3');
      expect(
        () => format('{2} {}', positionalArgs),
        throwsA(isA<FormattingException>()),
      );
      // expect(
      //   () => formatNamed('{}', <String, Object?>{}),
      //   throwsA(
      //     predicate(
      //       (e) =>
      //           e is ArgumentError &&
      //           e.message == '{} Positional args is missing.',
      //     ),
      //   ),
      // );
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
        "'key in single quotes'": 10,
      };

      expect(
        formatNamed(
          '{test_1} {тест_2} {テスト_3} {"hello world"} {_} {_0}',
          namedArgs,
        ),
        '1 2 3 4 5 6',
      );
      expect(formatNamed('{"+"}', namedArgs), '8');
      expect(
        formatNamed(
          '{"""key in double quotes"""} {"\'key in single quotes\'"}',
          namedArgs,
        ),
        '9 10',
      );
      expect(
        formatNamed(
          "{'\"key in double quotes\"'} {'''key in single quotes'''}",
          namedArgs,
        ),
        '9 10',
      );
      expect(
        formatNamed(
          '{"""key in double quotes"""} '
          "{'''key in single quotes'''}",
          namedArgs,
        ),
        '9 10',
      );

      expect(
        () => format('{a}', <Object?>[]),
        throwsA(isA<FormattingException>()),
      );
      expect(
        () => formatNamed('{a}', namedArgs),
        throwsA(isA<FormattingException>()),
      );
    });

    test('fill and align', () {
      const s = 'hello';

      expect(format('{:0}', [s]), 'hello');

      expect(format('{:9}', [s]), 'hello    ');
      expect(format('{:<9}', [s]), 'hello    ');
      expect(format('{:>9}', [s]), '    hello');
      expect(format('{:^9}', [s]), '  hello  ');
      expect(format('{:^10}', [s]), '  hello   ');

      expect(format('{:*<9}', [s]), 'hello****');
      expect(format('{:*>9}', [s]), '****hello');
      expect(format('{:*^9}', [s]), '**hello**');
      expect(format('{:*^10}', [s]), '**hello***');

      expect(format('{:👨<9}', [s]), 'hello👨👨👨👨');
      expect(format('{:👨>9}', [s]), '👨👨👨👨hello');
      expect(format('{:👨^9}', [s]), '👨👨hello👨👨');

      expect(
        format('{:👨‍👩‍👦‍👧<9}', [s]),
        'hello👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧',
      );
      expect(
        format('{:👨‍👩‍👦‍👧>9}', [s]),
        '👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧hello',
      );
      expect(
        format('{:👨‍👩‍👦‍👧^9}', [s]),
        '👨‍👩‍👦‍👧👨‍👩‍👦‍👧hello👨‍👩‍👦‍👧👨‍👩‍👦‍👧',
      );

      expect(format('{:a\u{0308}<9}', [s]), 'helloääää');
      expect(format('{:a\u{0308}>9}', [s]), 'äääähello');
      expect(format('{:a\u{0308}^9}', [s]), 'äähelloää');

      expect(
        format('{:(any symbols)<9}', [s]),
        'hello(any symbols)(any symbols)(any symbols)(any symbols)',
      );
      expect(
        format('{:(any symbols)>9}', [s]),
        '(any symbols)(any symbols)(any symbols)(any symbols)hello',
      );
      expect(
        format('{:(any symbols)^9}', [s]),
        '(any symbols)(any symbols)hello(any symbols)(any symbols)',
      );

      expect(format('{:<^><9}', [s]), 'hello<^><^><^><^>');
      expect(format('{:<^>>9}', [s]), '<^><^><^><^>hello');
      expect(format('{:<^>^9}', [s]), '<^><^>hello<^><^>');
    });
  });

  group('Format specifier', () {
    group('c:', () {
      test('basic use', () {
        expect(
          () => format('{:c}', ['a']),
          throwsA(isA<FormattingException>()),
        );
        expect(format('{:c}', [65]), 'A');
      });

      test('surrogate pairs', () {
        expect(
          format('{:c}+{:c}+{:c}+{:c}={:c}{:c}{:c}{:c}{:c}{:c}{:c}', [
            0x1F468,
            0x1F469,
            0x1F467,
            0x1F466,
            0x1F468,
            0x200D,
            0x1F469,
            0x200D,
            0x1F467,
            0x200D,
            0x1F466,
          ]),
          '👨+👩+👧+👦=👨‍👩‍👧‍👦',
        );
        expect(
          format('{:c}+{:c}+{:c}+{:c}={:c}', [
            0x1F468,
            0x1F469,
            0x1F467,
            0x1F466,
            [0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F467, 0x200D, 0x1F466],
          ]),
          '👨+👩+👧+👦=👨‍👩‍👧‍👦',
        );
        expect(
          format('{:c}={:c}', [
            [0x1F468, 0x2B, 0x1F469, 0x2B, 0x1F467, 0x2B, 0x1F466],
            [0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F467, 0x200D, 0x1F466],
          ]),
          '👨+👩+👧+👦=👨‍👩‍👧‍👦',
        );
      });

      test('width, align and fill', () {
        const c = 65;
        expect(format('{:4c}', [c]), 'A   ');
        expect(format('{:>4c}', [c]), '   A');
        expect(format('{:^4c}', [c]), ' A  ');
        expect(format('{:<4c}', [c]), 'A   ');

        expect(format('{:*>4c}', [c]), '***A');
        expect(format('{:*^4c}', [c]), '*A**');
        expect(format('{:*<4c}', [c]), 'A***');

        expect(format('{:*>4.0c}', [c]), '****');
        expect(format('{:*^4.0c}', [c]), '****');
        expect(format('{:*<4.0c}', [c]), '****');

        expect(format('{:*>4.1c}', [c]), '***A');
        expect(format('{:*^4.1c}', [c]), '*A**');
        expect(format('{:*<4.1c}', [c]), 'A***');

        expect(format('{:*>4.2c}', [c]), '***A');
        expect(format('{:*^4.2c}', [c]), '*A**');
        expect(format('{:*<4.2c}', [c]), 'A***');

        const c2 = [0xD83C, 0xDDFA, 0xD83C, 0xDDE6];

        expect(format('{:5c}', [c2]), '🇺🇦    ');
        expect(format('{:>5c}', [c2]), '    🇺🇦');
        expect(format('{:^5c}', [c2]), '  🇺🇦  ');
        expect(format('{:<5c}', [c2]), '🇺🇦    ');

        expect(format('{:🙏>5c}', [c2]), '🙏🙏🙏🙏🇺🇦');
        expect(format('{:🙏^5c}', [c2]), '🙏🙏🇺🇦🙏🙏');
        expect(format('{:🙏<5c}', [c2]), '🇺🇦🙏🙏🙏🙏');

        expect(format('{:🙏>5.0c}', [c2]), '🙏🙏🙏🙏🙏');
        expect(format('{:🙏^5.0c}', [c2]), '🙏🙏🙏🙏🙏');
        expect(format('{:🙏<5.0c}', [c2]), '🙏🙏🙏🙏🙏');

        expect(format('{:🙏>5.1c}', [c2]), '🙏🙏🙏🙏🇺🇦');
        expect(format('{:🙏^5.1c}', [c2]), '🙏🙏🇺🇦🙏🙏');
        expect(format('{:🙏<5.1c}', [c2]), '🇺🇦🙏🙏🙏🙏');

        expect(format('{:🙏>5.2c}', [c2]), '🙏🙏🙏🙏🇺🇦');
        expect(format('{:🙏^5.2c}', [c2]), '🙏🙏🇺🇦🙏🙏');
        expect(format('{:🙏<5.2c}', [c2]), '🇺🇦🙏🙏🙏🙏');
      });
    });

    group('s:', () {
      const s = 'Hello world';
      const s2 = '👨+👩+👧+👦=👨‍👩‍👧‍👦';

      test('basic use', () {
        expect(
          () => format('{:s}', [123]),
          throwsA(isA<FormattingException>()),
        );

        expect(format('{}', [s]), 'Hello world');
        expect(format('{:s}', [s]), 'Hello world');
      });

      test('precision', () {
        expect(format('{:.11s}', [s]), 'Hello world');
        expect(format('{:.20s}', [s]), 'Hello world');
        expect(format('{:.5s}', [s]), 'Hello');
        expect(format('{:#.5s}', [s]), 'Hell…');
        expect(format('{:#.6s}', [s]), 'Hello…');
        expect(format('{:#.7s}', [s]), 'Hello…');
        expect(format('{:#.8s}', [s]), 'Hello w…');

        expect(format('{:.1s}', [s2]), '👨');
        expect(format('{:.3s}', [s2]), '👨+👩');
        expect(format('{:.5s}', [s2]), '👨+👩+👧');
        expect(format('{:.7s}', [s2]), '👨+👩+👧+👦');
        expect(format('{:.9s}', [s2]), '👨+👩+👧+👦=👨‍👩‍👧‍👦');

        expect(format('{:#.2s}', [s2]), '👨…');
        expect(format('{:#.4s}', [s2]), '👨+👩…');
        expect(format('{:#.6s}', [s2]), '👨+👩+👧…');
        expect(format('{:#.8s}', [s2]), '👨+👩+👧+👦…');
        expect(format('{:#.10s}', [s2]), '👨+👩+👧+👦=👨‍👩‍👧‍👦');
      });

      test('width, align and fill', () {
        expect(format('{:16s}', [s]), 'Hello world     ');
        expect(format('{:>16s}', [s]), '     Hello world');
        expect(format('{:^16s}', [s]), '  Hello world   ');
        expect(format('{:<16s}', [s]), 'Hello world     ');

        expect(format('{:*>16s}', [s]), '*****Hello world');
        expect(format('{:*^16s}', [s]), '**Hello world***');
        expect(format('{:*<16s}', [s]), 'Hello world*****');

        expect(format('{:*>16.0s}', [s]), '****************');
        expect(format('{:*^16.0s}', [s]), '****************');
        expect(format('{:*<16.0s}', [s]), '****************');

        expect(format('{:*>16.5s}', [s]), '***********Hello');
        expect(format('{:*^16.5s}', [s]), '*****Hello******');
        expect(format('{:*<16.5s}', [s]), 'Hello***********');

        expect(format('{:*>#16.6s}', [s]), '**********Hello…');
        expect(format('{:*^#16.6s}', [s]), '*****Hello…*****');
        expect(format('{:*<#16.6s}', [s]), 'Hello…**********');

        expect(format('{:15s}', [s2]), '👨+👩+👧+👦=👨‍👩‍👧‍👦      ');
        expect(format('{:>15s}', [s2]), '      👨+👩+👧+👦=👨‍👩‍👧‍👦');
        expect(format('{:^15s}', [s2]), '   👨+👩+👧+👦=👨‍👩‍👧‍👦   ');
        expect(format('{:<15s}', [s2]), '👨+👩+👧+👦=👨‍👩‍👧‍👦      ');

        expect(
          format('{:💜>15s}', [s2]),
          '💜💜💜💜💜💜👨+👩+👧+👦=👨‍👩‍👧‍👦',
        );
        expect(
          format('{:💜^15s}', [s2]),
          '💜💜💜👨+👩+👧+👦=👨‍👩‍👧‍👦💜💜💜',
        );
        expect(
          format('{:💜<15s}', [s2]),
          '👨+👩+👧+👦=👨‍👩‍👧‍👦💜💜💜💜💜💜',
        );

        expect(format('{:❓>15.0s}', [s2]), '❓❓❓❓❓❓❓❓❓❓❓❓❓❓❓');
        expect(format('{:❓^15.0s}', [s2]), '❓❓❓❓❓❓❓❓❓❓❓❓❓❓❓');
        expect(format('{:❓<15.0s}', [s2]), '❓❓❓❓❓❓❓❓❓❓❓❓❓❓❓');

        expect(format('{:💚>15.7s}', [s2]), '💚💚💚💚💚💚💚💚👨+👩+👧+👦');
        expect(format('{:💚^15.7s}', [s2]), '💚💚💚💚👨+👩+👧+👦💚💚💚💚');
        expect(format('{:💚<15.7s}', [s2]), '👨+👩+👧+👦💚💚💚💚💚💚💚💚');

        expect(format('{:🩵>#15.8s}', [s2]), '🩵🩵🩵🩵🩵🩵🩵👨+👩+👧+👦…');
        expect(format('{:🩵^#15.8s}', [s2]), '🩵🩵🩵👨+👩+👧+👦…🩵🩵🩵🩵');
        expect(format('{:🩵<#15.8s}', [s2]), '👨+👩+👧+👦…🩵🩵🩵🩵🩵🩵🩵');

        expect(format('{:0>4}', ['5']), '0005');
        expect(format('{:0<4}', ['5']), '5000');
        expect(format('{:04}', ['5']), '5000');
      });
    });

    group('b:', () {
      const n = 0xAA;

      test('basic use', () {
        expect(
          () => format('{:b}', [123.0]),
          throwsA(isA<FormattingException>()),
        );

        expect(format('{:b}', [n]), '10101010');
        expect(format('{:b}', [-n]), '-10101010');

        expect(
          format('{:b}', [9223372036854775807]),
          '111111111111111111111111111111111111111111111111111111111111111',
        );
        expect(
          format('{:b}', [-9223372036854775807]),
          '-111111111111111111111111111111111111111111111111111111111111111',
        );
        expect(
          format('{:b}', [-9223372036854775808]),
          '-1000000000000000000000000000000000000000000000000000000000000000',
        );
      });

      test('sign', () {
        expect(format('{:+b}', [n]), '+10101010');
        expect(format('{:-b}', [n]), '10101010');
        expect(format('{: b}', [n]), ' 10101010');
        expect(format('{:+b}', [-n]), '-10101010');
        expect(format('{:-b}', [-n]), '-10101010');
        expect(format('{: b}', [-n]), '-10101010');
      });

      test('align', () {
        expect(format('{:12b}', [n]), '    10101010');
        expect(format('{:12b}', [-n]), '   -10101010');
      });

      test('zero', () {
        expect(format('{:0b}', [n]), '10101010');
        expect(format('{:012b}', [n]), '000010101010');
        expect(format('{:012b}', [-n]), '-00010101010');
        // zero flag is ignored
        expect(format('{:@>012b}', [n]), '@@@@10101010');
        expect(format('{:@>012b}', [-n]), '@@@-10101010');
      });

      test('group', () {
        expect(format('{:_b}', [n]), '1010_1010');
        expect(format('{:14_b}', [n]), '     1010_1010');
        expect(format('{:014_b}', [n]), '0000_1010_1010');
        expect(format('{:015_b}', [n]), '0_0000_1010_1010');
        expect(format('{:016_b}', [n]), '0_0000_1010_1010');

        expect(format('{:_b}', [-n]), '-1010_1010');
        expect(format('{:14_b}', [-n]), '    -1010_1010');
        expect(format('{:014_b}', [-n]), '-000_1010_1010');
        expect(format('{:015_b}', [-n]), '-0000_1010_1010');
        expect(format('{:016_b}', [-n]), '-0_0000_1010_1010');

        // zero flag is ignored
        expect(format('{:@>016_b}', [n]), '@@@@@@@1010_1010');
        expect(format('{:@>016_b}', [-n]), '@@@@@@-1010_1010');

        expect(() => format('{:,b}', [n]), throwsA(isA<FormattingException>()));
      });

      test('alt', () {
        expect(() => format('{:#b}', [n]), throwsA(isA<FormattingException>()));
      });

      test('precision', () {
        expect(
          () => format('{:.2b}', [n]),
          throwsA(isA<FormattingException>()),
        );
      });
    });

    group('o:', () {
      const n = 2739128;

      test('basic use', () {
        expect(
          () => format('{:o}', [123.0]),
          throwsA(isA<FormattingException>()),
        );

        expect(format('{:o}', [n]), '12345670');
        expect(format('{:o}', [-n]), '-12345670');

        expect(format('{:o}', [9223372036854775807]), '777777777777777777777');
        expect(
          format('{:o}', [-9223372036854775807]),
          '-777777777777777777777',
        );
        expect(
          format('{:o}', [-9223372036854775808]),
          '-1000000000000000000000',
        );
      });

      test('sign', () {
        expect(format('{:+o}', [n]), '+12345670');
        expect(format('{:-o}', [n]), '12345670');
        expect(format('{: o}', [n]), ' 12345670');
        expect(format('{:+o}', [-n]), '-12345670');
        expect(format('{:-o}', [-n]), '-12345670');
        expect(format('{: o}', [-n]), '-12345670');
      });

      test('align', () {
        expect(format('{:12o}', [n]), '    12345670');
        expect(format('{:12o}', [-n]), '   -12345670');
      });

      test('zero', () {
        expect(format('{:0o}', [n]), '12345670');
        expect(format('{:012o}', [n]), '000012345670');
        expect(format('{:012o}', [-n]), '-00012345670');
        // zero flag is ignored
        expect(format('{:@>012o}', [n]), '@@@@12345670');
        expect(format('{:@>012o}', [-n]), '@@@-12345670');
      });

      test('group', () {
        expect(format('{:_o}', [n]), '1234_5670');
        expect(format('{:14_o}', [n]), '     1234_5670');
        expect(format('{:014_o}', [n]), '0000_1234_5670');
        expect(format('{:015_o}', [n]), '0_0000_1234_5670');
        expect(format('{:016_o}', [n]), '0_0000_1234_5670');

        expect(format('{:_o}', [-n]), '-1234_5670');
        expect(format('{:14_o}', [-n]), '    -1234_5670');
        expect(format('{:014_o}', [-n]), '-000_1234_5670');
        expect(format('{:015_o}', [-n]), '-0000_1234_5670');
        expect(format('{:016_o}', [-n]), '-0_0000_1234_5670');

        // zero flag is ignored
        expect(format('{:@>016_o}', [n]), '@@@@@@@1234_5670');
        expect(format('{:@>016_o}', [-n]), '@@@@@@-1234_5670');

        expect(() => format('{:,o}', [n]), throwsA(isA<FormattingException>()));
      });

      test('alt', () {
        expect(() => format('{:#o}', [n]), throwsA(isA<FormattingException>()));
      });

      test('precision', () {
        expect(
          () => format('{:.2o}', [n]),
          throwsA(isA<FormattingException>()),
        );
      });
    });

    group('x:', () {
      const n = 0x12ABCDEF;

      test('basic use', () {
        expect(
          () => format('{:x}', [123.0]),
          throwsA(isA<FormattingException>()),
        );

        expect(format('{:x}', [n]), '12abcdef');
        expect(format('{:x}', [-n]), '-12abcdef');

        expect(format('{:x}', [9223372036854775807]), '7fffffffffffffff');
        expect(format('{:x}', [-9223372036854775807]), '-7fffffffffffffff');
        expect(format('{:x}', [-9223372036854775808]), '-8000000000000000');
      });

      test('sign', () {
        expect(format('{:+x}', [n]), '+12abcdef');
        expect(format('{:-x}', [n]), '12abcdef');
        expect(format('{: x}', [n]), ' 12abcdef');
        expect(format('{:+x}', [-n]), '-12abcdef');
        expect(format('{:-x}', [-n]), '-12abcdef');
        expect(format('{: x}', [-n]), '-12abcdef');
      });

      test('align', () {
        expect(format('{:12x}', [n]), '    12abcdef');
        expect(format('{:12x}', [-n]), '   -12abcdef');
      });

      test('zero', () {
        expect(format('{:0x}', [n]), '12abcdef');
        expect(format('{:012x}', [n]), '000012abcdef');
        expect(format('{:012x}', [-n]), '-00012abcdef');
        // zero flag is ignored
        expect(format('{:@>012x}', [n]), '@@@@12abcdef');
      });

      test('group', () {
        expect(format('{:_x}', [n]), '12ab_cdef');
        expect(format('{:14_x}', [n]), '     12ab_cdef');
        expect(format('{:014_x}', [n]), '0000_12ab_cdef');
        expect(format('{:015_x}', [n]), '0_0000_12ab_cdef');
        expect(format('{:016_x}', [n]), '0_0000_12ab_cdef');

        expect(format('{:_x}', [-n]), '-12ab_cdef');
        expect(format('{:14_x}', [-n]), '    -12ab_cdef');
        expect(format('{:014_x}', [-n]), '-000_12ab_cdef');
        expect(format('{:015_x}', [-n]), '-0000_12ab_cdef');
        expect(format('{:016_x}', [-n]), '-0_0000_12ab_cdef');

        // zero flag is ignored
        expect(format('{:@>016_x}', [n]), '@@@@@@@12ab_cdef');
        expect(format('{:@>016_x}', [-n]), '@@@@@@-12ab_cdef');

        expect(() => format('{:,x}', [n]), throwsA(isA<FormattingException>()));
      });

      test('alt', () {
        expect(format('{:#x}', [n]), '0x12abcdef');
        expect(format('{:#14x}', [n]), '    0x12abcdef');
        expect(format('{:#014x}', [n]), '0x000012abcdef');
        expect(format('{:#_x}', [n]), '0x12ab_cdef');
        expect(format('{:#12_x}', [n]), ' 0x12ab_cdef');
        expect(format('{:#012_x}', [n]), '0x0_12ab_cdef');
        expect(format('{:#013_x}', [n]), '0x0_12ab_cdef');

        expect(format('{:#x}', [-n]), '-0x12abcdef');
        expect(format('{:#14x}', [-n]), '   -0x12abcdef');
        expect(format('{:#014x}', [-n]), '-0x00012abcdef');
        expect(format('{:#_x}', [-n]), '-0x12ab_cdef');
        expect(format('{:#13_x}', [-n]), ' -0x12ab_cdef');
        expect(format('{:#013_x}', [-n]), '-0x0_12ab_cdef');
        expect(format('{:#014_x}', [-n]), '-0x0_12ab_cdef');
      });

      test('precision', () {
        expect(
          () => format('{:.2x}', [n]),
          throwsA(isA<FormattingException>()),
        );
      });
    });

    group('X:', () {
      const n = 0x12ABCDEF;

      test('basic use', () {
        expect(
          () => format('{:X}', [123.0]),
          throwsA(isA<FormattingException>()),
        );

        expect(format('{:X}', [n]), '12ABCDEF');
        expect(format('{:X}', [n]), '12ABCDEF');

        expect(format('{:X}', [9223372036854775807]), '7FFFFFFFFFFFFFFF');
        expect(format('{:X}', [-9223372036854775807]), '-7FFFFFFFFFFFFFFF');
        expect(format('{:X}', [-9223372036854775808]), '-8000000000000000');
      });

      test('sign', () {
        expect(format('{:+X}', [n]), '+12ABCDEF');
        expect(format('{:-X}', [n]), '12ABCDEF');
        expect(format('{: X}', [n]), ' 12ABCDEF');
        expect(format('{:+X}', [-n]), '-12ABCDEF');
        expect(format('{:-X}', [-n]), '-12ABCDEF');
        expect(format('{: X}', [-n]), '-12ABCDEF');
      });

      test('align', () {
        expect(format('{:12X}', [n]), '    12ABCDEF');
      });

      test('zero', () {
        expect(format('{:0X}', [n]), '12ABCDEF');
        expect(format('{:012X}', [n]), '000012ABCDEF');
        // zero flag is ignored
        expect(format('{:@>012X}', [n]), '@@@@12ABCDEF');
      });

      test('group', () {
        expect(format('{:_X}', [n]), '12AB_CDEF');
        expect(format('{:14_X}', [n]), '     12AB_CDEF');
        expect(format('{:014_X}', [n]), '0000_12AB_CDEF');
        expect(format('{:015_X}', [n]), '0_0000_12AB_CDEF');
        expect(format('{:016_X}', [n]), '0_0000_12AB_CDEF');
        // zero flag is ignored
        expect(format('{:@>016_X}', [n]), '@@@@@@@12AB_CDEF');

        expect(() => format('{:,X}', [n]), throwsA(isA<FormattingException>()));
      });

      test('alt', () {
        expect(format('{:#X}', [n]), '0x12ABCDEF');
        expect(format('{:#_X}', [n]), '0x12AB_CDEF');
      });

      test('precision', () {
        expect(
          () => format('{:.2X}', [n]),
          throwsA(isA<FormattingException>()),
        );
      });
    });

    group('d:', () {
      group('int', () {
        const n = 123456789;

        test('basic use', () {
          expect(
            () => format('{:d}', [123.0]),
            throwsA(isA<FormattingException>()),
          );

          expect(format('{}', [n]), '123456789');
          expect(format('{:d}', [n]), '123456789');

          expect(format('{}', [9223372036854775807]), '9223372036854775807');
          expect(format('{}', [-9223372036854775807]), '-9223372036854775807');
          expect(format('{}', [-9223372036854775808]), '-9223372036854775808');
        });

        test('sign', () {
          expect(format('{:+d}', [n]), '+123456789');
          expect(format('{:-d}', [n]), '123456789');
          expect(format('{: d}', [n]), ' 123456789');
          expect(format('{:+d}', [-n]), '-123456789');
          expect(format('{:-d}', [-n]), '-123456789');
          expect(format('{: d}', [-n]), '-123456789');
        });

        test('align', () {
          expect(format('{:13d}', [n]), '    123456789');
        });

        test('zero', () {
          expect(format('{:0d}', [n]), '123456789');
          expect(format('{:013d}', [n]), '0000123456789');
          // zero flag is ignored
          expect(format('{:@>013d}', [n]), '@@@@123456789');
        });

        test('group', () {
          expect(format('{:,d}', [n]), '123,456,789');
          expect(format('{:_d}', [n]), '123_456_789');
          expect(format('{:15,d}', [n]), '    123,456,789');
          expect(format('{:15_d}', [n]), '    123_456_789');
          expect(format('{:015,d}', [n]), '000,123,456,789');
          expect(format('{:015_d}', [n]), '000_123_456_789');
          expect(format('{:016,d}', [n]), '0,000,123,456,789');
          expect(format('{:017,d}', [n]), '0,000,123,456,789');

          // zero flag is ignored
          expect(format('{:@>017,d}', [n]), '@@@@@@123,456,789');
        });

        test('alt', () {
          expect(
            () => format('{:#d}', [n]),
            throwsA(isA<FormattingException>()),
          );
        });

        test('precision', () {
          expect(
            () => format('{:.2}', [n]),
            throwsA(isA<FormattingException>()),
          );

          expect(
            () => format('{:.2d}', [n]),
            throwsA(isA<FormattingException>()),
          );
        });
      });

      group('BigInt', () {
        final n = BigInt.from(123456789);

        test('basic use', () {
          expect(format('{}', [n]), '123456789');
          expect(format('{:d}', [n]), '123456789');

          expect(
            format('{}', [BigInt.from(9223372036854775807)]),
            '9223372036854775807',
          );
          expect(
            format('{}', [BigInt.from(-9223372036854775807)]),
            '-9223372036854775807',
          );
          expect(
            format('{}', [BigInt.from(-9223372036854775808)]),
            '-9223372036854775808',
          );
        });

        test('sign', () {
          expect(format('{:+d}', [n]), '+123456789');
          expect(format('{:-d}', [n]), '123456789');
          expect(format('{: d}', [n]), ' 123456789');
          expect(format('{:+d}', [-n]), '-123456789');
          expect(format('{:-d}', [-n]), '-123456789');
          expect(format('{: d}', [-n]), '-123456789');
        });

        test('align', () {
          expect(format('{:13d}', [n]), '    123456789');
        });

        test('zero', () {
          expect(format('{:0d}', [n]), '123456789');
          expect(format('{:013d}', [n]), '0000123456789');
          // zero flag is ignored
          expect(format('{:@>013d}', [n]), '@@@@123456789');
        });

        test('group', () {
          expect(format('{:,d}', [n]), '123,456,789');
          expect(format('{:_d}', [n]), '123_456_789');
          expect(format('{:15,d}', [n]), '    123,456,789');
          expect(format('{:15_d}', [n]), '    123_456_789');
          expect(format('{:015,d}', [n]), '000,123,456,789');
          expect(format('{:015_d}', [n]), '000_123_456_789');
          expect(format('{:016,d}', [n]), '0,000,123,456,789');
          expect(format('{:017,d}', [n]), '0,000,123,456,789');

          // zero flag is ignored
          expect(format('{:@>017,d}', [n]), '@@@@@@123,456,789');
        });

        test('alt', () {
          expect(
            () => format('{:#d}', [n]),
            throwsA(isA<FormattingException>()),
          );
        });

        test('precision', () {
          expect(
            () => format('{:.2}', [n]),
            throwsA(isA<FormattingException>()),
          );

          expect(
            () => format('{:.2d}', [n]),
            throwsA(isA<FormattingException>()),
          );
        });
      });
    });

    group('f:', () {
      const n = 12345.6789;

      test('basic use', () {
        expect(
          () => format('{:f}', [123]),
          throwsA(isA<FormattingException>()),
        );

        expect(format('{:f}', [n]), '12345.678900');
        expect(format('{:f}', [-n]), '-12345.678900');
      });

      test('sign', () {
        expect(format('{:+f}', [n]), '+12345.678900');
        expect(format('{:-f}', [n]), '12345.678900');
        expect(format('{: f}', [n]), ' 12345.678900');
        expect(format('{:+f}', [-n]), '-12345.678900');
        expect(format('{:-f}', [-n]), '-12345.678900');
        expect(format('{: f}', [-n]), '-12345.678900');
      });

      test('align', () {
        expect(format('{:16f}', [n]), '    12345.678900');
      });

      test('zero', () {
        expect(format('{:0f}', [n]), '12345.678900');
        expect(format('{:016f}', [n]), '000012345.678900');
        expect(format('{:0f}', [-n]), '-12345.678900');
        expect(format('{:016f}', [-n]), '-00012345.678900');

        // zero flag is ignored
        expect(format('{:@>016f}', [n]), '@@@@12345.678900');
        expect(format('{:@>016f}', [-n]), '@@@-12345.678900');
      });

      test('group', () {
        expect(format('{:,f}', [n]), '12,345.678900');
        expect(format('{:_f}', [n]), '12_345.678900');
        expect(format('{:18,f}', [n]), '     12,345.678900');
        expect(format('{:18_f}', [n]), '     12_345.678900');
        expect(format('{:018,f}', [n]), '000,012,345.678900');
        expect(format('{:018_f}', [n]), '000_012_345.678900');
        expect(format('{:019,f}', [n]), '0,000,012,345.678900');
        expect(format('{:019_f}', [n]), '0_000_012_345.678900');
        expect(format('{:020,f}', [n]), '0,000,012,345.678900');
        expect(format('{:020_f}', [n]), '0_000_012_345.678900');
        // zero flag is ignored
        expect(format('{:@>020_f}', [n]), '@@@@@@@12_345.678900');
      });

      test('alt', () {
        expect(format('{:#f}', [n]), '12345.678900');
        expect(format('{:#.0f}', [n]), '12346.');
      });

      test('precision', () {
        expect(format('{:.0f}', [n]), '12346');
        expect(format('{:.1f}', [n]), '12345.7');
        expect(format('{:.2f}', [n]), '12345.68');
        expect(format('{:.3f}', [n]), '12345.679');
        expect(format('{:.4f}', [n]), '12345.6789');
        expect(format('{:.5f}', [n]), '12345.67890');
      });

      test('nan and inf', () {
        // Zero flag is ignored.
        const nan = double.nan;
        const inf = double.infinity;
        assert(-inf == double.negativeInfinity);

        expect(format('{:f}', [nan]), 'nan');
        expect(format('{:-f}', [nan]), 'nan');
        expect(format('{:+f}', [nan]), 'nan');
        expect(format('{: f}', [nan]), 'nan');
        expect(format('{:f}', [-nan]), 'nan');
        expect(format('{:-f}', [-nan]), 'nan');
        expect(format('{:+f}', [-nan]), 'nan');
        expect(format('{: f}', [-nan]), 'nan');

        expect(format('{:0>06f}', [nan]), '000nan');
        expect(format('{:@>06f}', [nan]), '@@@nan');

        expect(format('{:06f}', [nan]), '   nan');
        expect(format('{:-06f}', [nan]), '   nan');
        expect(format('{:+06f}', [nan]), '   nan');
        expect(format('{: 06f}', [nan]), '   nan');
        expect(format('{:06f}', [-nan]), '   nan');
        expect(format('{:-06f}', [-nan]), '   nan');
        expect(format('{:+06f}', [-nan]), '   nan');
        expect(format('{: 06f}', [-nan]), '   nan');

        expect(format('{:#,f}', [nan]), 'nan');
        expect(format('{:#06f}', [nan]), '   nan');

        expect(format('{:f}', [inf]), 'inf');
        expect(format('{:-f}', [inf]), 'inf');
        expect(format('{:+f}', [inf]), '+inf');
        expect(format('{: f}', [inf]), ' inf');
        expect(format('{:f}', [-inf]), '-inf');
        expect(format('{:-f}', [-inf]), '-inf');
        expect(format('{:+f}', [-inf]), '-inf');
        expect(format('{: f}', [-inf]), '-inf');

        expect(format('{:0>06f}', [inf]), '000inf');
        expect(format('{:@>06f}', [inf]), '@@@inf');

        expect(format('{:06f}', [inf]), '   inf');
        expect(format('{:-06f}', [inf]), '   inf');
        expect(format('{:+06f}', [inf]), '  +inf');
        expect(format('{: 06f}', [inf]), '   inf');
        expect(format('{:06f}', [-inf]), '  -inf');
        expect(format('{:-06f}', [-inf]), '  -inf');
        expect(format('{:+06f}', [-inf]), '  -inf');
        expect(format('{: 06f}', [-inf]), '  -inf');

        expect(format('{:#,f}', [inf]), 'inf');
        expect(format('{:#,f}', [-inf]), '-inf');
        expect(format('{:#06f}', [inf]), '   inf');
        expect(format('{:#06f}', [-inf]), '  -inf');

        expect(format('{:F}', [nan]), 'NAN');
        expect(format('{:+F}', [nan]), 'NAN');
        expect(format('{:F}', [inf]), 'INF');
        expect(format('{:F}', [-inf]), '-INF');
      });
    });

    group('e:', () {
      const n1 = 0.000123456789;
      const n2 = 12345.6789;

      test('basic use', () {
        expect(
          () => format('{:e}', [123]),
          throwsA(isA<FormattingException>()),
        );

        expect(format('{:e}', [n1]), '1.234568e-4');
        expect(format('{:E}', [n1]), '1.234568E-4');
        expect(format('{:e}', [-n1]), '-1.234568e-4');
        expect(format('{:E}', [-n1]), '-1.234568E-4');

        expect(format('{:e}', [n2]), '1.234568e+4');
        expect(format('{:E}', [n2]), '1.234568E+4');
        expect(format('{:e}', [-n2]), '-1.234568e+4');
        expect(format('{:E}', [-n2]), '-1.234568E+4');
      });

      test('sign', () {
        expect(format('{:+e}', [n1]), '+1.234568e-4');
        expect(format('{:-e}', [n1]), '1.234568e-4');
        expect(format('{: e}', [n1]), ' 1.234568e-4');
        expect(format('{:+e}', [-n1]), '-1.234568e-4');
        expect(format('{:-e}', [-n1]), '-1.234568e-4');
        expect(format('{: e}', [-n1]), '-1.234568e-4');

        expect(format('{:+e}', [n2]), '+1.234568e+4');
        expect(format('{:-e}', [n2]), '1.234568e+4');
        expect(format('{: e}', [n2]), ' 1.234568e+4');
        expect(format('{:+e}', [-n2]), '-1.234568e+4');
        expect(format('{:-e}', [-n2]), '-1.234568e+4');
        expect(format('{: e}', [-n2]), '-1.234568e+4');
      });

      test('align', () {
        expect(format('{:15e}', [n1]), '    1.234568e-4');
        expect(format('{:15e}', [n2]), '    1.234568e+4');
      });

      test('zero', () {
        expect(format('{:0e}', [n1]), '1.234568e-4');
        expect(format('{:015e}', [n1]), '00001.234568e-4');
        expect(format('{:0e}', [-n1]), '-1.234568e-4');
        expect(format('{:015e}', [-n1]), '-0001.234568e-4');
        // zero flag is ignored
        expect(format('{:@>015e}', [n1]), '@@@@1.234568e-4');
        expect(format('{:@>015e}', [-n1]), '@@@-1.234568e-4');

        expect(format('{:0e}', [n2]), '1.234568e+4');
        expect(format('{:015e}', [n2]), '00001.234568e+4');
        expect(format('{:0e}', [-n2]), '-1.234568e+4');
        expect(format('{:015e}', [-n2]), '-0001.234568e+4');
        // zero flag is ignored
        expect(format('{:@>015e}', [n2]), '@@@@1.234568e+4');
        expect(format('{:@>015e}', [-n2]), '@@@-1.234568e+4');
      });

      test('group', () {
        expect(format('{:,e}', [n1]), '1.234568e-4');
        expect(format('{:_e}', [n1]), '1.234568e-4');
        expect(format('{:17,e}', [n1]), '      1.234568e-4');
        expect(format('{:17_e}', [n1]), '      1.234568e-4');
        expect(format('{:017,e}', [n1]), '000,001.234568e-4');
        expect(format('{:017_e}', [n1]), '000_001.234568e-4');
        expect(format('{:018,e}', [n1]), '0,000,001.234568e-4');
        expect(format('{:019,e}', [n1]), '0,000,001.234568e-4');
        expect(format('{:012,.0e}', [n1]), '0,000,001e-4');
        // zero flag is ignored
        expect(format('{:@>012,.0e}', [n1]), '@@@@@@@@1e-4');

        expect(format('{:,e}', [n2]), '1.234568e+4');
        expect(format('{:_e}', [n2]), '1.234568e+4');
        expect(format('{:17,e}', [n2]), '      1.234568e+4');
        expect(format('{:17_e}', [n2]), '      1.234568e+4');
        expect(format('{:017,e}', [n2]), '000,001.234568e+4');
        expect(format('{:017_e}', [n2]), '000_001.234568e+4');
        expect(format('{:018,e}', [n2]), '0,000,001.234568e+4');
        expect(format('{:019,e}', [n2]), '0,000,001.234568e+4');
        expect(format('{:012,.0e}', [n2]), '0,000,001e+4');
        // zero flag is ignored
        expect(format('{:@>012,.0e}', [n2]), '@@@@@@@@1e+4');
      });

      test('alt', () {
        expect(format('{:#e}', [n1]), '1.234568e-4');
        expect(format('{:#.0e}', [n1]), '1.e-4');

        expect(format('{:#e}', [n2]), '1.234568e+4');
        expect(format('{:#.0e}', [n2]), '1.e+4');
      });

      test('precision', () {
        expect(format('{:.0e}', [n1]), '1e-4');
        expect(format('{:.1e}', [n1]), '1.2e-4');
        expect(format('{:.2e}', [n1]), '1.23e-4');
        expect(format('{:.3e}', [n1]), '1.235e-4');
        expect(format('{:.4e}', [n1]), '1.2346e-4');
        expect(format('{:.5e}', [n1]), '1.23457e-4');
        expect(format('{:.6e}', [n1]), '1.234568e-4');
        expect(format('{:.7e}', [n1]), '1.2345679e-4');
        expect(format('{:.8e}', [n1]), '1.23456789e-4');
        expect(format('{:.9e}', [n1]), '1.234567890e-4');

        expect(format('{:.0e}', [n2]), '1e+4');
        expect(format('{:.1e}', [n2]), '1.2e+4');
        expect(format('{:.2e}', [n2]), '1.23e+4');
        expect(format('{:.3e}', [n2]), '1.235e+4');
        expect(format('{:.4e}', [n2]), '1.2346e+4');
        expect(format('{:.5e}', [n2]), '1.23457e+4');
        expect(format('{:.6e}', [n2]), '1.234568e+4');
        expect(format('{:.7e}', [n2]), '1.2345679e+4');
        expect(format('{:.8e}', [n2]), '1.23456789e+4');
        expect(format('{:.9e}', [n2]), '1.234567890e+4');
      });

      test('nan and inf', () {
        // В отличие от Python и C++ флаг zero для NaN и Infinity игнорирую.
        const nan = double.nan;
        const inf = double.infinity;
        assert(-inf == double.negativeInfinity);

        expect(format('{:e}', [nan]), 'nan');
        expect(format('{:-e}', [nan]), 'nan');
        expect(format('{:+e}', [nan]), 'nan');
        expect(format('{: e}', [nan]), 'nan');
        expect(format('{:e}', [-nan]), 'nan');
        expect(format('{:-e}', [-nan]), 'nan');
        expect(format('{:+e}', [-nan]), 'nan');
        expect(format('{: e}', [-nan]), 'nan');

        expect(format('{:06e}', [nan]), '   nan');
        expect(format('{:-06e}', [nan]), '   nan');
        expect(format('{:+06e}', [nan]), '   nan');
        expect(format('{: 06e}', [nan]), '   nan');
        expect(format('{:06e}', [-nan]), '   nan');
        expect(format('{:-06e}', [-nan]), '   nan');
        expect(format('{:+06e}', [-nan]), '   nan');
        expect(format('{: 06e}', [-nan]), '   nan');

        expect(format('{:#,e}', [nan]), 'nan');
        expect(format('{:#06e}', [nan]), '   nan');

        expect(format('{:e}', [inf]), 'inf');
        expect(format('{:-e}', [inf]), 'inf');
        expect(format('{:+e}', [inf]), '+inf');
        expect(format('{: e}', [inf]), ' inf');
        expect(format('{:e}', [-inf]), '-inf');
        expect(format('{:-e}', [-inf]), '-inf');
        expect(format('{:+e}', [-inf]), '-inf');
        expect(format('{: e}', [-inf]), '-inf');

        expect(format('{:06e}', [inf]), '   inf');
        expect(format('{:-06e}', [inf]), '   inf');
        expect(format('{:+06e}', [inf]), '  +inf');
        expect(format('{: 06e}', [inf]), '   inf');
        expect(format('{:06e}', [-inf]), '  -inf');
        expect(format('{:-06e}', [-inf]), '  -inf');
        expect(format('{:+06e}', [-inf]), '  -inf');
        expect(format('{: 06e}', [-inf]), '  -inf');

        expect(format('{:#,e}', [inf]), 'inf');
        expect(format('{:#,e}', [-inf]), '-inf');
        expect(format('{:#06e}', [inf]), '   inf');
        expect(format('{:#06e}', [-inf]), '  -inf');

        expect(format('{:E}', [nan]), 'NAN');
        expect(format('{:+E}', [nan]), 'NAN');
        expect(format('{:E}', [inf]), 'INF');
        expect(format('{:E}', [-inf]), '-INF');
      });
    });

    group('g:', () {
      test('basic use', () {
        expect(
          () => format('{:g}', [123]),
          throwsA(isA<FormattingException>()),
        );

        expect(format('{:g}', [0.0]), '0');
        expect(format('{:g}', [0.000001]), '0.000001');
        expect(format('{:g}', [0.0000001]), '1e-7');
        expect(format('{:G}', [0.0000001]), '1E-7');
        expect(format('{:g}', [123456.0]), '123456');
        expect(format('{:g}', [1234567.0]), '1.23457e+6');
        expect(format('{:G}', [1234567.0]), '1.23457E+6');
      });

      test('precision', () {
        expect(format('{:.1g}', [0.12]), '0.1');
        expect(format('{:.1g}', [1.2]), '1');
        expect(format('{:.1g}', [12.0]), '1e+1');
        expect(format('{:.2g}', [12.0]), '12');
        expect(format('{:.3g}', [1.2]), '1.2');
        expect(format('{:.3g}', [12.0]), '12');
        expect(format('{:.1g}', [0.000001]), '0.000001');
        expect(format('{:.15g}', [0.000001]), '0.000001');
        expect(format('{:.1g}', [0.0000001]), '1e-7');
        expect(format('{:.15g}', [0.0000001]), '1e-7');
        expect(format('{:.1g}', [123456.0]), '1e+5');
        expect(format('{:.15g}', [123456.0]), '123456');
        expect(format('{:.1g}', [123456789012345.0]), '1e+14');
        expect(format('{:.15g}', [123456789012345.0]), '123456789012345');
        expect(format('{:.15g}', [1234567890123456.0]), '1.23456789012346e+15');
      });

      test('alt', () {
        expect(format('{:#g}', [1.0]), '1.00000');
        expect(format('{:#g}', [0.0000001]), '1.00000e-7');
        expect(format('{:#.1g}', [1.2]), '1.');
        expect(format('{:#.1g}', [12.0]), '1.e+1');
        expect(format('{:#.2g}', [12.0]), '12.');
        expect(format('{:#.3g}', [1.2]), '1.20');
        expect(format('{:#.3g}', [12.0]), '12.0');
        expect(format('{:#.15g}', [123456789012345.0]), '123456789012345.');
        expect(format('{:#.16g}', [123456789012345.0]), '123456789012345.0');
        expect(format('{:#G}', [0.0000001]), '1.00000E-7');
        expect(format('{:#.1G}', [12.0]), '1.E+1');
        expect(format('{:#09g}', [1.0]), '001.00000');
      });

      test('zero', () {
        expect(format('{:0g}', [0.000001]), '0.000001');
        expect(format('{:#0g}', [0.000001]), '0.00000100000');
        expect(format('{:014g}', [0.000001]), '0000000.000001');
        expect(format('{:#014g}', [0.000001]), '00.00000100000');
        expect(format('{:0g}', [0.0000001]), '1e-7');
        expect(format('{:014g}', [0.0000001]), '00000000001e-7');
        expect(format('{:#014g}', [0.0000001]), '00001.00000e-7');
        // zero flag is ignored
        expect(format('{:@>#014g}', [0.0000001]), '@@@@1.00000e-7');
      });

      test('group', () {
        expect(format('{:,.9g}', [123456789.0]), '123,456,789');
        expect(format('{:_.9g}', [123456789.0]), '123_456_789');
        expect(format('{:012,.9g}', [123456789.0]), '0,123,456,789');
        expect(format('{:012_.9g}', [123456789.0]), '0_123_456_789');
        expect(format('{:013,.9g}', [123456789.0]), '0,123,456,789');
        expect(format('{:013_.9g}', [123456789.0]), '0_123_456_789');
        // zero flag is ignored
        expect(format('{:@>013_.9g}', [123456789.0]), '@@123_456_789');

        expect(format('{:010,g}', [0.0000001]), '000,001e-7');
        expect(format('{:011,g}', [0.0000001]), '0,000,001e-7');
        expect(format('{:012,g}', [0.0000001]), '0,000,001e-7');
        // zero flag is ignored
        expect(format('{:@>012,g}', [0.0000001]), '@@@@@@@@1e-7');

        expect(format('{:019,.9g}', [1234567890.0]), '000,001.23456789e+9');
        expect(format('{:020,.9g}', [1234567890.0]), '0,000,001.23456789e+9');
        expect(format('{:021,.9g}', [1234567890.0]), '0,000,001.23456789e+9');
        // zero flag is ignored
        expect(format('{:@>021,.9g}', [1234567890.0]), '@@@@@@@@1.23456789e+9');
      });
    });

    group('n:', () {
      const i = 123456789;
      const n = 123456.789;
      const n2 = 1234567.89;
      const nan = double.nan;
      const inf = double.infinity;

      test('common use', () {
        expect(
          () => format('{:n}', ['123']),
          throwsA(isA<FormattingException>()),
        );
      });

      test('integers', () {
        expect(
          () => format('{:.1n}', [0]),
          throwsA(isA<FormattingException>()),
        );

        expect(format('{:n}', [0]), '0');
        expect(format('{:#n}', [0]), '0');

        expect(format('{:n}', [1]), '1');
        expect(format('{:04n}', [1]), '0001');
        expect(format('{:07n}', [1]), '0000001');
        // zero flag is ignored
        expect(format('{:@>07n}', [1]), '@@@@@@1');

        expect(format('{:04,n}', [1]), '0,001');
        expect(format('{:05,n}', [1]), '0,001');
        expect(format('{:08,n}', [1]), '0,000,001');
        expect(format('{:09,n}', [1]), '0,000,001');
        // zero flag is ignored
        expect(format('{:@>09,n}', [1]), '@@@@@@@@1');

        expect(format('{:n}', [9223372036854775807]), '9223372036854775807');
        expect(format('{:n}', [-9223372036854775807]), '-9223372036854775807');
        expect(format('{:n}', [-9223372036854775808]), '-9223372036854775808');
        expect(
          format('{:,n}', [9223372036854775807]),
          '9,223,372,036,854,775,807',
        );
        expect(
          format('{:,n}', [-9223372036854775807]),
          '-9,223,372,036,854,775,807',
        );
        expect(
          format('{:,n}', [-9223372036854775808]),
          '-9,223,372,036,854,775,808',
        );
      });

      group('floats:', () {
        test('simple use', () {
          expect(format('{:g}', [0.0]), '0');
          expect(format('{:n}', [0.0]), '0');
          expect(format('{:g}', [-0.0]), '-0');
          expect(format('{:n}', [-0.0]), '-0');
          expect(format('{:g}', [0.000001]), '0.000001');
          expect(format('{:n}', [0.000001]), '0.000001');
          expect(format('{:g}', [0.0000001]), '1e-7');
          expect(format('{:n}', [0.0000001]), '1E-7');
          expect(format('{:g}', [n]), '123457');
          expect(format('{:n}', [n]), '123457');
          expect(format('{:g}', [-n]), '-123457');
          expect(format('{:n}', [-n]), '-123457');
          expect(format('{:g}', [n2]), '1.23457e+6');
          expect(format('{:n}', [n2]), '1.23457E6');
          expect(format('{:g}', [-n2]), '-1.23457e+6');
          expect(format('{:n}', [-n2]), '-1.23457E6');
        });

        test('precision', () {
          expect(format('{:.1g}', [n]), '1e+5');
          expect(format('{:.1n}', [n]), '1E5');
          expect(format('{:.2g}', [n]), '1.2e+5');
          expect(format('{:.2n}', [n]), '1.2E5');
          expect(format('{:.3g}', [n]), '1.23e+5');
          expect(format('{:.3n}', [n]), '1.23E5');
          expect(format('{:.4g}', [n]), '1.235e+5');
          expect(format('{:.4n}', [n]), '1.235E5');
          expect(format('{:.5g}', [n]), '1.2346e+5');
          expect(format('{:.5n}', [n]), '1.2346E5');
          expect(format('{:.6g}', [n]), '123457');
          expect(format('{:.6n}', [n]), '123457');
          expect(format('{:.7g}', [n]), '123456.8');
          expect(format('{:.7n}', [n]), '123456.8');
          expect(format('{:.8g}', [n]), '123456.79');
          expect(format('{:.8n}', [n]), '123456.79');
          expect(format('{:.9g}', [n]), '123456.789');
          expect(format('{:.9n}', [n]), '123456.789');
          expect(format('{:.10g}', [n]), '123456.789');
          expect(format('{:.10n}', [n]), '123456.789');
        });

        test('zero', () {
          expect(format('{:0g}', [n]), '123457');
          expect(format('{:0n}', [n]), '123457');
          expect(format('{:0g}', [-n]), '-123457');
          expect(format('{:0n}', [-n]), '-123457');
          expect(format('{:06g}', [n]), '123457');
          expect(format('{:06n}', [n]), '123457');
          expect(format('{:06g}', [-n]), '-123457');
          expect(format('{:06n}', [-n]), '-123457');
          expect(format('{:09g}', [n]), '000123457');
          expect(format('{:09n}', [n]), '000123457');
          expect(format('{:09g}', [-n]), '-00123457');
          expect(format('{:09n}', [-n]), '-00123457');
          expect(format('{:013g}', [n2]), '0001.23457e+6');
          expect(format('{:013n}', [n2]), '00001.23457E6');
          expect(format('{:013g}', [-n2]), '-001.23457e+6');
          expect(format('{:013n}', [-n2]), '-0001.23457E6');
          // zero flag is ignored
          expect(format('{:@>09g}', [n]), '@@@123457');
          expect(format('{:@>09n}', [n]), '@@@123457');
          expect(format('{:@>09g}', [-n]), '@@-123457');
          expect(format('{:@>09n}', [-n]), '@@-123457');
          expect(format('{:@>013g}', [n2]), '@@@1.23457e+6');
          expect(format('{:@>013n}', [n2]), '@@@@1.23457E6');
          expect(format('{:@>013g}', [-n2]), '@@-1.23457e+6');
          expect(format('{:@>013n}', [-n2]), '@@@-1.23457E6');

          expect(format('{:013.9g}', [n]), '000123456.789');
          expect(format('{:013.9n}', [n]), '000123456.789');
          expect(format('{:013.9g}', [-n]), '-00123456.789');
          expect(format('{:013.9n}', [-n]), '-00123456.789');
          expect(format('{:013.9g}', [n2]), '0001234567.89');
          expect(format('{:013.9n}', [n2]), '0001234567.89');
          expect(format('{:013.9g}', [-n2]), '-001234567.89');
          expect(format('{:013.9n}', [-n2]), '-001234567.89');
        });

        test('alt', () {
          expect(format('{:#g}', [0.0]), '0.00000');
          expect(format('{:#n}', [0.0]), '0.00000');
          expect(format('{:#g}', [-0.0]), '-0.00000');
          expect(format('{:#n}', [-0.0]), '-0.00000');
          expect(format('{:#g}', [0.0000001]), '1.00000e-7');
          expect(format('{:#n}', [0.0000001]), '1.00000E-7');
          expect(format('{:#g}', [-0.0000001]), '-1.00000e-7');
          expect(format('{:#n}', [-0.0000001]), '-1.00000E-7');

          expect(format('{:#g}', [n]), '123457.');
          expect(format('{:#n}', [n]), '123457.');
          expect(format('{:#g}', [-n]), '-123457.');
          expect(format('{:#n}', [-n]), '-123457.');
          expect(format('{:#.1g}', [n]), '1.e+5');
          expect(format('{:#.1n}', [n]), '1.E5');
          expect(format('{:#.1g}', [-n]), '-1.e+5');
          expect(format('{:#.1n}', [-n]), '-1.E5');
          expect(format('{:#.12g}', [n]), '123456.789000');
          expect(format('{:#.12n}', [n]), '123456.789000');
          expect(format('{:#.12g}', [-n]), '-123456.789000');
          expect(format('{:#.12n}', [-n]), '-123456.789000');
          expect(format('{:#016.12g}', [n]), '000123456.789000');
          expect(format('{:#016.12n}', [n]), '000123456.789000');
          expect(format('{:#016.12g}', [-n]), '-00123456.789000');
          expect(format('{:#016.12n}', [-n]), '-00123456.789000');
        });

        test('group option', () {
          expect(format('{:,g}', [n]), '123,457');
          expect(format('{:,n}', [n]), '123,457');
          expect(format('{:,g}', [-n]), '-123,457');
          expect(format('{:,n}', [-n]), '-123,457');
          expect(format('{:#,g}', [n]), '123,457.');
          expect(format('{:#,n}', [n]), '123,457.');
          expect(format('{:#,g}', [-n]), '-123,457.');
          expect(format('{:#,n}', [-n]), '-123,457.');
          expect(format('{:,.9g}', [n]), '123,456.789');
          expect(format('{:,.9n}', [n]), '123,456.789');
          expect(format('{:,.9g}', [-n]), '-123,456.789');
          expect(format('{:,.9n}', [-n]), '-123,456.789');
          expect(format('{:#,.12g}', [n]), '123,456.789000');
          expect(format('{:#,.12n}', [n]), '123,456.789000');
          expect(format('{:#,.12g}', [-n]), '-123,456.789000');
          expect(format('{:#,.12n}', [-n]), '-123,456.789000');

          expect(format('{:#015,.12g}', [n]), '0,123,456.789000');
          expect(format('{:#015,.12n}', [n]), '0,123,456.789000');
          expect(format('{:#016,.12g}', [-n]), '-0,123,456.789000');
          expect(format('{:#016,.12n}', [-n]), '-0,123,456.789000');
          expect(format('{:#016,.12g}', [n]), '0,123,456.789000');
          expect(format('{:#016,.12n}', [n]), '0,123,456.789000');
          expect(format('{:#017,.12g}', [-n]), '-0,123,456.789000');
          expect(format('{:#017,.12n}', [-n]), '-0,123,456.789000');
          expect(format('{:#019,.12g}', [n]), '0,000,123,456.789000');
          expect(format('{:#019,.12n}', [n]), '0,000,123,456.789000');
          expect(format('{:#020,.12g}', [-n]), '-0,000,123,456.789000');
          expect(format('{:#020,.12n}', [-n]), '-0,000,123,456.789000');
          expect(format('{:#020,.12g}', [n]), '0,000,123,456.789000');
          expect(format('{:#020,.12n}', [n]), '0,000,123,456.789000');
          expect(format('{:#021,.12g}', [-n]), '-0,000,123,456.789000');
          expect(format('{:#021,.12n}', [-n]), '-0,000,123,456.789000');
        });
      });

      // test('---', () {
      //   const f = -123456789.89;
      //   Intl.defaultLocale = 'ar_EG';
      //   print(NumberFormat().symbols.DECIMAL_PATTERN);

      //   final fmt = NumberFormat.decimalPattern();
      //   printA(fmt, f));

      //   print('14');
      //   printA('{:14n}', [f]));
      //   printA('{:14,n}', [f]));
      //   printA('{:014n}', [f]));
      //   printA('{:014,n}', [f]));

      //   print('15');
      //   printA('{:15n}', [f]));
      //   printA('{:15,n}', [f]));
      //   printA('{:015n}', [f]));
      //   printA('{:015,n}', [f]));

      //   print('16');
      //   printA('{:16n}', [f]));
      //   printA('{:16,n}', [f]));
      //   printA('{:016n}', [f]));
      //   printA('{:016,n}', [f]));

      //   print('17');
      //   printA('{:17n}', [f]));
      //   printA('{:17,n}', [f]));
      //   printA('{:017n}', [f]));
      //   printA('{:017,n}', [f]));

      //   print('18');
      //   printA('{:18n}', [f]));
      //   printA('{:18,n}', [f]));
      //   printA('{:018n}', [f]));
      //   printA('{:018,n}', [f]));
      // });

      test('en_US', () {
        Intl.defaultLocale = 'en_US';
        expect(format('{:n}', [i]), '123456789');
        expect(format('{:n}', [-i]), '-123456789');
        expect(format('{:012n}', [i]), '000123456789');
        expect(format('{:013n}', [-i]), '-000123456789');

        expect(format('{:,n}', [i]), '123,456,789');
        expect(format('{:,n}', [-i]), '-123,456,789');
        expect(format('{:015,n}', [i]), '000,123,456,789');
        expect(format('{:016,n}', [-i]), '-000,123,456,789');
        expect(format('{:016,n}', [i]), '0,000,123,456,789');
        expect(format('{:017,n}', [-i]), '-0,000,123,456,789');
        expect(format('{:017,n}', [i]), '0,000,123,456,789');
        expect(format('{:018,n}', [-i]), '-0,000,123,456,789');

        expect(format('{:n}', [0.0]), '0');
        expect(format('{:n}', [-0.0]), '-0');
        expect(format('{:#n}', [0.0]), '0.00000');
        expect(format('{:#n}', [-0.0]), '-0.00000');

        expect(format('{:n}', [n]), '123457');
        expect(format('{:n}', [-n]), '-123457');
        expect(format('{:#n}', [n]), '123457.');
        expect(format('{:#n}', [-n]), '-123457.');
        expect(format('{:#014.10n}', [n]), '000123456.7890');
        expect(format('{:#014.10n}', [-n]), '-00123456.7890');
        expect(format('{:#018,.10n}', [n]), '0,000,123,456.7890');
        expect(format('{:#018,.10n}', [-n]), '-0,000,123,456.7890');

        expect(format('{:n}', [n2]), '1.23457E6');
        expect(format('{:n}', [-n2]), '-1.23457E6');
        expect(format('{:#.7n}', [n2]), '1234568.');
        expect(format('{:#.7n}', [-n2]), '-1234568.');
        expect(format('{:012n}', [n2]), '0001.23457E6');
        expect(format('{:012n}', [-n2]), '-001.23457E6');
        expect(format('{:017,n}', [n2]), '0,000,001.23457E6');
        expect(format('{:017,n}', [-n2]), '-0,000,001.23457E6');

        expect(format('{:n}', [nan]), 'NaN');
        expect(format('{:n}', [-nan]), 'NaN');
        expect(format('{:n}', [inf]), '∞');
        expect(format('{:n}', [-inf]), '-∞');
        expect(format('{:+n}', [inf]), '+∞');
      });

      test('en_IN', () {
        Intl.defaultLocale = 'en_IN';
        expect(format('{:n}', [i]), '123456789');
        expect(format('{:n}', [-i]), '-123456789');
        expect(format('{:012n}', [i]), '000123456789');
        expect(format('{:013n}', [-i]), '-000123456789');

        expect(format('{:,n}', [i]), '12,34,56,789');
        expect(format('{:,n}', [-i]), '-12,34,56,789');
        expect(format('{:015,n}', [i]), '00,12,34,56,789');
        expect(format('{:016,n}', [-i]), '-00,12,34,56,789');
        expect(format('{:016,n}', [i]), '0,00,12,34,56,789');
        expect(format('{:017,n}', [-i]), '-0,00,12,34,56,789');
        expect(format('{:017,n}', [i]), '0,00,12,34,56,789');
        expect(format('{:018,n}', [-i]), '-0,00,12,34,56,789');

        expect(format('{:n}', [0.0]), '0');
        expect(format('{:n}', [-0.0]), '-0');
        expect(format('{:#n}', [0.0]), '0.00000');
        expect(format('{:#n}', [-0.0]), '-0.00000');

        expect(format('{:n}', [n]), '123457');
        expect(format('{:n}', [-n]), '-123457');
        expect(format('{:#n}', [n]), '123457.');
        expect(format('{:#n}', [-n]), '-123457.');
        expect(format('{:#014.10n}', [n]), '000123456.7890');
        expect(format('{:#014.10n}', [-n]), '-00123456.7890');
        expect(format('{:#019,.10n}', [n]), '0,00,01,23,456.7890');
        expect(format('{:#019,.10n}', [-n]), '-0,00,01,23,456.7890');

        expect(format('{:n}', [n2]), '1.23457E6');
        expect(format('{:n}', [-n2]), '-1.23457E6');
        expect(format('{:#.7n}', [n2]), '1234568.');
        expect(format('{:#.7n}', [-n2]), '-1234568.');
        expect(format('{:012n}', [n2]), '0001.23457E6');
        expect(format('{:012n}', [-n2]), '-001.23457E6');
        expect(format('{:016,n}', [n2]), '0,00,001.23457E6');
        expect(format('{:016,n}', [-n2]), '-0,00,001.23457E6');

        expect(format('{:n}', [nan]), 'NaN');
        expect(format('{:n}', [-nan]), 'NaN');
        expect(format('{:n}', [inf]), '∞');
        expect(format('{:n}', [-inf]), '-∞');
        expect(format('{:+n}', [inf]), '+∞');
      });

      test('ru_RU', () {
        Intl.defaultLocale = 'ru_RU';
        expect(format('{:n}', [i]), '123456789');
        expect(format('{:n}', [-i]), '-123456789');
        expect(format('{:012n}', [i]), '000123456789');
        expect(format('{:013n}', [-i]), '-000123456789');

        expect(format('{:,n}', [i]), '123 456 789');
        expect(format('{:,n}', [-i]), '-123 456 789');
        expect(format('{:015,n}', [i]), '000 123 456 789');
        expect(format('{:016,n}', [-i]), '-000 123 456 789');
        expect(format('{:016,n}', [i]), '0 000 123 456 789');
        expect(format('{:017,n}', [-i]), '-0 000 123 456 789');
        expect(format('{:017,n}', [i]), '0 000 123 456 789');
        expect(format('{:018,n}', [-i]), '-0 000 123 456 789');

        expect(format('{:n}', [0.0]), '0');
        expect(format('{:n}', [-0.0]), '-0');
        expect(format('{:#n}', [0.0]), '0,00000');
        expect(format('{:#n}', [-0.0]), '-0,00000');

        expect(format('{:n}', [n]), '123457');
        expect(format('{:n}', [-n]), '-123457');
        expect(format('{:#n}', [n]), '123457,');
        expect(format('{:#n}', [-n]), '-123457,');
        expect(format('{:#014.10n}', [n]), '000123456,7890');
        expect(format('{:#014.10n}', [-n]), '-00123456,7890');
        expect(format('{:#018,.10n}', [n]), '0 000 123 456,7890');
        expect(format('{:#018,.10n}', [-n]), '-0 000 123 456,7890');

        expect(format('{:n}', [n2]), '1,23457E6');
        expect(format('{:n}', [-n2]), '-1,23457E6');
        expect(format('{:#.7n}', [n2]), '1234568,');
        expect(format('{:#.7n}', [-n2]), '-1234568,');
        expect(format('{:012n}', [n2]), '0001,23457E6');
        expect(format('{:012n}', [-n2]), '-001,23457E6');
        expect(format('{:017,n}', [n2]), '0 000 001,23457E6');
        expect(format('{:017,n}', [-n2]), '-0 000 001,23457E6');

        expect(format('{:n}', [nan]), 'не число');
        expect(format('{:n}', [-nan]), 'не число');
        expect(format('{:n}', [inf]), '∞');
        expect(format('{:n}', [-inf]), '-∞');
        expect(format('{:+n}', [inf]), '+∞');
      });

      test('ar_EG', () {
        Intl.defaultLocale = 'ar_EG';
        expect(format('{:n}', [i]), '١٢٣٤٥٦٧٨٩');
        // printA('{:n}', [-i]));
        // \u061C - отметка об арабском письме
        expect(format('{:n}', [-i]), '\u061C-١٢٣٤٥٦٧٨٩');
        expect(format('{:012n}', [i]), '٠٠٠١٢٣٤٥٦٧٨٩');
        expect(format('{:014n}', [-i]), '\u061C-٠٠٠١٢٣٤٥٦٧٨٩');

        expect(format('{:,n}', [i]), '١٢٣٬٤٥٦٬٧٨٩');
        expect(format('{:,n}', [-i]), '\u061C-١٢٣٬٤٥٦٬٧٨٩');
        expect(format('{:015,n}', [i]), '٠٠٠٬١٢٣٬٤٥٦٬٧٨٩');
        expect(format('{:017,n}', [-i]), '\u061C-٠٠٠٬١٢٣٬٤٥٦٬٧٨٩');
        expect(format('{:016,n}', [i]), '٠٬٠٠٠٬١٢٣٬٤٥٦٬٧٨٩');
        expect(format('{:018,n}', [-i]), '\u061C-٠٬٠٠٠٬١٢٣٬٤٥٦٬٧٨٩');
        expect(format('{:017,n}', [i]), '٠٬٠٠٠٬١٢٣٬٤٥٦٬٧٨٩');
        expect(format('{:019,n}', [-i]), '\u061C-٠٬٠٠٠٬١٢٣٬٤٥٦٬٧٨٩');

        expect(format('{:n}', [0.0]), '٠');
        expect(format('{:n}', [-0.0]), '\u061C-٠');
        expect(format('{:#n}', [0.0]), '٠٫٠٠٠٠٠');
        expect(format('{:#n}', [-0.0]), '\u061C-٠٫٠٠٠٠٠');

        expect(format('{:n}', [n]), '١٢٣٤٥٧');
        expect(format('{:n}', [-n]), '\u061C-١٢٣٤٥٧');
        expect(format('{:#n}', [n]), '١٢٣٤٥٧٫');
        expect(format('{:#n}', [-n]), '\u061C-١٢٣٤٥٧٫');
        expect(format('{:#014.10n}', [n]), '٠٠٠١٢٣٤٥٦٫٧٨٩٠');
        expect(format('{:#014.10n}', [-n]), '\u061C-٠١٢٣٤٥٦٫٧٨٩٠');
        expect(format('{:#018,.10n}', [n]), '٠٬٠٠٠٬١٢٣٬٤٥٦٫٧٨٩٠');
        expect(format('{:#018,.10n}', [-n]), '\u061C-٠٠٠٬١٢٣٬٤٥٦٫٧٨٩٠');

        expect(format('{:n}', [n2]), '١٫٢٣٤٥٧أس٦');
        expect(format('{:n}', [-n2]), '\u061C-١٫٢٣٤٥٧أس٦');
        expect(format('{:#.7n}', [n2]), '١٢٣٤٥٦٨٫');
        expect(format('{:#.7n}', [-n2]), '\u061C-١٢٣٤٥٦٨٫');
        expect(format('{:013n}', [n2]), '٠٠٠١٫٢٣٤٥٧أس٦');
        expect(format('{:013n}', [-n2]), '\u061C-٠١٫٢٣٤٥٧أس٦');
        expect(format('{:018,n}', [n2]), '٠٬٠٠٠٬٠٠١٫٢٣٤٥٧أس٦');
        expect(format('{:018,n}', [-n2]), '\u061C-٠٠٠٬٠٠١٫٢٣٤٥٧أس٦');

        expect(format('{:n}', [nan]), 'ليس\xA0رقمًا');
        expect(format('{:n}', [-nan]), 'ليس\xA0رقمًا');
        expect(format('{:n}', [inf]), '∞');
        expect(format('{:n}', [-inf]), '\u061C-∞');
        expect(format('{:+n}', [inf]), '\u061C+∞');
      });

      test('bn', () {
        Intl.defaultLocale = 'bn';
        expect(format('{:n}', [i]), '১২৩৪৫৬৭৮৯');
        expect(format('{:n}', [-i]), '-১২৩৪৫৬৭৮৯');
        expect(format('{:012n}', [i]), '০০০১২৩৪৫৬৭৮৯');
        expect(format('{:013n}', [-i]), '-০০০১২৩৪৫৬৭৮৯');

        expect(format('{:,n}', [i]), '১২,৩৪,৫৬,৭৮৯');
        expect(format('{:,n}', [-i]), '-১২,৩৪,৫৬,৭৮৯');
        expect(format('{:015,n}', [i]), '০০,১২,৩৪,৫৬,৭৮৯');
        expect(format('{:016,n}', [-i]), '-০০,১২,৩৪,৫৬,৭৮৯');
        expect(format('{:016,n}', [i]), '০,০০,১২,৩৪,৫৬,৭৮৯');
        expect(format('{:017,n}', [-i]), '-০,০০,১২,৩৪,৫৬,৭৮৯');
        expect(format('{:017,n}', [i]), '০,০০,১২,৩৪,৫৬,৭৮৯');
        expect(format('{:018,n}', [-i]), '-০,০০,১২,৩৪,৫৬,৭৮৯');

        expect(format('{:n}', [0.0]), '০');
        expect(format('{:n}', [-0.0]), '-০');
        expect(format('{:#n}', [0.0]), '০.০০০০০');
        expect(format('{:#n}', [-0.0]), '-০.০০০০০');

        expect(format('{:n}', [n]), '১২৩৪৫৭');
        expect(format('{:n}', [-n]), '-১২৩৪৫৭');
        expect(format('{:#n}', [n]), '১২৩৪৫৭.');
        expect(format('{:#n}', [-n]), '-১২৩৪৫৭.');
        expect(format('{:#014.10n}', [n]), '০০০১২৩৪৫৬.৭৮৯০');
        expect(format('{:#014.10n}', [-n]), '-০০১২৩৪৫৬.৭৮৯০');
        expect(format('{:#019,.10n}', [n]), '০,০০,০১,২৩,৪৫৬.৭৮৯০');
        expect(format('{:#019,.10n}', [-n]), '-০,০০,০১,২৩,৪৫৬.৭৮৯০');

        expect(format('{:n}', [n2]), '১.২৩৪৫৭E৬');
        expect(format('{:n}', [-n2]), '-১.২৩৪৫৭E৬');
        expect(format('{:#.7n}', [n2]), '১২৩৪৫৬৮.');
        expect(format('{:#.7n}', [-n2]), '-১২৩৪৫৬৮.');
        expect(format('{:012n}', [n2]), '০০০১.২৩৪৫৭E৬');
        expect(format('{:012n}', [-n2]), '-০০১.২৩৪৫৭E৬');
        expect(format('{:016,n}', [n2]), '০,০০,০০১.২৩৪৫৭E৬');
        expect(format('{:016,n}', [-n2]), '-০,০০,০০১.২৩৪৫৭E৬');

        expect(format('{:n}', [nan]), 'NaN');
        expect(format('{:n}', [-nan]), 'NaN');
        expect(format('{:n}', [inf]), '∞');
        expect(format('{:n}', [-inf]), '-∞');
        expect(format('{:+n}', [inf]), '+∞');
      });

      test('other', () {
        Intl.defaultLocale = 'fa';
        expect(format('{:n}', [nan]), 'ناعدد');

        Intl.defaultLocale = 'fi';
        expect(format('{:n}', [nan]), 'epäluku');

        Intl.defaultLocale = 'hy';
        expect(format('{:n}', [nan]), 'ՈչԹ');

        Intl.defaultLocale = 'ka';
        expect(format('{:n}', [nan]), 'არ არის რიცხვი');

        Intl.defaultLocale = 'kk';
        expect(format('{:n}', [nan]), 'сан емес');

        Intl.defaultLocale = 'ky';
        expect(format('{:n}', [nan]), 'сан эмес');

        Intl.defaultLocale = 'lo';
        expect(format('{:n}', [nan]), 'ບໍ່​ແມ່ນ​ໂຕ​ເລກ');

        Intl.defaultLocale = 'lv';
        expect(format('{:n}', [nan]), 'NS');

        Intl.defaultLocale = 'my';
        expect(format('{:n}', [nan]), 'ဂဏန်းမဟုတ်သော');

        Intl.defaultLocale = 'uz';
        expect(format('{:n}', [nan]), 'son emas');

        Intl.defaultLocale = 'zh_HK';
        expect(format('{:n}', [nan]), '非數值');
      });
    });
  });

  group('bugs:', () {
    test('built-in formatter rejects unsupported values with context', () {
      expect(
        () => format('{:d}', const ['42']),
        throwsA(
          isA<UnsupportedFormatValueException>()
              .having((error) => error.specifier, 'specifier', 'd')
              .having((error) => error.value, 'value', '42'),
        ),
      );
    });

    test('argument resolution failures are typed', () {
      expect(
        () => format('{1}', const [0]),
        throwsA(isA<InvalidFormatException>()),
      );
      expect(
        () => formatNamed('{missing}', const {}),
        throwsA(isA<InvalidFormatException>()),
      );
    });

    test('unsupported built-in options are typed', () {
      for (final template in ['{:.1d}', '{:#d}', '{:,b}']) {
        expect(
          () => format(template, const [1]),
          throwsA(isA<InvalidFormatException>()),
        );
      }
    });

    test('precision upper bounds are typed', () {
      for (final template in ['{:.21f}', '{:.21e}', '{:.22g}', '{:.22n}']) {
        expect(
          () => format(template, const [1.0]),
          throwsA(isA<InvalidFormatException>()),
        );
      }
    });

    test('n precision is validated before dart number api', () {
      expect(
        () => format('{:.0n}', [0.0]),
        throwsA(isA<InvalidFormatException>()),
      );
    });

    test('n rejects precision that intl cannot represent safely', () {
      expect(format('{:.18n}', [0.1]), '0.1');
      expect(
        () => format('{:.19n}', [0.1]),
        throwsA(
          isA<InvalidFormatException>()
              .having((error) => error.fragment, 'fragment', '{:.19n}')
              .having((error) => error.reason, 'reason', contains('<= 18')),
        ),
      );
    });

    test('general precision uses typed validation', () {
      for (final specifier in ['g', 'G']) {
        expect(
          () => format('{:.0$specifier}', [0.0]),
          throwsA(isA<InvalidFormatException>()),
        );
      }
    });

    test('zero with grouping and no width does not crash', () {
      expect(format('{:0_d}', [-1234]), '-1_234');
      expect(format('{:#0_x}', [0x1234]), '0x1234');
      expect(format('{:0_d}', [BigInt.from(-1234)]), '-1_234');
    });

    test('fixed bugs', () {
      expect(format('{:!>5} {:!>3}', ['1', '3']), '!!!!1 !!3');
    });
  });
}
