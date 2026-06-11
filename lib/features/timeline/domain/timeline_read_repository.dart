import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the collections timeline (business_logic.md §5). Returns
/// the §8.6.3 [CollectionSummary] read-models, newest-updated first.
abstract interface class TimelineReadRepository {
  Future<Result<List<CollectionSummary>, TimelineFailure>> loadTimeline();
}
