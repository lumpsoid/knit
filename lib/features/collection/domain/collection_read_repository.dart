import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the Collection screen (business_logic.md §5). Loads the
/// header + ordered feed (§8.7) + link-finder candidates in one shot.
abstract interface class CollectionReadRepository {
  Future<Result<CollectionData, CollectionFailure>> loadCollection(String id);
}
