import 'dart:convert';

import 'extract.dart';
import 'fetch.dart';
import 'package:lychnion_guide/lychnion_guide.dart';

// A draft guide: what `draft` writes and `build` reads, in the shape of
// lychnion-data's package manifests (packages/<id>.json) plus the
// passages themselves. People review and edit it before it is built.

/// The draft format this tool writes and reads.
const draftFormat = 1;

/// Ids end up in file names: letters, digits, `.`, `_` and `-`, not
/// starting with a dot (the rule of signed records).
final _id = RegExp(r'^[A-Za-z0-9_-][A-Za-z0-9._-]{0,127}$');

/// Dotted numbers, e.g. 2026.11.18 (versions only go up).
final _version = RegExp(r'^\d{1,9}(\.\d{1,9}){0,3}$');

/// Today as a version, e.g. 2026.11.18.
String todayVersion([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${d.year}.${d.month}.${d.day}';
}

/// The notice shown before people rely on the guide, per language. The
/// publisher should check it says what the guide is not for. Emergency
/// numbers only for Japan (119, 110); elsewhere the publisher adds its own.
Map<String, List<String>> defaultNotice(
  String publisher, {
  String region = 'JP',
}) {
  final japan = region == 'JP' || region.startsWith('JP-');
  return {
    'ja': [
      'この情報は$publisherが公開したものです。最新の情報は$publisherの発表を確認してください。',
      if (japan) '緊急のときは119番・110番に電話してください。',
    ],
    'en': [
      'Published by $publisher. Check $publisher\'s own announcements for the '
          'latest information.',
      if (japan) 'In an emergency, call 119 (fire, ambulance) or 110 (police).',
    ],
  };
}

/// [url] without a user name or password in it.
String _publicUrl(String url) {
  final u = Uri.tryParse(url);
  return u == null || u.userInfo.isEmpty
      ? url
      : u.replace(userInfo: '').toString();
}

/// Fetches [sources] (addresses or saved files) and makes a draft guide
/// from them: one source per page, its passages in order. A saved file's
/// address is left empty: the publisher fills in the page's web address.
Future<Map<String, Object?>> makeDraft({
  required String id,
  required String publisher,
  required List<String> sources,
  String language = 'ja',
  String region = 'JP',
  String? version,
  Future<Page> Function(String source) read = readPage,
}) async {
  if (!_id.hasMatch(id)) throw FormatException('not a valid id: $id');
  if (!languageCode.hasMatch(language)) {
    throw FormatException('not a language code (e.g. ja): $language');
  }
  if (!regionCode.hasMatch(region)) {
    throw FormatException('not a region code (e.g. JP or JP-28): $region');
  }
  if (publisher.trim().isEmpty) throw const FormatException('no publisher');
  final srcs = <Map<String, Object?>>[];
  final rows = <Map<String, Object?>>[];
  for (final (i, s) in sources.indexed) {
    final page = await read(s);
    // Unique beyond this guide: the app merges the sources of all guides.
    final sid = '$id/s${i + 1}';
    final PageText text = page.isHtml
        ? pageText(page.text)
        : PageText('', page.text);
    final web =
        page.url.startsWith('http://') || page.url.startsWith('https://');
    srcs.add({
      'id': sid,
      'title': text.title,
      'publisher': publisher,
      'url': web ? _publicUrl(page.url) : '',
      // The publisher's own pages: no licence question, they decide.
      'licence': '© $publisher',
      'attribution': publisher,
    });
    for (final p in passages(cleanLines(text.text))) {
      rows.add({'source': sid, 'heading': p.heading, 'text': p.text});
    }
  }
  final notice = defaultNotice(publisher, region: region);
  return {
    'draft': draftFormat,
    'id': id,
    'version': version ?? todayVersion(),
    'language': language,
    'region': region,
    'title': publisher,
    'name': {language: publisher},
    'notice': {language: notice[language] ?? notice['en']!},
    'sources': srcs,
    'passages': rows,
  };
}

/// The draft as text: indented JSON, Japanese as it is.
String draftJson(Map<String, Object?> draft) =>
    '${const JsonEncoder.withIndent('  ').convert(draft)}\n';

/// What is wrong with [draft] for building, or empty when nothing is.
/// Checks everything the app needs to open the guide.
List<String> draftProblems(Object? draft) {
  if (draft is! Map) return ['not a JSON object'];
  final p = <String>[];
  String? text(String k) => draft[k] is String ? draft[k] as String : null;
  if (draft['draft'] != draftFormat) p.add('draft: must be $draftFormat');
  if (!_id.hasMatch(text('id') ?? '')) p.add('id: letters, digits, . _ -');
  if (!_version.hasMatch(text('version') ?? '')) {
    p.add('version: dotted numbers, e.g. 2026.11.18 (or 2026.11.18.1)');
  }
  final lang = text('language') ?? '';
  if (!languageCode.hasMatch(lang)) p.add('language: e.g. ja');
  if (draft['region'] != null && !regionCode.hasMatch(text('region') ?? '')) {
    p.add('region: e.g. JP or JP-28 (upper case)');
  }
  if ((text('title') ?? '').trim().isEmpty) {
    p.add('title: what the guide is called');
  }
  for (final (k, shape) in [
    ('name', nameShape),
    ('notice', noticeShape),
    ('suggestions', suggestionsShape),
    ('synonyms', synonymsShape),
  ]) {
    if (draft[k] == null) continue;
    if (shape(draft[k]) case final want?) p.add('$k: $want');
  }
  for (final k in ['icon', 'area', 'note', 'translation']) {
    if (draft[k] != null && draft[k] is! String) p.add('$k: text');
  }
  if (draft['gaps'] != null && draft['gaps'] is! List) p.add('gaps: a list');
  final notice = draft['notice'];
  if (notice is! Map ||
      notice[lang] is! List ||
      (notice[lang] as List).every((l) => l is! String || l.trim().isEmpty)) {
    p.add('notice: at least one line in "$lang" (what the guide is not for)');
  }
  final ids = <String>{};
  final sources = draft['sources'];
  if (sources is! List || sources.isEmpty) {
    p.add('sources: at least one');
  } else {
    for (final (i, s) in sources.indexed) {
      if (s is! Map || s['id'] is! String || (s['id'] as String).isEmpty) {
        p.add('sources[$i]: needs an id');
        continue;
      }
      if (!ids.add(s['id'] as String)) p.add('sources[$i]: id used twice');
      // The app shows these with every answer from the source.
      for (final k in ['title', 'publisher', 'licence', 'attribution']) {
        if (s[k] is! String || (s[k] as String).trim().isEmpty) {
          p.add('sources[$i].$k: needed');
        }
      }
      final url = s['url'];
      if (url is! String ||
          !(url.startsWith('https://') || url.startsWith('http://'))) {
        p.add('sources[$i].url: the page\'s web address (https://…)');
      }
      if (s['licence_url'] != null && s['licence_url'] is! String) {
        p.add('sources[$i].licence_url: text');
      }
      if (s['region'] != null &&
          !(s['region'] is String &&
              regionCode.hasMatch(s['region'] as String))) {
        p.add('sources[$i].region: e.g. JP or JP-28');
      }
    }
  }
  final rows = draft['passages'];
  if (rows is! List || rows.isEmpty) {
    p.add('passages: at least one');
  } else {
    final seen = <String, int>{};
    for (final (i, r) in rows.indexed) {
      if (r is! Map) {
        p.add('passages[$i]: not an object');
      } else if (!ids.contains(r['source'])) {
        p.add('passages[$i]: source "${r['source']}" is not in sources');
      } else if (r['text'] is! String || (r['text'] as String).trim().isEmpty) {
        p.add('passages[$i]: text is empty');
      } else if (r['heading'] != null && r['heading'] is! String) {
        p.add('passages[$i]: heading must be text');
      } else if (seen[(r['text'] as String).trim()] case final j?) {
        p.add('passages[$i]: same text as passages[$j] (delete one)');
      } else {
        seen[(r['text'] as String).trim()] = i;
      }
    }
  }
  return p;
}
