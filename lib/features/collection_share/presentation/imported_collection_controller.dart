import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection_share/domain/collection_copy_repositories.dart';
import 'package:knit/features/collection_share/domain/collection_share_failure.dart';
import 'package:knit/features/collection_share/domain/local_archive_repository.dart';
import 'package:knit/features/collection_share/presentation/imported_collection_state.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

/// What the Collection ⋮ sheet does with an imported collection
/// (docs/collection_share.md): **Save a copy** (§10.5 fork) and **Remove**
/// (local purge). App-wide; the Collection page calls it.
class ImportedCollectionController {
  ImportedCollectionController({
    required CollectionForkRepository forkRepository,
    required CollectionPurgeRepository purgeRepository,
    required LocalArchiveWriteRepository localArchive,
    required CollectionRouteArgsWriter collectionRouteArgs,
    required TimelineChannelEmitter timelineChannel,
    Logger? logger,
  }) : _fork = forkRepository,
       _purge = purgeRepository,
       _localArchive = localArchive,
       _collectionRouteArgs = collectionRouteArgs,
       _timelineChannel = timelineChannel,
       _log = logger ?? Logger('knit.collection_share');

  final CollectionForkRepository _fork;
  final CollectionPurgeRepository _purge;
  final LocalArchiveWriteRepository _localArchive;
  final CollectionRouteArgsWriter _collectionRouteArgs;
  final TimelineChannelEmitter _timelineChannel;
  final Logger _log;

  final ImportedCollectionState state = ImportedCollectionState();

  /// Save an own, editable copy of [collectionId]. Returns the copy's id —
  /// already written to the Collection carrier, so the caller only
  /// navigates — or null on failure or while busy.
  Future<String?> saveCopy(String collectionId) async {
    if (state.busy) return null;
    state.start();
    final result = await _fork.fork(collectionId);
    state.finish(failed: result.isFailure);
    return result.fold(
      (copyId) {
        _timelineChannel.emit(const RefreshChannelEvent());
        _collectionRouteArgs.open(copyId);
        return copyId;
      },
      (failure) {
        _logFailure('saving a copy failed', failure);
        return null;
      },
    );
  }

  /// Remove the imported [collectionId] from this device. Its local archive
  /// flag goes too, and the Timeline drops the row and its pin.
  Future<bool> remove(String collectionId) async {
    if (state.busy) return false;
    state.start();
    final result = await _purge.purge(collectionId);
    state.finish(failed: result.isFailure);
    switch (result) {
      case Ok():
        (await _localArchive.setArchived(
          collectionId,
          archived: false,
        )).onFailure((f) => _logFailure('clearing the archive flag failed', f));
        _timelineChannel.emit(CollectionDeletedChannelEvent(collectionId));
        return true;
      case Failure(:final error):
        _logFailure('removing the collection failed', error);
        return false;
    }
  }

  void _logFailure(String message, CollectionShareFailure failure) =>
      _log.severe(message, failure.error, failure.stackTrace);
}
