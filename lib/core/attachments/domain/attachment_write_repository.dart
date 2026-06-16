import 'package:knit/core/attachments/domain/attachment_failure.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for attachments (business_logic.md §5). Captures a picked
/// image or a recorded audio message into the signed `attachment` record +
/// content-addressed blob, and removes a record with reference-counted blob
/// cleanup.
abstract class AttachmentWriteRepository {
  /// Hash [image] → if a live record already exists for that hash, reuse it;
  /// otherwise write the bytes to the blob store and create the signed metadata
  /// record (spec §7.4.8: `{kind, mime, content_hash, size}`, never `local_path`).
  /// Returns the attachment id on success.
  Future<Result<String, AttachmentFailure>> createFromPicked(PickedImage image);

  /// As [createFromPicked], but for a recorded [audio] message — the stored
  /// record's `kind` is `audio` (spec §7.4.3/§7.4.8). Same hash-dedup + blob path.
  Future<Result<String, AttachmentFailure>> createFromAudio(PickedAudio audio);

  /// Soft-delete the attachment record, then delete its blob iff no other live
  /// record shares the same `content_hash` (reference-counted GC). Returns the
  /// deleted attachment id.
  Future<Result<String, AttachmentFailure>> delete(String attachmentId);
}
