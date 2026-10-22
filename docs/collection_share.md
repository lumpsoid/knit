# Collection share by file (design)

Send one collection to another person as a file, with no relay. The recipient
imports it and sees it as a **read-only collection** by the sender. They can
"Save a copy" to make their own editable fork. It is the offline transport for
the §10 share model: import is a §10.5 *subscription* (read-only, same ids,
updates merge), and "Save a copy" is the §10.5 *fork*. When the relay lands it
replaces the file as the transport; the read-only model, fork and purge stay.

## Decisions

| Topic | Decision |
|---|---|
| Recipient gets | Read-only collection marked "from `nickname#fp`" + **Save a copy** (fork, §10.5) |
| Payload | The sender's **signed ops verbatim** (like the backup bundle); verified on import |
| History | **Winning ops only**: per entity, the content winner (+ the placement winner for a card), incl. tombstones. No edit history, no deleted content |
| Re-import | Same ids → normal LWW merge: a newer file updates the read-only copy, an older one changes nothing |
| Outside links | Shipped as-is; missing targets render as §8.6.1 broken-link chips and come alive if the target is imported later. The sheet warns "N connections point outside this collection" and offers **Include linked collections** (see "Linked collections") |
| Media | Sender toggle **Include media** (default on, size shown). Without it, cards show a "media not included" placeholder; a later file with media fills it by `content_hash` |
| Card marks | Settled / emphasized / archived travel as-is (they are signed fields) |
| Protection | None. A plain signed zip; the transport is the boundary |
| Export | Collection ⋮ → **Share as file** → sheet: size + media toggle → **Send** (share_plus) / **Save to file** |
| Import from | Opening a `.knitc` from another app (Android VIEW intent + share-capture), and **Settings → Data → Import collection** |
| Recipient may | Present it, pin and archive it (local-only), find it in search, link to it from their own cards |
| Remove | **Local purge**: projection rows + its ops in `change_log` + unreferenced blobs. Nothing signed; a re-import restores it |

## The file

`<title>.knitc`, mime `application/vnd.knit.collection+zip`. Same zip shape as
the backup (`BackupArchiveCodec`), its own format tag:

```
manifest.json   { format: "knit-collection", version: 1 | 2, createdAtMs,
                  collectionId, owner: <pubkey>, title, cardCount,
                  opCount, blobCount, mediaIncluded: bool,
                  included?: [ { collectionId, owner, title, cardCount } ] }
log.jsonl       one signed PersistedOp row per line, verbatim
blobs/<hash>    attachment bytes (absent when mediaIncluded = false)
```

`title` and `cardCount` are an unsigned preview for the import sheet only. The
import never trusts them; it reads the verified ops.

`collectionId` / `owner` name the **primary** collection. `included` lists the
linked collections the file also carries (version 2). A file without them is
still written as version 1 with no `included` key, byte for byte the first
release's shape, so an older Knit opens it. An older Knit refuses a version-2
file through its existing check (`version > 1` → "This file is from a newer
Knit") instead of misreading it; this one reads both.

### The share set (export)

For collection `C`, the export reads `change_log` and keeps the **winning op
per entity** using the merge-core comparators (`compareContent`,
`comparePlacement`). It never re-signs.

- the `collection` op of `C`
- every `card` whose current `collection_id = C`, live or tombstoned: the
  content winner, plus the placement winner when that is a different op (§7.6)
- every `link` whose `source_id` is `C` or one of those cards (live or
  tombstoned); targets may be outside the set
- every `attachment` referenced by those cards or by `C`'s cover
- the `profile` op of each author in the set, so the nickname resolves

Tombstones keep re-import honest: a card the sender deleted disappears on the
recipient's side.

### Linked collections (sharing an index)

An index is a collection whose cards link to other collections or cards. Alone,
it reaches the recipient as broken chips. The pure `ShareReach`
(`lib/sync/storage/share/`) reads the collection's live links (one per pair,
§6.4; sourced at the collection or a live card) whose target lies outside its
`ShareScope`:

- **Warning**: "N connections point outside this collection", plus "M can't be
  included (not yours)" for targets in a collection whose `created_by` is not
  this identity (an imported one). A target already missing here counts as
  outside but is neither.
- **Include linked collections** (default off, shown when there is an own
  collection to bundle): each reached **own** collection rides along whole
  (collection, cards, links sourced in it, attachments per the media toggle,
  authors' profiles), each by its own `ShareScope`. A card target brings its
  collection, so the card arrives in context. One level deep: the linked
  collections' own outside links are not followed. The size shown follows the
  switch (`CollectionShareEstimate.alone` / `withLinked`).
- `SyncStore.shareSet(id, includeLinked: true)` unions the scopes, picks the
  winners once (an op ships once) and lists the bundled ones in
  `ShareSet.included`.

## Import

1. **Decode** the zip and check `format` / `version`. A mismatch is refused
   with "This file is from a newer Knit".
2. **Validate the whole file before applying anything.** The pure
   `CollectionShareImportPolicy` takes the parsed ops plus the recipient's
   current `created_by` for the touched ids, and rejects the file if:
   - any signature fails (verify over the payload bytes, §7.0)
   - a collection is declared twice, or a declared one has no collection op
   - an op belongs to no declared collection: a card's `collection_id` is not
     the primary or an `included` one, or a link's source is neither such a
     collection nor one of their cards in the file
   - an op's author or `created_by` is not the owner of the collection it
     belongs to (a profile is self-signed; an attachment is one of the
     owners'), so each collection's ops stay within its own scope
   - **any op targets an id that exists locally with a different
     `created_by`.** This is the security rule: without it a crafted file
     could out-rank, by LWW, the recipient's own cards.
3. **Preview sheet**: "Trip to Kyoto · 24 cards · from mira#9f86 · + 2 linked
   collections · media not included" → **Import** (or **Update** when the
   primary collection is already here).
4. **Apply** each op through `SyncStore.applyRemote` (dedup → verify → skew →
   one-txn merge). It records ops as `remote/acked`, so the sync indicator
   never counts them. The blobs go into the blob store by hash (the backup
   import path). A crash mid-apply leaves a partial import; importing again
   completes it (dedup by `op_id`).
5. Open the primary collection (`CollectionRouteArgs`) and ping
   `TimelineChannel`. Linked collections arrive as imported, read-only
   collections like any other; each is removed on its own (Remove purges one
   collection's scope).

Importing your **own** file (same identity) passes the same checks and merges
into an editable collection. It is a mini-restore. The same holds for a linked
collection that already exists here: it passes only when its local
`created_by` matches (it came back to its author, who gets a mini-restore of
it, still editable); one that exists under another creator refuses the whole
file by the foreign-overwrite rule.

## Read-only

A collection is read-only when `collection.created_by ≠` this device's pubkey.
It is derived on read, so no table is needed, and the future relay
subscription gets the same behaviour. The rule is one pure domain function
(`CollectionOwnership.of(createdBy, me)`) that the controllers ask. No widget
compares keys.

| Surface | Own collection | Imported (read-only) |
|---|---|---|
| Timeline card | as today | + "from `nickname#fp`" line |
| Collection feed | composer, reorder, select, header edit | no composer, no reorder / multi-select, header not editable |
| Card actions sheet | full | Connections, Copy text, **Link from my card…** |
| Collection ⋮ | Present, Reorder, Share as file, Delete | Present, **Save a copy**, Share as file (re-share verbatim), **Remove** |
| Card Edit | opens | not reachable |
| Move / share-capture pickers | offered as target | **excluded** as a write target |
| Widget picker | offered | offered (opens it, quick-input hidden) |
| Link picker targets | offered | offered (a link is the recipient's own op) |
| Search, Present | yes | yes |
| Pin | local (existing pref) | local (existing pref) |
| Archive | signed `archived_at` | **local-only flag** (shared_preferences, like pins) |

Archive: `TimelineSections` treats a collection as archived when
`summary.archived || localArchived.contains(id)`. The pure `ArchiveTarget`
decides signed vs local from ownership.

## Save a copy (fork, §10.5)

`ForkPlanner` (pure) maps the live share set to new entities: a new id for the
collection, every live card, every live intra-set link and every attachment.
Intra-set link endpoints are rewritten. Links that point outside keep their
targets. Attachments keep their `content_hash`, so no bytes are copied. The
recipient is `author = created_by`, with a fresh `created_at` and HLC.
Positions are kept. Settled / emphasized marks are kept. `archived_at` is
cleared. `SyncStore.forkCollection(plan)` writes everything in **one** UoW
transaction. The source stays; the user can Remove it afterwards. The local
"forked from" marker of §10.5 is deferred until something reads it.

## Remove (local purge)

`SyncStore.purgeCollection(id)` runs in one transaction. It deletes `C`, its
cards, links sourced in the set and their attachments from the projection, and
deletes **their ops from `change_log`**, so rebuild-from-log (§8.9) stays
identical. The recipient's own links into the set survive and become broken
chips. Afterwards, blobs no longer referenced are deleted (the `DeviceEraser`
blob path). It refuses an own collection: that path is the signed Delete.

## Code shape

A lightweight feature `lib/features/collection_share/` (controller +
ChangeNotifier state), plus additions to the sync core.

- **sync core** (both storage impls, contract tests):
  `ChangeLogStorage.readForEntities(ids)` / `deleteForEntities(ids)`,
  `ProjectionStorage.deleteMany(ids)`, `SyncStore.shareSet(collectionId)`,
  `purgeCollection`, `forkCollection(ForkPlan)`.
- **domain**: `CollectionShareManifest`, `CollectionShareBundle`,
  `ShareSetSelector` (winner per entity), `CollectionShareImportPolicy`,
  `CollectionOwnership`, `ArchiveTarget`, `ForkPlanner`, sealed
  `CollectionShareFailure`. Ports: `CollectionShareExportRepository`,
  `CollectionShareImportRepository`, `CollectionPurgeRepository`,
  `CollectionForkRepository`, `LocalArchiveRepository`.
- **infra**: `CollectionShareCodec` (shares zip helpers with
  `BackupArchiveCodec`), SyncStore-backed repositories, and the backup's
  save / source / delivery ports moved to `lib/core/files/` so both features
  use them.
- **presentation**: `CollectionShareExportController` + sheet,
  `CollectionShareImportController` + preview sheet. The read-only gating
  lands in the existing FCIS features (collection, timeline, card_links,
  collection_details, share_capture), each asking `CollectionOwnership`.
- **Android**: a VIEW intent filter for the mime (+ `*.knitc` path pattern as
  a fallback). Share-capture routes a shared `.knitc` to import instead of a
  file card.

## Build order (one commit each)

1. Sync core: entity-scoped change-log read/delete, projection delete,
   `shareSet`, `purgeCollection`, `forkCollection`. Tests on both impls,
   including a rebuild-after-purge test.
2. Codec + domain: manifest, bundle, selector, import policy (incl. the
   foreign-overwrite attack), fork planner.
3. Export: Collection ⋮ → Share as file sheet.
4. Import: Settings → Data entry, the preview sheet, intent + share-capture
   routing.
5. Read-only across features + the local archive flag.
6. Save a copy + Remove.
7. Spec: §4.6 points here; add §10.8 "File share"; update CLAUDE.md.

## As built

The build follows the order above. Where the code landed differs from the plan:

- The pure share scoping lives in the sync core, next to the store that uses it:
  `ShareScope` and `ShareSetSelector` (`lib/sync/storage/share/`), with `ForkPlan`.
  The feature's `ForkPlanner` produces the plan.
- `CollectionOwnership` and `ArchiveTarget` live in `lib/core/ownership/`, since six
  features ask them.
- The policy also refuses a file whose envelope hints (entity type and id) disagree
  with the payload, and a non-profile op whose `created_by` is not the owner. Purge
  and the log reads go by the hint, so they must match.
- The home-screen widget hides its ✎ quick input for an imported collection (a
  `quickInput` flag on the published tile, kept by the Android store).
- The Timeline's long-press sheet offers no Delete for an imported collection; Remove
  lives in the Collection ⋮ sheet.

## Known limits

- **A card the sender moved out of `C`** stays on the recipient's side, frozen
  at its last op. Its newer op lives in another collection's set. A fix later:
  the manifest lists the live card ids, and the import purges foreign cards of
  `C` that are missing from a *newer* file.
- **A file is a snapshot.** Updates need a new file (the relay fixes this).
- **There is no revoke**, the same honesty as §10.6: what was sent stays sent.
