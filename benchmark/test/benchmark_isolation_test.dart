/// Two properties of the frozen baselines that nothing else would catch.
///
/// `benchmark/baselines/format20` is a copy of version 2.0 kept for the release
/// gate to measure against. Being a copy, it has two ways to cause damage: it
/// could leak into the published API — the package would then export two
/// formatters, one of them years old — or it could be edited, at which point
/// every threshold calibrated against it silently means something else.
///
/// The first is checked by reading the export file; the second by pinning five
/// outputs that differ from the current version's, so any edit to the baseline
/// shows up as a failure rather than as a shifted benchmark.
library;

import 'dart:io';

import 'package:test/test.dart';

import '../baselines/format20/format20.dart';

void main() {
  // The baseline is compiled into the benchmark package, so nothing but this
  // check stands between it and the public export.
  test('benchmark baselines are absent from package:format public API', () {
    final exports = File('lib/format.dart').readAsStringSync();
    expect(exports, isNot(contains('benchmark/')));
    expect(exports, isNot(contains('legacyFormat')));
    expect(exports, isNot(contains('sprintf7')));
  });

  // Five outputs where 2.0 differs from what the package does now — a shorter
  // default double, a lowercase alternate prefix under `X`, a one-digit
  // exponent. They are chosen to be sensitive: an accidental edit to the
  // baseline cannot leave all five intact.
  test('frozen Format 2 preserves the selected baseline behavior', () {
    expect(legacyFormat('{}', [1.23456789]), '1.23457');
    expect(legacyFormat('{:#X}', [42]), '0x2A');
    expect(legacyFormat('{:e}', [1.0]), '1.000000e+0');
    expect(legacyFormat('{:>5}', [true]), ' true');
    expect(legacyFormat('{:_x}', [3735928559]), 'dead_beef');
  });
}
