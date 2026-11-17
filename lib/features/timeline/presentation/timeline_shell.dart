import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:knit/features/collection_details/domain/collection_details.dart';
import 'package:knit/features/collection_details/presentation/collection_details_controller.dart';
import 'package:knit/features/collection_share/domain/local_archive_repository.dart';
import 'package:knit/features/timeline/domain/timeline_hub_read_repository.dart';
import 'package:knit/features/timeline/domain/timeline_order.dart';
import 'package:knit/features/timeline/domain/timeline_order_repository.dart';
import 'package:knit/features/timeline/domain/timeline_owner_read_repository.dart';
import 'package:knit/features/timeline/domain/timeline_pin_repository.dart';
import 'package:knit/features/timeline/domain/timeline_read_repository.dart';
import 'package:knit/features/timeline/domain/timeline_write_repository.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_effect.dart';
import 'package:knit/features/timeline/presentation/timeline_ui_effect.dart';
import 'package:knit/sync/sync.dart';

/// Imperative shell for Timeline (fcis.md §6.6). Unwraps the read/write Results
/// at the seam (result.md §9.3) into success/failure Actions, and pushes
/// navigation/message UiEffects. Each home-feed read also refreshes the shared
/// collection details, which the page reads titles and covers from.
class TimelineShell extends Shell<TimelineEffect, TimelineAction> {
  TimelineShell({
    required TimelineReadRepository readRepository,
    required TimelineWriteRepository writeRepository,
    required TimelinePinReadRepository pinReadRepository,
    required TimelinePinWriteRepository pinWriteRepository,
    required TimelineOrderReadRepository orderReadRepository,
    required TimelineOrderWriteRepository orderWriteRepository,
    required TimelineOwnerReadRepository ownerReadRepository,
    required TimelineHubReadRepository hubReadRepository,
    required LocalArchiveReadRepository localArchiveReadRepository,
    required LocalArchiveWriteRepository localArchiveWriteRepository,
    required AttachmentImageCache imageCache,
    required CollectionDetailsController collectionDetails,
    required EffectEmitter<TimelineUiEffect> effectEmitter,
    required Logger logger,
  }) : _read = readRepository,
       _write = writeRepository,
       _pinRead = pinReadRepository,
       _pinWrite = pinWriteRepository,
       _orderRead = orderReadRepository,
       _orderWrite = orderWriteRepository,
       _ownerRead = ownerReadRepository,
       _hubRead = hubReadRepository,
       _localArchiveRead = localArchiveReadRepository,
       _localArchiveWrite = localArchiveWriteRepository,
       _images = imageCache,
       _details = collectionDetails,
       _effectEmitter = effectEmitter,
       _log = logger;

  final TimelineReadRepository _read;
  final TimelineWriteRepository _write;
  final TimelinePinReadRepository _pinRead;
  final TimelinePinWriteRepository _pinWrite;
  final TimelineOrderReadRepository _orderRead;
  final TimelineOrderWriteRepository _orderWrite;
  final TimelineOwnerReadRepository _ownerRead;
  final TimelineHubReadRepository _hubRead;
  final LocalArchiveReadRepository _localArchiveRead;
  final LocalArchiveWriteRepository _localArchiveWrite;
  final AttachmentImageCache _images;
  final CollectionDetailsController _details;
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
        // The manual order is a view preference too: unreadable keeps the last.
        final order = (await _orderRead.loadOrder()).fold<TimelineOrder?>(
          (order) => order,
          (failure) {
            _log.warning('Home order load failed', failure.error);
            return null;
          },
        );
        // Like pins, the local archive flag is a view preference: an
        // unreadable store keeps the last known set.
        final localArchived = (await _localArchiveRead.loadArchived())
            .fold<Set<String>?>((ids) => ids, (failure) {
              _log.warning('Local archive load failed', failure.error);
              return null;
            });
        final owners = switch (result) {
          Ok(value: final collections) =>
            (await _ownerRead.loadImportedOwners(collections)).fold(
              (owners) => owners,
              (failure) {
                _log.warning('Collection owners load failed', failure.error);
                return const <String, String>{};
              },
            ),
          Failure() => const <String, String>{},
        };
        // The "in:" line is a hint: a failed read shows rows without it.
        final hubs = switch (result) {
          Ok(value: final collections) =>
            (await _hubRead.loadHubs(collections)).fold((hubs) => hubs, (
              failure,
            ) {
              _log.warning('Collection hubs load failed', failure.error);
              return const <String, List<CollectionHub>>{};
            }),
          Failure() => const <String, List<CollectionHub>>{},
        };
        result.onTap(
          (collections) {
            _details.rememberAll([
              for (final c in collections)
                CollectionDetails(
                  collectionId: c.collectionId,
                  title: c.title,
                  description: c.description,
                  coverAttachmentId: c.coverAttachmentId,
                ),
            ]);
            dispatch(
              CollectionsLoaded(
                collections,
                pinnedIds: pinnedIds,
                importedOwners: owners,
                localArchivedIds: localArchived,
                hubs: hubs,
                order: order,
              ),
            );
          },
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

      case ShowCoversEffect(:final attachmentIds):
        await _images.show(this, attachmentIds);

      case ReleaseCoversEffect():
        _images.release(this);

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

      case SetArchivedEffect(:final collectionId, :final archived):
        final result = await _write.setArchived(
          collectionId,
          archived: archived,
        );
        result.onTap(
          (id) => dispatch(CollectionArchiveChanged(id, archived: archived)),
          (failure) {
            _log.severe(
              'Archive update failed',
              failure.error,
              failure.stackTrace,
            );
            _effectEmitter.push(
              const TimelineShowMessageUiEffect(TimelineMessage.archiveFailed),
            );
            dispatch(const ArchiveUpdateFailed());
          },
        );

      case SetLocalArchivedEffect(:final collectionId, :final archived):
        final result = await _localArchiveWrite.setArchived(
          collectionId,
          archived: archived,
        );
        result.onTap(
          (_) => dispatch(
            CollectionArchiveChanged(collectionId, archived: archived),
          ),
          (failure) {
            _log.severe(
              'Local archive update failed',
              failure.error,
              failure.stackTrace,
            );
            _effectEmitter.push(
              const TimelineShowMessageUiEffect(TimelineMessage.archiveFailed),
            );
            dispatch(const ArchiveUpdateFailed());
          },
        );

      case SetPinnedEffect(:final collectionId, :final pinned):
        final result = await _pinWrite.setPinned(collectionId, pinned: pinned);
        result.onTap((ids) => dispatch(PinsChanged(ids)), (failure) {
          _log.severe('Pin update failed', failure.error, failure.stackTrace);
          _effectEmitter.push(
            const TimelineShowMessageUiEffect(TimelineMessage.pinFailed),
          );
          dispatch(const PinUpdateFailed());
        });

      case SaveOrderEffect(:final order):
        final result = await _orderWrite.saveOrder(order);
        result.onTap((order) => dispatch(OrderChanged(order)), (failure) {
          _log.severe(
            'Home order update failed',
            failure.error,
            failure.stackTrace,
          );
          dispatch(const OrderUpdateFailed());
        });
    }
  }
}
