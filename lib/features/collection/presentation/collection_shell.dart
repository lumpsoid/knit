import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_read_repository.dart';
import 'package:knit/features/collection/domain/collection_write_repository.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_effect.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';

/// Imperative shell for the Collection screen (fcis.md §6.6). Unwraps each
/// repository [Result] at the seam (result.md §9.3) into a success/failure
/// Action; the updater never sees a Result. Every successful write re-reads the
/// feed (via [ReloadRequested]) so the projection — not the optimistic local
/// list — is the source of truth; a failed write surfaces a message and still
/// resyncs.
class CollectionShell extends Shell<CollectionEffect, CollectionAction> {
  CollectionShell({
    required CollectionReadRepository readRepository,
    required CollectionWriteRepository writeRepository,
    required AttachmentReadRepository attachmentReadRepository,
    required EffectEmitter<CollectionUiEffect> effectEmitter,
    required TimelineChannelEmitter timelineChannel,
    required Logger logger,
  })  : _read = readRepository,
        _write = writeRepository,
        _attachmentRead = attachmentReadRepository,
        _effectEmitter = effectEmitter,
        _timelineChannel = timelineChannel,
        _log = logger;

  final CollectionReadRepository _read;
  final CollectionWriteRepository _write;
  final AttachmentReadRepository _attachmentRead;
  final EffectEmitter<CollectionUiEffect> _effectEmitter;
  final TimelineChannelEmitter _timelineChannel;
  final Logger _log;

  @override
  Future<void> run(
    CollectionEffect effect, {
    required void Function(CollectionAction) dispatch,
  }) async {
    switch (effect) {
      case LoadCollectionEffect(:final collectionId):
        final result = await _read.loadCollection(collectionId);
        result.onTap(
          (data) => dispatch(CollectionLoaded(data)),
          (failure) {
            _log.severe(
                'Collection load failed', failure.error, failure.stackTrace);
            dispatch(const LoadFailed());
          },
        );

      case LoadImageBytesEffect(:final attachmentId):
        final result = await _attachmentRead.bytesOf(attachmentId);
        if (result.isFailure) {
          _log.warning('Card image bytes missing for $attachmentId');
          dispatch(ImageBytesLoaded(attachmentId, null));
        } else {
          dispatch(ImageBytesLoaded(attachmentId, result.getOrThrow().bytes));
        }

      case AddCardEffect(:final collectionId, :final kind, :final position, :final text):
        await _runWrite(
          () => _write.addCard(
            collectionId: collectionId,
            kind: kind,
            position: position,
            text: text,
          ),
          'add card',
          dispatch,
        );

      case DeleteCardEffect(:final cardId):
        await _runWrite(
          () => _write.deleteCard(cardId),
          'delete card',
          dispatch,
        );

      case ReorderCardEffect(:final cardId, :final position):
        await _runWrite(
          () => _write.reorderCard(cardId, position),
          'reorder card',
          dispatch,
        );

      case LoadLinkCollectionsEffect():
        final result = await _read.loadLinkCollections();
        result.onTap(
          (options) => dispatch(LinkCollectionsLoaded(options)),
          (failure) {
            _log.severe('Link collections load failed', failure.error,
                failure.stackTrace);
            dispatch(const LinkCollectionsLoaded([]));
          },
        );

      case LoadCollectionCardsEffect(:final collectionId):
        final result = await _read.loadCollectionCards(collectionId);
        result.onTap(
          (options) => dispatch(LinkCardsLoaded(collectionId, options)),
          (failure) {
            _log.severe(
                'Link cards load failed', failure.error, failure.stackTrace);
            dispatch(LinkCardsLoaded(collectionId, const []));
          },
        );

      case LinkEffect(:final cardId, :final targetKind, :final targetId):
        await _runWrite(
          () => _write.linkCardToTarget(
            cardId: cardId,
            targetKind: targetKind,
            targetId: targetId,
          ),
          'create link',
          dispatch,
        );

      case EditTitleEffect(:final collectionId, :final title):
        await _runWrite(
          () => _write.editTitle(collectionId, title),
          'rename collection',
          dispatch,
        );
    }
  }

  /// Run a write, then resync from the projection. On failure, surface a
  /// message and still resync (drops any optimistic local change).
  Future<void> _runWrite(
    Future<Result<String, CollectionFailure>> Function() op,
    String label,
    void Function(CollectionAction) dispatch,
  ) async {
    final result = await op();
    result.onTap(
      (_) {
        // The write changed the home timeline too (title, last-card preview,
        // count, updated-time). Nudge the Timeline to re-read via its input
        // channel (cross_feature.md §3) — it's mounted underneath this page.
        _timelineChannel.emit(const RefreshChannelEvent());
        dispatch(const ReloadRequested());
      },
      (failure) {
        _log.severe(
            'Collection $label failed', failure.error, failure.stackTrace);
        _effectEmitter.push(
          const CollectionShowMessageUiEffect(CollectionMessage.saveFailed),
        );
        dispatch(const ReloadRequested());
      },
    );
  }
}
