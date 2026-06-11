# Share-sheet capture — system entry point (§4.7)

## What's missing

The app has no **system share-target** entry point. Spec §4.7: when the user
shares content into Knit from another app (the OS share sheet), it opens a
"pick / create collection" flow — **not an in-app screen**, a system entry
point that lands the shared content as a new card.

## What to build

- Register the app as a share target on each platform (Android intent filters /
  iOS share extension, etc.).
- On receive: open a lightweight "pick or create a collection" prompt, then
  append the shared content as a card (reusing the Collection write path).

## References

- spec §4.7 (Share-sheet capture), §4.1 (pick/create collection), §4.2 (cards)
- `lib/features/collection/infra/sync_store_collection_write_repository.dart`
  (`addCard` — the write path to reuse)
- `lib/features/timeline/` (collection create to reuse)
