import 'dart:convert';
import 'dart:io';

import 'package:lychnion_studio/lychnion_studio.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

const _page = '''
<!doctype html>
<html><head><title>防災のページ｜サンプル市</title>
<script>var menu = "メニューのスクリプト";</script></head>
<body>
<header><p>サンプル市 トップページ メニュー 検索 ここは本文ではありません</p></header>
<nav><ul><li>くらし・手続き</li><li>防災・安全のメニューの項目です</li></ul></nav>
<main>
  <h1>地震に備える</h1>
  <p>家具の転倒を防ぐため、背の高い家具は壁に固定してください。寝室にはできるだけ家具を置かないようにします。</p>
  <h2>避難所</h2>
  <ul><li>市内の小学校と中学校が指定避難所です。場所は防災マップで確認できます。</li>
  <li>短い</li></ul>
  <p>ページの先頭へ</p>
</main>
<footer><p>サンプル市役所 〒000-0000 電話 000-000-0000 お問い合わせはこちら</p></footer>
</body></html>
''';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('studio'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('a page', () {
    test('only its main part, with headings', () {
      final t = pageText(_page);
      expect(t.title, '防災のページ｜サンプル市');
      final lines = cleanLines(t.text);
      expect(lines, contains('## 地震に備える'));
      expect(lines.any((l) => l.contains('メニュー')), isFalse);
      expect(lines.any((l) => l.contains('お問い合わせ')), isFalse);
      expect(lines, isNot(contains('ページの先頭へ')));
    });

    test('becomes passages: headings start one, short ones go', () {
      final ps = passages(cleanLines(pageText(_page).text));
      expect(ps.map((p) => p.heading), ['地震に備える', '避難所']);
      expect(ps[1].text, startsWith('市内の小学校'));
      expect(ps.any((p) => p.text == '短い'), isFalse);
    });

    test('long text is split at about 420 characters', () {
      final lines = [for (var i = 0; i < 10; i++) '${'あ' * 100}$i'];
      final ps = passages(lines);
      expect(ps.length, greaterThan(1));
      for (final p in ps) {
        expect(p.text.runes.length, lessThanOrEqualTo(maxPassageChars + 10));
      }
    });

    test('without <main>, the body without menus', () {
      final t = pageText(
        '<html><body><nav>メニュー</nav><h2>備蓄</h2>'
        '<p>水は一人一日3リットルを目安に、最低3日分を備えてください。</p></body></html>',
      );
      expect(passages(cleanLines(t.text)).single.heading, '備蓄');
    });
  });

  group('reading pages', () {
    test('a saved file; other kinds are refused', () async {
      final f = File('${tmp.path}/page.html')..writeAsStringSync(_page);
      final p = await readPage(f.path);
      expect(p.isHtml, isTrue);
      expect(p.text, contains('地震に備える'));
      final pdf = File('${tmp.path}/a.pdf')..writeAsStringSync('x');
      expect(readPage(pdf.path), throwsA(isA<PageError>()));
      expect(readPage('ftp://example.org/x'), throwsA(isA<PageError>()));
    });

    test('a web page; Shift_JIS and errors are refused', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        final r = req.response;
        switch (req.uri.path) {
          case '/ok':
            r.headers.contentType = ContentType.html;
            r.add(utf8.encode(_page));
          case '/sjis':
            r.headers.contentType = ContentType(
              'text',
              'html',
              charset: 'Shift_JIS',
            );
            r.add([0x82, 0xa0]);
          case '/meta':
            r.headers.set('content-type', 'text/html');
            r.write('<meta charset="euc-jp"><p>x</p>');
          default:
            r.statusCode = 404;
        }
        r.close();
      });
      final base = 'http://127.0.0.1:${server.port}';
      try {
        final p = await readPage('$base/ok');
        expect(p.isHtml, isTrue);
        expect(p.url, '$base/ok');
        for (final path in ['/sjis', '/meta']) {
          await expectLater(
            readPage('$base$path'),
            throwsA(
              isA<PageError>().having((e) => e.message, 'm', contains('UTF-8')),
            ),
          );
        }
        await expectLater(
          readPage('$base/missing'),
          throwsA(
            isA<PageError>().having((e) => e.message, 'm', contains('404')),
          ),
        );
      } finally {
        await server.close(force: true);
      }
    });
  });

  group('a draft', () {
    Future<Map<String, Object?>> draft() async {
      final f = File('${tmp.path}/page.html')..writeAsStringSync(_page);
      return makeDraft(
        id: 'jp.city.sample.bousai',
        publisher: 'サンプル市',
        sources: [f.path],
        version: '2026.11.18',
      );
    }

    test('has the publisher, a notice, sources and passages', () async {
      final d = await draft();
      expect(d['id'], 'jp.city.sample.bousai');
      expect((d['notice'] as Map)['ja'], isNotEmpty);
      final s = (d['sources'] as List).single as Map;
      expect(s['title'], '防災のページ｜サンプル市');
      expect(s['licence'], '© サンプル市');
      expect((d['passages'] as List).length, 2);
      expect(draftProblems(d), isEmpty);
      // The JSON keeps Japanese as it is, for editing.
      expect(draftJson(d), contains('地震に備える'));
    });

    test('a bad id is refused', () {
      expect(
        makeDraft(id: '../x', publisher: 'p', sources: const []),
        throwsA(isA<FormatException>()),
      );
    });

    test('problems are listed for building', () async {
      final d = await draft();
      d['version'] = 'new';
      d['notice'] = {'ja': <String>[]};
      (d['passages'] as List).add({'source': 's9', 'text': 'x'});
      final p = draftProblems(d);
      expect(p, contains(startsWith('version')));
      expect(p, contains(startsWith('notice')));
      expect(p, contains(contains('"s9" is not in sources')));
      expect(() => buildGuide(d, tmp), throwsA(isA<BuildError>()));
    });
  });

  group('a built guide', () {
    test('opens as the app opens it', () async {
      final f = File('${tmp.path}/page.html')..writeAsStringSync(_page);
      final d = await makeDraft(
        id: 'jp.city.sample.bousai',
        publisher: 'サンプル市',
        sources: [f.path],
        version: '2026.11.18',
      );
      final file = buildGuide(d, Directory('${tmp.path}/out'));
      expect(file.path, endsWith('/jp.city.sample.bousai.sqlite'));
      final s = checkGuide(file.path);
      expect(
        (s.id, s.version, s.sources, s.passages),
        ('jp.city.sample.bousai', '2026.11.18', 1, 2),
      );
      final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
      addTearDown(db.close);
      final meta = {
        for (final r in db.select('SELECT key, value FROM meta'))
          r['key']: r['value'],
      };
      expect(jsonDecode(meta['notice'] as String)['ja'], isNotEmpty);
      expect(jsonDecode(meta['name'] as String), {'ja': 'サンプル市'});
      // Keyword search over passages, as in Lychnion's own guides.
      expect(
        db.select(
          "SELECT rowid FROM passages_fts WHERE passages_fts MATCH '小学校'",
        ),
        hasLength(1),
      );
      expect(File('${file.path}.building').existsSync(), isFalse);
    });

    test('what the app cannot use is named', () {
      File make(String name, String sql) {
        final f = File('${tmp.path}/$name.sqlite');
        final db = sqlite3.open(f.path)..execute(sql);
        db.close();
        return f;
      }

      const base = '''
        CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
        INSERT INTO meta VALUES('id', 'x'), ('version', '1');
        CREATE TABLE sources(id TEXT PRIMARY KEY);
        INSERT INTO sources VALUES('s1');
        CREATE TABLE alerts(id TEXT, source_id TEXT, match_all TEXT);
      ''';
      String problem(File f) {
        try {
          checkGuide(f.path);
          return 'ok';
        } on GuideProblem catch (e) {
          return e.message;
        }
      }

      expect(problem(make('nopassages', base)), contains('passages'));
      expect(
        problem(
          make(
            'empty',
            '$base CREATE TABLE passages(id INTEGER, source_id TEXT, text TEXT);',
          ),
        ),
        'no passages',
      );
      expect(
        problem(
          make('orphan', '''$base
          CREATE TABLE passages(id INTEGER, source_id TEXT, text TEXT);
          INSERT INTO passages VALUES(1, 'gone', 'text');'''),
        ),
        contains('source is missing'),
      );
      final junk = File('${tmp.path}/junk.sqlite')
        ..writeAsStringSync('not sqlite at all');
      expect(problem(junk), isNot('ok'));
    });
  });

  test('the command line: draft, build, check', () async {
    final f = File('${tmp.path}/page.html')..writeAsStringSync(_page);
    Future<ProcessResult> run(List<String> a) => Process.run(
      Platform.resolvedExecutable,
      ['run', 'bin/lychnion_studio.dart', ...a],
    );
    final draft = '${tmp.path}/draft.json';
    var r = await run([
      'draft',
      '--id',
      'jp.city.sample.bousai',
      '--publisher',
      'サンプル市',
      '--out',
      draft,
      f.path,
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    r = await run(['build', draft, '--out', '${tmp.path}/out']);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(r.stdout, contains('2 passages'));
    r = await run(['check', '${tmp.path}/out/jp.city.sample.bousai.sqlite']);
    expect(r.exitCode, 0);
    r = await run(['draft', '--id', 'x']);
    expect(r.exitCode, 64);
  });
}
