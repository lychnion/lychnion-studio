# Publishing a guide for Lychnion

For cities, towns, clubs and others who want their own safety information
in Lychnion, so people can read it and ask about it without internet.

A **guide** is one file (`<id>.sqlite`) with short passages of text, the
pages they come from, a name and a notice. You make it from your own web
pages, check it, sign it with your publisher key, and pass it on. Phones
trust it because of your signature, not because of where it came from.

What the tools can read today: web pages and text files. **PDFs not
yet** (shelter lists and hazard maps are often PDFs): copy their text into
a text file for now (see step 1).

## What makes a good guide

- **One clear subject and place.** For example "Kobe: disaster
  preparedness", not everything your website has. People ask questions;
  the app answers from your passages and shows the page each answer comes
  from.
- **Your own content.** Pages you publish yourself are the easy case: you
  decide what may be passed on. Content from others needs their licence
  (for example CC BY 4.0) and its attribution in the source entry.
- **A notice.** One or two lines shown before people rely on the guide:
  who published it, that your official announcements come first, and the
  emergency numbers. The tool writes a first version; check it.
- **Short, current passages.** Remove menus, page footers, contact
  blocks, dates of past events and anything that is no longer true.
  Every passage should make sense alone, under its heading.
- **Translations** (later): when you add another language, a person who
  reads both languages should review it before you publish.

## Make it

You need, once:

- **Dart** 3.12 or newer: <https://dart.dev/get-dart> (macOS, Windows,
  Linux).
- **This repository**: on its GitHub page choose Code → Download ZIP and
  unpack it, or `git clone https://github.com/lychnion/lychnion-studio`.
- **Internet** for the first run: it downloads the libraries the tool
  uses, including SQLite.

Open a terminal (on Windows: PowerShell) in the repository folder and
run once:

```bash
dart pub get
```

The commands below are the same on macOS and Windows.

1. **Draft.** Give your id, your name and the pages:

   ```bash
   dart run bin/lychnion_studio.dart draft --id jp.city.example.bousai --publisher "Example City" https://www.city.example.lg.jp/bousai/jishin.html https://www.city.example.lg.jp/bousai/hinanjo.html
   ```

   The id is yours for good: letters, digits, `.`, `_` and `-`, for
   example your country, your city and the subject. Add `--region JP-28`
   (your prefecture's code, here Hyogo) so the app knows where the guide
   applies; the default is `JP`. The tool reads each page, keeps its main
   text and splits it into passages under their headings. It writes
   `draft.json`; an existing `draft.json` is not replaced (add `--force`
   to replace it).

   Pages must be UTF-8. Many Japanese city sites are in Shift_JIS or
   EUC-JP; the tool says so. For such a page, a PDF, or a page that needs
   a browser to show its text:
   1. Open it in the browser, select its text and copy it.
   2. Paste it into a text editor (Notepad on Windows, TextEdit in plain
      text mode on macOS) and put `## ` in front of each heading.
   3. Save it as UTF-8 text (Notepad: Save as → Encoding: UTF-8), for
      example `hinanjo.txt`.
   4. Give the file instead of the address: `... --publisher "Example
      City" hinanjo.txt`. Then fill in the page's web address (`url`) in
      the draft: people see it with every answer.

2. **Review.** Open `draft.json` in a text editor and check:
   - `name` and `title`: what people see in the app.
   - `notice`: what the guide is not for.
   - `sources`: one per page, with its title and address.
   - `passages`: delete menus and anything out of date; fix headings.
   - `version`: today's date. Each new version must be higher than the
     last one you published (versions only go up); a second one on the
     same day is `2026.11.18.1`.

3. **Build.**

   ```bash
   dart run bin/lychnion_studio.dart build draft.json
   ```

   This writes `build/<id>.sqlite` and opens it as the app does. If
   something in the draft is wrong, it lists what to fix, and a guide
   built earlier stays as it was.

4. **Sign and publish.** In the Lychnion desktop app (macOS or Windows):
   Settings → Publishers → "Publish your own".
   - The first time, create your publisher key: a name (lower-case
     letters, digits, `.`, `_` and `-`; it cannot change) and the name
     people see.
   - Then "Publish a guide or map", pick `build/<id>.sqlite`, check the
     form and choose "Sign and publish". The app checks the file again,
     signs it and installs it, and a base computer passes it on to
     phones on its Wi-Fi.

## Your key

The key is in the desktop app's folder (`publisher/publisher.json`); the
screen shows where. It signs everything you publish.

- **Keep a copy offline** (a USB stick in a safe place). Without it you
  cannot publish new versions under the same name.
- **Never share it** or put it on a web server. If someone else gets it,
  they can sign guides in your name.
- People add your publisher once, from your QR code or link
  (`lychnion://publisher?…`), shown in "Publish your own". Show it where
  people can see it is really yours: at your office, on your official
  website, at the shelter.

Replacing a lost or stolen key is not possible yet.

## Getting it to people

- **At a shelter:** the desktop app running as a base passes your guide
  to phones on its Wi-Fi. The base needs its own Wi-Fi (the computer's
  hotspot or a small router); shared and guest networks often block
  phones from reaching it.
- **On the internet:** a headless node (`lychnion_node` in
  [lychnion/lychnion](https://github.com/lychnion/lychnion/tree/main/packages/lychnion_node))
  serves your signed records and files on any web server. People follow
  your catalog with a link (`lychnion://catalog?…`).
- **Without any network:** copy to a USB stick in the desktop app
  (Downloads settings) and load it on another base.

See [`docs/distribution.md`](https://github.com/lychnion/lychnion/blob/main/docs/distribution.md)
in the app repository for how signing, versions and nodes work.

## Not yet

PDFs and pages in Shift_JIS or EUC-JP (copy their text, see step 1),
translation with a larger model, a desktop window for the whole studio,
and publishing to your node from the studio.
