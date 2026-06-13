# Epic — Card Edit page (§4.3)

Spec §4.3 calls for a dedicated **Card Edit page** that edits a card's
text/content **and** manages its **image** and its **links**. What started as
one task is really three unrelated lifts:

1. **Text/content edit** — trivial; the path already exists.
2. **Per-card links** (incl. card→card) — needs a richer target picker than the
   collections-only one we have today.
3. **Card image** — has *no* foundation at all: only the `AttachmentSchema`
   table is defined (no picker, no SHA256 hashing, no filesystem I/O, no
   `AttachmentStorage` impl, no read/render path). This is the same foundation
   `collection--cover-image.md` needs.

So it's an epic. Decisions taken up front: the page is a **new `card_edit` FCIS
feature** (mirroring `collection`'s shape), and links support the **full** scope
(card→card, not just card→collection).

## Current state (what this epic replaces)

Card edit is **inline and text-only**: the actions sheet on the Collection
screen opens a single-field prompt —
`CollectionPage._promptText` → `CardEditSubmitted` → `EditCardEffect` →
`editCardText`. This epic replaces that branch with navigation to the new page.

## Subtasks

- [x] **1 · [Attachments foundation](attachments--foundation.md)** — the heavy
  shared prerequisite: pick → hash → store → read → render an attachment. *Also
  unblocks `../collection--cover-image.md` — build it once.* Built as the headless
  `lib/core/attachments/` library (picker port + `image_picker` adapter, `sha256Hex`,
  content-addressed `AttachmentBlobStore` w/ filesystem + in-memory impls, narrow
  write/read repos over `SyncStore`, the `AttachmentImage` widget) + ref-counted blob
  GC; 25 tests.
- [x] **2 · [Page scaffold + text edit](page--scaffold-text.md)** — the MVP
  page: new `card_edit` feature + route-args carrier, reached from the actions
  sheet in place of the inline prompt. Text/content only. Built as
  `lib/features/card_edit/` (mirrors `collection`'s FCIS shape): narrow
  `CardEditWriteRepository.editCard({cardId, text})`, the `CardEditRouteArgs`
  carrier (cardId + initialText), and `CardEditPage`. The Collection actions
  sheet's **Edit** now navigates to it and resyncs on return; the old inline
  `CardEditSubmitted`/`EditCardEffect`/`editCardText` path was removed. 6 new
  tests.
- [x] **3 · [Per-card links](links--card-source.md)** — view/add/remove the
  card's links, incl. card→card, on the page. Built as three narrow card_edit
  ports (`CardEditLinksReadRepository` → reuses `linksOut`/`linkStatus` and the
  §4.4 `ConnectionItem` view-models for the list incl. the §8.6.1 broken row;
  `CardEditLinksWriteRepository.addLink({targetKind, targetId})`/`removeLink` —
  the generalized, generic-target write; `CardEditTargetsReadRepository` for the
  two-level picker tree, self-excluded). The page gained a Links section + an
  "Add link" sheet that browses collections and drills into a collection's cards.
- [x] **4 · [Card image](image--card-attachment.md)** — add/replace/remove the
  card's image on the page. `CardEditWriteRepository` gained `setCardImage`
  (flip `kind`→`image`, set `attachment_id`) / `removeCardImage` (flip back,
  clear it); the shell drives pick → store → attach → ref-counted GC of the
  replaced/removed blob over subtask 1's foundation (`ImagePickerPort`,
  `AttachmentWrite/ReadRepository`, `AttachmentImage`). The page renders the
  current image with Replace/Remove controls; route-args carry the initial id.

### Dependency order

- **1** and **2** are parallelizable.
- **3** and **4** unlock once **2** lands; they are then parallelizable.
- **4** also needs **1**.

```
1 (foundation) ─────────────┐
                            ▼
2 (scaffold) ──┬──► 3 (links)
               └──► 4 (image)  ◄── 1
```

## References

- spec §4.3 (Card Edit), §4.2 (actions sheet), §6.4 (card `kind`/content +
  attachment table), §7.4.3 (image/audio cards carry `attachment_id`)
- `docs/architecture/fcis.md` — the feature shape every subtask copies
- `lib/features/collection/` — the analog feature + current inline edit
- `lib/features/connections/` — link read-models + broken-link chip to reuse
