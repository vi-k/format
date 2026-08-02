import 'dart:io';

import 'package:test/test.dart';

import '../benchmark/baselines/format2/format2.dart';

void main() {
  test('benchmark baselines are absent from package:format public API', () {
    final exports = File('lib/format.dart').readAsStringSync();
    expect(exports, isNot(contains('benchmark/')));
    expect(exports, isNot(contains('legacyFormat')));
    expect(exports, isNot(contains('sprintf7')));
  });

  test('frozen Format 2 preserves the selected baseline behavior', () {
    expect(legacyFormat('{}', [1.23456789]), '1.23457');
    expect(legacyFormat('{:#X}', [42]), '0x2A');
    expect(legacyFormat('{:e}', [1.0]), '1.000000e+0');
  });
}
