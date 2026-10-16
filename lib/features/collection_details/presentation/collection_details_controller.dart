import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/features/collection_details/domain/collection_details.dart';
import 'package:knit/features/collection_details/domain/collection_details_failure.dart';
import 'package:knit/features/collection_details/domain/collection_details_write_repository.dart';
import 'package:knit/features/collection_details/presentation/collection_details_state.dart';
import 'package:result_dart/result_dart.dart';

/// The shared, app-wide owner of collection headers (title, description, cover
/// — spec §3.1). The Timeline, the Collection screen and the Collection Edit
/// page all read [state]; every header edit goes through here, so a change made
/// on one page shows on the others without a re-read.
///
/// Features that read collections from the projection hand what they read to
/// [remember]/[rememberAll], keeping [state] as fresh as the latest read. Each
/// write returns its [Result] so the calling feature can react (pop, message).
class CollectionDetailsController {
  CollectionDetailsController({
    required CollectionDetailsWriteRepository writeRepository,
    required AttachmentWriteRepository attachmentWriteRepository,
    Logger? logger,
  }) : _write = writeRepository,
       _attachmentWrite = attachmentWriteRepository,
       _log = logger ?? Logger('knit.collection_details');

  final CollectionDetailsWriteRepository _write;
  final AttachmentWriteRepository _attachmentWrite;
  final Logger _log;

  final CollectionDetailsState state = CollectionDetailsState();

  /// Record a header just read from the projection.
  void remember(CollectionDetails details) => state.put(details);

  /// Record a batch of headers just read from the projection.
  void rememberAll(Iterable<CollectionDetails> all) => state.putAll(all);

  /// Save [collectionId]'s [title] and [description]. Callers pass the
  /// already-validated values (trimmed, non-blank title; null for no blurb).
  Future<Result<String, CollectionDetailsFailure>> saveDetails({
    required String collectionId,
    required String title,
    String? description,
  }) async {
    final result = await _write.editDetails(
      collectionId: collectionId,
      title: title,
      description: description,
    );
    if (result.isSuccess) {
      _update(
        collectionId,
        (d) => d.copyWith(title: title, description: description),
      );
    }
    return result;
  }

  /// Point [collectionId]'s cover at the already-stored [attachmentId], then
  /// reclaim the cover it replaced.
  Future<Result<String, CollectionDetailsFailure>> setCover({
    required String collectionId,
    required String attachmentId,
  }) async {
    final previous = state.of(collectionId)?.coverAttachmentId;
    final result = await _write.setCover(
      collectionId: collectionId,
      attachmentId: attachmentId,
    );
    if (result.isSuccess) {
      _update(collectionId, (d) => d.copyWith(coverAttachmentId: attachmentId));
      if (previous != attachmentId) await _gcAttachment(previous);
    }
    return result;
  }

  /// Clear [collectionId]'s cover, then reclaim the removed image.
  Future<Result<String, CollectionDetailsFailure>> removeCover(
    String collectionId,
  ) async {
    final previous = state.of(collectionId)?.coverAttachmentId;
    final result = await _write.removeCover(collectionId: collectionId);
    if (result.isSuccess) {
      _update(collectionId, (d) => d.copyWith(coverAttachmentId: null));
      await _gcAttachment(previous);
    }
    return result;
  }

  /// Apply [change] to the known header. An unknown collection stays unknown —
  /// its next read from the projection records the whole header.
  void _update(
    String collectionId,
    CollectionDetails Function(CollectionDetails) change,
  ) {
    final current = state.of(collectionId);
    if (current != null) state.put(change(current));
  }

  /// Drop the replaced/removed cover's attachment record (ref-counted blob GC
  /// happens inside the repo). A GC failure is non-fatal — the header already
  /// points away.
  Future<void> _gcAttachment(String? attachmentId) async {
    if (attachmentId == null) return;
    final result = await _attachmentWrite.delete(attachmentId);
    if (result.isFailure) {
      _log.warning('Attachment GC failed for $attachmentId: ${result.error}');
    }
  }
}
