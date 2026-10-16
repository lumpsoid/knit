import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/features/timeline/domain/timeline_pin_repository.dart';
import 'package:result_dart/result_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The production pin store, over `shared_preferences` — device-local UI
/// config, kept out of the synced SQLite/change-log store (like Settings). One
/// class satisfies both narrow ports since it's a single key/value backing.
class SharedPreferencesTimelinePinRepository
    implements TimelinePinReadRepository, TimelinePinWriteRepository {
  const SharedPreferencesTimelinePinRepository();

  static const _pinnedKey = 'timeline.pinnedCollections';

  @override
  Future<Result<Set<String>, TimelineFailure>> loadPinned() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Ok({...?prefs.getStringList(_pinnedKey)});
    } catch (e, st) {
      return Failure(TimelinePinFailure(e, st));
    }
  }

  @override
  Future<Result<Set<String>, TimelineFailure>> setPinned(
    String collectionId, {
    required bool pinned,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = {...?prefs.getStringList(_pinnedKey)};
      if (pinned) {
        ids.add(collectionId);
      } else {
        ids.remove(collectionId);
      }
      await prefs.setStringList(_pinnedKey, ids.toList(growable: false));
      return Ok(ids);
    } catch (e, st) {
      return Failure(TimelinePinFailure(e, st));
    }
  }
}
