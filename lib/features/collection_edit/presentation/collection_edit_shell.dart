import 'dart:typed_data';

import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/features/collection_edit/domain/collection_edit_write_repository.dart';
import 'package:knit/features/collection_media/domain/collection_media_read_repository.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_action.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_effect.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_ui_effect.dart';

/// Imperative shell for the Collection Edit page (fcis.md §6.6). Unwraps each
/// repository [Result] at the seam (result.md §9.3): the updater never sees a
/// Result. A details save pops the page; a cover edit resyncs only the cover
/// section (the page-owned text fields are untouched). A failed write surfaces a
/// message and clears the in-flight flag.
class CollectionEditShell
    extends Shell<CollectionEditEffect, CollectionEditAction> {
  CollectionEditShell({
    required CollectionEditWriteRepository writeRepository,
    required AttachmentReadRepository attachmentReadRepository,
    required AttachmentWriteRepository attachmentWriteRepository,
    required ImagePickerPort imagePicker,
    required CollectionMediaReadRepository mediaReadRepository,
    required EffectEmitter<CollectionEditUiEffect> effectEmitter,
    required Logger logger,
  }) : _write = writeRepository,
       _mediaRead = mediaReadRepository,
       _attachmentRead = attachmentReadRepository,
       _attachmentWrite = attachmentWriteRepository,
       _picker = imagePicker,
       _effectEmitter = effectEmitter,
       _log = logger;

  final CollectionEditWriteRepository _write;
  final AttachmentReadRepository _attachmentRead;
  final AttachmentWriteRepository _attachmentWrite;
  final ImagePickerPort _picker;
  final CollectionMediaReadRepository _mediaRead;
  final EffectEmitter<CollectionEditUiEffect> _effectEmitter;
  final Logger _log;

  /// How many of the newest photos the summary row previews.
  static const int _previewCount = 4;

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
        final result = await _write.editDetails(
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

      case LoadCoverEffect(:final attachmentId):
        final result = await _attachmentRead.bytesOf(attachmentId);
        if (result.isFailure) {
          // Leave the header pointing at it; the section shows a broken-image
          // placeholder.
          _log.warning('Collection cover bytes missing for $attachmentId');
          dispatch(const CoverEditEnded());
        } else {
          dispatch(
            CoverResolved(
              attachmentId: attachmentId,
              bytes: result.getOrThrow().bytes,
            ),
          );
        }

      case LoadMediaSummaryEffect(:final collectionId):
        await _loadMediaSummary(collectionId, dispatch);

      case PickCoverEffect(:final collectionId, :final previousAttachmentId):
        await _pickCoverAndAttach(collectionId, previousAttachmentId, dispatch);

      case RemoveCoverEffect(:final collectionId, :final previousAttachmentId):
        final result = await _write.removeCover(collectionId: collectionId);
        if (result.isFailure) {
          final failure = result.error!;
          _log.severe(
            'Remove collection cover failed',
            failure.error,
            failure.stackTrace,
          );
          _failCover(dispatch);
        } else {
          await _gcAttachment(previousAttachmentId);
          dispatch(const CoverResolved());
        }
    }
  }

  /// Pick a photo → store it → point the collection at the new cover → GC the
  /// one it replaced. Any abort (cancelled pick, store/write failure) ends the
  /// busy state without changing the cover.
  Future<void> _pickCoverAndAttach(
    String collectionId,
    String? previousAttachmentId,
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
    final attached = await _write.setCover(
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

    if (previousAttachmentId != null && previousAttachmentId != attachmentId) {
      await _gcAttachment(previousAttachmentId);
    }
    dispatch(CoverResolved(attachmentId: attachmentId, bytes: picked.bytes));
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
    final previews = <Uint8List>[];
    for (final photo in media.recentPhotos(_previewCount)) {
      final bytes = await _attachmentRead.bytesOf(photo.attachmentId!);
      if (bytes.isSuccess) previews.add(bytes.getOrThrow().bytes);
    }
    dispatch(MediaSummaryLoaded(counts: media.counts, previews: previews));
  }

  /// Surface a write failure and clear the in-flight flag, leaving the
  /// collection's current cover untouched.
  void _failCover(void Function(CollectionEditAction) dispatch) {
    _effectEmitter.push(
      const CollectionEditShowMessageUiEffect(CollectionEditMessage.saveFailed),
    );
    dispatch(const CoverEditEnded());
  }

  /// Drop the replaced/removed attachment record (ref-counted blob GC happens
  /// inside the repo). A GC failure is non-fatal — the header already points away.
  Future<void> _gcAttachment(String? attachmentId) async {
    if (attachmentId == null) return;
    final result = await _attachmentWrite.delete(attachmentId);
    if (result.isFailure) {
      _log.warning('Attachment GC failed for $attachmentId: ${result.error}');
    }
  }
}
