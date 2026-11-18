import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// At most this many bytes are read from a page.
const maxPageBytes = 5 << 20;

/// Why a page could not be read.
class PageError implements Exception {
  const PageError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A page as text: an http(s) address, or a saved `.html` or `.txt` file.
typedef Page = ({String text, bool isHtml, String url});

/// Reads [source]: a saved file when one exists at that path, else an
/// http(s) address, within [timeout] in all. Only web pages and plain
/// text in UTF-8; others (PDFs, Shift_JIS, EUC-JP) are refused with a
/// hint what to do instead.
Future<Page> readPage(
  String source, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final uri = Uri.tryParse(source);
  final web = uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  if (!web) return _readFile(source);
  final client = HttpClient()
    ..connectionTimeout = timeout
    ..userAgent = 'lychnion-studio';
  try {
    // One deadline for everything: a server sending a byte now and then
    // cannot hold the tool.
    return await _fetch(client, uri, source).timeout(
      timeout,
      onTimeout: () =>
          throw PageError('$source: not read within ${timeout.inSeconds} s'),
    );
  } on SocketException catch (e) {
    throw PageError('$source: ${e.message}');
  } on HttpException catch (e) {
    throw PageError('$source: ${e.message}');
  } on ArgumentError {
    // A redirect to something other than http(s), e.g. file:.
    throw PageError('$source: redirected to an address that is not a web page');
  } finally {
    client.close(force: true);
  }
}

Page _readFile(String source) {
  final file = File(source);
  if (!file.existsSync()) {
    throw PageError('$source: no such file (or not an http(s) address)');
  }
  final lower = source.toLowerCase();
  final isHtml = lower.endsWith('.html') || lower.endsWith('.htm');
  if (!isHtml && !lower.endsWith('.txt')) {
    throw PageError(
      '$source: only .html, .htm and .txt files (PDFs are not supported yet)',
    );
  }
  try {
    if (file.lengthSync() > maxPageBytes) {
      throw PageError('$source: larger than ${maxPageBytes >> 20} MB');
    }
    return (
      text: _utf8(file.readAsBytesSync(), source),
      isHtml: isHtml,
      url: file.absolute.uri.toString(),
    );
  } on FileSystemException catch (e) {
    throw PageError('$source: ${e.osError?.message ?? e.message}');
  }
}

Future<Page> _fetch(HttpClient client, Uri uri, String source) async {
  final req = await client.getUrl(uri);
  final res = await req.close();
  if (res.statusCode != 200) {
    // Not read: the client is closed right after.
    throw PageError('$source: HTTP ${res.statusCode}');
  }
  final type = res.headers.contentType;
  final kind = type == null
      ? 'text/html'
      : '${type.primaryType}/${type.subType}';
  final isHtml = kind == 'text/html' || kind == 'application/xhtml+xml';
  if (!isHtml && kind != 'text/plain') {
    throw PageError(
      '$source: not a web page ($kind)'
      '${kind == 'application/pdf' ? '; PDFs are not supported yet' : ''}',
    );
  }
  if (res.contentLength > maxPageBytes) {
    throw PageError('$source: larger than ${maxPageBytes >> 20} MB');
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in res) {
    bytes.add(chunk);
    if (bytes.length > maxPageBytes) {
      throw PageError('$source: larger than ${maxPageBytes >> 20} MB');
    }
  }
  final data = bytes.takeBytes();
  _checkCharset(type?.charset ?? _metaCharset(data), source);
  return (text: _utf8(data, source), isHtml: isHtml, url: source);
}

/// The charset a page names in a `<meta>` tag near its start.
String? _metaCharset(Uint8List bytes) {
  final head = latin1.decode(bytes.sublist(0, bytes.length.clamp(0, 4096)));
  return RegExp(
    r'<meta[^>]*charset=["\x27]?([a-z0-9_-]+)',
    caseSensitive: false,
  ).firstMatch(head)?.group(1);
}

void _checkCharset(String? charset, String source) {
  if (charset == null) return;
  final c = charset.toLowerCase().replaceAll('_', '-');
  if (c == 'utf-8' || c == 'utf8' || c == 'us-ascii') return;
  throw PageError(
    '$source: the page is in $charset, not UTF-8. Copy its text into a '
    'text file saved as UTF-8 (see docs/publishing.md) and give that file '
    'instead.',
  );
}

String _utf8(List<int> bytes, String source) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw PageError(
      '$source: not UTF-8 text. Copy its text into a text file saved as '
      'UTF-8 (see docs/publishing.md) and give that file instead.',
    );
  }
}
