import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for the timeline (business_logic.md §5). The home screen
/// performs three writes: inline collection creation (§4.1) — on success it
/// returns the new collection's id so the View can open it — and, from the
/// long-press actions sheet, archiving/unarchiving (§3.4) and deleting a
/// collection, each returning the collection's id.
abstract interface class TimelineWriteRepository {
  Future<Result<String, TimelineFailure>> createCollection(String title);

  Future<Result<String, TimelineFailure>> deleteCollection(String collectionId);

  Future<Result<String, TimelineFailure>> setArchived(
    String collectionId, {
    required bool archived,
  });
}
