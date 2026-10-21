import 'package:knit/features/collection_present/domain/present_failure.dart';
import 'package:knit/features/collection_present/domain/present_progress_repository.dart';
import 'package:result_dart/result_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The production progress store, over `shared_preferences` — device-local,
/// like pins, kept out of the synced store. One key per collection.
class SharedPreferencesPresentProgressRepository
    implements PresentProgressReadRepository, PresentProgressWriteRepository {
  const SharedPreferencesPresentProgressRepository();

  static const _keyPrefix = 'present.anchor.';

  @override
  Future<Result<String?, PresentFailure>> loadAnchor(
    String collectionId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Ok(prefs.getString('$_keyPrefix$collectionId'));
    } catch (e, st) {
      return Failure(PresentProgressFailure(e, st));
    }
  }

  @override
  Future<Result<void, PresentFailure>> saveAnchor(
    String collectionId,
    String? anchorCardId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix$collectionId';
      if (anchorCardId == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, anchorCardId);
      }
      return const Ok<void, PresentFailure>(null);
    } catch (e, st) {
      return Failure(PresentProgressFailure(e, st));
    }
  }
}
