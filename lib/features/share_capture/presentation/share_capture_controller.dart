import 'package:knit/features/share_capture/domain/share_capture_models.dart';
import 'package:knit/features/share_capture/domain/share_capture_planner.dart';
import 'package:knit/features/share_capture/domain/share_capture_read_repository.dart';
import 'package:knit/features/share_capture/domain/share_capture_write_repository.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';
import 'package:knit/features/share_capture/presentation/share_capture_state.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

/// The capture screen's input object (§4.7): lists the collections to save
/// the shared [items] into, and saves them — into an existing collection or a
/// new one — as cards planned by the pure [ShareCapturePlanner]. One per page
/// instance; the page disposes it.
class ShareCaptureController {
  ShareCaptureController({
    required this.items,
    required ShareCaptureReadRepository readRepository,
    required ShareCaptureWriteRepository writeRepository,
    required TimelineChannelEmitter timelineChannel,
    ShareCapturePlanner planner = const ShareCapturePlanner(),
    Logger? logger,
  }) : _read = readRepository,
       _write = writeRepository,
       _timelineChannel = timelineChannel,
       _planner = planner,
       _log = logger ?? Logger('knit.share_capture');

  /// What was shared, in the order the sender gave it.
  final List<SharedItem> items;

  final ShareCaptureReadRepository _read;
  final ShareCaptureWriteRepository _write;
  final TimelineChannelEmitter _timelineChannel;
  final ShareCapturePlanner _planner;
  final Logger _log;

  final ShareCaptureState state = ShareCaptureState();

  Future<void> load() async {
    state.startLoading();
    final result = await _read.loadTargets();
    result.fold(state.showTargets, (failure) {
      _log.severe(
        'loading collections failed',
        failure.error,
        failure.stackTrace,
      );
      state.showLoadFailure();
    });
  }

  void filter(String query) => state.setQuery(query);

  /// Append the shared items to [target]. Returns what was saved, or null when
  /// the save failed (see [ShareCaptureState.saveFailed]) or one is running.
  Future<ShareCaptureSaved?> saveTo(ShareTarget target) async {
    if (state.saving) return null;
    state.startSaving();
    switch (await _read.lastCardPosition(target.collectionId)) {
      case Ok(:final value):
        return _save(target, value);
      case Failure(:final error):
        _log.severe(
          'reading the collection tail failed',
          error.error,
          error.stackTrace,
        );
        state.finishSaving(failed: true);
        return null;
    }
  }

  /// Create a collection titled [title] and save the shared items into it.
  Future<ShareCaptureSaved?> saveToNew(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || state.saving) return null;
    state.startSaving();
    switch (await _write.createCollection(trimmed)) {
      case Ok(:final value):
        return _save(ShareTarget(collectionId: value, title: trimmed), null);
      case Failure(:final error):
        _log.severe(
          'creating the collection failed',
          error.error,
          error.stackTrace,
        );
        state.finishSaving(failed: true);
        return null;
    }
  }

  Future<ShareCaptureSaved?> _save(
    ShareTarget target,
    String? lastPosition,
  ) async {
    final cards = _planner.plan(items, lastPosition: lastPosition);
    final result = await _write.saveCards(target.collectionId, cards);
    // Even a failed save may have written some cards (or the new collection).
    _timelineChannel.emit(const RefreshChannelEvent());
    return result.fold(
      (count) {
        state.finishSaving(failed: false);
        return ShareCaptureSaved(
          collectionId: target.collectionId,
          title: target.title,
          cardCount: count,
        );
      },
      (failure) {
        _log.severe(
          'saving the shared items failed',
          failure.error,
          failure.stackTrace,
        );
        state.finishSaving(failed: true);
        return null;
      },
    );
  }

  void dispose() => state.dispose();
}
