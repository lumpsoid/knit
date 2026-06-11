# Card Edit page (§4.3)

## What's missing

Card editing is **inline and text-only** today — the actions sheet on the
Collection screen opens a single-field text prompt (`CollectionPage._promptText`
→ `CardEditSubmitted`). There is no dedicated **Card Edit page** (§4.3) for
managing a card's **image** and **per-card links**.

## What to build

- A Card Edit page (likely its own FCIS feature, or an extension of `collection`)
  that edits text/content **and**:
  - manages the card's **image** (add/replace/remove an attachment),
  - manages that card's **links** (view/add/remove links the card is a source
    of — overlaps with the Connections view, §4.4).
- Reached from the card-actions sheet (replace the inline text prompt).

## References

- spec §4.3 (Card Edit), §4.2 (actions sheet), §6.4 (card `kind`/content),
  §7.4.3 (image/audio cards carry `attachment_id`)
- `lib/features/collection/presentation/collection_page.dart` (current inline edit)
- `lib/features/connections/` (link view to reuse/share)
- depends on attachment handling — see [collection--cover-image](collection--cover-image.md)
