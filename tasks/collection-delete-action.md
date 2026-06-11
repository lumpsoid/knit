# Expose a collection-delete action in the UI

## What's missing

Deleting a **collection** endpoint isn't yet exposed anywhere in the UI — there
is no collection-delete action. The write path exists (`SyncStore.delete(
EntityType.collection, id)`), but nothing in the app surfaces it.

## Why it matters

- **Gate 4 (§9.1) only has one in-app break-path today.** The Connections view
  (§4.4) renders the §8.6.1 broken-link chip for either end of a link, but the
  only endpoint a user can delete in-app is a **card**. So gate 4 is reachable
  only via: link a card → collection, then delete the *card*, and view the
  collection's backlink (now broken). Deleting the *collection* end (which would
  break a card's links-out) can't be done through the UI.
- Both break-paths are already proven in `connections_repository_test.dart`
  (deleting the target collection renders the links-out broken), but the
  collection-delete one has **no UI driver**.

## What to build

- A delete action for a collection — likely from the Timeline (long-press /
  overflow on a collection tile) and/or the Collection screen header menu.
- Confirm-before-delete (a collection can hold many cards).
- After delete: links pointing **at** that collection must render as broken
  chips in Connections (§8.6.1), never auto-removed — the resolver already
  handles this; just verify end-to-end through the live app.

## References

- spec §4.4 (Connections), §4.8 / §8.6.1 (broken-link chip), §9.1 gate 4
- `lib/features/connections/` (the chip + clear path)
- `lib/features/timeline/` and `lib/features/collection/` (likely entry points)
