import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the Collection's Outline (§4.2, business_logic.md §5).
/// The screen holds only a window of a large feed, so the Outline reads the
/// whole collection here; which cards head it is the domain's call
/// (`CollectionOutline`).
abstract interface class CollectionOutlineReadRepository {
  /// Every live card of [collectionId], in feed order (oldest → newest), with
  /// what an outline row shows: kind, text, file name and the §3.3 marks.
  /// Link counts are not read (zero).
  Future<Result<List<FeedCard>, CollectionFailure>> loadOutlineCards(
    String collectionId,
  );
}
