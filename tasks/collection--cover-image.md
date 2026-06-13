# Collection cover image + attachments (§4.2 / §4.8)

## What's missing

The collection header long-press only offers **rename** today. Spec §4.2/§4.8:
long-press the collection header (main card) → **add/replace cover image** (and
edit title). The cover is **shown on Home** (the Timeline). The plumbing exists
in shape — `coverAttachmentId` rides through `CollectionState` /
`CollectionData` and `cover_attachment_id` is in the collection content — but
nothing **captures, stores, or renders** an attachment.

## What to build

- **Attachment handling** (the missing foundation): pick an image, store the
  bytes (content-addressed by `content_hash`, §7.4.3), and a way to read them
  back for display. Image/audio **card** kinds depend on this too.
- Header long-press → "add/replace cover image" → set the collection's
  `cover_attachment_id` (an edit on the signed `collection` record).
- Render the cover on the Home/Timeline collection tiles and the Collection
  header.

## References

- spec §4.2 / §4.8 (collection image via header long-press; shown on Home),
  §7.4.3 (attachments, `content_hash`, image/audio cards)
- `lib/features/collection/` (`coverAttachmentId` already threads through state)
- shares the attachment foundation with the [Card Edit epic](card-edit/epic.md)
  (see its [attachments--foundation](card-edit/attachments--foundation.md) subtask)
