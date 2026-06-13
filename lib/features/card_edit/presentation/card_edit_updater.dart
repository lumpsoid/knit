import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';

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
          :final initialAttachmentId
        ):
        return (
          state.copyWith(
            status: CardEditStatus.editing,
            cardId: cardId,
            initialText: initialText,
            linksLoading: true,
            attachmentId: initialAttachmentId,
            imageBusy: initialAttachmentId != null,
          ),
          [
            LoadLinksEffect(cardId),
            LoadTargetsEffect(cardId),
            if (initialAttachmentId != null)
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

      // --- image ------------------------------------------------------------

      case PickImageRequested():
        return (
          state.copyWith(imageBusy: true),
          [
            PickImageEffect(
              cardId: state.cardId,
              previousAttachmentId: state.attachmentId,
            ),
          ],
        );

      case RemoveImageRequested():
        return (
          state.copyWith(imageBusy: true),
          [
            RemoveImageEffect(
              cardId: state.cardId,
              previousAttachmentId: state.attachmentId,
            ),
          ],
        );

      case ImageChanged(:final attachmentId):
        if (attachmentId == null) {
          return (
            state.copyWith(
              attachmentId: null,
              imageBytes: null,
              imageBusy: false,
            ),
            null,
          );
        }
        return (
          state.copyWith(
            attachmentId: attachmentId,
            imageBytes: null,
            imageBusy: true,
          ),
          [LoadImageEffect(attachmentId)],
        );

      case ImageBytesLoaded(:final bytes):
        return (state.copyWith(imageBytes: bytes, imageBusy: false), null);

      case ImageEditEnded():
        return (state.copyWith(imageBusy: false), null);

      case DeactivateFeature():
        return (state, null);
    }
  }
}
