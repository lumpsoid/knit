# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

The first public release. Earlier private builds (1.0.x) are not listed.

### Added
- Collections: chat-style feeds of cards — text, links, one or more photos,
  audio messages and any file — with reorder, multi-select, move to another
  collection, and a docked, editable title header with an optional cover.
- Links between cards and collections, shown as chips, Connection cards and
  backlinks; the Connections view lists an entity's links out and backlinks,
  flags broken links, and suggests unlinked mentions.
- Settle (quietly recede) or emphasize cards; archive collections.
- Search across collections and cards, with filters (type, kind, settled,
  archived, "Linked to…") and a per-collection search.
- Outline of a collection's emphasized cards, and Present mode: a collection
  as slides that can follow links.
- Optional "Optimize size" for photos, with an EXIF toggle in Settings.
- Share a collection as a `.knitc` file (optionally with the collections it
  links to), and import one as a read-only collection you can copy.
- Backup and restore of your data and identity (the identity key sealed
  under a passphrase).
- Android: capture text, photos and files shared from other apps, and a
  home-screen widget that opens or quick-adds to a collection.
- A per-device signing identity (`nickname#fingerprint`); every change is a
  signed record in a local log.
- Settings → About shows the version with its commit hash.
