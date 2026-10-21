/// Per-feature failure family for collection share by file (result.md §9.3).
/// Each variant carries the original [error] (and [stackTrace] when caught
/// from an exception) so the caller logs the real cause.
sealed class CollectionShareFailure {
  const CollectionShareFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}

/// Building the share file failed (reading the store or the blobs).
class CollectionShareExportFailure extends CollectionShareFailure {
  const CollectionShareExportFailure(super.error, [super.stackTrace]);
}

/// The bytes are not a Knit collection file (bad zip, missing or foreign
/// manifest, unreadable log line).
class CollectionShareCorruptFailure extends CollectionShareFailure {
  const CollectionShareCorruptFailure(super.error, [super.stackTrace]);
}

/// The file was made by a newer Knit ("This file is from a newer Knit").
class CollectionShareNewerVersionFailure extends CollectionShareFailure {
  const CollectionShareNewerVersionFailure(super.error, [super.stackTrace]);
}

/// The file failed validation ([CollectionShareImportPolicy]); nothing was
/// applied.
class CollectionShareRejectedFailure extends CollectionShareFailure {
  const CollectionShareRejectedFailure(this.reason, super.error);

  final ShareRejection reason;
}

/// Applying a validated file failed part-way (importing again completes it).
class CollectionShareImportFailure extends CollectionShareFailure {
  const CollectionShareImportFailure(super.error, [super.stackTrace]);
}

/// Sending, saving or picking the file failed.
class CollectionShareFileFailure extends CollectionShareFailure {
  const CollectionShareFileFailure(super.error, [super.stackTrace]);
}

/// Removing an imported collection failed.
class CollectionPurgeFailure extends CollectionShareFailure {
  const CollectionPurgeFailure(super.error, [super.stackTrace]);
}

/// Writing a copy ("Save a copy") failed.
class CollectionForkFailure extends CollectionShareFailure {
  const CollectionForkFailure(super.error, [super.stackTrace]);
}

/// Reading or writing the local-only archive flag failed.
class LocalArchiveFailure extends CollectionShareFailure {
  const LocalArchiveFailure(super.error, [super.stackTrace]);
}

/// Why [CollectionShareImportPolicy] refused a file.
enum ShareRejection {
  /// An op's envelope hints (entity type and id) disagree with its payload.
  malformed,

  /// A signature does not verify over its payload bytes (§7.0).
  badSignature,

  /// An op is signed or created by someone other than the file's owner, or a
  /// profile op is not self-signed.
  foreignAuthor,

  /// An op lies outside the collection: a card of another collection, a link
  /// sourced outside the set, another collection, or no collection op at all.
  outsideCollection,

  /// An op targets an id that exists here with a different `created_by` —
  /// a crafted file trying to out-rank the recipient's own entities by LWW.
  foreignOverwrite,
}
