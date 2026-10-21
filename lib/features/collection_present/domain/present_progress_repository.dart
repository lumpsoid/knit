import 'package:knit/features/collection_present/domain/present_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for where a presentation was left (§4.9). Device-local —
/// never synced or signed, like pins. A slide is remembered by its first
/// card's id, so edits elsewhere in the collection don't move it.
abstract interface class PresentProgressReadRepository {
  /// The remembered card of [collectionId]'s presentation; null when none.
  Future<Result<String?, PresentFailure>> loadAnchor(String collectionId);
}

/// Narrow write port for where a presentation was left (§4.9).
abstract interface class PresentProgressWriteRepository {
  /// Remember [anchorCardId] for [collectionId]; null forgets it.
  Future<Result<void, PresentFailure>> saveAnchor(
    String collectionId,
    String? anchorCardId,
  );
}
