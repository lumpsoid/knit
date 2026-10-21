import 'package:knit/features/collection_share/domain/collection_share_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Reads the device-local archive flag of imported collections
/// (docs/collection_share.md "Read-only"): an imported collection can't carry
/// a signed `archived_at` of the recipient's, so archiving it is a local view
/// preference, like pins — never synced or signed.
abstract interface class LocalArchiveReadRepository {
  Future<Result<Set<String>, CollectionShareFailure>> loadArchived();
}

/// Archives or unarchives [collectionId] locally; returns the full set after
/// the write.
abstract interface class LocalArchiveWriteRepository {
  Future<Result<Set<String>, CollectionShareFailure>> setArchived(
    String collectionId, {
    required bool archived,
  });
}
