import 'package:knit/features/card_links/domain/card_links_failure.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for card links (§4.4, business_logic.md §5). Each call is
/// one signed local write (§8.5). Links are neutral (no label here) and point
/// at a generic entity: [ConnectedEntityKind.collection] or a card.
abstract interface class CardLinksWriteRepository {
  /// Create a link from [sourceCardId] to the [targetKind] entity [targetId].
  /// Returns the new link's id.
  Future<Result<String, CardLinksFailure>> addLink({
    required String sourceCardId,
    required ConnectedEntityKind targetKind,
    required String targetId,
  });

  /// Delete the link [linkId] — both endpoints are left untouched. Also how a
  /// broken link (§8.6.1) is cleared.
  Future<Result<String, CardLinksFailure>> removeLink(String linkId);
}
