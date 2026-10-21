import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for whose the home collections are
/// (docs/collection_share.md): of [collections], the imported (read-only)
/// ones, each with its creator's `nickname#fingerprint` for the row's "from"
/// line. Own collections are absent.
abstract interface class TimelineOwnerReadRepository {
  Future<Result<Map<String, String>, TimelineFailure>> loadImportedOwners(
    Iterable<CollectionSummary> collections,
  );
}
