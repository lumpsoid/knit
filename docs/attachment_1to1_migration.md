# Transient: legacy attachment-record split (remove after rollout)

**Status:** temporary. This whole mechanism — the migration *and* its safety
guard — exists only to heal data captured before the **1 referent : 1 attachment
record** invariant held. Once every active install has run a build containing the
migration at least once, **all of it should be deleted** (see
[Removal](#removal)). This doc is the record of *why* it exists and *what* to
remove.

---

## The data shape

```
Card ──content['attachment_id']──▶ Attachment record ──content_hash──▶ Blob (bytes)
```

- A **card** points at an **attachment record** by `attachment_id`.
- An attachment record points at the actual **bytes** by `content_hash`.
- Identical bytes are content-addressed: one **blob**, ref-counted across the
  records that share its hash.

The intended invariant — call it **1 : 1** — is: **each card uniquely owns its
own attachment record.** Identical photos still share a single blob (that's the
ref-counted, byte-level dedup); they do *not* share a record.

## The initial issue (fixed in `83a99bc`)

Before `83a99bc` (`fix(attachments): stop sharing one record across cards that
reuse a photo`), dedup happened at the **record** level: adding the same photo to
two cards reused the *one* existing attachment record. So the data could be
`N cards : 1 record`:

```
Card A ─┐
        ├─▶ ONE shared record ──▶ blob
Card B ─┘
```

This caused **data loss**, not just a leak:

- **Replace/remove on one card orphaned the other.** `CardEditShell._gcAttachment`
  deletes a card's attachment record when the card is pointed away from it. With a
  shared record, deleting it via card A also yanks it out from under card B → card
  B silently loses its image ("Фото").
- (A separate, milder symptom: deleting an image card didn't reclaim its
  attachment at all — a storage leak — which the later per-card GC fix addressed.)

`83a99bc` fixed the **logic**: every capture now mints its **own** record
(`SyncStoreAttachmentWriteRepository._create` — "every capture mints its OWN
record (1 referent : 1 record)"). Identical bytes still collapse to one blob.

## Why this is still not enough — and why the guard + migration exist

`83a99bc` is **forward-only**. It changes how *new* captures behave; it does
**not** rewrite records already sitting on a device. A phone used before the fix
can still hold `N : 1` records — **"legacy shared records."** So two pieces of
*temporary* protection were added on top:

1. **The reference guard** (defensive, on the delete path).
   `CollectionShell._gcDeletedCardAttachment` reclaims a deleted card's attachment
   **only when no other live card still references it**, via the narrow read port
   `CollectionReadRepository.isAttachmentReferenced`. On a legacy shared record,
   the sibling still references it → the GC is skipped → no orphan. Without this
   guard, the new per-card GC would re-introduce the exact `83a99bc` data-loss bug
   on upgraded devices.

2. **The migration** (the actual remedy).
   `LegacyAttachmentSplitMigration` walks every attachment record referenced by
   `> 1` live card, keeps the first card on the original record, and gives each
   other card its own freshly-cloned record (same `content_hash` → same
   ref-counted blob, no bytes duplicated). After it runs, the `1 : 1` invariant
   holds for old data too. It runs once at startup from
   `ProductionInitializationRepository._runDataMigrations`, is idempotent (a no-op
   once everything is `1 : 1`), and is best-effort (a failure is logged and
   swallowed, never bricking startup).

   It is a **plain local pass**: there is no relay yet (a single, authoritative
   device per install) and Android cloud backup is disabled (`aa300df`), so the
   fresh record ids it mints can never collide with another device's split, and a
   healed DB cannot revert to the `N : 1` shape. No idempotency-across-instances
   or merge handling is required. **When a relay/sync lands, re-evaluate before
   shipping this as-is** — but by then it should already be removed.

## Removal

The migration and the guard are **scaffolding for a one-time data fix**. Keep
them only as long as some install might still hold pre-`83a99bc` data.

**Safe-to-remove condition:** every active install has launched a build that
includes `LegacyAttachmentSplitMigration` at least once. Because backup/restore
of the local DB is disabled and there is no sync path to reintroduce old records,
a device that has launched a migrated build is healed permanently. In practice:
remove after a release window long enough to be confident the migrated build has
shipped and run on essentially all installs (e.g. a few releases / a couple of
months after the migration first ships — pick the number when you cut the
release, and note it here).

When that condition is met, delete **all** of the following:

### The migration

- `lib/core/attachments/domain/legacy_attachment_split_migration.dart`
- `lib/core/attachments/infra/sync_store_legacy_attachment_migration_port.dart`
- Their barrel exports in `lib/core/attachments/domain/domain.dart` and
  `lib/core/attachments/infra/infra.dart`
- The `_runDataMigrations` step (and its imports) in
  `lib/features/app_launch/infra/production_initialization_repository.dart`
- `test/core/attachments/legacy_attachment_split_migration_test.dart`

### The guard (now unnecessary — every record is `1 : 1`)

- `CollectionReadRepository.isAttachmentReferenced` (the port method) +
  its impl in `SyncStoreCollectionReadRepository`
- The reference check inside `CollectionShell._gcDeletedCardAttachment` —
  simplify to an **unconditional** GC, matching `CardEditShell._gcAttachment`
  (which is already unconditional and becomes safe once `1 : 1` is guaranteed)
- The corresponding tests: the `isAttachmentReferenced` case in
  `test/features/collection/collection_repository_test.dart`, and the
  "legacy shared record keeps the sibling" case in
  `test/features/collection/collection_shell_test.dart`

After removal, the invariant is upheld purely by the write path (each capture
mints its own record), and attachment GC on delete/replace is a simple
unconditional reclaim in both `collection` and `card_edit`.
