/// Per-area failure family for the attachments foundation (result.md §9.3).
/// Callers map these to user-facing messages; the value never reaches a pure
/// updater (the consuming feature's shell unwraps the [Result]).
sealed class AttachmentFailure {
  const AttachmentFailure();
}

/// Capturing or storing a picked image failed (hash, blob write, or the signed
/// metadata write).
class AttachmentWriteFailure extends AttachmentFailure {
  const AttachmentWriteFailure(this.cause);
  final String cause;
}

/// No attachment record exists for the requested id.
class AttachmentNotFound extends AttachmentFailure {
  const AttachmentNotFound(this.attachmentId);
  final String attachmentId;
}

/// The attachment record exists but its bytes are missing from the blob store
/// (e.g. not yet fetched out-of-band on this device).
class AttachmentBytesMissing extends AttachmentFailure {
  const AttachmentBytesMissing(this.contentHash);
  final String contentHash;
}
