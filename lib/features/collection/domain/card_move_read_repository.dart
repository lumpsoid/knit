import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for moving selected cards into another collection
/// (business_logic.md §5): the picker's rows and the target's tail.
abstract interface class CardMoveReadRepository {
  /// Every live collection, most recently updated first (§8.6.3) — the rows
  /// of the move picker. The current collection is included; the caller
  /// decides what to exclude.
  Future<Result<List<MoveTarget>, CollectionFailure>> loadMoveTargets();

  /// The `position` of [collectionId]'s newest (last) live card, or null for
  /// an empty collection — where moved cards are appended after (§8.7).
  Future<Result<String?, CollectionFailure>> lastCardPosition(
    String collectionId,
  );
}
