import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the home rows' "in:" line (§4.1): of [collections],
/// the hubs over each — the live collections linking to it (§8.6.4). Ones
/// without a hub are absent.
abstract interface class TimelineHubReadRepository {
  Future<Result<Map<String, List<CollectionHub>>, TimelineFailure>> loadHubs(
    Iterable<CollectionSummary> collections,
  );
}
