import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';
import 'package:knit/features/collection/domain/collection_models.dart';

/// Pure reducer for the Card Edit page (fcis.md §6.1). Text saves on demand (a
/// blank/whitespace-only body is dropped, matching the Collection screen);
/// links and the image are managed in place — each intent emits one write effect
/// and the result reloads the affected section.
class CardEditUpdater
    implements Updater<CardEditState, CardEditAction, CardEditEffect> {
  const CardEditUpdater();

  @override
  (CardEditState, List<CardEditEffect>?) update(
    CardEditState state,
    CardEditAction action,
  ) {
    switch (action) {
      case ViewAttached(
          :final cardId,
          :final initialText,
          :final initialAttachmentId,
          :final initialAttachmentKind,
          :final initialFileName,
          :final initialFileSize
        ):
        // An image attachment needs its bytes fetched to render the thumbnail;
        // audio/file render straight from the metadata the carrier passed.
        final isImage = initialAttachmentKind == CardKind.image;
        return (
          state.copyWith(
            status: CardEditStatus.editing,
            cardId: cardId,
            initialText: initialText,
            linksLoading: true,
            attachmentId: initialAttachmentId,
            attachmentKind: initialAttachmentKind,
            attachmentName: initialFileName,
            attachmentSize: initialFileSize,
            attachmentBusy: initialAttachmentId != null && isImage,
          ),
          [
            LoadLinksEffect(cardId),
            LoadTargetsEffect(cardId),
            if (initialAttachmentId != null && isImage)
              LoadImageEffect(initialAttachmentId),
          ],
        );

      case SaveRequested(:final text):
        final body = text.trim();
        if (body.isEmpty) return (state, null);
        return (
          state.copyWith(status: CardEditStatus.saving),
          [SaveCardEffect(state.cardId, body)],
        );

      case SaveSucceeded():
        return (state, null);

      case SaveFailed():
        return (
          state.copyWith(status: CardEditStatus.failed),
          null,
        );

      // --- links ------------------------------------------------------------

      case LinksLoaded(:final links):
        return (state.copyWith(links: links, linksLoading: false), null);

      case LinksLoadFailed():
        return (state.copyWith(linksLoading: false), null);

      case TargetsLoaded(:final targets):
        return (state.copyWith(targets: targets), null);

      case AddLinkRequested(:final targetKind, :final targetId):
        return (
          state.copyWith(linksLoading: true),
          [
            AddLinkEffect(
              cardId: state.cardId,
              targetKind: targetKind,
              targetId: targetId,
            ),
          ],
        );

      case RemoveLinkRequested(:final linkId):
        return (
          state.copyWith(linksLoading: true),
          [RemoveLinkEffect(linkId)],
        );

      case LinksChanged():
        return (
          state.copyWith(linksLoading: true),
          [LoadLinksEffect(state.cardId)],
        );

      // --- attachment -------------------------------------------------------

      case PickImageRequested():
        return (
          state.copyWith(attachmentBusy: true),
          [
            PickImageEffect(
              cardId: state.cardId,
              previousAttachmentId: state.attachmentId,
            ),
          ],
        );

      case PickFileRequested():
        return (
          state.copyWith(attachmentBusy: true),
          [
            PickFileEffect(
              cardId: state.cardId,
              previousAttachmentId: state.attachmentId,
            ),
          ],
        );

      case RemoveAttachmentRequested():
        return (
          state.copyWith(attachmentBusy: true),
          [
            RemoveAttachmentEffect(
              cardId: state.cardId,
              previousAttachmentId: state.attachmentId,
            ),
          ],
        );

      case AttachmentResolved(
          :final attachmentId,
          :final kind,
          :final bytes,
          :final name,
          :final size
        ):
        return (
          state.copyWith(
            attachmentId: attachmentId,
            attachmentKind: kind,
            imageBytes: bytes,
            attachmentName: name,
            attachmentSize: size,
            attachmentBusy: false,
          ),
          null,
        );

      case AttachmentEditEnded():
        return (state.copyWith(attachmentBusy: false), null);

      case DeactivateFeature():
        return (state, null);
    }
  }
}
