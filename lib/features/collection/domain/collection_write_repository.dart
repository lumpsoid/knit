import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for the Collection screen (business_logic.md §5). Every op
/// is one signed local write through the §6.8 path; positions are minted by the
/// (pure) updater and passed in, so this port carries no ordering logic. Each
/// op returns the affected entity id on success.
abstract interface class CollectionWriteRepository {
  /// Append/insert a card of [kind] at the pre-computed [position] (§8.4/§8.7).
  /// [text] is the body for a text card or the URL/label for a link card — or
  /// the caption for an image card. [attachmentId] points an image card at its
  /// stored attachment (§7.4.8); it is null for text/link cards.
  /// [moreAttachmentIds] are an image card's further images, after
  /// [attachmentId] (§4.2).
  Future<Result<String, CollectionFailure>> addCard({
    required String collectionId,
    required CardKind kind,
    required String position,
    String? text,
    String? attachmentId,
    List<String> moreAttachmentIds = const [],
  });

  /// Append a Connection card at [position] (§4.2): a card of [kind] with
  /// [text] and one link out to the [targetKind] entity [targetId], a
  /// collection or a card, written together in one transaction. The default
  /// is the §6.4 link block: a `link`-kind card with no text; a label makes it
  /// a text card. Returns the new card id.
  Future<Result<String, CollectionFailure>> addConnectionCard({
    required String collectionId,
    required String position,
    required ConnectedEntityKind targetKind,
    required String targetId,
    CardKind kind = CardKind.link,
    String? text,
  });

  /// Create a collection titled [title] and append a Connection card to it
  /// at [position] (as [addConnectionCard]), all in one transaction — the
  /// Connection picker's "New collection" (§4.4). Returns the new
  /// collection's id.
  Future<Result<String, CollectionFailure>> addConnectionCardToNewCollection({
    required String collectionId,
    required String position,
    required String title,
    CardKind kind = CardKind.link,
    String? text,
  });

  /// Soft-delete a card (§6.1). Links to it become broken chips, never vanish.
  Future<Result<String, CollectionFailure>> deleteCard(String cardId);

  /// Soft-delete [cardIds] in one transaction (all or none). Returns the first
  /// card's id on success.
  Future<Result<String, CollectionFailure>> deleteCards(List<String> cardIds);

  /// Move a card to [position] — a placement-only write (§8.4).
  Future<Result<String, CollectionFailure>> reorderCard(
    String cardId,
    String position,
  );

  /// Settle (or, with [settled] false, unsettle) [cardIds] in one transaction
  /// (§3.3) — a content write per card, placement frozen. Returns the first
  /// card's id on success.
  Future<Result<String, CollectionFailure>> setCardsSettled(
    List<String> cardIds, {
    required bool settled,
  });

  /// Emphasize (or, with [emphasized] false, unemphasize) [cardIds] in one
  /// transaction (§3.3); emphasizing unsettles. Returns the first card's id.
  Future<Result<String, CollectionFailure>> setCardsEmphasized(
    List<String> cardIds, {
    required bool emphasized,
  });

  /// Create an empty collection titled [title] — a move's new target, made
  /// from the picker on the fly. Returns the new collection id.
  Future<Result<String, CollectionFailure>> createCollection(String title);

  /// Soft-delete the collection [collectionId] (§6.1). Links to it become
  /// broken chips. Returns the collection id.
  Future<Result<String, CollectionFailure>> deleteCollection(
    String collectionId,
  );

  /// Move cards into [collectionId] in one transaction (all or none):
  /// [positions] maps each card id to its pre-computed position in the target
  /// (§8.7). Returns the target collection id on success.
  Future<Result<String, CollectionFailure>> moveCards(
    String collectionId,
    Map<String, String> positions,
  );
}
