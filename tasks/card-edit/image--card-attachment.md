# Subtask 4 — Card image management (§4.3)

Part of [Card Edit epic](epic.md). Depends on subtask 1 (attachments
foundation) **and** subtask 2 (the page scaffold).

## What's missing

The card-edit page can't add, replace, or remove a card's image.
`FeedCard.attachmentId` already threads through state, but nothing sets or
renders it.

## What to build

- **Add / replace / remove** the card's image on the page, using subtask 1's
  picker + content-addressed store + shared render widget.
- Extend `editCard` to carry `{attachment_id}` and flip the card `kind` to
  `image` (clear it back when the image is removed).
- Render the current image (with a remove control) on the page.

## References

- spec §6.4 (card `kind`/content), §7.4.3 (image cards carry `attachment_id`)
- [Attachments foundation](attachments--foundation.md) — hard dependency
- `lib/features/collection/domain/collection_models.dart` (`FeedCard.attachmentId`)
