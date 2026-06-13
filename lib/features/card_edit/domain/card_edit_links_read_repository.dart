import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the card's outgoing links (business_logic.md §5). Returns
/// the §4.4 [ConnectionItem] view-models (all [ConnectionDirection.outgoing]) so
/// the page reuses the connections list shape + the §8.6.1 broken-link treatment
/// rather than reimplementing them.
abstract interface class CardEditLinksReadRepository {
  Future<Result<List<ConnectionItem>, CardEditFailure>> linksOf(String cardId);
}
