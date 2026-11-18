# Publishing a guide for Lychnion

For cities, towns, clubs and others who want their own safety information
in Lychnion, so people can read it and ask about it without internet.

A **guide** is one file (`<id>.sqlite`) with short passages of text, the
pages they come from, a name and a notice. You make it from your own web
pages, check it, sign it with your publisher key, and pass it on. Phones
trust it because of your signature, not because of where it came from.

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

You need the Dart SDK (3.12 or newer) and this repository. In the
repository folder:

```bash
dart pub get
```

1. **Draft.** Give your id, your name and the pages:

   ```bash
   dart run bin/lychnion_studio.dart draft --id jp.city.example.bousai --publisher "Example City" https://www.city.example.lg.jp/bousai/jishin.html https://www.city.example.lg.jp/bousai/hinanjo.html
   ```

   The id is yours for good: letters, digits, `.`, `_` and `-`, for
   example your country, your city and the subject. The tool reads each
   page, keeps its main text and splits it into passages under their
   headings. It writes `draft.json`.

   Pages must be UTF-8. For a page in Shift_JIS or EUC-JP, or one that
   needs a browser to show its text, open it in a browser, save it as
   text (UTF-8), and give the saved `.txt` or `.html` file instead of the
   address. In a `.txt` file, a line starting with `## ` is a heading.

2. **Review.** Open `draft.json` in a text editor and check:
   - `name` and `title`: what people see in the app.
   - `notice`: what the guide is not for.
   - `sources`: one per page, with its title and address.
   - `passages`: delete menus and anything out of date; fix headings.
   - `version`: today's date. Each new version must be higher than the
     last one you published (versions only go up).

3. **Build.**

   ```bash
   dart run bin/lychnion_studio.dart build draft.json
   ```

   This writes `build/<id>.sqlite` and checks that the app can open it.
   If something in the draft is wrong, it lists what to fix.

4. **Sign and publish.** In the Lychnion desktop app (macOS or Windows):
   Settings → Publishers → "Publish your own".
   - The first time, create your publisher key: a name (cannot change)
     and the name people see.
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

PDFs, translation with a larger model, a desktop window for the whole
studio, and publishing to your node from the studio.
