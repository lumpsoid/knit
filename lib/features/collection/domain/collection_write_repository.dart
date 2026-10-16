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
  Future<Result<String, CollectionFailure>> addCard({
    required String collectionId,
    required CardKind kind,
    required String position,
    String? text,
    String? attachmentId,
  });

  /// Soft-delete a card (§6.1). Links to it become broken chips, never vanish.
  Future<Result<String, CollectionFailure>> deleteCard(String cardId);

  /// Move a card to [position] — a placement-only write (§8.4).
  Future<Result<String, CollectionFailure>> reorderCard(
    String cardId,
    String position,
  );

  /// Create a neutral link from this card to [targetId] — a collection or
  /// another card, per [targetKind] (§4.4/§7.4.5). Its own synced record,
  /// merging independently of the card.
  Future<Result<String, CollectionFailure>> linkCardToTarget({
    required String cardId,
    required ConnectedEntityKind targetKind,
    required String targetId,
  });
}
