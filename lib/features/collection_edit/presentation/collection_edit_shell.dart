import 'dart:async';

import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:knit/features/collection_details/presentation/collection_details_controller.dart';
import 'package:knit/features/collection_media/domain/collection_media_read_repository.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_action.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_effect.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_ui_effect.dart';

/// Imperative shell for the Collection Edit page (fcis.md §6.6). Unwraps each
/// repository [Result] at the seam (result.md §9.3): the updater never sees a
/// Result. Header writes go through the shared [CollectionDetailsController], so
/// the Timeline and the Collection screen see them at once. A details save pops
/// the page; a cover edit resyncs only the cover section (the page-owned text
/// fields are untouched). A failed write surfaces a message and clears the
/// in-flight flag.
class CollectionEditShell
    extends Shell<CollectionEditEffect, CollectionEditAction> {
  CollectionEditShell({
    required CollectionDetailsController collectionDetails,
    required AttachmentImageCache imageCache,
    required AttachmentWriteRepository attachmentWriteRepository,
    required ImagePickerPort imagePicker,
    required CollectionMediaReadRepository mediaReadRepository,
    required EffectEmitter<CollectionEditUiEffect> effectEmitter,
    required Logger logger,
  }) : _details = collectionDetails,
       _mediaRead = mediaReadRepository,
       _images = imageCache,
       _attachmentWrite = attachmentWriteRepository,
       _picker = imagePicker,
       _effectEmitter = effectEmitter,
       _log = logger;

  final CollectionDetailsController _details;
  final AttachmentImageCache _images;
  final AttachmentWriteRepository _attachmentWrite;
  final ImagePickerPort _picker;
  final CollectionMediaReadRepository _mediaRead;
  final EffectEmitter<CollectionEditUiEffect> _effectEmitter;
  final Logger _log;

  /// How many of the newest photos the summary row previews.
  static const int _previewCount = 4;

  /// This page's owner tokens in the shared image cache.
  final Object _coverImage = Object();
  final Object _previewImages = Object();

  @override
  Future<void> run(
    CollectionEditEffect effect, {
    required void Function(CollectionEditAction) dispatch,
  }) async {
    switch (effect) {
      case SaveDetailsEffect(
        :final collectionId,
        :final title,
        :final description,
      ):
        final result = await _details.saveDetails(
          collectionId: collectionId,
          title: title,
          description: description,
        );
        result.onTap(
          (_) {
            dispatch(const SaveSucceeded());
            _effectEmitter.push(const CollectionEditSavedUiEffect());
          },
          (failure) {
            _log.severe(
              'Collection edit failed',
              failure.error,
              failure.stackTrace,
            );
            _effectEmitter.push(
              const CollectionEditShowMessageUiEffect(
                CollectionEditMessage.saveFailed,
              ),
            );
            dispatch(const SaveFailed());
          },
        );

      case ShowCoverEffect(:final attachmentId):
        await _images.show(_coverImage, [?attachmentId]);

      case ReleaseImagesEffect():
        _images
          ..release(_coverImage)
          ..release(_previewImages);

      case LoadMediaSummaryEffect(:final collectionId):
        await _loadMediaSummary(collectionId, dispatch);

      case PickCoverEffect(:final collectionId):
        await _pickCoverAndAttach(collectionId, dispatch);

      case RemoveCoverEffect(:final collectionId):
        final result = await _details.removeCover(collectionId);
        result.onTap(
          (_) {
            _images.release(_coverImage);
            dispatch(const CoverEditEnded());
          },
          (failure) {
            _log.severe(
              'Remove collection cover failed',
              failure.error,
              failure.stackTrace,
            );
            _failCover(dispatch);
          },
        );
    }
  }

  /// Pick a photo → store it → point the collection at the new cover (the
  /// shared details GC the one it replaced). Any abort (cancelled pick,
  /// store/write failure) ends the busy state without changing the cover.
  Future<void> _pickCoverAndAttach(
    String collectionId,
    void Function(CollectionEditAction) dispatch,
  ) async {
    final picked = await _picker.pickImage();
    if (picked == null) {
      dispatch(const CoverEditEnded()); // cancelled
      return;
    }

    final created = await _attachmentWrite.createFromPicked(picked);
    if (created.isFailure) {
      _log.severe('Store picked cover failed', created.error);
      _failCover(dispatch);
      return;
    }

    final attachmentId = created.getOrThrow();
    // The bytes are in hand: seed the shared cache so no page re-reads them.
    _images.put(attachmentId, picked.bytes);
    final attached = await _details.setCover(
      collectionId: collectionId,
      attachmentId: attachmentId,
    );
    if (attached.isFailure) {
      final failure = attached.error!;
      _log.severe(
        'Set collection cover failed',
        failure.error,
        failure.stackTrace,
      );
      _failCover(dispatch);
      return;
    }

    unawaited(_images.show(_coverImage, [attachmentId]));
    dispatch(const CoverEditEnded());
  }

  /// Read the media overview, then the bytes of its newest photos for the
  /// thumbnail strip. A read failure leaves the row hidden (logged only — the
  /// rest of the page is unaffected); a missing blob just drops its thumbnail.
  Future<void> _loadMediaSummary(
    String collectionId,
    void Function(CollectionEditAction) dispatch,
  ) async {
    final result = await _mediaRead.loadMedia(collectionId);
    if (result.isFailure) {
      final failure = result.error!;
      _log.severe(
        'Collection media summary failed',
        failure.error,
        failure.stackTrace,
      );
      return;
    }
    final media = result.getOrThrow();
    final previewIds = [
      for (final photo in media.recentPhotos(_previewCount))
        photo.attachmentId!,
    ];
    dispatch(MediaSummaryLoaded(counts: media.counts, previewIds: previewIds));
    await _images.show(_previewImages, previewIds);
  }

  /// Surface a write failure and clear the in-flight flag, leaving the
  /// collection's current cover untouched.
  void _failCover(void Function(CollectionEditAction) dispatch) {
    _effectEmitter.push(
      const CollectionEditShowMessageUiEffect(CollectionEditMessage.saveFailed),
    );
    dispatch(const CoverEditEnded());
  }
}
