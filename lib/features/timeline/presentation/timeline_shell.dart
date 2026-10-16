import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/features/timeline/domain/timeline_pin_repository.dart';
import 'package:knit/features/timeline/domain/timeline_read_repository.dart';
import 'package:knit/features/timeline/domain/timeline_write_repository.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_effect.dart';
import 'package:knit/features/timeline/presentation/timeline_ui_effect.dart';

/// Imperative shell for Timeline (fcis.md §6.6). Unwraps the read/write Results
/// at the seam (result.md §9.3) into success/failure Actions, and pushes
/// navigation/message UiEffects.
class TimelineShell extends Shell<TimelineEffect, TimelineAction> {
  TimelineShell({
    required TimelineReadRepository readRepository,
    required TimelineWriteRepository writeRepository,
    required TimelinePinReadRepository pinReadRepository,
    required TimelinePinWriteRepository pinWriteRepository,
    required AttachmentReadRepository attachmentReadRepository,
    required EffectEmitter<TimelineUiEffect> effectEmitter,
    required Logger logger,
  }) : _read = readRepository,
       _write = writeRepository,
       _pinRead = pinReadRepository,
       _pinWrite = pinWriteRepository,
       _attachmentRead = attachmentReadRepository,
       _effectEmitter = effectEmitter,
       _log = logger;

  final TimelineReadRepository _read;
  final TimelineWriteRepository _write;
  final TimelinePinReadRepository _pinRead;
  final TimelinePinWriteRepository _pinWrite;
  final AttachmentReadRepository _attachmentRead;
  final EffectEmitter<TimelineUiEffect> _effectEmitter;
  final Logger _log;

  @override
  Future<void> run(
    TimelineEffect effect, {
    required void Function(TimelineAction) dispatch,
  }) async {
    switch (effect) {
      case LoadTimelineEffect():
        final result = await _read.loadTimeline();
        // Pins are a non-essential view preference: an unreadable pin store
        // keeps the last known pins rather than failing the whole feed.
        final pins = await _pinRead.loadPinned();
        final pinnedIds = pins.fold<Set<String>?>((ids) => ids, (failure) {
          _log.warning('Pinned collections load failed', failure.error);
          return null;
        });
        result.onTap(
          (collections) =>
              dispatch(CollectionsLoaded(collections, pinnedIds: pinnedIds)),
          (failure) {
            _log.severe(
              'Timeline load failed',
              failure.error,
              failure.stackTrace,
            );
            dispatch(const TimelineLoadFailed());
          },
        );

      case CreateCollectionEffect(:final title):
        final result = await _write.createCollection(title);
        result.onTap((id) => dispatch(CollectionCreated(id)), (failure) {
          _log.severe(
            'Create collection failed',
            failure.error,
            failure.stackTrace,
          );
          _effectEmitter.push(
            const TimelineShowMessageUiEffect(TimelineMessage.createFailed),
          );
          dispatch(const CollectionCreateFailed());
        });

      case LoadCoverBytesEffect(:final attachmentId):
        final result = await _attachmentRead.bytesOf(attachmentId);
        if (result.isFailure) {
          _log.warning('Collection cover bytes missing for $attachmentId');
          dispatch(CoverBytesLoaded(attachmentId, null));
        } else {
          dispatch(CoverBytesLoaded(attachmentId, result.getOrThrow().bytes));
        }

      case OpenCollectionEffect(:final collectionId):
        _effectEmitter.push(TimelineOpenCollectionUiEffect(collectionId));

      case DeleteCollectionEffect(:final collectionId):
        final result = await _write.deleteCollection(collectionId);
        result.onTap((id) => dispatch(CollectionDeleted(id)), (failure) {
          _log.severe(
            'Delete collection failed',
            failure.error,
            failure.stackTrace,
          );
          _effectEmitter.push(
            const TimelineShowMessageUiEffect(TimelineMessage.deleteFailed),
          );
          dispatch(const CollectionDeleteFailed());
        });

      case SetPinnedEffect(:final collectionId, :final pinned):
        final result = await _pinWrite.setPinned(collectionId, pinned: pinned);
        result.onTap((ids) => dispatch(PinsChanged(ids)), (failure) {
          _log.severe('Pin update failed', failure.error, failure.stackTrace);
          _effectEmitter.push(
            const TimelineShowMessageUiEffect(TimelineMessage.pinFailed),
          );
          dispatch(const PinUpdateFailed());
        });
    }
  }
}
