import 'package:knit/core/recents/domain/recent_targets.dart';
import 'package:knit/core/recents/domain/recent_targets_failure.dart';
import 'package:knit/core/recents/domain/recent_targets_repository.dart';
import 'package:result_dart/result_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The production recents store, over `shared_preferences` — device-local
/// view state kept out of the synced store, like pins. One string list per
/// [RecentPurpose].
class SharedPreferencesRecentTargetsRepository
    implements RecentTargetsReadRepository, RecentTargetsWriteRepository {
  const SharedPreferencesRecentTargetsRepository();

  static String _keyOf(RecentPurpose purpose) => switch (purpose) {
    RecentPurpose.move => 'recents.moveTargets',
    RecentPurpose.link => 'recents.linkTargets',
  };

  @override
  Future<Result<RecentTargets, RecentTargetsFailure>> load(
    RecentPurpose purpose,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Ok(RecentTargets([...?prefs.getStringList(_keyOf(purpose))]));
    } catch (e, st) {
      return Failure(RecentTargetsStorageFailure(e, st));
    }
  }

  @override
  Future<Result<RecentTargets, RecentTargetsFailure>> record(
    RecentPurpose purpose,
    String collectionId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyOf(purpose);
      final next = RecentTargets([
        ...?prefs.getStringList(key),
      ]).touched(collectionId);
      await prefs.setStringList(key, next.ids);
      return Ok(next);
    } catch (e, st) {
      return Failure(RecentTargetsStorageFailure(e, st));
    }
  }
}
