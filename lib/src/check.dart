import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'shapes.dart';

// Reads a guide file the way the Lychnion app does when it loads it
// (KnowledgePackage.open in lychnion/lychnion): the meta, sources,
// passages and alerts tables with the same types and JSON shapes, every
// passage and alert with its source. The desktop app opens it again
// before it signs it.

/// What the app needs to use the guide.
class GuideSummary {
  const GuideSummary(this.id, this.version, this.sources, this.passages);
  final String id;
  final String version;
  final int sources;
  final int passages;
}

/// Why the app could not use the guide at [path].
class GuideProblem implements Exception {
  const GuideProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Opens the guide at [path] as the app does; throws [GuideProblem] when
/// the app could not use it.
GuideSummary checkGuide(String path) {
  if (!File(path).existsSync()) throw GuideProblem('$path: no such file');
  final Database db;
  try {
    db = sqlite3.open(path, mode: OpenMode.readOnly);
  } on SqliteException catch (e) {
    throw GuideProblem('not a guide file: ${e.message}');
  }
  try {
    final meta = <String, String>{};
    for (final r in db.select('SELECT key, value FROM meta')) {
      if (r['key'] is! String || r['value'] is! String) {
        throw const GuideProblem('meta: a key or value is not text');
      }
      meta[r['key'] as String] = r['value'] as String;
    }
    final id = meta['id'] ?? '';
    final version = meta['version'] ?? '';
    if (id.isEmpty) throw const GuideProblem('meta: no id');
    if (version.isEmpty) throw const GuideProblem('meta: no version');
    for (final (k, shape) in [
      ('name', nameShape),
      ('notice', noticeShape),
      ('suggestions', suggestionsShape),
      ('synonyms', synonymsShape),
    ]) {
      final Object? v;
      try {
        v = jsonDecode(meta[k] ?? '{}');
      } on FormatException {
        throw GuideProblem('meta $k: broken JSON');
      }
      if (shape(v) case final want?) throw GuideProblem('meta $k: not $want');
    }
    final sources = <String>{};
    for (final r in db.select(
      'SELECT id, title, publisher, url, licence, attribution FROM sources',
    )) {
      for (final k in [
        'id',
        'title',
        'publisher',
        'url',
        'licence',
        'attribution',
      ]) {
        if (r[k] is! String) throw GuideProblem('source ${r['id']}: no $k');
      }
      sources.add(r['id'] as String);
    }
    var count = 0;
    for (final r in db.select(
      'SELECT id, source_id, heading, text FROM passages ORDER BY id',
    )) {
      if (!sources.contains(r['source_id'])) {
        throw GuideProblem('passage ${r['id']}: its source is missing');
      }
      if (r['text'] is! String) {
        throw GuideProblem('passage ${r['id']}: no text');
      }
      if (r['heading'] != null && r['heading'] is! String) {
        throw GuideProblem('passage ${r['id']}: heading is not text');
      }
      count++;
    }
    if (count == 0) throw const GuideProblem('no passages');
    for (final r in db.select('SELECT * FROM alerts')) {
      if (!sources.contains(r['source_id'])) {
        throw GuideProblem('alert ${r['id']}: its source is missing');
      }
      if (r['id'] is! String || r['text'] is! String) {
        throw GuideProblem('alert ${r['id']}: no id or text');
      }
      if (r['text_en'] != null && r['text_en'] is! String) {
        throw GuideProblem('alert ${r['id']}: text_en is not text');
      }
      for (final k in ['match_all', 'match_all_en']) {
        if (!r.containsKey(k)) continue;
        final Object? v;
        try {
          v = jsonDecode(r[k] as String? ?? '[]');
        } on Object {
          throw GuideProblem('alert ${r['id']}: broken $k');
        }
        if (groupsShape(v) != null) {
          throw GuideProblem('alert ${r['id']}: $k is not ${groupsShape(v)}');
        }
      }
    }
    return GuideSummary(id, version, sources.length, count);
  } on SqliteException catch (e) {
    throw GuideProblem(e.message);
  } finally {
    db.close();
  }
}
