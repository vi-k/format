import 'package:format/format.dart';
import 'package:intl/intl.dart';
import 'package:test/test.dart';

void main() {
  group('Common use:', () {
    //setUp(() );
    test('escaping', () {
      expect(format2('{{0}->{0}', [9]), '{0}->9');
    });

    test('auto and manual numeration of arguments', () {
      expect(
        format2('{0} {} {} {5} {}', [0, 1, 2, 3, 4, 5, 6]),
        '0 1 2 5 6',
      );
    });

    test('positional arguments', () {
      const positionalArgs = [1, 2, 3];

      expect(format2('{} {} {}', positionalArgs), '1 2 3');
      expect(format2('{2} {1} {0}', positionalArgs), '3 2 1');
      expect(format2('{} {} {} {0} {} {}', positionalArgs), '1 2 3 1 2 3');
      expect(
        () => format2('{2} {}', positionalArgs),
        throwsA(
          predicate(
            (e) =>
                e is ArgumentError &&
                e.message == '{} Index #3 out of range of positional args.',
          ),
        ),
      );
      // expect(
      //   () => format2m('{}', <String, Object?>{}),
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
        format2m(
          '{test_1} {тест_2} {テスト_3} {"hello world"} {_} {_0}',
          namedArgs,
        ),
        '1 2 3 4 5 6',
      );
      expect(format2m('{+} {"+"}', namedArgs), '{+} 8');
      expect(
        format2m(
          '{"""key in double quotes"""} {"\'key in single quotes\'"}',
          namedArgs,
        ),
        '9 10',
      );
      expect(
        format2m(
          "{'\"key in double quotes\"'} {'''key in single quotes'''}",
          namedArgs,
        ),
        '9 10',
      );
      expect(
        format2m(
          '{"""key in double quotes"""} ' "{'''key in single quotes'''}",
          namedArgs,
        ),
        '9 10',
      );

      expect(
        () => format2('{a}', <Object?>[]),
        throwsA(
          predicate(
            (e) =>
                e is ArgumentError && e.message == '{a} Named args is missing.',
          ),
        ),
      );
      expect(
        () => format2m('{a}', namedArgs),
        throwsA(
          predicate(
            (e) =>
                e is ArgumentError &&
                e.message == '{a} Key [a] is missing in named args.',
          ),
        ),
      );
    });

    test('fill and align', () {
      const s = 'hello';

      expect(format2('{:0}', [s]), 'hello');

      expect(format2('{:9}', [s]), 'hello    ');
      expect(format2('{:<9}', [s]), 'hello    ');
      expect(format2('{:>9}', [s]), '    hello');
      expect(format2('{:^9}', [s]), '  hello  ');
      expect(format2('{:^10}', [s]), '  hello   ');

      expect(format2('{:*9}', [s]), '{:*9}'); // align is missing
      expect(format2('{:*<9}', [s]), 'hello****');
      expect(format2('{:*>9}', [s]), '****hello');
      expect(format2('{:*^9}', [s]), '**hello**');
      expect(format2('{:*^10}', [s]), '**hello***');

      expect(format2('{:👨<9}', [s]), 'hello👨👨👨👨');
      expect(format2('{:👨>9}', [s]), '👨👨👨👨hello');
      expect(format2('{:👨^9}', [s]), '👨👨hello👨👨');

      expect(
        format2('{:👨‍👩‍👦‍👧<9}', [s]),
        'hello👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧',
      );
      expect(
        format2('{:👨‍👩‍👦‍👧>9}', [s]),
        '👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧👨‍👩‍👦‍👧hello',
      );
      expect(
        format2('{:👨‍👩‍👦‍👧^9}', [s]),
        '👨‍👩‍👦‍👧👨‍👩‍👦‍👧hello👨‍👩‍👦‍👧👨‍👩‍👦‍👧',
      );

      expect(format2('{:a\u{0308}<9}', [s]), 'helloääää');
      expect(format2('{:a\u{0308}>9}', [s]), 'äääähello');
      expect(format2('{:a\u{0308}^9}', [s]), 'äähelloää');

      expect(
        format2('{:(any symbols)<9}', [s]),
        'hello(any symbols)(any symbols)(any symbols)(any symbols)',
      );
      expect(
        format2('{:(any symbols)>9}', [s]),
        '(any symbols)(any symbols)(any symbols)(any symbols)hello',
      );
      expect(
        format2('{:(any symbols)^9}', [s]),
        '(any symbols)(any symbols)hello(any symbols)(any symbols)',
      );

      expect(format2('{:<^><9}', [s]), 'hello<^><^><^><^>');
      expect(format2('{:<^>>9}', [s]), '<^><^><^><^>hello');
      expect(format2('{:<^>^9}', [s]), '<^><^>hello<^><^>');
    });

    test('width and precision', () {
      expect(
        () => format2('{:{}}', [0.0, -1]),
        throwsA(
          predicate(
            (e) =>
                e is ArgumentError &&
                e.message == '{:{}} Width must be >= 0. Passed -1.',
          ),
        ),
      );

      // expect(
      //   () => format2('{:.{}f}', [0.0, -1]),
      //   throwsA(
      //     predicate(
      //       (e) =>
      //           e is ArgumentError &&
      //           e.message == '{:.{}f} Precision must be >= 0. Passed -1.',
      //     ),
      //   ),
      // );

      // expect(
      //   () => format2('{:.0g}', [0.0, 0]),
      //   throwsA(
      //     predicate(
      //       (e) =>
      //           e is ArgumentError &&
      //           e.message == '{:.0g} Precision must be >= 1. Passed 0.',
      //     ),
      //   ),
      // );

      // expect(
      //   () => format2('{:.0}', [0.0, 0]),
      //   throwsA(
      //     predicate(
      //       (e) =>
      //           e is ArgumentError &&
      //           e.message == '{:.0} Precision must be >= 1. Passed 0.',
      //     ),
      //   ),
      // );

      // expect(format2('{:0}', [123]), '123'); // Flag zero and zero width
      // expect(format2('{:00}', [123]), '123');
    });
  });

  group('Format specifier', () {
    group('c:', () {
      test('basic use', () {
        expect(
          () => format2('{:c}', ['a']),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:c} Formatter for type String'
                          ' and specifier c is not registered',
            ),
          ),
        );
        expect(format2('{:c}', [65]), 'A');
      });

      test('surrogate pairs', () {
        expect(
          format2('{:c}+{:c}+{:c}+{:c}={:c}{:c}{:c}{:c}{:c}{:c}{:c}', [
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
          format2('{:c}+{:c}+{:c}+{:c}={:c}', [
            0x1F468,
            0x1F469,
            0x1F467,
            0x1F466,
            [
              0x1F468,
              0x200D,
              0x1F469,
              0x200D,
              0x1F467,
              0x200D,
              0x1F466,
            ],
          ]),
          '👨+👩+👧+👦=👨‍👩‍👧‍👦',
        );
        expect(
          format2('{:c}={:c}', [
            [0x1F468, 0x2B, 0x1F469, 0x2B, 0x1F467, 0x2B, 0x1F466],
            [0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F467, 0x200D, 0x1F466],
          ]),
          '👨+👩+👧+👦=👨‍👩‍👧‍👦',
        );
      });

      test('width, align and fill', () {
        const c = 65;
        expect(format2('{:4c}', [c]), 'A   ');
        expect(format2('{:>4c}', [c]), '   A');
        expect(format2('{:^4c}', [c]), ' A  ');
        expect(format2('{:<4c}', [c]), 'A   ');

        expect(format2('{:*>4c}', [c]), '***A');
        expect(format2('{:*^4c}', [c]), '*A**');
        expect(format2('{:*<4c}', [c]), 'A***');

        expect(format2('{:*>4.0c}', [c]), '****');
        expect(format2('{:*^4.0c}', [c]), '****');
        expect(format2('{:*<4.0c}', [c]), '****');

        expect(format2('{:*>4.1c}', [c]), '***A');
        expect(format2('{:*^4.1c}', [c]), '*A**');
        expect(format2('{:*<4.1c}', [c]), 'A***');

        expect(format2('{:*>4.2c}', [c]), '***A');
        expect(format2('{:*^4.2c}', [c]), '*A**');
        expect(format2('{:*<4.2c}', [c]), 'A***');

        const c2 = [0xD83C, 0xDDFA, 0xD83C, 0xDDE6];

        expect(format2('{:5c}', [c2]), '🇺🇦    ');
        expect(format2('{:>5c}', [c2]), '    🇺🇦');
        expect(format2('{:^5c}', [c2]), '  🇺🇦  ');
        expect(format2('{:<5c}', [c2]), '🇺🇦    ');

        expect(format2('{:🙏>5c}', [c2]), '🙏🙏🙏🙏🇺🇦');
        expect(format2('{:🙏^5c}', [c2]), '🙏🙏🇺🇦🙏🙏');
        expect(format2('{:🙏<5c}', [c2]), '🇺🇦🙏🙏🙏🙏');

        expect(format2('{:🙏>5.0c}', [c2]), '🙏🙏🙏🙏🙏');
        expect(format2('{:🙏^5.0c}', [c2]), '🙏🙏🙏🙏🙏');
        expect(format2('{:🙏<5.0c}', [c2]), '🙏🙏🙏🙏🙏');

        expect(format2('{:🙏>5.1c}', [c2]), '🙏🙏🙏🙏🇺🇦');
        expect(format2('{:🙏^5.1c}', [c2]), '🙏🙏🇺🇦🙏🙏');
        expect(format2('{:🙏<5.1c}', [c2]), '🇺🇦🙏🙏🙏🙏');

        expect(format2('{:🙏>5.2c}', [c2]), '🙏🙏🙏🙏🇺🇦');
        expect(format2('{:🙏^5.2c}', [c2]), '🙏🙏🇺🇦🙏🙏');
        expect(format2('{:🙏<5.2c}', [c2]), '🇺🇦🙏🙏🙏🙏');
      });
    });

    group('s:', () {
      const s = 'Hello world';
      const s2 = '👨+👩+👧+👦=👨‍👩‍👧‍👦';

      test('basic use', () {
        expect(
          () => format2('{:s}', [123]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:s} Formatter for type int'
                          ' and specifier s is not registered',
            ),
          ),
        );

        expect(format2('{}', [s]), 'Hello world');
        expect(format2('{:s}', [s]), 'Hello world');
      });

      test('precision', () {
        expect(format2('{:.11s}', [s]), 'Hello world');
        expect(format2('{:.20s}', [s]), 'Hello world');
        expect(format2('{:.5s}', [s]), 'Hello');
        expect(format2('{:#.5s}', [s]), 'Hell…');
        expect(format2('{:#.6s}', [s]), 'Hello…');
        expect(format2('{:#.7s}', [s]), 'Hello…');
        expect(format2('{:#.8s}', [s]), 'Hello w…');

        expect(format2('{:.1s}', [s2]), '👨');
        expect(format2('{:.3s}', [s2]), '👨+👩');
        expect(format2('{:.5s}', [s2]), '👨+👩+👧');
        expect(format2('{:.7s}', [s2]), '👨+👩+👧+👦');
        expect(format2('{:.9s}', [s2]), '👨+👩+👧+👦=👨‍👩‍👧‍👦');

        expect(format2('{:#.2s}', [s2]), '👨…');
        expect(format2('{:#.4s}', [s2]), '👨+👩…');
        expect(format2('{:#.6s}', [s2]), '👨+👩+👧…');
        expect(format2('{:#.8s}', [s2]), '👨+👩+👧+👦…');
        expect(format2('{:#.10s}', [s2]), '👨+👩+👧+👦=👨‍👩‍👧‍👦');
      });

      test('width, align and fill', () {
        expect(format2('{:16s}', [s]), 'Hello world     ');
        expect(format2('{:>16s}', [s]), '     Hello world');
        expect(format2('{:^16s}', [s]), '  Hello world   ');
        expect(format2('{:<16s}', [s]), 'Hello world     ');

        expect(format2('{:*>16s}', [s]), '*****Hello world');
        expect(format2('{:*^16s}', [s]), '**Hello world***');
        expect(format2('{:*<16s}', [s]), 'Hello world*****');

        expect(format2('{:*>16.0s}', [s]), '****************');
        expect(format2('{:*^16.0s}', [s]), '****************');
        expect(format2('{:*<16.0s}', [s]), '****************');

        expect(format2('{:*>16.5s}', [s]), '***********Hello');
        expect(format2('{:*^16.5s}', [s]), '*****Hello******');
        expect(format2('{:*<16.5s}', [s]), 'Hello***********');

        expect(format2('{:*>#16.6s}', [s]), '**********Hello…');
        expect(format2('{:*^#16.6s}', [s]), '*****Hello…*****');
        expect(format2('{:*<#16.6s}', [s]), 'Hello…**********');

        expect(format2('{:15s}', [s2]), '👨+👩+👧+👦=👨‍👩‍👧‍👦      ');
        expect(format2('{:>15s}', [s2]), '      👨+👩+👧+👦=👨‍👩‍👧‍👦');
        expect(format2('{:^15s}', [s2]), '   👨+👩+👧+👦=👨‍👩‍👧‍👦   ');
        expect(format2('{:<15s}', [s2]), '👨+👩+👧+👦=👨‍👩‍👧‍👦      ');

        expect(
          format2('{:💜>15s}', [s2]),
          '💜💜💜💜💜💜👨+👩+👧+👦=👨‍👩‍👧‍👦',
        );
        expect(
          format2('{:💜^15s}', [s2]),
          '💜💜💜👨+👩+👧+👦=👨‍👩‍👧‍👦💜💜💜',
        );
        expect(
          format2('{:💜<15s}', [s2]),
          '👨+👩+👧+👦=👨‍👩‍👧‍👦💜💜💜💜💜💜',
        );

        expect(format2('{:❓>15.0s}', [s2]), '❓❓❓❓❓❓❓❓❓❓❓❓❓❓❓');
        expect(format2('{:❓^15.0s}', [s2]), '❓❓❓❓❓❓❓❓❓❓❓❓❓❓❓');
        expect(format2('{:❓<15.0s}', [s2]), '❓❓❓❓❓❓❓❓❓❓❓❓❓❓❓');

        expect(format2('{:💚>15.7s}', [s2]), '💚💚💚💚💚💚💚💚👨+👩+👧+👦');
        expect(format2('{:💚^15.7s}', [s2]), '💚💚💚💚👨+👩+👧+👦💚💚💚💚');
        expect(format2('{:💚<15.7s}', [s2]), '👨+👩+👧+👦💚💚💚💚💚💚💚💚');

        expect(format2('{:🩵>#15.8s}', [s2]), '🩵🩵🩵🩵🩵🩵🩵👨+👩+👧+👦…');
        expect(format2('{:🩵^#15.8s}', [s2]), '🩵🩵🩵👨+👩+👧+👦…🩵🩵🩵🩵');
        expect(format2('{:🩵<#15.8s}', [s2]), '👨+👩+👧+👦…🩵🩵🩵🩵🩵🩵🩵');

        expect(format2('{:0>4}', ['5']), '0005');
        expect(format2('{:0<4}', ['5']), '5000');
        expect(format2('{:04}', ['5']), '5000');
      });
    });

    group('b:', () {
      const n = 0xAA;

      test('basic use', () {
        expect(
          () => format2('{:b}', [123.0]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:b} Formatter for type double'
                          ' and specifier b is not registered',
            ),
          ),
        );

        expect(format2('{:b}', [n]), '10101010');
        expect(format2('{:b}', [-n]), '-10101010');

        expect(
          format2('{:b}', [9223372036854775807]),
          '111111111111111111111111111111111111111111111111111111111111111',
        );
        expect(
          format2('{:b}', [-9223372036854775807]),
          '-111111111111111111111111111111111111111111111111111111111111111',
        );
        expect(
          format2('{:b}', [-9223372036854775808]),
          '-1000000000000000000000000000000000000000000000000000000000000000',
        );
      });

      test('sign', () {
        expect(format2('{:+b}', [n]), '+10101010');
        expect(format2('{:-b}', [n]), '10101010');
        expect(format2('{: b}', [n]), ' 10101010');
        expect(format2('{:+b}', [-n]), '-10101010');
        expect(format2('{:-b}', [-n]), '-10101010');
        expect(format2('{: b}', [-n]), '-10101010');
      });

      test('align', () {
        expect(format2('{:12b}', [n]), '    10101010');
        expect(format2('{:12b}', [-n]), '   -10101010');
      });

      test('zero', () {
        expect(format2('{:0b}', [n]), '10101010');
        expect(format2('{:012b}', [n]), '000010101010');
        expect(format2('{:012b}', [-n]), '-00010101010');
        // zero flag is ignored
        expect(format2('{:@>012b}', [n]), '@@@@10101010');
        expect(format2('{:@>012b}', [-n]), '@@@-10101010');
      });

      test('group', () {
        expect(format2('{:_b}', [n]), '1010_1010');
        expect(format2('{:14_b}', [n]), '     1010_1010');
        expect(format2('{:014_b}', [n]), '0000_1010_1010');
        expect(format2('{:015_b}', [n]), '0_0000_1010_1010');
        expect(format2('{:016_b}', [n]), '0_0000_1010_1010');

        expect(format2('{:_b}', [-n]), '-1010_1010');
        expect(format2('{:14_b}', [-n]), '    -1010_1010');
        expect(format2('{:014_b}', [-n]), '-000_1010_1010');
        expect(format2('{:015_b}', [-n]), '-0000_1010_1010');
        expect(format2('{:016_b}', [-n]), '-0_0000_1010_1010');

        // zero flag is ignored
        expect(format2('{:@>016_b}', [n]), '@@@@@@@1010_1010');
        expect(format2('{:@>016_b}', [-n]), '@@@@@@-1010_1010');

        expect(
          () => format2('{:,b}', [n]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      "{:,b} Group option ',' is not supported by specifier b",
            ),
          ),
        );
      });

      test('alt', () {
        expect(
          () => format2('{:#b}', [n]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:#b} Alternate form (#)'
                          ' is not supported by specifier b',
            ),
          ),
        );
      });

      test('precision', () {
        expect(
          () => format2('{:.2b}', [n]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:.2b} Precision is not supported by specifier b',
            ),
          ),
        );
      });
    });

    group('o:', () {
      const n = 2739128;

      test('basic use', () {
        expect(
          () => format2('{:o}', [123.0]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:o} Formatter for type double'
                          ' and specifier o is not registered',
            ),
          ),
        );

        expect(format2('{:o}', [n]), '12345670');
        expect(format2('{:o}', [-n]), '-12345670');

        expect(format2('{:o}', [9223372036854775807]), '777777777777777777777');
        expect(
          format2('{:o}', [-9223372036854775807]),
          '-777777777777777777777',
        );
        expect(
          format2('{:o}', [-9223372036854775808]),
          '-1000000000000000000000',
        );
      });

      test('sign', () {
        expect(format2('{:+o}', [n]), '+12345670');
        expect(format2('{:-o}', [n]), '12345670');
        expect(format2('{: o}', [n]), ' 12345670');
        expect(format2('{:+o}', [-n]), '-12345670');
        expect(format2('{:-o}', [-n]), '-12345670');
        expect(format2('{: o}', [-n]), '-12345670');
      });

      test('align', () {
        expect(format2('{:12o}', [n]), '    12345670');
        expect(format2('{:12o}', [-n]), '   -12345670');
      });

      test('zero', () {
        expect(format2('{:0o}', [n]), '12345670');
        expect(format2('{:012o}', [n]), '000012345670');
        expect(format2('{:012o}', [-n]), '-00012345670');
        // zero flag is ignored
        expect(format2('{:@>012o}', [n]), '@@@@12345670');
        expect(format2('{:@>012o}', [-n]), '@@@-12345670');
      });

      test('group', () {
        expect(format2('{:_o}', [n]), '1234_5670');
        expect(format2('{:14_o}', [n]), '     1234_5670');
        expect(format2('{:014_o}', [n]), '0000_1234_5670');
        expect(format2('{:015_o}', [n]), '0_0000_1234_5670');
        expect(format2('{:016_o}', [n]), '0_0000_1234_5670');

        expect(format2('{:_o}', [-n]), '-1234_5670');
        expect(format2('{:14_o}', [-n]), '    -1234_5670');
        expect(format2('{:014_o}', [-n]), '-000_1234_5670');
        expect(format2('{:015_o}', [-n]), '-0000_1234_5670');
        expect(format2('{:016_o}', [-n]), '-0_0000_1234_5670');

        // zero flag is ignored
        expect(format2('{:@>016_o}', [n]), '@@@@@@@1234_5670');
        expect(format2('{:@>016_o}', [-n]), '@@@@@@-1234_5670');

        expect(
          () => format2('{:,o}', [n]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      "{:,o} Group option ',' is not supported by specifier o",
            ),
          ),
        );
      });

      test('alt', () {
        expect(
          () => format2('{:#o}', [n]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:#o} Alternate form (#)'
                          ' is not supported by specifier o',
            ),
          ),
        );
      });

      test('precision', () {
        expect(
          () => format2('{:.2o}', [n]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:.2o} Precision is not supported by specifier o',
            ),
          ),
        );
      });
    });

    group('x:', () {
      const n = 0x12ABCDEF;

      test('basic use', () {
        expect(
          () => format2('{:x}', [123.0]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:x} Formatter for type double'
                          ' and specifier x is not registered',
            ),
          ),
        );

        expect(format2('{:x}', [n]), '12abcdef');
        expect(format2('{:x}', [-n]), '-12abcdef');

        expect(format2('{:x}', [9223372036854775807]), '7fffffffffffffff');
        expect(format2('{:x}', [-9223372036854775807]), '-7fffffffffffffff');
        expect(format2('{:x}', [-9223372036854775808]), '-8000000000000000');
      });

      test('sign', () {
        expect(format2('{:+x}', [n]), '+12abcdef');
        expect(format2('{:-x}', [n]), '12abcdef');
        expect(format2('{: x}', [n]), ' 12abcdef');
        expect(format2('{:+x}', [-n]), '-12abcdef');
        expect(format2('{:-x}', [-n]), '-12abcdef');
        expect(format2('{: x}', [-n]), '-12abcdef');
      });

      test('align', () {
        expect(format2('{:12x}', [n]), '    12abcdef');
        expect(format2('{:12x}', [-n]), '   -12abcdef');
      });

      test('zero', () {
        expect(format2('{:0x}', [n]), '12abcdef');
        expect(format2('{:012x}', [n]), '000012abcdef');
        expect(format2('{:012x}', [-n]), '-00012abcdef');
        // zero flag is ignored
        expect(format2('{:@>012x}', [n]), '@@@@12abcdef');
      });

      test('group', () {
        expect(format2('{:_x}', [n]), '12ab_cdef');
        expect(format2('{:14_x}', [n]), '     12ab_cdef');
        expect(format2('{:014_x}', [n]), '0000_12ab_cdef');
        expect(format2('{:015_x}', [n]), '0_0000_12ab_cdef');
        expect(format2('{:016_x}', [n]), '0_0000_12ab_cdef');

        expect(format2('{:_x}', [-n]), '-12ab_cdef');
        expect(format2('{:14_x}', [-n]), '    -12ab_cdef');
        expect(format2('{:014_x}', [-n]), '-000_12ab_cdef');
        expect(format2('{:015_x}', [-n]), '-0000_12ab_cdef');
        expect(format2('{:016_x}', [-n]), '-0_0000_12ab_cdef');

        // zero flag is ignored
        expect(format2('{:@>016_x}', [n]), '@@@@@@@12ab_cdef');
        expect(format2('{:@>016_x}', [-n]), '@@@@@@-12ab_cdef');

        expect(
          () => format2('{:,x}', [n]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      "{:,x} Group option ',' is not supported by specifier x",
            ),
          ),
        );
      });

      test('alt', () {
        expect(format2('{:#x}', [n]), '0x12abcdef');
        expect(format2('{:#14x}', [n]), '    0x12abcdef');
        expect(format2('{:#014x}', [n]), '0x000012abcdef');
        expect(format2('{:#_x}', [n]), '0x12ab_cdef');
        expect(format2('{:#12_x}', [n]), ' 0x12ab_cdef');
        expect(format2('{:#012_x}', [n]), '0x0_12ab_cdef');
        expect(format2('{:#013_x}', [n]), '0x0_12ab_cdef');

        expect(format2('{:#x}', [-n]), '-0x12abcdef');
        expect(format2('{:#14x}', [-n]), '   -0x12abcdef');
        expect(format2('{:#014x}', [-n]), '-0x00012abcdef');
        expect(format2('{:#_x}', [-n]), '-0x12ab_cdef');
        expect(format2('{:#13_x}', [-n]), ' -0x12ab_cdef');
        expect(format2('{:#013_x}', [-n]), '-0x0_12ab_cdef');
        expect(format2('{:#014_x}', [-n]), '-0x0_12ab_cdef');
      });

      test('precision', () {
        expect(
          () => format2('{:.2x}', [n]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:.2x} Precision is not supported by specifier x',
            ),
          ),
        );
      });
    });

    group('X:', () {
      const n = 0x12ABCDEF;

      test('basic use', () {
        expect(
          () => format2('{:X}', [123.0]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:X} Formatter for type double'
                          ' and specifier X is not registered',
            ),
          ),
        );

        expect(format2('{:X}', [n]), '12ABCDEF');
        expect(format2('{:X}', [n]), '12ABCDEF');

        expect(format2('{:X}', [9223372036854775807]), '7FFFFFFFFFFFFFFF');
        expect(format2('{:X}', [-9223372036854775807]), '-7FFFFFFFFFFFFFFF');
        expect(format2('{:X}', [-9223372036854775808]), '-8000000000000000');
      });

      test('sign', () {
        expect(format2('{:+X}', [n]), '+12ABCDEF');
        expect(format2('{:-X}', [n]), '12ABCDEF');
        expect(format2('{: X}', [n]), ' 12ABCDEF');
        expect(format2('{:+X}', [-n]), '-12ABCDEF');
        expect(format2('{:-X}', [-n]), '-12ABCDEF');
        expect(format2('{: X}', [-n]), '-12ABCDEF');
      });

      test('align', () {
        expect(format2('{:12X}', [n]), '    12ABCDEF');
      });

      test('zero', () {
        expect(format2('{:0X}', [n]), '12ABCDEF');
        expect(format2('{:012X}', [n]), '000012ABCDEF');
        // zero flag is ignored
        expect(format2('{:@>012X}', [n]), '@@@@12ABCDEF');
      });

      test('group', () {
        expect(format2('{:_X}', [n]), '12AB_CDEF');
        expect(format2('{:14_X}', [n]), '     12AB_CDEF');
        expect(format2('{:014_X}', [n]), '0000_12AB_CDEF');
        expect(format2('{:015_X}', [n]), '0_0000_12AB_CDEF');
        expect(format2('{:016_X}', [n]), '0_0000_12AB_CDEF');
        // zero flag is ignored
        expect(format2('{:@>016_X}', [n]), '@@@@@@@12AB_CDEF');

        expect(
          () => format2('{:,X}', [n]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      "{:,X} Group option ',' is not supported by specifier X",
            ),
          ),
        );
      });

      test('alt', () {
        expect(format2('{:#X}', [n]), '0x12ABCDEF');
        expect(format2('{:#_X}', [n]), '0x12AB_CDEF');
      });

      test('precision', () {
        expect(
          () => format2('{:.2X}', [n]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:.2X} Precision is not supported by specifier X',
            ),
          ),
        );
      });
    });

    group('d:', () {
      group('int', () {
        const n = 123456789;

        test('basic use', () {
          expect(
            () => format2('{:d}', [123.0]),
            throwsA(
              predicate(
                (e) =>
                    e is ArgumentError &&
                    e.message ==
                        '{:d} Formatter for type double'
                            ' and specifier d is not registered',
              ),
            ),
          );

          expect(format2('{}', [n]), '123456789');
          expect(format2('{:d}', [n]), '123456789');

          expect(format2('{}', [9223372036854775807]), '9223372036854775807');
          expect(format2('{}', [-9223372036854775807]), '-9223372036854775807');
          expect(format2('{}', [-9223372036854775808]), '-9223372036854775808');
        });

        test('sign', () {
          expect(format2('{:+d}', [n]), '+123456789');
          expect(format2('{:-d}', [n]), '123456789');
          expect(format2('{: d}', [n]), ' 123456789');
          expect(format2('{:+d}', [-n]), '-123456789');
          expect(format2('{:-d}', [-n]), '-123456789');
          expect(format2('{: d}', [-n]), '-123456789');
        });

        test('align', () {
          expect(format2('{:13d}', [n]), '    123456789');
        });

        test('zero', () {
          expect(format2('{:0d}', [n]), '123456789');
          expect(format2('{:013d}', [n]), '0000123456789');
          // zero flag is ignored
          expect(format2('{:@>013d}', [n]), '@@@@123456789');
        });

        test('group', () {
          expect(format2('{:,d}', [n]), '123,456,789');
          expect(format2('{:_d}', [n]), '123_456_789');
          expect(format2('{:15,d}', [n]), '    123,456,789');
          expect(format2('{:15_d}', [n]), '    123_456_789');
          expect(format2('{:015,d}', [n]), '000,123,456,789');
          expect(format2('{:015_d}', [n]), '000_123_456_789');
          expect(format2('{:016,d}', [n]), '0,000,123,456,789');
          expect(format2('{:017,d}', [n]), '0,000,123,456,789');

          // zero flag is ignored
          expect(format2('{:@>017,d}', [n]), '@@@@@@123,456,789');
        });

        test('alt', () {
          expect(
            () => format2('{:#d}', [n]),
            throwsA(
              predicate(
                (e) =>
                    e is ArgumentError &&
                    e.message ==
                        '{:#d} Alternate form (#)'
                            ' is not supported by specifier d',
              ),
            ),
          );
        });

        test('precision', () {
          expect(
            () => format2('{:.2}', [n]),
            throwsA(
              predicate(
                (e) =>
                    e is ArgumentError &&
                    e.message ==
                        '{:.2} Precision is not supported by specifier d',
              ),
            ),
          );

          expect(
            () => format2('{:.2d}', [n]),
            throwsA(
              predicate(
                (e) =>
                    e is ArgumentError &&
                    e.message ==
                        '{:.2d} Precision is not supported by specifier d',
              ),
            ),
          );
        });
      });

      group('BigInt', () {
        final n = BigInt.from(123456789);

        test('basic use', () {
          expect(format2('{}', [n]), '123456789');
          expect(format2('{:d}', [n]), '123456789');

          expect(
            format2('{}', [BigInt.from(9223372036854775807)]),
            '9223372036854775807',
          );
          expect(
            format2('{}', [BigInt.from(-9223372036854775807)]),
            '-9223372036854775807',
          );
          expect(
            format2('{}', [BigInt.from(-9223372036854775808)]),
            '-9223372036854775808',
          );
        });

        test('sign', () {
          expect(format2('{:+d}', [n]), '+123456789');
          expect(format2('{:-d}', [n]), '123456789');
          expect(format2('{: d}', [n]), ' 123456789');
          expect(format2('{:+d}', [-n]), '-123456789');
          expect(format2('{:-d}', [-n]), '-123456789');
          expect(format2('{: d}', [-n]), '-123456789');
        });

        test('align', () {
          expect(format2('{:13d}', [n]), '    123456789');
        });

        test('zero', () {
          expect(format2('{:0d}', [n]), '123456789');
          expect(format2('{:013d}', [n]), '0000123456789');
          // zero flag is ignored
          expect(format2('{:@>013d}', [n]), '@@@@123456789');
        });

        test('group', () {
          expect(format2('{:,d}', [n]), '123,456,789');
          expect(format2('{:_d}', [n]), '123_456_789');
          expect(format2('{:15,d}', [n]), '    123,456,789');
          expect(format2('{:15_d}', [n]), '    123_456_789');
          expect(format2('{:015,d}', [n]), '000,123,456,789');
          expect(format2('{:015_d}', [n]), '000_123_456_789');
          expect(format2('{:016,d}', [n]), '0,000,123,456,789');
          expect(format2('{:017,d}', [n]), '0,000,123,456,789');

          // zero flag is ignored
          expect(format2('{:@>017,d}', [n]), '@@@@@@123,456,789');
        });

        test('alt', () {
          expect(
            () => format2('{:#d}', [n]),
            throwsA(
              predicate(
                (e) =>
                    e is ArgumentError &&
                    e.message ==
                        '{:#d} Alternate form (#)'
                            ' is not supported by specifier d',
              ),
            ),
          );
        });

        test('precision', () {
          expect(
            () => format2('{:.2}', [n]),
            throwsA(
              predicate(
                (e) =>
                    e is ArgumentError &&
                    e.message ==
                        '{:.2} Precision is not supported by specifier d',
              ),
            ),
          );

          expect(
            () => format2('{:.2d}', [n]),
            throwsA(
              predicate(
                (e) =>
                    e is ArgumentError &&
                    e.message ==
                        '{:.2d} Precision is not supported by specifier d',
              ),
            ),
          );
        });
      });
    });

    group('f:', () {
      const n = 12345.6789;

      test('basic use', () {
        expect(
          () => format2('{:f}', [123]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:f} Formatter for type int'
                          ' and specifier f is not registered',
            ),
          ),
        );

        expect(format2('{:f}', [n]), '12345.678900');
        expect(format2('{:f}', [-n]), '-12345.678900');
      });

      test('sign', () {
        expect(format2('{:+f}', [n]), '+12345.678900');
        expect(format2('{:-f}', [n]), '12345.678900');
        expect(format2('{: f}', [n]), ' 12345.678900');
        expect(format2('{:+f}', [-n]), '-12345.678900');
        expect(format2('{:-f}', [-n]), '-12345.678900');
        expect(format2('{: f}', [-n]), '-12345.678900');
      });

      test('align', () {
        expect(format2('{:16f}', [n]), '    12345.678900');
      });

      test('zero', () {
        expect(format2('{:0f}', [n]), '12345.678900');
        expect(format2('{:016f}', [n]), '000012345.678900');
        expect(format2('{:0f}', [-n]), '-12345.678900');
        expect(format2('{:016f}', [-n]), '-00012345.678900');

        // zero flag is ignored
        expect(format2('{:@>016f}', [n]), '@@@@12345.678900');
        expect(format2('{:@>016f}', [-n]), '@@@-12345.678900');
      });

      test('group', () {
        expect(format2('{:,f}', [n]), '12,345.678900');
        expect(format2('{:_f}', [n]), '12_345.678900');
        expect(format2('{:18,f}', [n]), '     12,345.678900');
        expect(format2('{:18_f}', [n]), '     12_345.678900');
        expect(format2('{:018,f}', [n]), '000,012,345.678900');
        expect(format2('{:018_f}', [n]), '000_012_345.678900');
        expect(format2('{:019,f}', [n]), '0,000,012,345.678900');
        expect(format2('{:019_f}', [n]), '0_000_012_345.678900');
        expect(format2('{:020,f}', [n]), '0,000,012,345.678900');
        expect(format2('{:020_f}', [n]), '0_000_012_345.678900');
        // zero flag is ignored
        expect(format2('{:@>020_f}', [n]), '@@@@@@@12_345.678900');
      });

      test('alt', () {
        expect(format2('{:#f}', [n]), '12345.678900');
        expect(format2('{:#.0f}', [n]), '12346.');
      });

      test('precision', () {
        expect(format2('{:.0f}', [n]), '12346');
        expect(format2('{:.1f}', [n]), '12345.7');
        expect(format2('{:.2f}', [n]), '12345.68');
        expect(format2('{:.3f}', [n]), '12345.679');
        expect(format2('{:.4f}', [n]), '12345.6789');
        expect(format2('{:.5f}', [n]), '12345.67890');
      });

      test('nan and inf', () {
        // Zero flag is ignored.
        const nan = double.nan;
        const inf = double.infinity;
        assert(-inf == double.negativeInfinity);

        expect(format2('{:f}', [nan]), 'nan');
        expect(format2('{:-f}', [nan]), 'nan');
        expect(format2('{:+f}', [nan]), 'nan');
        expect(format2('{: f}', [nan]), 'nan');
        expect(format2('{:f}', [-nan]), 'nan');
        expect(format2('{:-f}', [-nan]), 'nan');
        expect(format2('{:+f}', [-nan]), 'nan');
        expect(format2('{: f}', [-nan]), 'nan');

        expect(format2('{:0>06f}', [nan]), '000nan');
        expect(format2('{:@>06f}', [nan]), '@@@nan');

        expect(format2('{:06f}', [nan]), '   nan');
        expect(format2('{:-06f}', [nan]), '   nan');
        expect(format2('{:+06f}', [nan]), '   nan');
        expect(format2('{: 06f}', [nan]), '   nan');
        expect(format2('{:06f}', [-nan]), '   nan');
        expect(format2('{:-06f}', [-nan]), '   nan');
        expect(format2('{:+06f}', [-nan]), '   nan');
        expect(format2('{: 06f}', [-nan]), '   nan');

        expect(format2('{:#,f}', [nan]), 'nan');
        expect(format2('{:#06f}', [nan]), '   nan');

        expect(format2('{:f}', [inf]), 'inf');
        expect(format2('{:-f}', [inf]), 'inf');
        expect(format2('{:+f}', [inf]), '+inf');
        expect(format2('{: f}', [inf]), ' inf');
        expect(format2('{:f}', [-inf]), '-inf');
        expect(format2('{:-f}', [-inf]), '-inf');
        expect(format2('{:+f}', [-inf]), '-inf');
        expect(format2('{: f}', [-inf]), '-inf');

        expect(format2('{:0>06f}', [inf]), '000inf');
        expect(format2('{:@>06f}', [inf]), '@@@inf');

        expect(format2('{:06f}', [inf]), '   inf');
        expect(format2('{:-06f}', [inf]), '   inf');
        expect(format2('{:+06f}', [inf]), '  +inf');
        expect(format2('{: 06f}', [inf]), '   inf');
        expect(format2('{:06f}', [-inf]), '  -inf');
        expect(format2('{:-06f}', [-inf]), '  -inf');
        expect(format2('{:+06f}', [-inf]), '  -inf');
        expect(format2('{: 06f}', [-inf]), '  -inf');

        expect(format2('{:#,f}', [inf]), 'inf');
        expect(format2('{:#,f}', [-inf]), '-inf');
        expect(format2('{:#06f}', [inf]), '   inf');
        expect(format2('{:#06f}', [-inf]), '  -inf');

        expect(format2('{:F}', [nan]), 'NAN');
        expect(format2('{:+F}', [nan]), 'NAN');
        expect(format2('{:F}', [inf]), 'INF');
        expect(format2('{:F}', [-inf]), '-INF');
      });
    });

    group('e:', () {
      const n1 = 0.000123456789;
      const n2 = 12345.6789;

      test('basic use', () {
        expect(
          () => format2('{:e}', [123]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:e} Formatter for type int'
                          ' and specifier e is not registered',
            ),
          ),
        );

        expect(format2('{:e}', [n1]), '1.234568e-4');
        expect(format2('{:E}', [n1]), '1.234568E-4');
        expect(format2('{:e}', [-n1]), '-1.234568e-4');
        expect(format2('{:E}', [-n1]), '-1.234568E-4');

        expect(format2('{:e}', [n2]), '1.234568e+4');
        expect(format2('{:E}', [n2]), '1.234568E+4');
        expect(format2('{:e}', [-n2]), '-1.234568e+4');
        expect(format2('{:E}', [-n2]), '-1.234568E+4');
      });

      test('sign', () {
        expect(format2('{:+e}', [n1]), '+1.234568e-4');
        expect(format2('{:-e}', [n1]), '1.234568e-4');
        expect(format2('{: e}', [n1]), ' 1.234568e-4');
        expect(format2('{:+e}', [-n1]), '-1.234568e-4');
        expect(format2('{:-e}', [-n1]), '-1.234568e-4');
        expect(format2('{: e}', [-n1]), '-1.234568e-4');

        expect(format2('{:+e}', [n2]), '+1.234568e+4');
        expect(format2('{:-e}', [n2]), '1.234568e+4');
        expect(format2('{: e}', [n2]), ' 1.234568e+4');
        expect(format2('{:+e}', [-n2]), '-1.234568e+4');
        expect(format2('{:-e}', [-n2]), '-1.234568e+4');
        expect(format2('{: e}', [-n2]), '-1.234568e+4');
      });

      test('align', () {
        expect(format2('{:15e}', [n1]), '    1.234568e-4');
        expect(format2('{:15e}', [n2]), '    1.234568e+4');
      });

      test('zero', () {
        expect(format2('{:0e}', [n1]), '1.234568e-4');
        expect(format2('{:015e}', [n1]), '00001.234568e-4');
        expect(format2('{:0e}', [-n1]), '-1.234568e-4');
        expect(format2('{:015e}', [-n1]), '-0001.234568e-4');
        // zero flag is ignored
        expect(format2('{:@>015e}', [n1]), '@@@@1.234568e-4');
        expect(format2('{:@>015e}', [-n1]), '@@@-1.234568e-4');

        expect(format2('{:0e}', [n2]), '1.234568e+4');
        expect(format2('{:015e}', [n2]), '00001.234568e+4');
        expect(format2('{:0e}', [-n2]), '-1.234568e+4');
        expect(format2('{:015e}', [-n2]), '-0001.234568e+4');
        // zero flag is ignored
        expect(format2('{:@>015e}', [n2]), '@@@@1.234568e+4');
        expect(format2('{:@>015e}', [-n2]), '@@@-1.234568e+4');
      });

      test('group', () {
        expect(format2('{:,e}', [n1]), '1.234568e-4');
        expect(format2('{:_e}', [n1]), '1.234568e-4');
        expect(format2('{:17,e}', [n1]), '      1.234568e-4');
        expect(format2('{:17_e}', [n1]), '      1.234568e-4');
        expect(format2('{:017,e}', [n1]), '000,001.234568e-4');
        expect(format2('{:017_e}', [n1]), '000_001.234568e-4');
        expect(format2('{:018,e}', [n1]), '0,000,001.234568e-4');
        expect(format2('{:019,e}', [n1]), '0,000,001.234568e-4');
        expect(format2('{:012,.0e}', [n1]), '0,000,001e-4');
        // zero flag is ignored
        expect(format2('{:@>012,.0e}', [n1]), '@@@@@@@@1e-4');

        expect(format2('{:,e}', [n2]), '1.234568e+4');
        expect(format2('{:_e}', [n2]), '1.234568e+4');
        expect(format2('{:17,e}', [n2]), '      1.234568e+4');
        expect(format2('{:17_e}', [n2]), '      1.234568e+4');
        expect(format2('{:017,e}', [n2]), '000,001.234568e+4');
        expect(format2('{:017_e}', [n2]), '000_001.234568e+4');
        expect(format2('{:018,e}', [n2]), '0,000,001.234568e+4');
        expect(format2('{:019,e}', [n2]), '0,000,001.234568e+4');
        expect(format2('{:012,.0e}', [n2]), '0,000,001e+4');
        // zero flag is ignored
        expect(format2('{:@>012,.0e}', [n2]), '@@@@@@@@1e+4');
      });

      test('alt', () {
        expect(format2('{:#e}', [n1]), '1.234568e-4');
        expect(format2('{:#.0e}', [n1]), '1.e-4');

        expect(format2('{:#e}', [n2]), '1.234568e+4');
        expect(format2('{:#.0e}', [n2]), '1.e+4');
      });

      test('precision', () {
        expect(format2('{:.0e}', [n1]), '1e-4');
        expect(format2('{:.1e}', [n1]), '1.2e-4');
        expect(format2('{:.2e}', [n1]), '1.23e-4');
        expect(format2('{:.3e}', [n1]), '1.235e-4');
        expect(format2('{:.4e}', [n1]), '1.2346e-4');
        expect(format2('{:.5e}', [n1]), '1.23457e-4');
        expect(format2('{:.6e}', [n1]), '1.234568e-4');
        expect(format2('{:.7e}', [n1]), '1.2345679e-4');
        expect(format2('{:.8e}', [n1]), '1.23456789e-4');
        expect(format2('{:.9e}', [n1]), '1.234567890e-4');

        expect(format2('{:.0e}', [n2]), '1e+4');
        expect(format2('{:.1e}', [n2]), '1.2e+4');
        expect(format2('{:.2e}', [n2]), '1.23e+4');
        expect(format2('{:.3e}', [n2]), '1.235e+4');
        expect(format2('{:.4e}', [n2]), '1.2346e+4');
        expect(format2('{:.5e}', [n2]), '1.23457e+4');
        expect(format2('{:.6e}', [n2]), '1.234568e+4');
        expect(format2('{:.7e}', [n2]), '1.2345679e+4');
        expect(format2('{:.8e}', [n2]), '1.23456789e+4');
        expect(format2('{:.9e}', [n2]), '1.234567890e+4');
      });

      test('nan and inf', () {
        // В отличие от Python и C++ флаг zero для NaN и Infinity игнорирую.
        const nan = double.nan;
        const inf = double.infinity;
        assert(-inf == double.negativeInfinity);

        expect(format2('{:e}', [nan]), 'nan');
        expect(format2('{:-e}', [nan]), 'nan');
        expect(format2('{:+e}', [nan]), 'nan');
        expect(format2('{: e}', [nan]), 'nan');
        expect(format2('{:e}', [-nan]), 'nan');
        expect(format2('{:-e}', [-nan]), 'nan');
        expect(format2('{:+e}', [-nan]), 'nan');
        expect(format2('{: e}', [-nan]), 'nan');

        expect(format2('{:06e}', [nan]), '   nan');
        expect(format2('{:-06e}', [nan]), '   nan');
        expect(format2('{:+06e}', [nan]), '   nan');
        expect(format2('{: 06e}', [nan]), '   nan');
        expect(format2('{:06e}', [-nan]), '   nan');
        expect(format2('{:-06e}', [-nan]), '   nan');
        expect(format2('{:+06e}', [-nan]), '   nan');
        expect(format2('{: 06e}', [-nan]), '   nan');

        expect(format2('{:#,e}', [nan]), 'nan');
        expect(format2('{:#06e}', [nan]), '   nan');

        expect(format2('{:e}', [inf]), 'inf');
        expect(format2('{:-e}', [inf]), 'inf');
        expect(format2('{:+e}', [inf]), '+inf');
        expect(format2('{: e}', [inf]), ' inf');
        expect(format2('{:e}', [-inf]), '-inf');
        expect(format2('{:-e}', [-inf]), '-inf');
        expect(format2('{:+e}', [-inf]), '-inf');
        expect(format2('{: e}', [-inf]), '-inf');

        expect(format2('{:06e}', [inf]), '   inf');
        expect(format2('{:-06e}', [inf]), '   inf');
        expect(format2('{:+06e}', [inf]), '  +inf');
        expect(format2('{: 06e}', [inf]), '   inf');
        expect(format2('{:06e}', [-inf]), '  -inf');
        expect(format2('{:-06e}', [-inf]), '  -inf');
        expect(format2('{:+06e}', [-inf]), '  -inf');
        expect(format2('{: 06e}', [-inf]), '  -inf');

        expect(format2('{:#,e}', [inf]), 'inf');
        expect(format2('{:#,e}', [-inf]), '-inf');
        expect(format2('{:#06e}', [inf]), '   inf');
        expect(format2('{:#06e}', [-inf]), '  -inf');

        expect(format2('{:E}', [nan]), 'NAN');
        expect(format2('{:+E}', [nan]), 'NAN');
        expect(format2('{:E}', [inf]), 'INF');
        expect(format2('{:E}', [-inf]), '-INF');
      });
    });

    group('g:', () {
      test('basic use', () {
        expect(
          () => format2('{:g}', [123]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:g} Formatter for type int'
                          ' and specifier g is not registered',
            ),
          ),
        );

        expect(format2('{:g}', [0.0]), '0');
        expect(format2('{:g}', [0.000001]), '0.000001');
        expect(format2('{:g}', [0.0000001]), '1e-7');
        expect(format2('{:G}', [0.0000001]), '1E-7');
        expect(format2('{:g}', [123456.0]), '123456');
        expect(format2('{:g}', [1234567.0]), '1.23457e+6');
        expect(format2('{:G}', [1234567.0]), '1.23457E+6');
      });

      test('precision', () {
        expect(format2('{:.1g}', [0.12]), '0.1');
        expect(format2('{:.1g}', [1.2]), '1');
        expect(format2('{:.1g}', [12.0]), '1e+1');
        expect(format2('{:.2g}', [12.0]), '12');
        expect(format2('{:.3g}', [1.2]), '1.2');
        expect(format2('{:.3g}', [12.0]), '12');
        expect(format2('{:.1g}', [0.000001]), '0.000001');
        expect(format2('{:.15g}', [0.000001]), '0.000001');
        expect(format2('{:.1g}', [0.0000001]), '1e-7');
        expect(format2('{:.15g}', [0.0000001]), '1e-7');
        expect(format2('{:.1g}', [123456.0]), '1e+5');
        expect(format2('{:.15g}', [123456.0]), '123456');
        expect(format2('{:.1g}', [123456789012345.0]), '1e+14');
        expect(format2('{:.15g}', [123456789012345.0]), '123456789012345');
        expect(
          format2('{:.15g}', [1234567890123456.0]),
          '1.23456789012346e+15',
        );
      });

      test('alt', () {
        expect(format2('{:#g}', [1.0]), '1.00000');
        expect(format2('{:#g}', [0.0000001]), '1.00000e-7');
        expect(format2('{:#.1g}', [1.2]), '1.');
        expect(format2('{:#.1g}', [12.0]), '1.e+1');
        expect(format2('{:#.2g}', [12.0]), '12.');
        expect(format2('{:#.3g}', [1.2]), '1.20');
        expect(format2('{:#.3g}', [12.0]), '12.0');
        expect(format2('{:#.15g}', [123456789012345.0]), '123456789012345.');
        expect(format2('{:#.16g}', [123456789012345.0]), '123456789012345.0');
        expect(format2('{:#G}', [0.0000001]), '1.00000E-7');
        expect(format2('{:#.1G}', [12.0]), '1.E+1');
        expect(format2('{:#09g}', [1.0]), '001.00000');
      });

      test('zero', () {
        expect(format2('{:0g}', [0.000001]), '0.000001');
        expect(format2('{:#0g}', [0.000001]), '0.00000100000');
        expect(format2('{:014g}', [0.000001]), '0000000.000001');
        expect(format2('{:#014g}', [0.000001]), '00.00000100000');
        expect(format2('{:0g}', [0.0000001]), '1e-7');
        expect(format2('{:014g}', [0.0000001]), '00000000001e-7');
        expect(format2('{:#014g}', [0.0000001]), '00001.00000e-7');
        // zero flag is ignored
        expect(format2('{:@>#014g}', [0.0000001]), '@@@@1.00000e-7');
      });

      test('group', () {
        expect(format2('{:,.9g}', [123456789.0]), '123,456,789');
        expect(format2('{:_.9g}', [123456789.0]), '123_456_789');
        expect(format2('{:012,.9g}', [123456789.0]), '0,123,456,789');
        expect(format2('{:012_.9g}', [123456789.0]), '0_123_456_789');
        expect(format2('{:013,.9g}', [123456789.0]), '0,123,456,789');
        expect(format2('{:013_.9g}', [123456789.0]), '0_123_456_789');
        // zero flag is ignored
        expect(format2('{:@>013_.9g}', [123456789.0]), '@@123_456_789');

        expect(format2('{:010,g}', [0.0000001]), '000,001e-7');
        expect(format2('{:011,g}', [0.0000001]), '0,000,001e-7');
        expect(format2('{:012,g}', [0.0000001]), '0,000,001e-7');
        // zero flag is ignored
        expect(format2('{:@>012,g}', [0.0000001]), '@@@@@@@@1e-7');

        expect(format2('{:019,.9g}', [1234567890.0]), '000,001.23456789e+9');
        expect(format2('{:020,.9g}', [1234567890.0]), '0,000,001.23456789e+9');
        expect(format2('{:021,.9g}', [1234567890.0]), '0,000,001.23456789e+9');
        // zero flag is ignored
        expect(
          format2('{:@>021,.9g}', [1234567890.0]),
          '@@@@@@@@1.23456789e+9',
        );
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
          () => format2('{:n}', ['123']),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message == '{:n} Expected num. Passed String.',
            ),
          ),
        );

        expect(
          () => format2('{:.0n}', [0.0]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message == '{:.0n} Precision must be >= 1. Passed 0.',
            ),
          ),
        );
      });

      test('integers', () {
        expect(
          () => format2('{:.1n}', [0]),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.message ==
                      '{:.1n} Precision not allowed'
                          " for int with format specifier 'n'.",
            ),
          ),
        );

        expect(format2('{:n}', [0]), '0');
        expect(format2('{:#n}', [0]), '0');

        expect(format2('{:n}', [1]), '1');
        expect(format2('{:04n}', [1]), '0001');
        expect(format2('{:07n}', [1]), '0000001');
        // zero flag is ignored
        expect(format2('{:@>07n}', [1]), '@@@@@@1');

        expect(format2('{:04,n}', [1]), '0,001');
        expect(format2('{:05,n}', [1]), '0,001');
        expect(format2('{:08,n}', [1]), '0,000,001');
        expect(format2('{:09,n}', [1]), '0,000,001');
        // zero flag is ignored
        expect(format2('{:@>09,n}', [1]), '@@@@@@@@1');

        expect(format2('{:n}', [9223372036854775807]), '9223372036854775807');
        expect(format2('{:n}', [-9223372036854775807]), '-9223372036854775807');
        expect(format2('{:n}', [-9223372036854775808]), '-9223372036854775808');
        expect(
          format2('{:,n}', [9223372036854775807]),
          '9,223,372,036,854,775,807',
        );
        expect(
          format2('{:,n}', [-9223372036854775807]),
          '-9,223,372,036,854,775,807',
        );
        expect(
          format2('{:,n}', [-9223372036854775808]),
          '-9,223,372,036,854,775,808',
        );
      });

      group('floats:', () {
        test('simple use', () {
          expect(format2('{:g}', [0.0]), '0');
          expect(format2('{:n}', [0.0]), '0');
          expect(format2('{:g}', [-0.0]), '-0');
          expect(format2('{:n}', [-0.0]), '-0');
          expect(format2('{:g}', [0.000001]), '0.000001');
          expect(format2('{:n}', [0.000001]), '0.000001');
          expect(format2('{:g}', [0.0000001]), '1e-7');
          expect(format2('{:n}', [0.0000001]), '1E-7');
          expect(format2('{:g}', [n]), '123457');
          expect(format2('{:n}', [n]), '123457');
          expect(format2('{:g}', [-n]), '-123457');
          expect(format2('{:n}', [-n]), '-123457');
          expect(format2('{:g}', [n2]), '1.23457e+6');
          expect(format2('{:n}', [n2]), '1.23457E6');
          expect(format2('{:g}', [-n2]), '-1.23457e+6');
          expect(format2('{:n}', [-n2]), '-1.23457E6');
        });

        test('precision', () {
          expect(format2('{:.1g}', [n]), '1e+5');
          expect(format2('{:.1n}', [n]), '1E5');
          expect(format2('{:.2g}', [n]), '1.2e+5');
          expect(format2('{:.2n}', [n]), '1.2E5');
          expect(format2('{:.3g}', [n]), '1.23e+5');
          expect(format2('{:.3n}', [n]), '1.23E5');
          expect(format2('{:.4g}', [n]), '1.235e+5');
          expect(format2('{:.4n}', [n]), '1.235E5');
          expect(format2('{:.5g}', [n]), '1.2346e+5');
          expect(format2('{:.5n}', [n]), '1.2346E5');
          expect(format2('{:.6g}', [n]), '123457');
          expect(format2('{:.6n}', [n]), '123457');
          expect(format2('{:.7g}', [n]), '123456.8');
          expect(format2('{:.7n}', [n]), '123456.8');
          expect(format2('{:.8g}', [n]), '123456.79');
          expect(format2('{:.8n}', [n]), '123456.79');
          expect(format2('{:.9g}', [n]), '123456.789');
          expect(format2('{:.9n}', [n]), '123456.789');
          expect(format2('{:.10g}', [n]), '123456.789');
          expect(format2('{:.10n}', [n]), '123456.789');
        });

        test('zero', () {
          expect(format2('{:0g}', [n]), '123457');
          expect(format2('{:0n}', [n]), '123457');
          expect(format2('{:0g}', [-n]), '-123457');
          expect(format2('{:0n}', [-n]), '-123457');
          expect(format2('{:06g}', [n]), '123457');
          expect(format2('{:06n}', [n]), '123457');
          expect(format2('{:06g}', [-n]), '-123457');
          expect(format2('{:06n}', [-n]), '-123457');
          expect(format2('{:09g}', [n]), '000123457');
          expect(format2('{:09n}', [n]), '000123457');
          expect(format2('{:09g}', [-n]), '-00123457');
          expect(format2('{:09n}', [-n]), '-00123457');
          expect(format2('{:013g}', [n2]), '0001.23457e+6');
          expect(format2('{:013n}', [n2]), '00001.23457E6');
          expect(format2('{:013g}', [-n2]), '-001.23457e+6');
          expect(format2('{:013n}', [-n2]), '-0001.23457E6');
          // zero flag is ignored
          expect(format2('{:@>09g}', [n]), '@@@123457');
          expect(format2('{:@>09n}', [n]), '@@@123457');
          expect(format2('{:@>09g}', [-n]), '@@-123457');
          expect(format2('{:@>09n}', [-n]), '@@-123457');
          expect(format2('{:@>013g}', [n2]), '@@@1.23457e+6');
          expect(format2('{:@>013n}', [n2]), '@@@@1.23457E6');
          expect(format2('{:@>013g}', [-n2]), '@@-1.23457e+6');
          expect(format2('{:@>013n}', [-n2]), '@@@-1.23457E6');

          expect(format2('{:013.9g}', [n]), '000123456.789');
          expect(format2('{:013.9n}', [n]), '000123456.789');
          expect(format2('{:013.9g}', [-n]), '-00123456.789');
          expect(format2('{:013.9n}', [-n]), '-00123456.789');
          expect(format2('{:013.9g}', [n2]), '0001234567.89');
          expect(format2('{:013.9n}', [n2]), '0001234567.89');
          expect(format2('{:013.9g}', [-n2]), '-001234567.89');
          expect(format2('{:013.9n}', [-n2]), '-001234567.89');
        });

        test('alt', () {
          expect(format2('{:#g}', [0.0]), '0.00000');
          expect(format2('{:#n}', [0.0]), '0.00000');
          expect(format2('{:#g}', [-0.0]), '-0.00000');
          expect(format2('{:#n}', [-0.0]), '-0.00000');
          expect(format2('{:#g}', [0.0000001]), '1.00000e-7');
          expect(format2('{:#n}', [0.0000001]), '1.00000E-7');
          expect(format2('{:#g}', [-0.0000001]), '-1.00000e-7');
          expect(format2('{:#n}', [-0.0000001]), '-1.00000E-7');

          expect(format2('{:#g}', [n]), '123457.');
          expect(format2('{:#n}', [n]), '123457.');
          expect(format2('{:#g}', [-n]), '-123457.');
          expect(format2('{:#n}', [-n]), '-123457.');
          expect(format2('{:#.1g}', [n]), '1.e+5');
          expect(format2('{:#.1n}', [n]), '1.E5');
          expect(format2('{:#.1g}', [-n]), '-1.e+5');
          expect(format2('{:#.1n}', [-n]), '-1.E5');
          expect(format2('{:#.12g}', [n]), '123456.789000');
          expect(format2('{:#.12n}', [n]), '123456.789000');
          expect(format2('{:#.12g}', [-n]), '-123456.789000');
          expect(format2('{:#.12n}', [-n]), '-123456.789000');
          expect(format2('{:#016.12g}', [n]), '000123456.789000');
          expect(format2('{:#016.12n}', [n]), '000123456.789000');
          expect(format2('{:#016.12g}', [-n]), '-00123456.789000');
          expect(format2('{:#016.12n}', [-n]), '-00123456.789000');
        });

        test('group option', () {
          expect(format2('{:,g}', [n]), '123,457');
          expect(format2('{:,n}', [n]), '123,457');
          expect(format2('{:,g}', [-n]), '-123,457');
          expect(format2('{:,n}', [-n]), '-123,457');
          expect(format2('{:#,g}', [n]), '123,457.');
          expect(format2('{:#,n}', [n]), '123,457.');
          expect(format2('{:#,g}', [-n]), '-123,457.');
          expect(format2('{:#,n}', [-n]), '-123,457.');
          expect(format2('{:,.9g}', [n]), '123,456.789');
          expect(format2('{:,.9n}', [n]), '123,456.789');
          expect(format2('{:,.9g}', [-n]), '-123,456.789');
          expect(format2('{:,.9n}', [-n]), '-123,456.789');
          expect(format2('{:#,.12g}', [n]), '123,456.789000');
          expect(format2('{:#,.12n}', [n]), '123,456.789000');
          expect(format2('{:#,.12g}', [-n]), '-123,456.789000');
          expect(format2('{:#,.12n}', [-n]), '-123,456.789000');

          expect(format2('{:#015,.12g}', [n]), '0,123,456.789000');
          expect(format2('{:#015,.12n}', [n]), '0,123,456.789000');
          expect(format2('{:#016,.12g}', [-n]), '-0,123,456.789000');
          expect(format2('{:#016,.12n}', [-n]), '-0,123,456.789000');
          expect(format2('{:#016,.12g}', [n]), '0,123,456.789000');
          expect(format2('{:#016,.12n}', [n]), '0,123,456.789000');
          expect(format2('{:#017,.12g}', [-n]), '-0,123,456.789000');
          expect(format2('{:#017,.12n}', [-n]), '-0,123,456.789000');
          expect(format2('{:#019,.12g}', [n]), '0,000,123,456.789000');
          expect(format2('{:#019,.12n}', [n]), '0,000,123,456.789000');
          expect(format2('{:#020,.12g}', [-n]), '-0,000,123,456.789000');
          expect(format2('{:#020,.12n}', [-n]), '-0,000,123,456.789000');
          expect(format2('{:#020,.12g}', [n]), '0,000,123,456.789000');
          expect(format2('{:#020,.12n}', [n]), '0,000,123,456.789000');
          expect(format2('{:#021,.12g}', [-n]), '-0,000,123,456.789000');
          expect(format2('{:#021,.12n}', [-n]), '-0,000,123,456.789000');
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
        expect(format2('{:n}', [i]), '123456789');
        expect(format2('{:n}', [-i]), '-123456789');
        expect(format2('{:012n}', [i]), '000123456789');
        expect(format2('{:013n}', [-i]), '-000123456789');

        expect(format2('{:,n}', [i]), '123,456,789');
        expect(format2('{:,n}', [-i]), '-123,456,789');
        expect(format2('{:015,n}', [i]), '000,123,456,789');
        expect(format2('{:016,n}', [-i]), '-000,123,456,789');
        expect(format2('{:016,n}', [i]), '0,000,123,456,789');
        expect(format2('{:017,n}', [-i]), '-0,000,123,456,789');
        expect(format2('{:017,n}', [i]), '0,000,123,456,789');
        expect(format2('{:018,n}', [-i]), '-0,000,123,456,789');

        expect(format2('{:n}', [0.0]), '0');
        expect(format2('{:n}', [-0.0]), '-0');
        expect(format2('{:#n}', [0.0]), '0.00000');
        expect(format2('{:#n}', [-0.0]), '-0.00000');

        expect(format2('{:n}', [n]), '123457');
        expect(format2('{:n}', [-n]), '-123457');
        expect(format2('{:#n}', [n]), '123457.');
        expect(format2('{:#n}', [-n]), '-123457.');
        expect(format2('{:#014.10n}', [n]), '000123456.7890');
        expect(format2('{:#014.10n}', [-n]), '-00123456.7890');
        expect(format2('{:#018,.10n}', [n]), '0,000,123,456.7890');
        expect(format2('{:#018,.10n}', [-n]), '-0,000,123,456.7890');

        expect(format2('{:n}', [n2]), '1.23457E6');
        expect(format2('{:n}', [-n2]), '-1.23457E6');
        expect(format2('{:#.7n}', [n2]), '1234568.');
        expect(format2('{:#.7n}', [-n2]), '-1234568.');
        expect(format2('{:012n}', [n2]), '0001.23457E6');
        expect(format2('{:012n}', [-n2]), '-001.23457E6');
        expect(format2('{:017,n}', [n2]), '0,000,001.23457E6');
        expect(format2('{:017,n}', [-n2]), '-0,000,001.23457E6');

        expect(format2('{:n}', [nan]), 'NaN');
        expect(format2('{:n}', [-nan]), 'NaN');
        expect(format2('{:n}', [inf]), '∞');
        expect(format2('{:n}', [-inf]), '-∞');
        expect(format2('{:+n}', [inf]), '+∞');
      });

      test('en_IN', () {
        Intl.defaultLocale = 'en_IN';
        expect(format2('{:n}', [i]), '123456789');
        expect(format2('{:n}', [-i]), '-123456789');
        expect(format2('{:012n}', [i]), '000123456789');
        expect(format2('{:013n}', [-i]), '-000123456789');

        expect(format2('{:,n}', [i]), '12,34,56,789');
        expect(format2('{:,n}', [-i]), '-12,34,56,789');
        expect(format2('{:015,n}', [i]), '00,12,34,56,789');
        expect(format2('{:016,n}', [-i]), '-00,12,34,56,789');
        expect(format2('{:016,n}', [i]), '0,00,12,34,56,789');
        expect(format2('{:017,n}', [-i]), '-0,00,12,34,56,789');
        expect(format2('{:017,n}', [i]), '0,00,12,34,56,789');
        expect(format2('{:018,n}', [-i]), '-0,00,12,34,56,789');

        expect(format2('{:n}', [0.0]), '0');
        expect(format2('{:n}', [-0.0]), '-0');
        expect(format2('{:#n}', [0.0]), '0.00000');
        expect(format2('{:#n}', [-0.0]), '-0.00000');

        expect(format2('{:n}', [n]), '123457');
        expect(format2('{:n}', [-n]), '-123457');
        expect(format2('{:#n}', [n]), '123457.');
        expect(format2('{:#n}', [-n]), '-123457.');
        expect(format2('{:#014.10n}', [n]), '000123456.7890');
        expect(format2('{:#014.10n}', [-n]), '-00123456.7890');
        expect(format2('{:#019,.10n}', [n]), '0,00,01,23,456.7890');
        expect(format2('{:#019,.10n}', [-n]), '-0,00,01,23,456.7890');

        expect(format2('{:n}', [n2]), '1.23457E6');
        expect(format2('{:n}', [-n2]), '-1.23457E6');
        expect(format2('{:#.7n}', [n2]), '1234568.');
        expect(format2('{:#.7n}', [-n2]), '-1234568.');
        expect(format2('{:012n}', [n2]), '0001.23457E6');
        expect(format2('{:012n}', [-n2]), '-001.23457E6');
        expect(format2('{:016,n}', [n2]), '0,00,001.23457E6');
        expect(format2('{:016,n}', [-n2]), '-0,00,001.23457E6');

        expect(format2('{:n}', [nan]), 'NaN');
        expect(format2('{:n}', [-nan]), 'NaN');
        expect(format2('{:n}', [inf]), '∞');
        expect(format2('{:n}', [-inf]), '-∞');
        expect(format2('{:+n}', [inf]), '+∞');
      });

      test('ru_RU', () {
        Intl.defaultLocale = 'ru_RU';
        expect(format2('{:n}', [i]), '123456789');
        expect(format2('{:n}', [-i]), '-123456789');
        expect(format2('{:012n}', [i]), '000123456789');
        expect(format2('{:013n}', [-i]), '-000123456789');

        expect(format2('{:,n}', [i]), '123 456 789');
        expect(format2('{:,n}', [-i]), '-123 456 789');
        expect(format2('{:015,n}', [i]), '000 123 456 789');
        expect(format2('{:016,n}', [-i]), '-000 123 456 789');
        expect(format2('{:016,n}', [i]), '0 000 123 456 789');
        expect(format2('{:017,n}', [-i]), '-0 000 123 456 789');
        expect(format2('{:017,n}', [i]), '0 000 123 456 789');
        expect(format2('{:018,n}', [-i]), '-0 000 123 456 789');

        expect(format2('{:n}', [0.0]), '0');
        expect(format2('{:n}', [-0.0]), '-0');
        expect(format2('{:#n}', [0.0]), '0,00000');
        expect(format2('{:#n}', [-0.0]), '-0,00000');

        expect(format2('{:n}', [n]), '123457');
        expect(format2('{:n}', [-n]), '-123457');
        expect(format2('{:#n}', [n]), '123457,');
        expect(format2('{:#n}', [-n]), '-123457,');
        expect(format2('{:#014.10n}', [n]), '000123456,7890');
        expect(format2('{:#014.10n}', [-n]), '-00123456,7890');
        expect(format2('{:#018,.10n}', [n]), '0 000 123 456,7890');
        expect(format2('{:#018,.10n}', [-n]), '-0 000 123 456,7890');

        expect(format2('{:n}', [n2]), '1,23457E6');
        expect(format2('{:n}', [-n2]), '-1,23457E6');
        expect(format2('{:#.7n}', [n2]), '1234568,');
        expect(format2('{:#.7n}', [-n2]), '-1234568,');
        expect(format2('{:012n}', [n2]), '0001,23457E6');
        expect(format2('{:012n}', [-n2]), '-001,23457E6');
        expect(format2('{:017,n}', [n2]), '0 000 001,23457E6');
        expect(format2('{:017,n}', [-n2]), '-0 000 001,23457E6');

        expect(format2('{:n}', [nan]), 'не число');
        expect(format2('{:n}', [-nan]), 'не число');
        expect(format2('{:n}', [inf]), '∞');
        expect(format2('{:n}', [-inf]), '-∞');
        expect(format2('{:+n}', [inf]), '+∞');
      });

      test('ar_EG', () {
        Intl.defaultLocale = 'ar_EG';
        expect(format2('{:n}', [i]), '١٢٣٤٥٦٧٨٩');
        // printA('{:n}', [-i]));
        // \u061C - отметка об арабском письме
        expect(format2('{:n}', [-i]), '\u061C-١٢٣٤٥٦٧٨٩');
        expect(format2('{:012n}', [i]), '٠٠٠١٢٣٤٥٦٧٨٩');
        expect(format2('{:014n}', [-i]), '\u061C-٠٠٠١٢٣٤٥٦٧٨٩');

        expect(format2('{:,n}', [i]), '١٢٣٬٤٥٦٬٧٨٩');
        expect(format2('{:,n}', [-i]), '\u061C-١٢٣٬٤٥٦٬٧٨٩');
        expect(format2('{:015,n}', [i]), '٠٠٠٬١٢٣٬٤٥٦٬٧٨٩');
        expect(format2('{:017,n}', [-i]), '\u061C-٠٠٠٬١٢٣٬٤٥٦٬٧٨٩');
        expect(format2('{:016,n}', [i]), '٠٬٠٠٠٬١٢٣٬٤٥٦٬٧٨٩');
        expect(format2('{:018,n}', [-i]), '\u061C-٠٬٠٠٠٬١٢٣٬٤٥٦٬٧٨٩');
        expect(format2('{:017,n}', [i]), '٠٬٠٠٠٬١٢٣٬٤٥٦٬٧٨٩');
        expect(format2('{:019,n}', [-i]), '\u061C-٠٬٠٠٠٬١٢٣٬٤٥٦٬٧٨٩');

        expect(format2('{:n}', [0.0]), '٠');
        expect(format2('{:n}', [-0.0]), '\u061C-٠');
        expect(format2('{:#n}', [0.0]), '٠٫٠٠٠٠٠');
        expect(format2('{:#n}', [-0.0]), '\u061C-٠٫٠٠٠٠٠');

        expect(format2('{:n}', [n]), '١٢٣٤٥٧');
        expect(format2('{:n}', [-n]), '\u061C-١٢٣٤٥٧');
        expect(format2('{:#n}', [n]), '١٢٣٤٥٧٫');
        expect(format2('{:#n}', [-n]), '\u061C-١٢٣٤٥٧٫');
        expect(format2('{:#014.10n}', [n]), '٠٠٠١٢٣٤٥٦٫٧٨٩٠');
        expect(format2('{:#014.10n}', [-n]), '\u061C-٠١٢٣٤٥٦٫٧٨٩٠');
        expect(format2('{:#018,.10n}', [n]), '٠٬٠٠٠٬١٢٣٬٤٥٦٫٧٨٩٠');
        expect(format2('{:#018,.10n}', [-n]), '\u061C-٠٠٠٬١٢٣٬٤٥٦٫٧٨٩٠');

        expect(format2('{:n}', [n2]), '١٫٢٣٤٥٧أس٦');
        expect(format2('{:n}', [-n2]), '\u061C-١٫٢٣٤٥٧أس٦');
        expect(format2('{:#.7n}', [n2]), '١٢٣٤٥٦٨٫');
        expect(format2('{:#.7n}', [-n2]), '\u061C-١٢٣٤٥٦٨٫');
        expect(format2('{:013n}', [n2]), '٠٠٠١٫٢٣٤٥٧أس٦');
        expect(format2('{:013n}', [-n2]), '\u061C-٠١٫٢٣٤٥٧أس٦');
        expect(format2('{:018,n}', [n2]), '٠٬٠٠٠٬٠٠١٫٢٣٤٥٧أس٦');
        expect(format2('{:018,n}', [-n2]), '\u061C-٠٠٠٬٠٠١٫٢٣٤٥٧أس٦');

        expect(format2('{:n}', [nan]), 'ليس\xA0رقمًا');
        expect(format2('{:n}', [-nan]), 'ليس\xA0رقمًا');
        expect(format2('{:n}', [inf]), '∞');
        expect(format2('{:n}', [-inf]), '\u061C-∞');
        expect(format2('{:+n}', [inf]), '\u061C+∞');
      });

      test('bn', () {
        Intl.defaultLocale = 'bn';
        expect(format2('{:n}', [i]), '১২৩৪৫৬৭৮৯');
        expect(format2('{:n}', [-i]), '-১২৩৪৫৬৭৮৯');
        expect(format2('{:012n}', [i]), '০০০১২৩৪৫৬৭৮৯');
        expect(format2('{:013n}', [-i]), '-০০০১২৩৪৫৬৭৮৯');

        expect(format2('{:,n}', [i]), '১২,৩৪,৫৬,৭৮৯');
        expect(format2('{:,n}', [-i]), '-১২,৩৪,৫৬,৭৮৯');
        expect(format2('{:015,n}', [i]), '০০,১২,৩৪,৫৬,৭৮৯');
        expect(format2('{:016,n}', [-i]), '-০০,১২,৩৪,৫৬,৭৮৯');
        expect(format2('{:016,n}', [i]), '০,০০,১২,৩৪,৫৬,৭৮৯');
        expect(format2('{:017,n}', [-i]), '-০,০০,১২,৩৪,৫৬,৭৮৯');
        expect(format2('{:017,n}', [i]), '০,০০,১২,৩৪,৫৬,৭৮৯');
        expect(format2('{:018,n}', [-i]), '-০,০০,১২,৩৪,৫৬,৭৮৯');

        expect(format2('{:n}', [0.0]), '০');
        expect(format2('{:n}', [-0.0]), '-০');
        expect(format2('{:#n}', [0.0]), '০.০০০০০');
        expect(format2('{:#n}', [-0.0]), '-০.০০০০০');

        expect(format2('{:n}', [n]), '১২৩৪৫৭');
        expect(format2('{:n}', [-n]), '-১২৩৪৫৭');
        expect(format2('{:#n}', [n]), '১২৩৪৫৭.');
        expect(format2('{:#n}', [-n]), '-১২৩৪৫৭.');
        expect(format2('{:#014.10n}', [n]), '০০০১২৩৪৫৬.৭৮৯০');
        expect(format2('{:#014.10n}', [-n]), '-০০১২৩৪৫৬.৭৮৯০');
        expect(format2('{:#019,.10n}', [n]), '০,০০,০১,২৩,৪৫৬.৭৮৯০');
        expect(format2('{:#019,.10n}', [-n]), '-০,০০,০১,২৩,৪৫৬.৭৮৯০');

        expect(format2('{:n}', [n2]), '১.২৩৪৫৭E৬');
        expect(format2('{:n}', [-n2]), '-১.২৩৪৫৭E৬');
        expect(format2('{:#.7n}', [n2]), '১২৩৪৫৬৮.');
        expect(format2('{:#.7n}', [-n2]), '-১২৩৪৫৬৮.');
        expect(format2('{:012n}', [n2]), '০০০১.২৩৪৫৭E৬');
        expect(format2('{:012n}', [-n2]), '-০০১.২৩৪৫৭E৬');
        expect(format2('{:016,n}', [n2]), '০,০০,০০১.২৩৪৫৭E৬');
        expect(format2('{:016,n}', [-n2]), '-০,০০,০০১.২৩৪৫৭E৬');

        expect(format2('{:n}', [nan]), 'NaN');
        expect(format2('{:n}', [-nan]), 'NaN');
        expect(format2('{:n}', [inf]), '∞');
        expect(format2('{:n}', [-inf]), '-∞');
        expect(format2('{:+n}', [inf]), '+∞');
      });

      test('other', () {
        Intl.defaultLocale = 'fa';
        expect(format2('{:n}', [nan]), 'ناعدد');

        Intl.defaultLocale = 'fi';
        expect(format2('{:n}', [nan]), 'epäluku');

        Intl.defaultLocale = 'hy';
        expect(format2('{:n}', [nan]), 'ՈչԹ');

        Intl.defaultLocale = 'ka';
        expect(format2('{:n}', [nan]), 'არ არის რიცხვი');

        Intl.defaultLocale = 'kk';
        expect(format2('{:n}', [nan]), 'сан емес');

        Intl.defaultLocale = 'ky';
        expect(format2('{:n}', [nan]), 'сан эмес');

        Intl.defaultLocale = 'lo';
        expect(format2('{:n}', [nan]), 'ບໍ່​ແມ່ນ​ໂຕ​ເລກ');

        Intl.defaultLocale = 'lv';
        expect(format2('{:n}', [nan]), 'NS');

        Intl.defaultLocale = 'my';
        expect(format2('{:n}', [nan]), 'ဂဏန်းမဟုတ်သော');

        Intl.defaultLocale = 'uz';
        expect(format2('{:n}', [nan]), 'son emas');

        Intl.defaultLocale = 'zh_HK';
        expect(format2('{:n}', [nan]), '非數值');
      });
    });
  });

  group('bugs:', () {
    test('fixed bugs', () {
      expect(format2('{:!>5} {:!>3}', ['1', '3']), '!!!!1 !!3');
    });
  });
}
