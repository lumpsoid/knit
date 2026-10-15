import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/collection_media/domain/collection_media_models.dart';
import 'package:knit/features/collection_media/presentation/collection_media_action.dart';
import 'package:knit/features/collection_media/presentation/collection_media_effect.dart';
import 'package:knit/features/collection_media/presentation/collection_media_state.dart';

/// Pure reducer for the Collection Media page (fcis.md §6.1). A load resolves the
/// overview, then fetches bytes for any photo not already cached; file/link taps
/// resolve the item and emit the matching share/open effect.
class CollectionMediaUpdater
    implements
        Updater<
          CollectionMediaState,
          CollectionMediaAction,
          CollectionMediaEffect
        > {
  const CollectionMediaUpdater();

  @override
  (CollectionMediaState, List<CollectionMediaEffect>?) update(
    CollectionMediaState state,
    CollectionMediaAction action,
  ) {
    switch (action) {
      case ViewAttached(:final collectionId):
        // The controller outlives one page visit: drop the last collection's
        // media, but keep the content-addressed thumbnail cache.
        return (
          CollectionMediaState(
            collectionId: collectionId,
            photoBytes: state.photoBytes,
          ),
          [LoadMediaEffect(collectionId)],
        );

      case ReloadRequested():
        return (
          state.status == CollectionMediaStatus.failed
              ? state.copyWith(status: CollectionMediaStatus.loading)
              : state,
          [LoadMediaEffect(state.collectionId)],
        );

      case MediaLoaded(:final media):
        final toLoad = [
          for (final photo in media.ofKind(MediaKind.photo))
            if (!state.photoBytes.containsKey(photo.attachmentId))
              photo.attachmentId!,
        ];
        return (
          state.copyWith(
            status: CollectionMediaStatus.ready,
            media: media,
            missingPhotos: const {},
          ),
          toLoad.isEmpty ? null : [LoadPhotoBytesEffect(toLoad)],
        );

      case MediaLoadFailed():
        return (state.copyWith(status: CollectionMediaStatus.failed), null);

      case PhotoBytesLoaded(:final attachmentId, :final bytes):
        if (bytes == null) {
          return (
            state.copyWith(
              missingPhotos: {...state.missingPhotos, attachmentId},
            ),
            null,
          );
        }
        return (
          state.copyWith(
            photoBytes: {...state.photoBytes, attachmentId: bytes},
          ),
          null,
        );

      case FileShareRequested(:final cardId):
        final item = state.media.byCardId(cardId);
        final attachmentId = item?.attachmentId;
        if (item == null || attachmentId == null) return (state, null);
        return (
          state,
          [
            ShareFileEffect(
              attachmentId: attachmentId,
              fileName: item.fileName,
              caption: item.caption,
            ),
          ],
        );

      case LinkOpenRequested(:final cardId):
        final url = state.media.byCardId(cardId)?.url;
        if (url == null) return (state, null);
        return (state, [OpenLinkEffect(url)]);

      case DeactivateFeature():
        return (state, null);
    }
  }
}
