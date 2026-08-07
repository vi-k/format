import 'dart:io';

import 'package:test/test.dart';

import '../baselines/format20/format20.dart';

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
    expect(legacyFormat('{:>5}', [true]), ' true');
    expect(legacyFormat('{:_x}', [3735928559]), 'dead_beef');
  });
}
