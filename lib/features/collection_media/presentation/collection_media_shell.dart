import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/features/collection/domain/card_share_repository.dart';
import 'package:knit/features/collection/domain/link_launcher.dart';
import 'package:knit/features/collection_media/domain/collection_media_read_repository.dart';
import 'package:knit/features/collection_media/presentation/collection_media_action.dart';
import 'package:knit/features/collection_media/presentation/collection_media_effect.dart';
import 'package:knit/features/collection_media/presentation/collection_media_ui_effect.dart';

/// Imperative shell for the Collection Media page (fcis.md §6.6). Unwraps each
/// [Result] at the seam (result.md §9.3). Everything here is a read or a
/// read-only side-effect (share / open link) — nothing triggers a resync.
class CollectionMediaShell
    extends Shell<CollectionMediaEffect, CollectionMediaAction> {
  CollectionMediaShell({
    required CollectionMediaReadRepository readRepository,
    required AttachmentReadRepository attachmentReadRepository,
    required CardShareRepository shareRepository,
    required LinkLauncher linkLauncher,
    required EffectEmitter<CollectionMediaUiEffect> effectEmitter,
    required Logger logger,
  }) : _read = readRepository,
       _attachmentRead = attachmentReadRepository,
       _share = shareRepository,
       _links = linkLauncher,
       _effectEmitter = effectEmitter,
       _log = logger;

  /// Share-sheet name for a file attachment that kept no original name.
  static const String _fallbackFileName = 'knit-file';

  final CollectionMediaReadRepository _read;
  final AttachmentReadRepository _attachmentRead;
  final CardShareRepository _share;
  final LinkLauncher _links;
  final EffectEmitter<CollectionMediaUiEffect> _effectEmitter;
  final Logger _log;

  @override
  Future<void> run(
    CollectionMediaEffect effect, {
    required void Function(CollectionMediaAction) dispatch,
  }) async {
    switch (effect) {
      case LoadMediaEffect(:final collectionId):
        final result = await _read.loadMedia(collectionId);
        result.fold((media) => dispatch(MediaLoaded(media)), (failure) {
          _log.severe(
            'Collection media load failed',
            failure.error,
            failure.stackTrace,
          );
          dispatch(const MediaLoadFailed());
        });

      case LoadPhotoBytesEffect(:final attachmentIds):
        // One at a time, each landing as it resolves, so the grid fills in
        // progressively rather than waiting on the slowest blob.
        for (final id in attachmentIds) {
          final result = await _attachmentRead.bytesOf(id);
          if (result.isFailure) {
            _log.warning('Media photo bytes missing for $id');
            dispatch(PhotoBytesLoaded(attachmentId: id));
          } else {
            dispatch(
              PhotoBytesLoaded(
                attachmentId: id,
                bytes: result.getOrThrow().bytes,
              ),
            );
          }
        }

      case ShareFileEffect(
        :final attachmentId,
        :final fileName,
        :final caption,
      ):
        final result = await _attachmentRead.bytesOf(attachmentId);
        if (result.isFailure) {
          _log.warning('Share: attachment bytes missing for $attachmentId');
          return;
        }
        final file = result.getOrThrow();
        final shared = await _share.share(
          ShareableCard(
            text: caption,
            image: ShareableImage(
              bytes: file.bytes,
              mime: file.mime,
              fileName: fileName ?? file.name ?? _fallbackFileName,
            ),
          ),
        );
        shared.onFailure(
          (failure) => _log.severe(
            'Share file failed',
            failure.error,
            failure.stackTrace,
          ),
        );

      case OpenLinkEffect(:final url):
        final opened = await _links.open(url);
        opened.onFailure((failure) {
          _log.severe('Open link failed', failure.error, failure.stackTrace);
          _effectEmitter.push(
            const CollectionMediaShowMessageUiEffect(
              CollectionMediaMessage.linkOpenFailed,
            ),
          );
        });
    }
  }
}
