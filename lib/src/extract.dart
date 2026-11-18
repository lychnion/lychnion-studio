import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

// Turns a web page into lines of text and the lines into passages, the
// same way lychnion-data/tool/build_package.py does for Lychnion's own
// guides: headings start a new passage, a passage holds up to 420
// characters, very short ones (menus, captions) are dropped.

/// Longest passage, in characters.
const maxPassageChars = 420;

/// Shorter passages carry no usable guidance.
const minPassageChars = 25;

/// A heading line in the extracted text starts with this.
const headingMark = '## ';

const _block = {
  'p', 'li', 'div', 'tr', 'br', 'td', 'th', 'dd', 'dt', 'section', //
  'article', 'ul', 'ol', 'dl', 'table', 'blockquote', 'pre', 'figure',
  'figcaption', 'details', 'summary', 'aside', 'address', 'hr',
};
const _heading = {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'};

/// Never text people read: scripts, menus, furigana (ruby text), struck
/// out text.
const _skip = {
  'script', 'style', 'noscript', 'template', 'svg', 'nav', 'rt', 'rp', //
  'del', 's', 'select', 'button', 'iframe', 'object',
};

/// Page header and footer: skipped around the main part of a page, kept
/// inside it (an article's header often holds its title).
const _pageFrame = {'header', 'footer'};

/// Page furniture on Japanese government sites, not content.
const _dropLines = {
  '子項目を開閉',
  'この記事で伝えたいトピックス',
  '関連リンク',
  'ページの先頭へ',
  '印刷',
  'このページの本文へ移動',
};

/// A web page: its title and its text, headings marked with `## `.
class PageText {
  const PageText(this.title, this.text);
  final String title;
  final String text;
}

/// The text of an HTML page: its main part when it marks one (`<main>`,
/// `role="main"` or `<article>`, the largest one) and that holds most of
/// the page's text, else the whole page; without menus, scripts and
/// hidden text.
PageText pageText(String source) {
  final doc = html.parse(source);
  final body = doc.body;
  final sizes = _textSizes(doc.documentElement);
  final all = sizes[body] ?? 0;
  Element? root = body;
  var size = 0;
  for (final e in _all(
    doc.documentElement,
    (e) =>
        e.localName == 'main' ||
        e.localName == 'article' ||
        e.attributes['role'] == 'main',
  )) {
    final n = sizes[e] ?? 0;
    if (n > size) (root, size) = (e, n);
  }
  // A small "main" (a card, a teaser) would leave most of the page out.
  if (size < all * 0.2) root = body;
  final out = StringBuffer();
  if (root != null) _walk(root, out, page: identical(root, body));
  final title = _shortText(
    _all(
      doc.documentElement,
      (e) => e.localName == 'title',
      all: true,
    ).firstOrNull,
  );
  final h1 = _shortText(_all(root, (e) => e.localName == 'h1').firstOrNull);
  return PageText(title.isNotEmpty ? title : h1, out.toString());
}

/// How much text [e] holds, without spaces. A loop, not recursion (the
/// html package's `text` recurses and overflows on deeply nested pages).
/// How much text each element holds, without spaces, in one pass from
/// the leaves up. Only text people read counts: scripts, menus and hidden
/// parts do not.
Map<Element, int> _textSizes(Element? root) {
  final sizes = <Element, int>{};
  if (root == null) return sizes;
  // Each element twice: first to add its children, then (done) to sum.
  final stack = <(Element, bool)>[(root, false)];
  while (stack.isNotEmpty) {
    final (e, done) = stack.removeLast();
    if (_pruned(e)) {
      sizes[e] = 0;
      continue;
    }
    if (!done) {
      stack.add((e, true));
      for (final c in e.children) {
        stack.add((c, false));
      }
      continue;
    }
    var n = 0;
    for (final node in e.nodes) {
      if (node is Text) {
        n += node.data.replaceAll(RegExp(r'\s+'), '').length;
      } else if (node is Element) {
        n += sizes[node] ?? 0;
      }
    }
    sizes[e] = n;
  }
  return sizes;
}

/// Never read, with everything inside it.
bool _pruned(Element e) => _skip.contains(e.localName) || _hidden(e);

/// The elements under [root] (and [root]) that [test] picks, in page
/// order, not inside skipped or hidden parts unless [all]. A loop, not
/// recursion, like [_textSize].
List<Element> _all(
  Element? root,
  bool Function(Element) test, {
  bool all = false,
}) {
  final out = <Element>[];
  if (root == null) return out;
  final stack = <Element>[root];
  while (stack.isNotEmpty) {
    final e = stack.removeLast();
    if (!all && _pruned(e)) continue;
    if (test(e)) out.add(e);
    stack.addAll(e.children.reversed);
  }
  return out;
}

/// The text of a small element (a title or a heading), at most about
/// 1,000 characters; read in a loop, skipping hidden parts.
String _shortText(Element? e) {
  if (e == null) return '';
  final out = StringBuffer();
  final stack = <Node>[e];
  while (stack.isNotEmpty && out.length < 1000) {
    final node = stack.removeLast();
    if (node is Text) {
      out.write(node.data);
    } else if (node is Element && (identical(node, e) || !_pruned(node))) {
      stack.addAll(node.nodes.reversed);
    }
  }
  return _oneLine(out.toString());
}

bool _hidden(Element e) =>
    e.attributes.containsKey('hidden') || e.attributes['aria-hidden'] == 'true';

/// Writes the text of [root]; a loop, not recursion, so deeply nested
/// pages cannot overflow the stack.
void _walk(Element root, StringBuffer out, {required bool page}) {
  // Work items: a node to visit, or text to write after an element.
  final stack = <Object>[...root.nodes.reversed];
  var pre = 0;
  while (stack.isNotEmpty) {
    final item = stack.removeLast();
    if (item is String) {
      if (item == '</pre>') {
        pre--;
      } else {
        out.write(item);
      }
      continue;
    }
    if (item is Text) {
      out.write(
        pre > 0 ? item.data : item.data.replaceAll(RegExp(r'\s+'), ' '),
      );
      continue;
    }
    if (item is! Element) continue;
    final tag = item.localName ?? '';
    if (_skip.contains(tag) || _hidden(item)) continue;
    if (page && _pageFrame.contains(tag)) continue;
    if (_heading.contains(tag)) {
      out.write('\n$headingMark');
      stack.add('\n');
    } else if (_block.contains(tag)) {
      out.write('\n');
      stack.add('\n');
    }
    if (tag == 'pre') {
      pre++;
      stack.add('</pre>');
    }
    stack.addAll(item.nodes.reversed);
  }
}

String _oneLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

final _spaces = RegExp(r'[ \t\u3000\u00a0]+');

/// The non-empty lines of [text], with runs of spaces made one.
List<String> cleanLines(String text) => [
  for (final raw in text.split('\n'))
    if (raw.replaceAll(_spaces, ' ').trim() case final line
        when line.isNotEmpty && line != '##' && !_dropLines.contains(line))
      line,
];

/// A passage: its heading and its text.
typedef Passage = ({String heading, String text});

/// [line] cut at sentence ends into pieces of up to [max] characters
/// (a piece without a sentence end in reach is cut at [max]).
List<String> _pieces(String line, int max) {
  final chars = line.runes.toList();
  if (chars.length <= max) return [line];
  const ends = {0x3002, 0xff01, 0xff1f, 0x21, 0x3f}; // 。！？!?
  final out = <String>[];
  var start = 0;
  while (start < chars.length) {
    var end = start + max;
    if (end >= chars.length) {
      end = chars.length;
    } else {
      // The last sentence end in this window (only the window is read).
      for (var i = end - 1; i > start; i--) {
        final c = chars[i];
        if (ends.contains(c) ||
            (c == 0x2e && i + 1 < chars.length && chars[i + 1] == 0x20)) {
          end = i + 1;
          break;
        }
      }
    }
    final piece = String.fromCharCodes(chars, start, end).trim();
    if (piece.isNotEmpty) out.add(piece);
    start = end;
  }
  return out;
}

/// Groups [lines] into passages of up to [maxChars], each with the last
/// heading before it.
List<Passage> passages(List<String> lines, {int maxChars = maxPassageChars}) {
  var heading = '';
  final buf = <String>[];
  final out = <Passage>[];
  void flush() {
    if (buf.isEmpty) return;
    out.add((heading: heading, text: buf.join('\n')));
    buf.clear();
  }

  for (final line in lines) {
    if (line.startsWith(headingMark)) {
      flush();
      heading = line.substring(headingMark.length).trim();
      continue;
    }
    for (final piece in _pieces(line, maxChars)) {
      final size = buf.fold(0, (n, b) => n + b.runes.length);
      if (buf.isNotEmpty && size + piece.runes.length > maxChars) flush();
      buf.add(piece);
    }
  }
  flush();
  // A short passage right after another under the same heading (the end
  // of a long paragraph, the last line of a section) joins it, so its
  // instruction is not lost; other short passages (menus, captions) go.
  final kept = <Passage>[];
  int? previous; // index in [out] of the passage kept last
  for (final (i, p) in out.indexed) {
    if (p.text.runes.length >= minPassageChars) {
      kept.add(p);
      previous = i;
    } else if (previous == i - 1 && kept.last.heading == p.heading) {
      final last = kept.removeLast();
      kept.add((heading: last.heading, text: '${last.text}\n${p.text}'));
      previous = i;
    }
  }
  return kept;
}
