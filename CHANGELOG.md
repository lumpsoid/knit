# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.2+3] — 2026-06-18

### Added
- Attach any file to a card. Image and audio files render and play as media cards; everything else becomes a tappable file card (icon, name, size) you can share.
- Play audio messages with a mini-player pinned above the composer that follows the feed, plus a now-playing indicator on the audio card.
- Editable collection header — a top-most title card showing the cover, title, and optional description, edited on a dedicated page (title, description, add/replace/remove cover).
- Home feed rows now show a collection's cover image in place of the lettered avatar when one is set.
- Card edit now handles image, audio, and file attachments: add a photo or attach any file, and replacing an attachment can switch its kind.

### Changed
- The collection screen app-bar title is now a static "Collection" (the name lives in the header card).
- A caption-less file card opens the card-actions sheet on tap (reaching Share and Delete) instead of sharing directly, so it can be removed.

## [1.0.1+2] — 2026-06-17

### Added
- Record an audio message in a collection, with an optional caption.
- Choose the source when adding a photo — camera or gallery.
- Share a card via the system share sheet.
- Full-screen image preview for image cards.

### Changed
- Sync indicator now shows a cloud icon for the pending state instead of a save-to-disk icon.
