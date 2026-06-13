import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/card_edit/domain/card_edit_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the link picker's target tree (business_logic.md §5):
/// every live collection plus its cards, so the add-link flow can browse
/// collections and drill into a collection's cards (§4.3, full scope). The card
/// being edited is excluded from the card lists (no self-link).
abstract interface class CardEditTargetsReadRepository {
  Future<Result<List<CardLinkCollectionTargets>, CardEditFailure>> loadTargets({
    required String excludeCardId,
  });
}
