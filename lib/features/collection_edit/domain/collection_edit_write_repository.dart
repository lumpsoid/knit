import 'package:knit/features/collection_edit/domain/collection_edit_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for the Collection Edit page (business_logic.md §5). A
/// collection carries `title` + optional `description` + an optional cover image
/// only (spec §3.1); these are the only edits this page makes. Each call is one
/// signed local write that overlays the changed content keys (§8.5).
abstract interface class CollectionEditWriteRepository {
  /// Persist the collection's `title` (required, never blank) and optional
  /// `description` (spec §3.1/§7.4). Named (vs positional) so the call site
  /// stays stable as the field set grows.
  Future<Result<String, CollectionEditFailure>> editDetails({
    required String collectionId,
    required String title,
    String? description,
  });

  /// Point the collection's header at [attachmentId] as its cover image
  /// (`cover_attachment_id`, spec §7.4.1). The bytes were already captured into
  /// the signed `attachment` record + blob by the attachments foundation; this
  /// only points the header at it.
  Future<Result<String, CollectionEditFailure>> setCover({
    required String collectionId,
    required String attachmentId,
  });

  /// Clear the collection's cover image (`cover_attachment_id` → null). The
  /// `attachment` record itself is GC'd separately (ref-counted).
  Future<Result<String, CollectionEditFailure>> removeCover({
    required String collectionId,
  });
}
