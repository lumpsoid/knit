import 'package:knit/features/collection_share/domain/collection_share_failure.dart';
import 'package:knit/features/collection_share/domain/local_archive_repository.dart';
import 'package:result_dart/result_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The local archive flag over `shared_preferences` — device-local, kept out
/// of the synced store (like the Timeline's pins).
class SharedPreferencesLocalArchiveRepository
    implements LocalArchiveReadRepository, LocalArchiveWriteRepository {
  const SharedPreferencesLocalArchiveRepository();

  static const _key = 'collections.localArchived';

  @override
  Future<Result<Set<String>, CollectionShareFailure>> loadArchived() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Ok({...?prefs.getStringList(_key)});
    } catch (e, st) {
      return Failure(LocalArchiveFailure(e, st));
    }
  }

  @override
  Future<Result<Set<String>, CollectionShareFailure>> setArchived(
    String collectionId, {
    required bool archived,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = {...?prefs.getStringList(_key)};
      if (archived) {
        ids.add(collectionId);
      } else {
        ids.remove(collectionId);
      }
      await prefs.setStringList(_key, ids.toList(growable: false));
      return Ok(ids);
    } catch (e, st) {
      return Failure(LocalArchiveFailure(e, st));
    }
  }
}

/// In-memory local archive for dev and tests.
class InMemoryLocalArchiveRepository
    implements LocalArchiveReadRepository, LocalArchiveWriteRepository {
  InMemoryLocalArchiveRepository([Set<String>? ids]) : _ids = {...?ids};

  final Set<String> _ids;

  @override
  Future<Result<Set<String>, CollectionShareFailure>> loadArchived() async =>
      Ok({..._ids});

  @override
  Future<Result<Set<String>, CollectionShareFailure>> setArchived(
    String collectionId, {
    required bool archived,
  }) async {
    archived ? _ids.add(collectionId) : _ids.remove(collectionId);
    return Ok({..._ids});
  }
}
