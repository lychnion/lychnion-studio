import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

// Reads a guide file the way the Lychnion app does when it loads it
// (KnowledgePackage.open in lychnion/lychnion): the meta, sources,
// passages and alerts tables, every passage with its source. The desktop
// app runs the same kind of check before it signs a guide.

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
    final meta = {
      for (final r in db.select('SELECT key, value FROM meta'))
        r['key'] as String: r['value'] as String,
    };
    final id = meta['id'] ?? '';
    final version = meta['version'] ?? '';
    if (id.isEmpty) throw const GuideProblem('meta: no id');
    if (version.isEmpty) throw const GuideProblem('meta: no version');
    for (final k in ['notice', 'name', 'synonyms', 'suggestions']) {
      if (meta[k] case final v? when v.isNotEmpty) {
        try {
          jsonDecode(v);
        } on FormatException {
          throw GuideProblem('meta $k: broken JSON');
        }
      }
    }
    final sources = {
      for (final r in db.select('SELECT id FROM sources')) r['id'] as String,
    };
    var count = 0;
    for (final r in db.select(
      'SELECT id, source_id, text FROM passages ORDER BY id',
    )) {
      if (!sources.contains(r['source_id'])) {
        throw GuideProblem('passage ${r['id']}: its source is missing');
      }
      if (r['text'] is! String) {
        throw GuideProblem('passage ${r['id']}: no text');
      }
      count++;
    }
    if (count == 0) throw const GuideProblem('no passages');
    for (final r in db.select('SELECT id, source_id, match_all FROM alerts')) {
      if (!sources.contains(r['source_id'])) {
        throw GuideProblem('alert ${r['id']}: its source is missing');
      }
      try {
        jsonDecode(r['match_all'] as String);
      } on Object {
        throw GuideProblem('alert ${r['id']}: broken match_all');
      }
    }
    return GuideSummary(id, version, sources.length, count);
  } on SqliteException catch (e) {
    throw GuideProblem(e.message);
  } finally {
    db.close();
  }
}
