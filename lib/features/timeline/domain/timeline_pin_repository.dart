import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for pinned collections (business_logic.md §5). Pins are a
/// **device-local** view preference — never synced or signed — so the home
/// timeline on another device is unaffected. A first run with nothing persisted
/// yields an empty set, not a failure.
abstract interface class TimelinePinReadRepository {
  Future<Result<Set<String>, TimelineFailure>> loadPinned();
}

/// Narrow write port for pinned collections (business_logic.md §5). Pins or
/// unpins [collectionId] and returns the full pinned set after the write.
abstract interface class TimelinePinWriteRepository {
  Future<Result<Set<String>, TimelineFailure>> setPinned(
    String collectionId, {
    required bool pinned,
  });
}
