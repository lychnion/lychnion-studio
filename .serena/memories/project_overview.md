# Lychnion Studio: overview

Pure Dart CLI for publishers: turns their own web pages into a guide (a
SQLite knowledge package) that the Lychnion app reads. Repo
`lychnion/lychnion-studio` is public: everything in these memories is public too.

Do not restate the docs here. Read:
- `README.md`: commands (`draft`, `build`, `check`), what is not supported yet,
  how to move the `lychnion_guide` pin.
- `docs/publishing.md`: the whole publishing process, signing and keys.
- `.github/workflows/ci.yml`: the checks to run before pushing (format,
  analyze with `--fatal-infos`, test).

The guide tables and check come from `packages/lychnion_guide` in the app
repo (`lychnion/lychnion`), pinned by commit in `pubspec.yaml`. Lychnion's own
guides are built in the sibling repo `lychnion-data`.
