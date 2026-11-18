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

- **Never share it** or put it on a web server. If someone else gets it,
  they can sign guides in your name.
- People add your publisher once, from your QR code or link
  (`lychnion://publisher?…`), shown in "Publish your own". Show it where
  people can see it is really yours: at your office, on your official
  website, at the shelter.

**Back it up.** In "Publish your own", "Save a key backup" writes a file
`<name>.lychnion-key`, protected by a passphrase of at least 12
characters: choose several unrelated words, it is the only protection if
the file leaks. Keep the file offline (a USB stick in a safe, or a
password manager), never on a server, in a repository or on a stick you
hand out. Keep the passphrase somewhere else (on paper in another safe,
or with another person), never next to the file or in the same password
manager. `publisher/publisher.json` is the live key without a
passphrase: never copy it as a backup. A forgotten passphrase cannot
be recovered. Without the passphrase a leaked file cannot sign in your
name, but it can switch your key off (revoke it).

**New computer.** "Restore from a backup" works only on a computer that
has no key yet; it never replaces a key. A wrong passphrase or a damaged
file is refused and nothing is written. Restore your newest backup only:
a backup of a key you have replaced since must not be used again.

**Replace or revoke?** Replace when you still have the key and nobody
else does, to move to a new key; the old key stays valid for what it
signed. If the key may have been stolen, revoke it: replacing a stolen
key does not stop the thief. Revoking cannot be undone.

**Replace the key** ("Replace the key"): the app makes a new key and
signs it with the old one. Phones that trust your old key accept the new
one once they get the statement from you (see "Tell phones about it"
below). What you signed before stays valid. Then save a new key backup,
and keep the old backup as safely as the new one: anyone who gets the
old key or its backup can switch it off, and phones that only know the
old key would then lose your new key too.

**If the key was stolen**, or may have been ("Revoke the key"): phones
stop trusting the key and everything it signed. The app makes a new key
and signs the newest version of each of your guides and maps again with
it. Then:

1. Put the statement into your catalog (see "Tell phones about it").
2. Save a new key backup.
3. Show your new QR code or link again, only in person or on your
   official website, where people can see it is really yours. Phones
   cannot tell you from the thief, so each person decides by adding
   your new code. Until then your publisher shows as revoked there, and
   your old code is refused.

**If you lost the computer:** "Revoke a lost key from a backup", with
your newest backup, uses the ready-made revocation in the file; it needs
no passphrase and cannot be undone. (An older backup holds an older key;
revoking it also cuts off the keys that replaced it.) You then have no
key: create a new one in "Publish your own", save a backup and show its
QR code again, as above. With no backup at all you can neither revoke
nor replace the key: whoever has the computer can sign in your name
until people remove your publisher, so ask them to remove it and add
your new one.

**Tell phones about it.** A replacement or a revocation does nothing on
phones until they get the statement. After either one, before you
publish anything signed with the new key:

1. Open `publisher/keys.json` in the desktop app's folder (it holds no
   private key).
2. Copy its whole `keys` list into the `catalog.json` you publish, each
   time: the earlier statements must stay there too.
3. Publish the catalog.

Phones learn it from your catalog, also from a copy they fetched
earlier, and from USB sticks made in the desktop app. Do not count on
anything else to pass it on: put it in your own catalog.

Older versions of the app do not know about replaced or revoked keys:
they show guides signed by your new key as having a bad signature, and
they keep trusting a revoked key. Ask people to update.

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
