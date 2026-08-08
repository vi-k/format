import 'package:test/test.dart';

import 'support/markdown_anchors.dart';

void main() {
  test('derives an anchor from every heading level', () {
    expect(markdownAnchors('# One\n\n## Two words\n\n### Three\n'), {
      '#one',
      '#two-words',
      '#three',
    });
  });

  test('slugs the way GitHub does', () {
    expect(markdownAnchors('## Format 3.0 migration'), {
      '#format-30-migration',
    });
    expect(markdownAnchors('## `sprintf`, and more!'), {'#sprintf-and-more'});
    expect(markdownAnchors('##    Padded   '), {'#padded'});
  });

  test('ignores a hash that is not a heading', () {
    expect(markdownAnchors('#no-space\ntext # not a heading\n'), isEmpty);
  });

  test('ignores hashes inside a fenced block', () {
    expect(markdownAnchors('## Real\n\n```console\n# a shell comment\n```\n'), {
      '#real',
    });
  });
}
