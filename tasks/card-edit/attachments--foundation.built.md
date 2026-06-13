# Built — Attachments foundation (reference for consumers)

> Companion to [attachments--foundation.md](attachments--foundation.md). This is
> the as-built map of the shared attachment layer so the consumers
> ([epic](epic.md) subtasks 3/4 + [../collection--cover-image.md](../collection--cover-image.md))
> can wire it without re-exploring the codebase. Status: **done, 25 tests, green.**

## TL;DR for a consumer

To show / add / remove an attachment from a feature you need **three ports**, all
in `lib/core/attachments/` and all re-exported from the single barrel
`package:knit/core/attachments/attachments.dart`:

- `ImagePickerPort.pickImage() → Future<PickedImage?>` — prompt the user; `null` = cancelled.
- `AttachmentWriteRepository.createFromPicked(PickedImage) → Result<String id, AttachmentFailure>`
  and `.delete(String id) → Result<String id, AttachmentFailure>`.
- `AttachmentReadRepository.bytesOf(String id) → Result<AttachmentBytes, AttachmentFailure>`.

To render bytes: `AttachmentImage(bytes: Uint8List?)` (a plain widget, primitives only).

The attachment **id** is what you store on the owning record — set
`card.attachment_id` / `collection.cover_attachment_id` to it (a normal signed
edit on that record, via the owner's own write repo — not done here).

## Where it lives

```
lib/core/attachments/
  attachments.dart                         ← import THIS barrel
  domain/  (ports, value types, failures — no Flutter, no dart:io)
    picked_image.dart            PickedImage { Uint8List bytes; String mime }
    image_picker_port.dart       ImagePickerPort
    attachment_blob_store.dart   AttachmentBlobStore (content-addressed bytes)
    attachment_hashing.dart      Future<String> sha256Hex(List<int>)  (lowercase hex)
    attachment_models.dart       AttachmentBytes { Uint8List bytes; String mime }
    attachment_failure.dart      sealed AttachmentFailure (see below)
    attachment_write_repository.dart  AttachmentWriteRepository
    attachment_read_repository.dart   AttachmentReadRepository
    domain.dart                  (barrel)
  infra/  (impls)
    image_picker_adapter.dart            ImagePickerAdapter   (over package:image_picker)
    in_memory_attachment_blob_store.dart InMemoryAttachmentBlobStore  (Map; dev/tests)
    filesystem_attachment_blob_store.dart FilesystemAttachmentBlobStore (dart:io; app)
    sync_store_attachment_write_repository.dart  SyncStoreAttachmentWriteRepository
    sync_store_attachment_read_repository.dart   SyncStoreAttachmentReadRepository
    infra.dart                   (barrel)
  presentation/
    attachment_image.dart        AttachmentImage widget (Image.memory + placeholder)
```

Tests: `test/core/attachments/` (blob-store contract over both impls; hashing;
write-repo; read-repo; widget).

## Public API (exact signatures)

```dart
class PickedImage { const PickedImage({required Uint8List bytes, required String mime}); }
class AttachmentBytes { const AttachmentBytes({required Uint8List bytes, required String mime}); }

abstract class ImagePickerPort { Future<PickedImage?> pickImage(); }

abstract class AttachmentWriteRepository {
  Future<Result<String, AttachmentFailure>> createFromPicked(PickedImage image);
  Future<Result<String, AttachmentFailure>> delete(String attachmentId);
}
abstract class AttachmentReadRepository {
  Future<Result<AttachmentBytes, AttachmentFailure>> bytesOf(String attachmentId);
}

sealed class AttachmentFailure {}
class AttachmentWriteFailure  extends AttachmentFailure { final String cause; }
class AttachmentNotFound      extends AttachmentFailure { final String attachmentId; }
class AttachmentBytesMissing  extends AttachmentFailure { final String contentHash; }
```

`Result`/`Ok`/`Failure`/`.isFailure`/`.error`/`.getOrThrow()` are from
`package:result_dart/result_dart.dart` (same as every other repo).

`AttachmentImage` props: `bytes` (Uint8List?), `fit` (BoxFit, default cover),
`width`, `height`, `placeholder` (Widget?). Null bytes → placeholder glyph;
decode error → broken-image glyph.

## How to wire it in a feature (the pattern to copy)

These repos are **not** registered in a Scope (no globals). Construct them in your
feature module from the shared `AppGraph` + `IdGenerator`, exactly like
`CollectionModule` already does. In `lib/main.dart` the graph and `const ids =
UuidIdGenerator()` are already in scope at every `*Scope.setFactory(...)` call:

```dart
// inside your feature's module wiring
final attachmentWrite = SyncStoreAttachmentWriteRepository(graph: graph, ids: ids);
final attachmentRead  = SyncStoreAttachmentReadRepository(graph: graph);
final picker          = ImagePickerAdapter();           // infra; swap a fake in tests
```

Constructors:
- `SyncStoreAttachmentWriteRepository({required AppGraph graph, required IdGenerator ids})`
- `SyncStoreAttachmentReadRepository({required AppGraph graph})`
- `ImagePickerAdapter({ImagePicker? picker})`

The blob store is already created + bound during init — you never construct it in a
feature; the repos read `graph.blobStore` internally.

## What it does under the hood (so you don't have to re-derive)

- **create**: `sha256Hex(bytes)` → if a **live** `attachment` record already has that
  `content_hash`, returns its id (record-level dedup, no new op/blob). Else
  `blobStore.put(hash, bytes)` then `SyncStore.create(EntityType.attachment, id,
  {kind:'image', mime, content_hash, size})`. **`local_path` is never written** — the
  bytes are addressed purely by `content_hash`, so nothing unsigned hits the
  projection (spec §7.4.8). `kind` is hard-coded `'image'` today (audio later).
- **delete**: signed soft-delete of the record, then **reference-counted blob GC** —
  the blob file is removed only if no other *live* record shares its `content_hash`
  (the same bytes can back a card image **and** a collection cover → one shared blob).
- **bytesOf**: reads the record (→ `AttachmentNotFound` if absent/deleted), then
  `blobStore.readBytes(content_hash)` (→ `AttachmentBytesMissing` if the bytes aren't
  on this device, e.g. not yet fetched out-of-band).

## Touch points added to the rest of the app (already done)

- `lib/sync/storage/sync_store.dart`: new `Future<List<Snapshot>> readAll(EntityType)`
  (used for dedup + GC); attachment `_withContentDefaults` now yields
  `{kind, mime, content_hash, size}` = null.
- `lib/app/app_graph.dart`: `blobStore` getter + `bindBlobStore(...)` cell (mirrors
  `store`/`bindStore`; throws if read pre-init).
- Init seam binds the blob store: `in_memory_initialization_repository.dart` →
  `InMemoryAttachmentBlobStore`; `production_initialization_repository.dart` →
  `FilesystemAttachmentBlobStore(baseDir: '<getApplicationSupportDirectory()>/blobs')`.
- `pubspec.yaml`: added `image_picker: ^1.1.2`, `path_provider: ^2.1.4`.

`attachment` projection columns already existed: `AttachmentSchema` in
`lib/sync/storage/projection/domain/entity_schema.dart`
(`colKind/colMime/colContentHash/colSize/colLocalPath`). Use these constants when
reading a snapshot's `content[...]` rather than raw strings.

## Gotchas

- `sha256Hex` is **async** (cryptography's hash API is). Don't expect a sync hash.
- The picker has no platform-supplied mime; `ImagePickerAdapter` infers it from the
  file extension (jpg/png/gif/webp/bmp/heic → image/*, else
  `application/octet-stream`). Fine for storage; revisit if you need exact mime.
- `delete(id)` operates at the **attachment record** level. Whether a card/collection
  still references that `attachment_id` is the **owner's** responsibility — clear the
  owner's `attachment_id`/`cover_attachment_id` before/around deleting, in that
  feature's write repo. The foundation does not scan owners.
- Reading bytes is content-addressed only; there is no `local_path` round-trip.
