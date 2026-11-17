# Knit

[![CI](https://github.com/lumpsoid/knit_mobile/actions/workflows/ci.yml/badge.svg)](https://github.com/lumpsoid/knit_mobile/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Knit is a place to put things down and tie them together. You write **cards**
into **collections**, one after another like a chat with yourself, and
**link** any card or collection to any other. The links you make become the
structure: a collection can act as a tag, a hub, or a table of contents.

Everything stays on your phone. Knit has no account and no server, and the
Android app has no internet permission.

## Features

- **Chat-style collections.** Text, links, photos (several per card), audio
  messages and any file, in a feed you can reorder, multi-select and move
  between collections.
- **Links everywhere.** Link a card to another card or to a collection.
  Links show as chips under a card, as Connection cards in the feed, and
  as backlinks. The Connections view shows what a card or collection links
  to and what links back, flags links whose target is gone, and finds
  cards that mention a collection without linking it.
- **Settle and emphasize.** Settle a card you're done with: it recedes but
  stays. Emphasize one that matters: it's framed, becomes a heading in the
  Outline, and starts a new slide.
- **Search** across everything, with filters for type, kind, settled,
  archived and "Linked to…" (tags through links).
- **Present** a collection as slides that follow its links.
- **Share a collection as a file** (`.knitc`), optionally with the
  collections it links to. The receiver gets a read-only copy, signed by
  you, and can save their own copy.
- **Backup and restore** of all your data and your identity. The identity
  key is sealed with a passphrase you choose.
- **Android extras:** share text, photos and files into Knit from other
  apps, and a home-screen widget that opens a collection or adds a card to
  it.

## Install

Knit is released for **Android 7.0 or newer**.

1. Download `knit-<version>.apk` from the
   [latest release](https://github.com/lumpsoid/knit_mobile/releases/latest).
2. Optionally check it against the `.sha256` file next to it:
   `sha256sum -c knit-<version>.apk.sha256`.
3. Open the APK on your phone and allow installing from that source.

Updates install over the previous version and keep your data. Back up from
Settings → Data now and then: Knit keeps everything on the device, so a
lost phone loses whatever isn't backed up.

## Build from source

You need [Flutter](https://docs.flutter.dev/get-started/install) (the version
in `.fvmrc`) and the Android SDK.

```sh
git clone https://github.com/lumpsoid/knit_mobile.git
cd knit_mobile
flutter pub get
flutter run --flavor prod -t lib/main_prod.dart
```

`scripts/release_apk.sh` builds a release APK into `dist/`. The code also
targets iOS, macOS, Linux and Windows, but only Android is released and
tested. Share capture and the widget are Android only.

## How it works

Each device has a local SQLite database and an Ed25519 identity, made when you
set Knit up. Every change is a signed record in an append-only log. The tables
you see are a cache of that log, kept by a deterministic merge (hybrid logical
clocks, last-writer-wins per entity) and rebuildable from it. That merge is
what lets collections move between devices and people as files today, and
through a sync relay later.

The full design is in [`docs/app_spec.md`](docs/app_spec.md). The code is
laid out in [`CLAUDE.md`](CLAUDE.md), and the UI architecture is in
[`docs/architecture/`](docs/architecture/).

## Contributing

Bug reports and ideas are welcome. Please read
[CONTRIBUTING.md](CONTRIBUTING.md) first; for anything bigger than a small
fix, start with a proposal issue.

## License

[MIT](LICENSE) © lumpsoid. Knit bundles no third-party fonts or media; its
icons are Flutter's Material Icons (Apache 2.0).
