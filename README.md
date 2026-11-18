# Lychnion Studio

Tools for publishers: turn your own web pages into a guide for
[Lychnion](https://github.com/lychnion/lychnion), the offline safety app.
People can then read your guide and ask about it on their phones, even
without internet.

```bash
dart pub get
dart run bin/lychnion_studio.dart draft --id jp.city.example.bousai --publisher "Example City" https://www.city.example.lg.jp/bousai/jishin.html
dart run bin/lychnion_studio.dart build draft.json
dart run bin/lychnion_studio.dart check build/jp.city.example.bousai.sqlite
```

- `draft` reads your pages (addresses, or saved `.html` and `.txt` files
  in UTF-8) and writes `draft.json`: the guide's name, notice, sources
  and passages. Review and edit it.
- `build` writes `build/<id>.sqlite` in the format the app reads, and
  checks it.
- `check` opens a guide file as the app does.

You then sign and publish the file with the Lychnion desktop app
("Publish your own"). The whole process, what makes a good guide and how
to keep your key: [docs/publishing.md](docs/publishing.md).

The guide format is the one Lychnion's own guides use (built by
`tool/build_package.py` in lychnion-data). The tables, writing a guide
and the check come from `lychnion_guide` in
[lychnion/lychnion](https://github.com/lychnion/lychnion/tree/main/packages/lychnion_guide),
the package the app uses, so a guide that passes `check` here passes in
the app. `pubspec.yaml` pins it to a commit (`ref`); to move it, set a
newer commit and run `dart pub upgrade lychnion_guide`. Pure Dart, no
Flutter.

Not yet: PDFs and pages in Shift_JIS or EUC-JP (copy their text into a
UTF-8 text file, see the guide), translation, a desktop window.

## Licence

AGPL-3.0, see [LICENSE](LICENSE).
