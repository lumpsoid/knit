import 'package:knit/core/recents/domain/recent_targets.dart';
import 'package:knit/core/recents/domain/recent_targets_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for a picker's recents (business_logic.md §5). Recents
/// are **device-local** view state, like pins — never synced or signed. A
/// first run with nothing persisted yields an empty list, not a failure.
abstract interface class RecentTargetsReadRepository {
  Future<Result<RecentTargets, RecentTargetsFailure>> load(
    RecentPurpose purpose,
  );
}

/// Narrow write port for a picker's recents (business_logic.md §5): note that
/// [collectionId] was just used for [purpose], and return the list after.
abstract interface class RecentTargetsWriteRepository {
  Future<Result<RecentTargets, RecentTargetsFailure>> record(
    RecentPurpose purpose,
    String collectionId,
  );
}
