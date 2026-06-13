# Subtask 3 — Per-card link management (§4.3, full scope)

Part of [Card Edit epic](epic.md). Depends on subtask 2 (the page scaffold).

## What's missing

Card→card linking and an in-page link manager don't exist. Today only
card→collection **create** (`linkCardToCollection`) and link **clear**
(`clearLink`) exist, and the only target picker is `homeTimeline`
(collections-only).

## What to build

- On the card-edit page, **list** the card's outgoing links via
  `SyncStore.linksOut` — reuse the `connections` view-models and the §8.6.1
  broken-link chip rather than reimplementing.
- **Remove** a link: a signed `link` delete, reusing `clearLink`'s pattern.
- **Add** a link from this card to a **collection or a card**. The `link`
  content already carries `source_type/id` + `target_type/id`, so generalize the
  write to `linkCardTo({targetType, targetId})`. The add flow needs a **generic
  entity target picker** (browse collections → drill into a collection's cards),
  since the current picker surfaces collections only.

## References

- spec §4.3 (manage the card's links), §8.6.1/2 (broken-link chip)
- `lib/features/connections/` (read-models + chip to reuse)
- `lib/features/collection/infra/sync_store_collection_write_repository.dart`
  (`linkCardToCollection` to generalize)
- `lib/sync/storage/sync_store.dart` (`linksOut`, `delete` for links)
