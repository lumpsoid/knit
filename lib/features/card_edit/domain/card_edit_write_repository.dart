import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for the Card Edit page (business_logic.md §5). Editing a
/// card is one signed local write through the §6.8 path — content stamp bumps,
/// placement frozen (§8.4). Returns the affected card id on success.
abstract interface class CardEditWriteRepository {
  /// Edit a card's content (§4.3). [text] is the body; named (vs a positional
  /// arg) so the call site stays stable as more content fields (e.g. an
  /// attachment id, subtask 4) are added later.
  Future<Result<String, CardEditFailure>> editCard({
    required String cardId,
    String? text,
  });
}
