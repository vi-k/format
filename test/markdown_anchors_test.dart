// The slug derivation used to check documentation links — a test of the test
// support code, not of the package.
//
// `markdownAnchors` is what lets other tests assert that a link like
// `[the cache](#template-cache)` actually lands somewhere. That check is only
// as trustworthy as the slugging: if this helper derived anchors GitHub would
// not, the link tests would either pass on broken links or fail on working
// ones, and either way the failure would be blamed on the documentation.
//
// So the rules are pinned against GitHub's behaviour directly: punctuation is
// dropped rather than replaced, spaces become hyphens, case folds, and a `#`
// that is not a heading — no space after it, or not at the start of a line, or
// inside a fenced code block — produces no anchor at all.

import 'package:test/test.dart';

import 'support/markdown_anchors.dart';

void main() {
  // All six levels are headings and all of them get anchors — a helper that
  // only recognized `##` would quietly skip the section links in a document
  // structured differently.
  test('derives an anchor from every heading level', () {
    expect(markdownAnchors('# One\n\n## Two words\n\n### Three\n'), {
      '#one',
      '#two-words',
      '#three',
    });
  });

  // The three rules that are easy to get subtly wrong. A dot is deleted, not
  // turned into a hyphen, so `3.0` slugs to `30`. Backticks and punctuation go
  // the same way, while the space that separated the words stays a hyphen.
  // Surrounding whitespace, including the run after the hashes, is trimmed
  // rather than encoded.
  test('slugs the way GitHub does', () {
    expect(markdownAnchors('## Format 3.0 migration'), {
      '#format-30-migration',
    });
    expect(markdownAnchors('## `sprintf`, and more!'), {'#sprintf-and-more'});
    expect(markdownAnchors('##    Padded   '), {'#padded'});
  });

  // A hash only opens a heading at the start of a line and with a space after
  // it. Both counterexamples would otherwise contribute phantom anchors, and a
  // phantom anchor is worse than a missing one: it makes a broken link pass.
  test('ignores a hash that is not a heading', () {
    expect(markdownAnchors('#no-space\ntext # not a heading\n'), isEmpty);
  });

  // The case that made the helper necessary rather than a one-line regexp: the
  // README is full of shell examples, and `# a shell comment` looks exactly
  // like a heading. Fenced blocks are skipped, and the real heading beside them
  // still counts.
  test('ignores hashes inside a fenced block', () {
    expect(markdownAnchors('## Real\n\n```console\n# a shell comment\n```\n'), {
      '#real',
    });
  });
}
