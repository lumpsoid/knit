# Subtask 1 — Attachments foundation (§6.4 / §7.4.3)

Part of [Card Edit epic](epic.md). The heavy, shared prerequisite. **Also the
foundation `../collection--cover-image.md` needs — build it once.**

> ✅ **Built.** See **[attachments--foundation.built.md](attachments--foundation.built.md)**
> for the as-built map (ports, where they live, how to wire them in a feature,
> the content map / GC semantics) — consumers should read that instead of
> re-exploring the codebase.

## What's missing

There is **no attachment capture, store, or read path** anywhere. Only the
schema exists: `AttachmentSchema` in
`lib/sync/storage/projection/domain/entity_schema.dart`
(`kind`, `mime`, `content_hash`, `size`, `local_path`). Nothing picks an image,
computes its hash, writes bytes to disk, signs an `attachment` record, or reads
bytes back to render.

## What to build

- **Pick:** add an image picker dependency (`image_picker` / `file_picker`) and
  a narrow port over it so it stays mockable in tests.
- **Hash:** SHA256 `content_hash` over the bytes (§7.4.3) — dedup + integrity.
- **Store:** a content-addressed filesystem store (keyed by `content_hash`) with
  cleanup on delete; the bytes never enter the op (out-of-band, §7.4.8).
- **`AttachmentStorage`** interface in `domain/` with **both** impls per the
  storage convention — sqflite + in-memory — asserting the same contract.
- **`AttachmentWriteRepository`** (narrow): create a signed `attachment` record
  via `SyncStore.create(EntityType.attachment, …)`. `local_path` stays
  **unsigned / device-local** (§7.4.8); only `content_hash` etc. are signed.
- **Read path:** load bytes by `attachment_id` and a shared render widget that
  takes primitives (widgets.md §1), reused by cards and the collection cover.

## References

- spec §6.4 (attachment table), §7.4.3 (`content_hash`, image/audio cards),
  §7.4.8 (attachment put — `local_path` local-only / unsigned)
- `lib/sync/storage/projection/domain/entity_schema.dart` (`AttachmentSchema`)
- `lib/sync/storage/sync_store.dart` (`create` write path)
- `../collection--cover-image.md` — the other consumer of this foundation
