import 'dart:async';
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

List<Passage> _passagesOf(String html) =>
    passages(cleanLines(pageText(html).text));

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
      final ps = _passagesOf(_page);
      expect(ps.map((p) => p.heading), ['地震に備える', '避難所']);
      expect(ps[1].text, startsWith('市内の小学校'));
      expect(ps.any((p) => p.text == '短い'), isFalse);
    });

    test('long text is split, at sentence ends when it can be', () {
      final lines = [for (var i = 0; i < 10; i++) '${'あ' * 100}$i'];
      for (final p in passages(lines)) {
        expect(p.text.runes.length, lessThanOrEqualTo(maxPassageChars + 10));
      }
      // One long paragraph without line breaks.
      final long = List.filled(40, '避難所では係の人の指示に従ってください。').join();
      final ps = passages([long]);
      expect(ps.length, greaterThan(1));
      for (final p in ps) {
        expect(p.text.runes.length, lessThanOrEqualTo(maxPassageChars));
        expect(p.text, endsWith('。'));
      }
    });

    test('without <main>, the body without menus; forms are kept', () {
      final ps = _passagesOf(
        '<html><body><nav>メニュー</nav><form><h2>備蓄</h2>'
        '<p>水は一人一日3リットルを目安に、最低3日分を備えてください。</p></form></body></html>',
      );
      expect(ps.single.heading, '備蓄');
    });

    test('furigana, hidden text and wrapped headings', () {
      final ps = _passagesOf(
        '<main><h2>避難の\n  しかた</h2><p><ruby>避難<rt>ひなん</rt></ruby>する'
        'ときは、<span hidden>隠れた文字</span>近所の人に声をかけて一緒に'
        '移動してください。</p><h5>小見出し</h5><section>持ち出し品は'
        'リュックに入れて玄関の近くに置いてください。</section></main>',
      );
      expect(ps.first.heading, '避難の しかた');
      expect(ps.first.text, startsWith('避難するときは、近所の人に'));
      expect(ps.first.text, isNot(contains('隠れた')));
      expect(ps.last.heading, '小見出し');
    });

    test('a small main part does not hide the rest of the page', () {
      final body = List.filled(
        10,
        '<p>非常用の持ち出し袋には、水と食料と薬を入れておいてください。</p>',
      ).join();
      final ps = _passagesOf(
        '<body><main><p>お知らせ</p></main><h2>備え</h2>$body</body>',
      );
      expect(ps.single.heading, '備え');
    });

    test('very deep nesting does not overflow', () {
      final deep =
          '${'<div>' * 20000}深い入れ子の中にある本文の文章です。避難所の場所を確認してください。'
          '${'</div>' * 20000}';
      expect(_passagesOf('<body>$deep</body>'), hasLength(1));
    });
  });

  group('reading pages', () {
    test('a saved file; other kinds and missing files are refused', () async {
      final f = File('${tmp.path}/page.html')..writeAsStringSync(_page);
      final p = await readPage(f.path);
      expect(p.isHtml, isTrue);
      expect(p.text, contains('地震に備える'));
      final pdf = File('${tmp.path}/a.pdf')..writeAsStringSync('x');
      expect(
        readPage(pdf.path),
        throwsA(
          isA<PageError>().having((e) => e.message, 'm', contains('PDF')),
        ),
      );
      expect(
        readPage('${tmp.path}/pagee.html'),
        throwsA(
          isA<PageError>().having(
            (e) => e.message,
            'm',
            contains('no such file'),
          ),
        ),
      );
    });

    test(
      'a web page; other charsets, types, errors and slow servers are refused',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((req) async {
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
            case '/pdf':
              r.headers.set('content-type', 'application/pdf');
              r.write('%PDF');
            case '/slow':
              r.headers.contentType = ContentType.html;
              for (var i = 0; i < 20; i++) {
                r.write('<p>a</p>');
                await r.flush();
                await Future<void>.delayed(const Duration(milliseconds: 200));
              }
            case '/file':
              r.statusCode = 302;
              r.headers.set('location', 'file:///etc/hosts');
            default:
              r.statusCode = 404;
          }
          await r.close().catchError((Object _) {});
        });
        final base = 'http://127.0.0.1:${server.port}';
        Matcher refused(String text) => throwsA(
          isA<PageError>().having((e) => e.message, 'm', contains(text)),
        );
        try {
          final p = await readPage('$base/ok');
          expect(p.isHtml, isTrue);
          expect(p.url, '$base/ok');
          await expectLater(readPage('$base/sjis'), refused('UTF-8'));
          await expectLater(readPage('$base/meta'), refused('UTF-8'));
          await expectLater(readPage('$base/pdf'), refused('PDFs'));
          await expectLater(readPage('$base/missing'), refused('404'));
          await expectLater(readPage('$base/file'), refused('redirected'));
          await expectLater(
            readPage('$base/slow', timeout: const Duration(seconds: 1)),
            refused('not read within'),
          );
        } finally {
          await server.close(force: true);
        }
      },
    );
  });

  group('a draft', () {
    Future<Map<String, Object?>> draft() async {
      final f = File('${tmp.path}/page.html')..writeAsStringSync(_page);
      final d = await makeDraft(
        id: 'jp.city.sample.bousai',
        publisher: 'サンプル市',
        sources: [f.path],
        version: '2026.11.18',
      );
      // A page given as a file: the publisher fills in its address.
      ((d['sources'] as List).single as Map)['url'] =
          'https://www.city.sample.lg.jp/bousai/';
      return d;
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

    test('a saved file leaves the address to fill in', () async {
      final f = File('${tmp.path}/page.html')..writeAsStringSync(_page);
      final d = await makeDraft(id: 'x', publisher: 'p', sources: [f.path]);
      expect(((d['sources'] as List).single as Map)['url'], '');
      expect(draftProblems(d), contains(startsWith('sources[0].url')));
    });

    test('bad ids, regions and languages are refused', () {
      for (final (id, region, lang) in [
        ('../x', 'JP', 'ja'),
        ('x', 'jp', 'ja'),
        ('x', 'JP', 'Japanese'),
      ]) {
        expect(
          makeDraft(
            id: id,
            publisher: 'p',
            sources: const [],
            region: region,
            language: lang,
          ),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('problems are listed for building', () async {
      final d = await draft();
      d['version'] = 'new';
      d['notice'] = {
        'ja': <String>[],
        'en': [1],
      };
      d['name'] = {'ja': 3};
      ((d['sources'] as List).single as Map).remove('title');
      final rows = d['passages'] as List;
      rows.add({'source': 's9', 'text': 'x'});
      rows.add(Map<String, Object?>.of(rows.first as Map<String, Object?>));
      final p = draftProblems(d);
      expect(p, contains(startsWith('version')));
      expect(p, contains(startsWith('notice')));
      expect(p, contains(startsWith('name')));
      expect(p, contains('sources[0].title: needed'));
      expect(p, contains(contains('"s9" is not in sources')));
      expect(p, contains(contains('same text as passages[0]')));
      expect(() => buildGuide(d, tmp), throwsA(isA<BuildError>()));
    });
  });

  group('a built guide', () {
    Future<File> built() async {
      final f = File('${tmp.path}/page.html')..writeAsStringSync(_page);
      final d = await makeDraft(
        id: 'jp.city.sample.bousai',
        publisher: 'サンプル市',
        sources: [f.path],
        version: '2026.11.18',
      );
      ((d['sources'] as List).single as Map)['url'] = 'https://example.org/';
      return buildGuide(d, Directory('${tmp.path}/out'));
    }

    test('opens as the app opens it', () async {
      final file = await built();
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

    test('what the app cannot use is named', () async {
      File make(String name, String sql) {
        final f = File('${tmp.path}/$name.sqlite');
        final db = sqlite3.open(f.path)..execute(sql);
        db.close();
        return f;
      }

      const base = '''
        CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
        INSERT INTO meta VALUES('id', 'x'), ('version', '1');
        CREATE TABLE sources(id TEXT PRIMARY KEY, title TEXT, publisher TEXT,
          url TEXT, licence TEXT, attribution TEXT);
        INSERT INTO sources VALUES('s1', 't', 'p', 'https://x', 'l', 'a');
        CREATE TABLE alerts(id TEXT, source_id TEXT, text TEXT, match_all TEXT);
      ''';
      const passagesTable =
          'CREATE TABLE passages(id INTEGER, source_id TEXT, heading TEXT, text TEXT);';
      String problem(File f) {
        try {
          checkGuide(f.path);
          return 'ok';
        } on GuideProblem catch (e) {
          return e.message;
        }
      }

      expect(problem(make('nopassages', base)), contains('passages'));
      expect(problem(make('empty', '$base $passagesTable')), 'no passages');
      final ok = "INSERT INTO passages VALUES(1, 's1', 'h', 'text');";
      expect(problem(make('fine', '$base $passagesTable $ok')), 'ok');
      expect(
        problem(
          make('orphan', '''$base $passagesTable
          INSERT INTO passages VALUES(1, 'gone', 'h', 'text');'''),
        ),
        contains('source is missing'),
      );
      expect(
        problem(
          make('nulltitle', '''$base $passagesTable $ok
          UPDATE sources SET title = NULL;'''),
        ),
        contains('no title'),
      );
      expect(
        problem(
          make('notice', '''$base $passagesTable $ok
          INSERT INTO meta VALUES('notice', '{"ja": "not a list"}');'''),
        ),
        contains('meta notice'),
      );
      expect(
        problem(
          make('alert', '''$base $passagesTable $ok
          INSERT INTO alerts VALUES('a', 's1', 'text', '["not groups"]');'''),
        ),
        contains('match_all'),
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
    final args = [
      'draft',
      '--id=jp.city.sample.bousai',
      '--publisher',
      'サンプル市',
      '--out',
      draft,
      f.path,
    ];
    var r = await run(args);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(r.stdout, contains('Fill in the web address'));
    // A reviewed draft is not replaced by accident.
    final d = jsonDecode(File(draft).readAsStringSync()) as Map;
    ((d['sources'] as List).single as Map)['url'] = 'https://example.org/';
    File(draft).writeAsStringSync(jsonEncode(d));
    r = await run(args);
    expect(r.exitCode, 1);
    expect(r.stderr, contains('not replaced'));
    expect(File(draft).readAsStringSync(), contains('https://example.org/'));
    r = await run(['build', draft, '--out', '${tmp.path}/out']);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(r.stdout, contains('2 passages'));
    r = await run(['check', '${tmp.path}/out/jp.city.sample.bousai.sqlite']);
    expect(r.exitCode, 0);
    r = await run(['draft', '--id', 'x']);
    expect(r.exitCode, 64);
    r = await run(['check', '--out', 'x', 'y']);
    expect(r.exitCode, 64);
    // A missing folder: one plain line, no stack trace.
    r = await run(['build', '${tmp.path}/none/draft.json']);
    expect(r.exitCode, 1);
    expect(r.stderr, isNot(contains('#0')));
  });

  group('review fixes', () {
    test('notices name 119 and 110 only for Japan', () {
      expect(
        defaultNotice('City', region: 'US')['en']!.join(),
        isNot(contains('119')),
      );
      expect(
        defaultNotice('City', region: 'JP-28')['ja']!.join(),
        contains('119'),
      );
    });

    test('scripts and menus do not decide the main part', () {
      final text = List.filled(
        5,
        '<p>給水所は市役所の駐車場です。ポリタンクを持ってきてください。</p>',
      ).join();
      final ps = _passagesOf(
        '<body><nav><article>${'メニュー' * 500}</article></nav>'
        '<article><script>${'x' * 100000}</script><h2>給水</h2>$text</article>'
        '<aside>${'関係のない横の欄の文章です。' * 3}</aside></body>',
      );
      expect(ps.single.heading, '給水');
      expect(ps.single.text, isNot(contains('関係のない')));
    });

    test('a very long line is split quickly', () {
      final long = '避難所の場所を確認してください。' * 20000; // 320,000 characters
      final sw = Stopwatch()..start();
      final ps = passages([long]);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      expect(ps.length, greaterThan(700));
    });

    test('source ids are unique beyond the guide', () async {
      final f = File('${tmp.path}/page.html')..writeAsStringSync(_page);
      final d = await makeDraft(id: 'jp.a', publisher: 'p', sources: [f.path]);
      expect(((d['sources'] as List).single as Map)['id'], 'jp.a/s1');
      expect(((d['passages'] as List).first as Map)['source'], 'jp.a/s1');
    });

    test('check reads what the app reads', () {
      var n = 0;
      String problem(String extra) {
        final f = File('${tmp.path}/g${n++}.sqlite');
        final db = sqlite3.open(f.path)
          ..execute('''
            CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
            INSERT INTO meta VALUES('id', 'x'), ('version', '1');
            CREATE TABLE sources(id TEXT PRIMARY KEY, title TEXT, publisher TEXT,
              url TEXT, licence TEXT, attribution TEXT, region TEXT);
            INSERT INTO sources VALUES('s1', 't', 'p', 'https://x', 'l', 'a', 'JP');
            CREATE TABLE passages(id INTEGER PRIMARY KEY, source_id TEXT,
              heading TEXT, text TEXT, original_heading TEXT, original TEXT);
            INSERT INTO passages VALUES(1, 's1', 'h', 'text', NULL, NULL);
            CREATE TABLE alerts(id TEXT, source_id TEXT, text TEXT, match_all TEXT);
            $extra''');
        db.close();
        try {
          checkGuide(f.path);
          return 'ok';
        } on GuideProblem catch (e) {
          return e.message;
        }
      }

      expect(problem(''), 'ok');
      expect(problem("UPDATE sources SET region = x'01';"), contains('region'));
      expect(
        problem("UPDATE passages SET original = x'01';"),
        contains('original'),
      );
      expect(
        problem('''CREATE TABLE passage_texts(passage_id INTEGER, lang TEXT,
          heading TEXT, text TEXT);
          INSERT INTO passage_texts VALUES(1, 'en', NULL, NULL);'''),
        contains('passage_texts'),
      );
      expect(
        problem(
          '''CREATE TABLE vectors(model TEXT, passage_id INTEGER, vec BLOB);
          INSERT INTO vectors VALUES('m', 1, 'text');''',
        ),
        contains('vectors'),
      );
    });
  });

  group('second review', () {
    test('the end of a long paragraph is kept', () {
      final line = '${'安全な場所に避難してください。' * 28}川には絶対に近づかないでください。';
      final ps = passages([line]);
      expect(ps.map((p) => p.text).join(), contains('川には絶対に近づかないでください。'));
    });

    test('a short last line of a section is kept, a lone one is not', () {
      final ps = passages(['## 避難', 'あ' * 410, '川に近づかない。', '## メニュー', '短い']);
      expect(ps.single.text, endsWith('\n川に近づかない。'));
    });

    test('deeply nested headings and many articles are fine', () {
      final heading = '<h1>${'<span>' * 20000}見出し${'</span>' * 20000}</h1>';
      expect(pageText('<body>$heading<p>本文</p></body>').title, '見出し');
      final articles =
          '${'<article>' * 5000}'
          '<p>入れ子の記事の中の本文です。避難所を確認してください。</p>'
          '${'</article>' * 5000}';
      final sw = Stopwatch()..start();
      expect(_passagesOf('<body>$articles</body>'), hasLength(1));
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('vectors without passage_id are refused', () {
      final f = File('${tmp.path}/v.sqlite');
      sqlite3.open(f.path)
        ..execute('''
          CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
          INSERT INTO meta VALUES('id', 'x'), ('version', '1');
          CREATE TABLE sources(id TEXT PRIMARY KEY, title TEXT, publisher TEXT,
            url TEXT, licence TEXT, attribution TEXT);
          INSERT INTO sources VALUES('s1', 't', 'p', 'https://x', 'l', 'a');
          CREATE TABLE passages(id INTEGER PRIMARY KEY, source_id TEXT,
            heading TEXT, text TEXT);
          INSERT INTO passages VALUES(1, 's1', 'h', 'text');
          CREATE TABLE alerts(id TEXT, source_id TEXT, text TEXT, match_all TEXT);
          CREATE TABLE vectors(model TEXT, vec BLOB);
          INSERT INTO vectors VALUES('m', x'00');''')
        ..close();
      expect(() => checkGuide(f.path), throwsA(isA<GuideProblem>()));
    });
  });
}
