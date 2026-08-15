/// The workflow contract for a controlled CPU-reference capture.
///
/// This test does not execute GitHub Actions locally. It protects the boundary
/// that Actions owns: capture must measure the requested immutable revision,
/// retain all eight raw reports, and never turn an artifact into a git write.
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('controlled capture preserves raw reports without a gate verdict', () {
    final workflow = File('.github/workflows/ci.yaml').readAsStringSync();

    expect(workflow, contains('capture_baseline:'));
    expect(workflow, contains('baseline_revision:'));
    expect(workflow, contains('contents: read'));
    expect(workflow, contains('if: inputs.capture_baseline == true'));
    expect(workflow, contains(r'^[0-9A-Fa-f]{40}$'));
    expect(
      workflow,
      contains(
        r'ref: ${{ inputs.capture_baseline && '
        'inputs.baseline_revision || github.sha }}',
      ),
    );
    expect(workflow, contains('if: inputs.capture_baseline != true'));
    expect(workflow, contains('jit-*.json'));
    expect(workflow, contains('aot-*.json'));
    expect(workflow, contains('js-*.json'));
    expect(workflow, contains('wasm-*.json'));
    expect(workflow, isNot(contains('git commit')));
    expect(workflow, isNot(contains('git push')));
    expect(workflow, isNot(contains('--record')));
  });
}
