import 'dart:convert';
import 'dart:io';

import 'package:lychnion_guide/lychnion_guide.dart';

import 'draft.dart';

// Writes a guide file (<id>.sqlite) from a draft with writeGuide from
// lychnion_guide (shared with the app), so the app reads it like
// Lychnion's own guides.

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
  String json(Object? v) => jsonEncode(v);
  String text(String k) => draft[k] is String ? draft[k] as String : '';
  final region = draft['region'] is String ? draft['region'] as String : 'JP';
  return writeGuide(
    File('${outDir.path}/${draft['id']}.sqlite'),
    meta: {
      for (final k in ['id', 'title', 'language', 'version', 'note'])
        k: text(k),
      'translation': text('translation'),
      // What the guide is not for, shown before people rely on it.
      'notice': json(draft['notice'] ?? const {}),
      'name': json(draft['name'] ?? const {}),
      'icon': text('icon'),
      'suggestions': json(draft['suggestions'] ?? const {}),
      'area': text('area'),
      'gaps': json(draft['gaps'] ?? const []),
      'synonyms': json(draft['synonyms'] ?? const {}),
    },
    sources: [
      for (final s in (draft['sources'] as List).cast<Map<Object?, Object?>>())
        GuideSource(
          id: s['id'] as String,
          title: s['title'] as String,
          publisher: s['publisher'] as String,
          url: s['url'] as String,
          licence: s['licence'] as String,
          licenceUrl: s['licence_url'] as String?,
          attribution: s['attribution'] as String,
          region: s['region'] is String ? s['region'] as String : region,
        ),
    ],
    passages: [
      for (final r in (draft['passages'] as List).cast<Map<Object?, Object?>>())
        GuidePassage(
          sourceId: r['source'] as String,
          heading: (r['heading'] as String?) ?? '',
          text: r['text'] as String,
        ),
    ],
  );
}
