import 'dart:convert';
import 'dart:io';

import 'package:lychnion_studio/lychnion_studio.dart';

const _usage = '''
Turns your own web pages into a Lychnion guide.

  lychnion_studio draft --id ID --publisher NAME [--language ja]
                        [--region JP] [--out draft.json] PAGE...
      Reads each PAGE (an http(s) address, or a saved .html or .txt file
      in UTF-8) and writes a draft: the guide's name, notice, sources and
      passages. Check and edit it before you build.

  lychnion_studio build DRAFT [--out DIR]
      Writes DIR/<id>.sqlite (default DIR: build) from the draft, and
      checks it.

  lychnion_studio check FILE.sqlite
      Opens a guide file as the app does and says whether the app can use
      it.

Then sign and publish the file in the Lychnion desktop app: Settings,
Publishers, "Publish your own" (see docs/publishing.md).
''';

Future<void> main(List<String> args) async {
  try {
    exitCode = await _run(args);
  } on _Usage catch (e) {
    stderr.writeln('${e.message}\n\n$_usage');
    exitCode = 64;
  }
}

class _Usage implements Exception {
  const _Usage(this.message);
  final String message;
}

Future<int> _run(List<String> args) async {
  if (args.isEmpty || const {'-h', '--help', 'help'}.contains(args.first)) {
    stdout.write(_usage);
    return 0;
  }
  final (options, rest) = _options(args.skip(1).toList());
  switch (args.first) {
    case 'draft':
      final id = options['id'];
      final publisher = options['publisher'];
      if (id == null || publisher == null || rest.isEmpty) {
        throw const _Usage('draft needs --id, --publisher and pages');
      }
      final Map<String, Object?> draft;
      try {
        draft = await makeDraft(
          id: id,
          publisher: publisher,
          sources: rest,
          language: options['language'] ?? 'ja',
          region: options['region'] ?? 'JP',
        );
      } on PageError catch (e) {
        stderr.writeln(e.message);
        return 1;
      } on FormatException catch (e) {
        stderr.writeln(e.message);
        return 1;
      }
      final out = File(options['out'] ?? 'draft.json');
      out.writeAsStringSync(draftJson(draft));
      final n = (draft['passages'] as List).length;
      stdout.writeln(
        'wrote ${out.path}: ${(draft['sources'] as List).length} pages, '
        '$n passages. Check the name, the notice and every passage, then '
        'build it.',
      );
      if (n == 0) {
        stderr.writeln(
          'No passages found: the pages may need a browser to show their '
          'text. Save them as text and give the files instead.',
        );
        return 1;
      }
      return 0;
    case 'build':
      if (rest.length != 1) throw const _Usage('build needs one draft');
      final Object? draft;
      try {
        draft = jsonDecode(File(rest.single).readAsStringSync());
      } on FileSystemException catch (e) {
        stderr.writeln('${rest.single}: ${e.osError?.message ?? e.message}');
        return 1;
      } on FormatException catch (e) {
        stderr.writeln('${rest.single}: not JSON (${e.message})');
        return 1;
      }
      if (draft is! Map<String, Object?>) {
        stderr.writeln('${rest.single}: not a draft');
        return 1;
      }
      try {
        final file = buildGuide(draft, Directory(options['out'] ?? 'build'));
        final s = checkGuide(file.path);
        stdout.writeln(
          'wrote ${file.path}: ${s.id} ${s.version}, ${s.passages} '
          'passages from ${s.sources} sources',
        );
        return 0;
      } on BuildError catch (e) {
        stderr.writeln('The draft cannot be built yet:');
        for (final p in e.problems) {
          stderr.writeln('  $p');
        }
        return 1;
      } on GuideProblem catch (e) {
        stderr.writeln('The built guide does not open: ${e.message}');
        return 1;
      }
    case 'check':
      if (rest.length != 1) throw const _Usage('check needs one file');
      try {
        final s = checkGuide(rest.single);
        stdout.writeln(
          'ok: ${s.id} ${s.version}, ${s.passages} passages from '
          '${s.sources} sources',
        );
        return 0;
      } on GuideProblem catch (e) {
        stderr.writeln('The app cannot use this guide: ${e.message}');
        return 1;
      }
    default:
      throw _Usage('unknown command: ${args.first}');
  }
}

/// `--name value` options, and the other arguments in order.
(Map<String, String>, List<String>) _options(List<String> args) {
  const known = {'id', 'publisher', 'language', 'region', 'out'};
  final options = <String, String>{};
  final rest = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a.startsWith('--')) {
      final name = a.substring(2);
      if (!known.contains(name)) throw _Usage('unknown option: $a');
      if (i + 1 >= args.length) throw _Usage('$a needs a value');
      options[name] = args[++i];
    } else {
      rest.add(a);
    }
  }
  return (options, rest);
}
