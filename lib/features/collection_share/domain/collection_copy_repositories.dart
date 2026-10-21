import 'package:knit/features/collection_share/domain/collection_share_failure.dart';
import 'package:result_dart/result_dart.dart';

/// "Save a copy" (§10.5 fork, docs/collection_share.md): an own, editable
/// copy of a collection, written in one transaction. The source stays.
abstract interface class CollectionForkRepository {
  /// Fork [collectionId]; returns the copy's id.
  Future<Result<String, CollectionShareFailure>> fork(String collectionId);
}

/// "Remove" an imported collection (docs/collection_share.md): a local purge
/// of its rows, its ops and its unreferenced blobs. Nothing is signed;
/// importing the file again restores it.
abstract interface class CollectionPurgeRepository {
  Future<Result<void, CollectionShareFailure>> purge(String collectionId);
}
