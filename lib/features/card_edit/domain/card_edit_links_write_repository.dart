import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for the card's links (business_logic.md §5). Both methods
/// are one signed local write through the §6.8 path. Like the Collection
/// screen's `linkCardToTarget`, the target is a generic entity ([targetKind] =
/// collection *or* card), so the page supports the full §4.3 scope (card→card).
abstract interface class CardEditLinksWriteRepository {
  /// Create a `link` from this card to [targetId] (a collection or a card).
  /// Returns the new link id.
  Future<Result<String, CardEditFailure>> addLink({
    required String sourceCardId,
    required ConnectedEntityKind targetKind,
    required String targetId,
  });

  /// Delete a `link` record (reuses the §8.6.1 clear pattern). The endpoints are
  /// never touched. Returns the removed link id.
  Future<Result<String, CardEditFailure>> removeLink(String linkId);
}
