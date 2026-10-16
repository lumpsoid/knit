import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the Collection screen (business_logic.md §5). Loads the
/// header + ordered feed (§8.7); the link-finder targets load lazily, per level,
/// so opening a collection never reads every other collection's cards.
abstract interface class CollectionReadRepository {
  /// The header + the [window] of the feed (default: every card). The screen
  /// passes a bounded window so a very large collection opens in one page.
  Future<Result<CollectionData, CollectionFailure>> loadCollection(
    String id, {
    FeedWindow window = const FeedWindow.all(),
  });

  /// Up to [limit] cards strictly older than [before] — the next page as the
  /// user scrolls up the feed.
  Future<Result<FeedPage, CollectionFailure>> loadOlderCards(
    String collectionId, {
    required FeedCursor before,
    required int limit,
  });

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

  /// True when any **live** card still references [attachmentId] via its
  /// `content['attachment_id']`. The shell consults this before reclaiming a
  /// deleted card's attachment so a legacy shared record (one record reused by
  /// several cards, created before the 1 referent : 1 record invariant) is never
  /// orphaned (business_logic.md §5: a narrow, single-purpose port).
  Future<Result<bool, CollectionFailure>> isAttachmentReferenced(
    String attachmentId,
  );
}
