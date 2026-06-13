# Collection feed — render image-card thumbnails (§4.2 / §7.4.3)

## What's missing

The Collection feed renders an **image** card (`kind: image`, `attachment_id`
set) as a static **"Photo" placeholder** — `_CardBubble._placeholder(theme,
Icons.image_outlined, 'Photo')` in `collection_page.dart` — never the actual
image. The data is already there (`FeedCard.attachmentId` threads through
`CollectionData` → `CollectionState`, mapped from `content['attachment_id']`),
and the §4.3 Card Edit page already sets it; the feed just never reads the bytes.

The attachments foundation now exists (`lib/core/attachments/`, card-edit epic
subtask 1): `AttachmentReadRepository.bytesOf(id)` → bytes + the shared
`AttachmentImage` render widget. The Card Edit page already renders a card's
image through it. This task wires that read path into the **collection** feature
so the feed (and the reorder list) show thumbnails.

## What to build

- Inject a narrow `AttachmentReadRepository` into the Collection feature (via the
  module/shell, over `AppGraph`, mirroring how Card Edit consumes it).
- Load bytes for the feed's image cards and render them with `AttachmentImage`
  in `_CardBubble` (and a small thumbnail in `_ReorderRow`), keeping the
  placeholder as the loading/missing fallback. Decide the load shape within the
  FCIS contract — bytes belong in primitives the widget can take (widgets.md §1),
  loaded via an effect, not a repo call from the widget.
- Avoid reloading on every rebuild — cache decoded bytes by `attachment_id` in
  state (content-addressed, so an id's bytes are immutable).

## Notes / scope

- Same render path the **cover image** needs — see
  [collection--cover-image.md](collection--cover-image.md) (Home/Timeline tiles
  + the Collection header). Worth doing together or sharing the load helper.
- Audio cards (`kind: audio`) are still a placeholder — out of scope here.

## References

- spec §4.2 (feed), §7.4.3 (image cards carry `attachment_id`)
- `lib/features/collection/presentation/collection_page.dart`
  (`_CardBubble`, `_ReorderRow` — the placeholders to replace)
- `lib/features/collection/infra/sync_store_collection_read_repository.dart`
  (`FeedCard.attachmentId` already populated, line ~37)
- `lib/core/attachments/` — `AttachmentReadRepository`, `AttachmentImage`
- `lib/features/card_edit/` — the analog wiring (image read path already done)

---

## Done

Wired the existing attachments read path into the **collection** feature, so the
feed and the reorder list now render real image thumbnails instead of the static
"Photo" placeholder. Follows the Card Edit analog exactly.

**FCIS plumbing**
- `collection_state.dart` — added `Map<String, Uint8List> imageBytes`, a cache
  keyed by `attachment_id`. Content-addressed (an id's bytes are immutable), so
  it is preserved across feed reloads rather than reloaded on every rebuild.
- `collection_action.dart` — `ImageBytesLoaded(attachmentId, bytes)` delivery.
- `collection_effect.dart` — `LoadImageBytesEffect(attachmentId)`.
- `collection_updater.dart` — on `CollectionLoaded`, carry the cache forward and
  emit one `LoadImageBytesEffect` per **uncached** image card (helper
  `_uncachedImageAttachments`); `ImageBytesLoaded` caches only on success — a
  miss leaves the placeholder and triggers no loop.
- `collection_shell.dart` — injected a narrow `AttachmentReadRepository`; handles
  `LoadImageBytesEffect` via `bytesOf(id)`, dispatching null bytes on failure.
- `collection_module.dart` + `main.dart` — threaded
  `SyncStoreAttachmentReadRepository(graph: graph)` through.

**UI** (`collection_page.dart`)
- `_CardBubble` image case → `AttachmentImage` (220×220, clipped) with the old
  "Photo" row as the loading/missing `placeholder`.
- `_ReorderRow` → a 40×40 thumbnail leading for image cards (placeholder icon
  fallback), drag handle for everything else.
- A `_bytesFor(state, card)` helper feeds each widget primitives only
  (widgets.md §1) — bytes loaded via an effect, never a repo call from a widget.

**Tests** — added an "image thumbnails" group to `collection_updater_test.dart`:
loading uncached image cards, skipping cards with no attachment id, not
reloading cached bytes + cache survival across reload, caching on
`ImageBytesLoaded`, and not caching a missing image. Full suite green (241), and
`flutter analyze lib test` clean.

**Out of scope / follow-ups** — audio cards remain a placeholder; the
cover-image sibling ([collection--cover-image.md](../collection--cover-image.md))
can reuse this same `AttachmentImage` + bytes-cache shape.
