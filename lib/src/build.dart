import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'check.dart';
import 'draft.dart';

// Writes a guide file (<id>.sqlite) from a draft, with the tables and
// meta keys lychnion-data/tool/build_package.py writes, so the app reads
// it like Lychnion's own guides.

/// Why a draft could not be built.
class BuildError implements Exception {
  const BuildError(this.problems);
  final List<String> problems;
  @override
  String toString() => problems.join('\n');
}

/// Builds [draft] into `<outDir>/<id>.sqlite` and returns that file.
/// Throws [BuildError] listing what is wrong with the draft, or
/// [GuideProblem] when the built file would not open in the app.
File buildGuide(Map<String, Object?> draft, Directory outDir) {
  final problems = draftProblems(draft);
  if (problems.isNotEmpty) throw BuildError(problems);
  outDir.createSync(recursive: true);
  final out = File('${outDir.path}/${draft['id']}.sqlite');
  // Written next to it first: a failed build never leaves half a guide.
  final tmp = File('${out.path}.building');
  if (tmp.existsSync()) tmp.deleteSync();
  final db = sqlite3.open(tmp.path);
  try {
    db.execute('''
      CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE sources(id TEXT PRIMARY KEY, title TEXT, publisher TEXT,
                           url TEXT, licence TEXT, licence_url TEXT,
                           attribution TEXT,
                           region TEXT NOT NULL DEFAULT 'JP');
      CREATE TABLE passages(id INTEGER PRIMARY KEY,
                            source_id TEXT NOT NULL REFERENCES sources(id),
                            heading TEXT, text TEXT NOT NULL,
                            original_heading TEXT, original TEXT);
      CREATE VIRTUAL TABLE passages_fts USING fts5(heading, text,
                            content='passages', content_rowid='id',
                            tokenize='trigram');
      CREATE TABLE alerts(id TEXT PRIMARY KEY,
                          source_id TEXT NOT NULL REFERENCES sources(id),
                          text TEXT NOT NULL, match_all TEXT NOT NULL,
                          text_en TEXT, match_all_en TEXT);
    ''');
    db.execute('BEGIN');
    String json(Object? v) => jsonEncode(v);
    final meta = <String, String>{
      for (final k in [
        'id',
        'title',
        'language',
        'version',
        'note',
        'translation',
      ])
        k: draft[k] is String ? draft[k] as String : '',
      // What the guide is not for, shown before people rely on it.
      'notice': json(draft['notice'] ?? const {}),
      'name': json(draft['name'] ?? const {}),
      'icon': draft['icon'] is String ? draft['icon'] as String : '',
      'suggestions': json(draft['suggestions'] ?? const {}),
      'area': draft['area'] is String ? draft['area'] as String : '',
      'gaps': json(draft['gaps'] ?? const []),
      'synonyms': json(draft['synonyms'] ?? const {}),
    };
    final putMeta = db.prepare('INSERT INTO meta VALUES(?, ?)');
    for (final e in meta.entries) {
      putMeta.execute([e.key, e.value]);
    }
    putMeta.close();
    final region = draft['region'] is String ? draft['region'] : 'JP';
    final putSource = db.prepare(
      'INSERT INTO sources VALUES(?, ?, ?, ?, ?, ?, ?, ?)',
    );
    for (final s in (draft['sources'] as List).cast<Map>()) {
      putSource.execute([
        s['id'],
        s['title'],
        s['publisher'],
        s['url'],
        s['licence'],
        s['licence_url'],
        s['attribution'],
        s['region'] is String ? s['region'] : region,
      ]);
    }
    putSource.close();
    final putPassage = db.prepare(
      'INSERT INTO passages(source_id, heading, text) VALUES(?, ?, ?)',
    );
    for (final r in (draft['passages'] as List).cast<Map>()) {
      putPassage.execute([
        r['source'],
        (r['heading'] as String?)?.trim() ?? '',
        (r['text'] as String).trim(),
      ]);
    }
    putPassage.close();
    db.execute("INSERT INTO passages_fts(passages_fts) VALUES('rebuild')");
    db.execute('COMMIT');
    db.execute('VACUUM');
  } catch (_) {
    db.close();
    if (tmp.existsSync()) tmp.deleteSync();
    rethrow;
  }
  db.close();
  // Checked before it replaces a guide built earlier: a guide the app
  // could not open never takes the place of one it can.
  try {
    checkGuide(tmp.path);
  } on GuideProblem {
    tmp.deleteSync();
    rethrow;
  }
  return tmp.renameSync(out.path);
}
