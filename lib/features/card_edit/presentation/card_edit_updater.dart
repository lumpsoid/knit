import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/card_edit/domain/card_text_edit.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// Pure reducer for the Card Edit page (fcis.md §6.1). Text saves on demand (a
/// blank/whitespace-only body is dropped, matching the Collection screen,
/// except on a Connection card — [CardTextEdit] decides);
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
        :final collectionId,
        :final initialText,
        :final initialKind,
        :final initialAttachmentId,
        :final initialMoreAttachmentIds,
        :final initialAttachmentKind,
        :final initialFileName,
        :final initialFileSize,
        :final initialSettled,
        :final initialEmphasized,
      ):
        // Images show through the shared image cache; audio/file render
        // straight from the metadata the carrier passed.
        final next = state.copyWith(
          status: CardEditStatus.editing,
          cardId: cardId,
          initialText: initialText,
          kind: initialKind,
          linksLoading: true,
          attachmentId: initialAttachmentId,
          moreAttachmentIds: initialMoreAttachmentIds,
          attachmentKind: initialAttachmentKind,
          attachmentName: initialFileName,
          attachmentSize: initialFileSize,
          attachmentBusy: false,
          settled: initialSettled,
          settledBusy: false,
          emphasized: initialEmphasized && !initialSettled,
          emphasizedBusy: false,
        );
        return (
          next,
          [
            LoadLinksEffect(cardId),
            LoadTimelinePreviewEffect(
              cardId: cardId,
              collectionId: collectionId,
            ),
            ShowImageEffect(next.imageIds),
          ],
        );

      case TimelinePreviewResolved(:final isTimelinePreview):
        return (state.copyWith(isTimelinePreview: isTimelinePreview), null);

      case SaveRequested(:final text):
        final edit = CardTextEdit.of(
          kind: state.kind,
          text: text,
          attachmentIds: state.attachmentIds,
          linksOut: [
            for (final link in state.links)
              if (link.direction == ConnectionDirection.outgoing)
                (targetKind: link.otherKind, targetId: link.otherId),
          ],
        );
        if (edit == null) return (state, null);
        return (
          state.copyWith(status: CardEditStatus.saving),
          [SaveCardEffect(state.cardId, edit.text, kind: edit.kind)],
        );

      case SaveSucceeded():
        return (state, _refreshTimeline(state));

      case SaveFailed():
        return (state.copyWith(status: CardEditStatus.failed), null);

      // --- links ------------------------------------------------------------

      case LinksLoaded(:final links):
        return (state.copyWith(links: links, linksLoading: false), null);

      case LinksLoadFailed():
        return (state.copyWith(linksLoading: false), null);

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
        return (state.copyWith(linksLoading: true), [RemoveLinkEffect(linkId)]);

      case LinksChanged():
        return (
          state.copyWith(linksLoading: true),
          [LoadLinksEffect(state.cardId)],
        );

      // --- attachment -------------------------------------------------------

      case PickImageRequested():
        if (state.attachmentBusy) return (state, null);
        // New photos join an image card's images; on any other card they
        // take the place of what it had.
        final isImage = state.attachmentKind == CardKind.image;
        return (
          state.copyWith(attachmentBusy: true),
          [
            PickImageEffect(
              cardId: state.cardId,
              keptImageIds: state.imageIds,
              replacedAttachmentId: isImage ? null : state.attachmentId,
            ),
          ],
        );

      case RemoveImageRequested(:final attachmentId):
        final images = state.imageIds;
        if (state.attachmentBusy || !images.contains(attachmentId)) {
          return (state, null);
        }
        return (
          state.copyWith(attachmentBusy: true),
          [
            RemoveImageEffect(
              cardId: state.cardId,
              remainingIds: [
                for (final id in images)
                  if (id != attachmentId) id,
              ],
              removedId: attachmentId,
            ),
          ],
        );

      case PickFileRequested():
        if (state.attachmentBusy) return (state, null);
        return (
          state.copyWith(attachmentBusy: true),
          [
            PickFileEffect(
              cardId: state.cardId,
              previousAttachmentIds: state.attachmentIds,
            ),
          ],
        );

      case OptimizeImageRequested():
        final images = state.imageIds;
        if (state.attachmentBusy || images.isEmpty) return (state, null);
        return (
          state.copyWith(attachmentBusy: true, optimizingImage: true),
          [OptimizeImageEffect(cardId: state.cardId, attachmentIds: images)],
        );

      case RemoveAttachmentRequested():
        if (state.attachmentBusy) return (state, null);
        return (
          state.copyWith(attachmentBusy: true),
          [
            RemoveAttachmentEffect(
              cardId: state.cardId,
              previousAttachmentIds: state.attachmentIds,
            ),
          ],
        );

      case AttachmentResolved(
        :final attachmentId,
        :final moreAttachmentIds,
        :final kind,
        :final name,
        :final size,
      ):
        final resolved = state.copyWith(
          attachmentId: attachmentId,
          moreAttachmentIds: moreAttachmentIds,
          attachmentKind: kind,
          // Attaching takes the attachment's kind; removing makes a text card.
          kind: kind ?? CardKind.text,
          attachmentName: name,
          attachmentSize: size,
          attachmentBusy: false,
          optimizingImage: false,
        );
        return (
          resolved,
          [ShowImageEffect(resolved.imageIds), ...?_refreshTimeline(state)],
        );

      case AttachmentEditEnded():
        return (
          state.copyWith(attachmentBusy: false, optimizingImage: false),
          null,
        );

      // --- settled ----------------------------------------------------------

      case SettledToggled(:final settled):
        if (state.markBusy || settled == state.settled) return (state, null);
        return (
          state.copyWith(settledBusy: true),
          [SetSettledEffect(state.cardId, settled: settled)],
        );

      case SettledResolved(:final settled):
        return (
          state.copyWith(
            settled: settled,
            settledBusy: false,
            // Settling clears the emphasis (§3.3).
            emphasized: settled ? false : state.emphasized,
          ),
          _refreshTimeline(state),
        );

      case SettledEditFailed():
        return (state.copyWith(settledBusy: false), null);

      // --- emphasized -------------------------------------------------------

      case EmphasizedToggled(:final emphasized):
        if (state.markBusy || emphasized == state.emphasized) {
          return (state, null);
        }
        return (
          state.copyWith(emphasizedBusy: true),
          [SetEmphasizedEffect(state.cardId, emphasized: emphasized)],
        );

      case EmphasizedResolved(:final emphasized):
        // Emphasizing unsettles (§3.3); only that reaches the Timeline, whose
        // row mutes a settled preview.
        final unsettled = emphasized && state.settled;
        return (
          state.copyWith(
            emphasized: emphasized,
            emphasizedBusy: false,
            settled: unsettled ? false : state.settled,
          ),
          unsettled ? _refreshTimeline(state) : null,
        );

      case EmphasizedEditFailed():
        return (state.copyWith(emphasizedBusy: false), null);

      case DeactivateFeature():
        return (state, const [ReleaseImageEffect()]);
    }
  }

  /// A text, attachment or settled edit changes the Timeline only when this card is the
  /// one its collection's row previews (§8.6.3).
  static List<CardEditEffect>? _refreshTimeline(CardEditState state) =>
      state.isTimelinePreview ? const [RefreshTimelineEffect()] : null;
}
