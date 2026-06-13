# Subtask 2 — Card Edit page scaffold + text edit (§4.3)

Part of [Card Edit epic](epic.md). The MVP page — ships text/content editing on
a real page; links (subtask 3) and image (subtask 4) hang off it.

> ✅ **Built.** As-built map for the subtask 3/4 consumers:
> - Feature lives at `lib/features/card_edit/`, mirroring `collection`'s FCIS
>   shape (domain · infra · presentation; no barrels, import files directly).
> - **Write port:** `CardEditWriteRepository.editCard({required String cardId, String? text})`
>   → `Future<Result<String, CardEditFailure>>`, impl
>   `SyncStoreCardEditWriteRepository(graph:)` over `store.edit(EntityType.card, …)`.
>   Generalize this method (add `attachment_id` for subtask 4); re-add an
>   `IdGenerator` dep when subtask 3 needs to mint link ids.
> - **Carrier:** `CardEditRouteArgs`/`Writer`/`Store` +
>   `InMemoryCardEditRouteArgsStore` (cardId + initialText). Collection writes via
>   `CollectionScope.cardEditRouteArgsWriter.open(...)`; the page reads
>   `CardEditScope.routeArgs` on entry.
> - **Page → save → pop:** the shell pushes `CardEditSavedUiEffect` on success;
>   the page pops; `CollectionPage._openCardEdit` awaits the push then dispatches
>   `ReloadRequested` (projection-is-truth). Add link/image controls to
>   `card_edit_page.dart` for subtasks 3/4.
> - Wired in `lib/main.dart` (`CardEditScope.setFactory` + the third carrier).

## What's missing

There is no dedicated edit page. Editing is an inline dialog:
`CollectionPage._promptText` → `CardEditSubmitted` → `EditCardEffect` →
`editCardText` (text only).

## What to build

- A new **`lib/features/card_edit/`** FCIS feature copying `collection`'s full
  shape: `domain/` (narrow ports + models + failures), `infra/` (impls over
  `AppGraph.store`), `presentation/` (state · action · effect · ui_effect ·
  updater · shell · loop · controller · module · scope · page), with barrels.
- A **`card_edit_route_args.dart`** carrier (card id + initial content), written
  by `collection_page` before navigation and read on page entry — same pattern
  as `connections_route_args.dart` (cross_feature §2).
- **Replace the edit branch** in `collection_page.dart` `_openCardActions`: drop
  the `_promptText` edit call, write the carrier, navigate to the new page.
- **Write path:** a narrow `CardEditWriteRepository` over
  `SyncStore.edit(EntityType.card, …)`; generalize the existing `editCardText`
  to an `editCard({text})`. On save, dispatch + pop; the Collection screen picks
  up the change through its existing `ReloadRequested` (projection-is-truth)
  flow — no cross-feature push needed.

## References

- `docs/architecture/fcis.md` (the feature shape), `cross_feature.md` §2 (carrier)
- `lib/features/collection/presentation/collection_page.dart`
  (`_openCardActions`, `_promptText`)
- `lib/features/connections/presentation/connections_route_args.dart` (carrier pattern)
- `lib/features/collection/infra/sync_store_collection_write_repository.dart`
  (`editCardText` to generalize)
