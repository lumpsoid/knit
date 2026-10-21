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
  /// flip the card `kind` to match [kind] (`image`/`audio`/`file`), dropping
  /// any further images. The bytes were already captured into the signed
  /// `attachment` record + blob by the attachments foundation; this only
  /// points the card at it.
  Future<Result<String, CardEditFailure>> setCardAttachment({
    required String cardId,
    required String attachmentId,
    required CardKind kind,
  });

  /// Make the card an image card holding [attachmentIds] in order (§4.2): the
  /// first in `attachment_id`, the rest in `more_attachment_ids`. Must not be
  /// empty — removing the last image is [removeCardAttachment].
  Future<Result<String, CardEditFailure>> setCardImages({
    required String cardId,
    required List<String> attachmentIds,
  });

  /// Settle (or, with [settled] false, unsettle) the card (§3.3) — a content
  /// write, placement frozen.
  Future<Result<String, CardEditFailure>> setCardSettled({
    required String cardId,
    required bool settled,
  });

  /// Emphasize (or, with [emphasized] false, unemphasize) the card (§3.3) —
  /// a content write, placement frozen; emphasizing unsettles.
  Future<Result<String, CardEditFailure>> setCardEmphasized({
    required String cardId,
    required bool emphasized,
  });

  /// Remove the card's attachment: clear `attachment_id` (and any further
  /// images) and flip `kind` back to `text`. The `attachment` record itself is GC'd separately (ref-counted).
  Future<Result<String, CardEditFailure>> removeCardAttachment({
    required String cardId,
  });
}
