import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the Collection screen (business_logic.md §5). Loads the
/// header + ordered feed (§8.7); the link-finder targets load lazily, per level,
/// so opening a collection never reads every other collection's cards.
abstract interface class CollectionReadRepository {
  Future<Result<CollectionData, CollectionFailure>> loadCollection(String id);

  /// Live collections offered as link targets (§4.4) — the finder's first
  /// level. The current collection is included so the user can drill into it to
  /// link to a sibling card; the page hides its direct "link to collection".
  Future<Result<List<LinkOption>, CollectionFailure>> loadLinkCollections();

  /// The live cards of [collectionId] as link targets — the finder's drilled
  /// level. Returns *all* cards (keyed cache is source-card-independent); the
  /// page drops the source card at render so a card can't link to itself.
  Future<Result<List<LinkOption>, CollectionFailure>> loadCollectionCards(
    String collectionId,
  );
}
