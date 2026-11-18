// The shapes the Lychnion app expects when it opens a guide
// (KnowledgePackage.open, parseLabels and parseNotice in
// lychnion/lychnion lib/knowledge/knowledge_package.dart). The draft is
// checked against them before it is built, and a built guide again.

/// A region code: a country, or a country and a part of it (JP, JP-28).
/// Upper case: the app compares them as they are.
final regionCode = RegExp(r'^[A-Z]{2}(-[A-Z0-9]{1,3})?$');

/// A language code, e.g. ja or en.
final languageCode = RegExp(r'^[a-z]{2,3}$');

bool _strings(Object? v) => v is List && v.every((e) => e is String);

/// `name`: language → text.
String? nameShape(Object? v) =>
    v is Map &&
        v.keys.every((k) => k is String) &&
        v.values.every((x) => x is String)
    ? null
    : 'an object of language: text';

/// `notice`: language → lines of text.
String? noticeShape(Object? v) =>
    v is Map && v.keys.every((k) => k is String) && v.values.every(_strings)
    ? null
    : 'an object of language: [lines of text]';

/// `suggestions`: language → [{icon, text}].
String? suggestionsShape(Object? v) =>
    v is Map &&
        v.keys.every((k) => k is String) &&
        v.values.every(
          (l) =>
              l is List &&
              l.every(
                (s) => s is Map && s['icon'] is String && s['text'] is String,
              ),
        )
    ? null
    : 'an object of language: [{"icon": text, "text": text}]';

/// `synonyms`: word → [other words].
String? synonymsShape(Object? v) =>
    v is Map && v.keys.every((k) => k is String) && v.values.every(_strings)
    ? null
    : 'an object of word: [words]';

/// An alert's `match_all`: groups of words.
String? groupsShape(Object? v) =>
    v is List && v.every(_strings) ? null : 'a list of [words]';
