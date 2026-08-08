import 'dart:convert';

/// The anchors a Markdown document's headings resolve to.
///
/// Follows the slug GitHub derives for a heading — lowercased, punctuation
/// dropped, spaces turned into hyphens — so that a `#anchor` recorded in a
/// fixture can be checked against the document it points into instead of
/// being taken on trust.
Set<String> markdownAnchors(String markdown) {
  final anchors = <String>{};
  // A fenced block can contain a line that starts with `#` — a shell prompt,
  // a comment — which is not a heading.
  var fenced = false;
  for (final line in const LineSplitter().convert(markdown)) {
    if (line.trimLeft().startsWith('```')) {
      fenced = !fenced;
      continue;
    }
    if (fenced) continue;
    final heading = _heading.firstMatch(line);
    if (heading == null) continue;
    anchors.add('#${_slug(heading.group(1)!)}');
  }

  return anchors;
}

final _heading = RegExp(r'^#{1,6} +(.+)$');

final _dropped = RegExp(r'[^\w\- ]');

String _slug(String heading) =>
    heading.trim().toLowerCase().replaceAll(_dropped, '').replaceAll(' ', '-');
