import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
/// http(s) address. Pages must be UTF-8; others (Shift_JIS, EUC-JP) are
/// refused with a hint to save them as UTF-8 text.
Future<Page> readPage(
  String source, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final file = File(source);
  if (file.existsSync()) {
    final lower = source.toLowerCase();
    final isHtml = lower.endsWith('.html') || lower.endsWith('.htm');
    if (!isHtml && !lower.endsWith('.txt')) {
      throw PageError('$source: only .html, .htm and .txt files');
    }
    if (file.lengthSync() > maxPageBytes) {
      throw PageError('$source: larger than ${maxPageBytes >> 20} MB');
    }
    return (
      text: _utf8(file.readAsBytesSync(), source),
      isHtml: isHtml,
      url: file.absolute.uri.toString(),
    );
  }
  final uri = Uri.tryParse(source);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    throw PageError('$source: not a file or an http(s) address');
  }
  final client = HttpClient()
    ..connectionTimeout = timeout
    ..userAgent = 'lychnion-studio';
  try {
    final req = await client.getUrl(uri).timeout(timeout);
    final res = await req.close().timeout(timeout);
    if (res.statusCode != 200) {
      await res.drain<void>().catchError((Object _) {});
      throw PageError('$source: HTTP ${res.statusCode}');
    }
    final bytes = <int>[];
    await for (final chunk in res.timeout(timeout)) {
      bytes.addAll(chunk);
      if (bytes.length > maxPageBytes) {
        throw PageError('$source: larger than ${maxPageBytes >> 20} MB');
      }
    }
    final type = res.headers.contentType;
    final isHtml = type == null || type.subType.contains('html');
    _checkCharset(type?.charset ?? _metaCharset(bytes), source);
    return (text: _utf8(bytes, source), isHtml: isHtml, url: source);
  } on TimeoutException {
    throw PageError('$source: no answer within ${timeout.inSeconds} s');
  } on SocketException catch (e) {
    throw PageError('$source: ${e.message}');
  } on HttpException catch (e) {
    throw PageError('$source: ${e.message}');
  } finally {
    client.close(force: true);
  }
}

/// The charset a page names in a `<meta>` tag near its start.
String? _metaCharset(List<int> bytes) {
  final head = latin1.decode(bytes.take(4096).toList()).toLowerCase();
  return RegExp(r'charset=["\x27]?([a-z0-9_-]+)').firstMatch(head)?.group(1);
}

void _checkCharset(String? charset, String source) {
  if (charset == null) return;
  final c = charset.toLowerCase().replaceAll('_', '-');
  if (c == 'utf-8' || c == 'utf8' || c == 'us-ascii') return;
  throw PageError(
    '$source: the page is in $charset, not UTF-8. Open it in a browser, '
    'save it as text (UTF-8), and give the saved file instead.',
  );
}

String _utf8(List<int> bytes, String source) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw PageError(
      '$source: not UTF-8 text. Save it as text (UTF-8) and give the '
      'saved file instead.',
    );
  }
}
