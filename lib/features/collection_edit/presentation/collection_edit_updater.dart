import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_action.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_effect.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_state.dart';

/// Pure reducer for the Collection Edit page (fcis.md §6.1). Title + description
/// save on demand (a blank title is dropped — `title` is NOT NULL, spec §6.4);
/// the cover is managed in place — each intent emits one write effect and the
/// result resolves the cover section. The read-only media summary loads on
/// attach and again on return from the Media page.
class CollectionEditUpdater
    implements
        Updater<
          CollectionEditState,
          CollectionEditAction,
          CollectionEditEffect
        > {
  const CollectionEditUpdater();

  @override
  (CollectionEditState, List<CollectionEditEffect>?) update(
    CollectionEditState state,
    CollectionEditAction action,
  ) {
    switch (action) {
      case ViewAttached(:final collectionId, :final coverAttachmentId):
        // The controller outlives one page visit: start from a fresh state so
        // the previous collection's cover/media never flash on this one.
        return (
          CollectionEditState(collectionId: collectionId),
          [
            ShowCoverEffect(coverAttachmentId),
            LoadMediaSummaryEffect(collectionId),
          ],
        );

      case SaveRequested(:final title, :final description):
        final name = title.trim();
        if (name.isEmpty) return (state, null);
        final blurb = description?.trim();
        return (
          state.copyWith(status: CollectionEditStatus.saving),
          [
            SaveDetailsEffect(
              collectionId: state.collectionId,
              title: name,
              description: blurb == null || blurb.isEmpty ? null : blurb,
            ),
          ],
        );

      case SaveSucceeded():
        return (state, null);

      case SaveFailed():
        return (state.copyWith(status: CollectionEditStatus.failed), null);

      case PickCoverRequested():
        return (
          state.copyWith(coverBusy: true),
          [PickCoverEffect(state.collectionId)],
        );

      case RemoveCoverRequested():
        return (
          state.copyWith(coverBusy: true),
          [RemoveCoverEffect(state.collectionId)],
        );

      case CoverEditEnded():
        return (state.copyWith(coverBusy: false), null);

      case MediaSummaryReloadRequested():
        return (state, [LoadMediaSummaryEffect(state.collectionId)]);

      case MediaSummaryLoaded(:final counts, :final previewIds):
        return (
          state.copyWith(mediaCounts: counts, mediaPreviewIds: previewIds),
          null,
        );

      case DeactivateFeature():
        return (state, const [ReleaseImagesEffect()]);
    }
  }
}
