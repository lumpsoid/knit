import 'package:knit/features/card_links/domain/card_links_failure.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the link picker's two levels (§4.4,
/// business_logic.md §5). Read lazily, one level at a time, so opening the
/// picker never walks every card on the device.
abstract interface class LinkTargetsReadRepository {
  /// The device's live collections — the picker's first level.
  Future<Result<List<LinkTarget>, CardLinksFailure>> loadCollections();

  /// [collectionId]'s live cards, in feed order — the drilled level.
  Future<Result<List<LinkTarget>, CardLinksFailure>> loadCards(
    String collectionId,
  );

  /// The targets [cardId] already links to, one per pair (§6.4) — the
  /// picker's ✓ marks.
  Future<Result<LinkedTargets, CardLinksFailure>> loadLinkedTargets(
    String cardId,
  );
}
