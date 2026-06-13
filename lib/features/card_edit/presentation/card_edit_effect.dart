import 'package:knit/features/connections/domain/connections_models.dart';

/// Async-work descriptors for the Card Edit page (fcis.md §6.4).
sealed class CardEditEffect {
  const CardEditEffect();
}

/// Persist the card's edited text (§4.3). [text] is the trimmed body.
class SaveCardEffect extends CardEditEffect {
  const SaveCardEffect(this.cardId, this.text);
  final String cardId;
  final String text;
}

// --- links (subtask 3) -----------------------------------------------------

/// Load the card's outgoing links.
class LoadLinksEffect extends CardEditEffect {
  const LoadLinksEffect(this.cardId);
  final String cardId;
}

/// Load the link-picker target tree (collections + their cards), excluding
/// [cardId].
class LoadTargetsEffect extends CardEditEffect {
  const LoadTargetsEffect(this.cardId);
  final String cardId;
}

/// Create a link from [cardId] to the chosen target.
class AddLinkEffect extends CardEditEffect {
  const AddLinkEffect({
    required this.cardId,
    required this.targetKind,
    required this.targetId,
  });
  final String cardId;
  final ConnectedEntityKind targetKind;
  final String targetId;
}

/// Delete a link record.
class RemoveLinkEffect extends CardEditEffect {
  const RemoveLinkEffect(this.linkId);
  final String linkId;
}

// --- image (subtask 4) -----------------------------------------------------

/// Load the decoded bytes for [attachmentId] to render the current image.
class LoadImageEffect extends CardEditEffect {
  const LoadImageEffect(this.attachmentId);
  final String attachmentId;
}

/// Pick an image, store it, point [cardId] at the new attachment, and GC the
/// [previousAttachmentId] it replaced (if any).
class PickImageEffect extends CardEditEffect {
  const PickImageEffect({
    required this.cardId,
    required this.previousAttachmentId,
  });
  final String cardId;
  final String? previousAttachmentId;
}

/// Clear [cardId]'s image and GC the [previousAttachmentId].
class RemoveImageEffect extends CardEditEffect {
  const RemoveImageEffect({
    required this.cardId,
    required this.previousAttachmentId,
  });
  final String cardId;
  final String? previousAttachmentId;
}
