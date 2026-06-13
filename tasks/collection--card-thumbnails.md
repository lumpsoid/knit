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
