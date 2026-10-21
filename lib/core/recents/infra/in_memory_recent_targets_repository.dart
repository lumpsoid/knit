import 'package:knit/core/recents/domain/recent_targets.dart';
import 'package:knit/core/recents/domain/recent_targets_failure.dart';
import 'package:knit/core/recents/domain/recent_targets_repository.dart';
import 'package:result_dart/result_dart.dart';

/// In-memory recents for dev mode and tests — no platform channel. Holds each
/// purpose's list for the process lifetime, by the same rule as the
/// shared_preferences impl.
class InMemoryRecentTargetsRepository
    implements RecentTargetsReadRepository, RecentTargetsWriteRepository {
  InMemoryRecentTargetsRepository([
    Map<RecentPurpose, List<String>> initial = const {},
  ]) : _lists = {
         for (final MapEntry(:key, :value) in initial.entries)
           key: RecentTargets(value),
       };

  final Map<RecentPurpose, RecentTargets> _lists;

  @override
  Future<Result<RecentTargets, RecentTargetsFailure>> load(
    RecentPurpose purpose,
  ) async => Ok(_lists[purpose] ?? const RecentTargets());

  @override
  Future<Result<RecentTargets, RecentTargetsFailure>> record(
    RecentPurpose purpose,
    String collectionId,
  ) async {
    final next = (_lists[purpose] ?? const RecentTargets()).touched(
      collectionId,
    );
    _lists[purpose] = next;
    return Ok(next);
  }
}
