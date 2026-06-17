import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for the Card Edit page (business_logic.md §5). Each method
/// is one signed local write through the §6.8 path — content stamp bumps,
/// placement frozen (§8.4). Returns the affected card id on success.
abstract interface class CardEditWriteRepository {
  /// Edit a card's body text (§4.3). Named (vs a positional arg) so the call
  /// site stays stable.
  Future<Result<String, CardEditFailure>> editCard({
    required String cardId,
    String? text,
  });

  /// Attach (or replace) the card's attachment (§7.4.3): set `attachment_id` and
  /// flip the card `kind` to match [kind] (`image`/`audio`/`file`). The bytes
  /// were already captured into the signed `attachment` record + blob by the
  /// attachments foundation; this only points the card at it.
  Future<Result<String, CardEditFailure>> setCardAttachment({
    required String cardId,
    required String attachmentId,
    required CardKind kind,
  });

  /// Remove the card's attachment: clear `attachment_id` and flip `kind` back to
  /// `text`. The `attachment` record itself is GC'd separately (ref-counted).
  Future<Result<String, CardEditFailure>> removeCardAttachment({
    required String cardId,
  });
}
