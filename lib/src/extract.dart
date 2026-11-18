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

const _block = {'p', 'li', 'div', 'tr', 'br', 'td', 'th', 'dd', 'dt'};
const _heading = {'h1', 'h2', 'h3', 'h4'};
const _skip = {
  'script',
  'style',
  'nav',
  'header',
  'footer',
  'noscript',
  'template',
  'svg',
  'form',
};

/// Page furniture on Japanese government sites, not content.
const _dropLines = {'子項目を開閉', 'この記事で伝えたいトピックス', '関連リンク', 'ページの先頭へ', '印刷'};

/// A web page: its title and its text, headings marked with `## `.
class PageText {
  const PageText(this.title, this.text);
  final String title;
  final String text;
}

/// The text of an HTML page: only its main part when it marks one
/// (`<main>`, `role="main"` or `<article>`), without menus, scripts and
/// forms.
PageText pageText(String source) {
  final doc = html.parse(source);
  final root =
      doc.querySelector('main') ??
      doc.querySelector('[role=main]') ??
      doc.querySelector('article') ??
      doc.body;
  final out = StringBuffer();
  if (root != null) _walk(root, out);
  final title = _oneLine(doc.querySelector('title')?.text ?? '');
  final h1 = _oneLine(root?.querySelector('h1')?.text ?? '');
  return PageText(title.isNotEmpty ? title : h1, out.toString());
}

void _walk(Node node, StringBuffer out) {
  for (final child in node.nodes) {
    if (child is Text) {
      out.write(child.data);
    } else if (child is Element) {
      final tag = child.localName ?? '';
      if (_skip.contains(tag)) continue;
      if (_heading.contains(tag)) {
        out.write('\n$headingMark');
        _walk(child, out);
        out.write('\n');
      } else {
        if (_block.contains(tag)) out.write('\n');
        _walk(child, out);
      }
    }
  }
}

String _oneLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// The non-empty lines of [text], with runs of spaces made one.
List<String> cleanLines(String text) => [
  for (final raw in text.split('\n'))
    if (raw.replaceAll(RegExp(r'[ \t\u3000\u00a0]+'), ' ').trim()
        case final line
        when line.isNotEmpty && line != '##' && !_dropLines.contains(line))
      line,
];

/// A passage: its heading and its text.
typedef Passage = ({String heading, String text});

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
    final size = buf.fold(0, (n, b) => n + b.runes.length);
    if (buf.isNotEmpty && size + line.runes.length > maxChars) flush();
    buf.add(line);
  }
  flush();
  return [
    for (final p in out)
      if (p.text.runes.length >= minPassageChars) p,
  ];
}
