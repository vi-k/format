/// A child-process probe for transient parser memory that must not be hidden
/// by the test runner's own heap or by another test running concurrently.
library;

import 'dart:convert';
import 'dart:io';

import 'package:format/format.dart';

const _digitCount = 5000000;

void main(List<String> arguments) {
  final kind = arguments.single;
  switch (kind) {
    case 'item':
      format('{0[0]}', ['warmup']);
    case 'width':
      format('{:${'0' * 256}d}', 1);
    default:
      throw ArgumentError.value(kind, 'kind');
  }
  final digits = '0' * _digitCount;
  final template = switch (kind) {
    'item' => '{0[$digits]}',
    'width' => '{:${digits}d}',
    _ => throw StateError('Validated above.'),
  };
  final beforeMaxRss = ProcessInfo.maxRss;
  final outcome = switch (kind) {
    'item' => format(template, ['value']),
    'width' => format(template, 1),
    _ => throw StateError('Validated above.'),
  };

  stdout.write(
    jsonEncode({
      'outcome': outcome,
      'maxRssDelta': ProcessInfo.maxRss - beforeMaxRss,
    }),
  );
}
