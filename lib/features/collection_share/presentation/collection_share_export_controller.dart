import 'package:knit/core/files/domain/domain.dart';
import 'package:knit/features/collection_share/domain/collection_share_export_repository.dart';
import 'package:knit/features/collection_share/presentation/collection_share_export_state.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

/// Where the share file goes: the OS share sheet or a save-file dialog.
enum ShareExportDestination { send, save }

/// How a delivery ended.
enum ShareExportOutcome { sent, saved, cancelled, failed }

/// The "Share as file" sheet's input object (docs/collection_share.md
/// "Export"): reads the size estimate, holds the media toggle, builds the
/// `.knitc` and hands it to the share sheet or a save dialog. One per sheet;
/// the sheet disposes it.
class CollectionShareExportController {
  CollectionShareExportController({
    required this.collectionId,
    required CollectionShareExportRepository exportRepository,
    required FileDeliveryPort deliveryPort,
    required FileSavePort savePort,
    Logger? logger,
  }) : _export = exportRepository,
       _delivery = deliveryPort,
       _save = savePort,
       _log = logger ?? Logger('knit.collection_share');

  final String collectionId;
  final CollectionShareExportRepository _export;
  final FileDeliveryPort _delivery;
  final FileSavePort _save;
  final Logger _log;

  final CollectionShareExportState state = CollectionShareExportState();

  Future<void> load() async {
    state.startLoading();
    (await _export.estimate(collectionId)).fold(state.showEstimate, (failure) {
      _log.severe(
        'reading the share size failed',
        failure.error,
        failure.stackTrace,
      );
      state.showLoadFailure();
    });
  }

  void setIncludeMedia(bool include) => state.setIncludeMedia(include);

  /// Build the file and deliver it to [destination]. Null while one is
  /// already running.
  Future<ShareExportOutcome?> deliver(
    ShareExportDestination destination,
  ) async {
    if (state.busy) return null;
    state.startDelivery();
    final outcome = await _deliver(destination);
    state.finishDelivery(failed: outcome == ShareExportOutcome.failed);
    return outcome;
  }

  Future<ShareExportOutcome> _deliver(
    ShareExportDestination destination,
  ) async {
    final OutgoingFile file;
    switch (await _export.export(
      collectionId,
      includeMedia: state.includeMedia && state.hasMedia,
    )) {
      case Ok(:final value):
        file = value;
      case Failure(:final error):
        _log.severe(
          'building the share file failed',
          error.error,
          error.stackTrace,
        );
        return ShareExportOutcome.failed;
    }
    switch (destination) {
      case ShareExportDestination.send:
        return (await _delivery.share(file)).fold(
          (_) => ShareExportOutcome.sent,
          (failure) {
            _log.severe(
              'sending the share file failed',
              failure.error,
              failure.stackTrace,
            );
            return ShareExportOutcome.failed;
          },
        );
      case ShareExportDestination.save:
        return (await _save.save(file)).fold(
          (saved) =>
              saved ? ShareExportOutcome.saved : ShareExportOutcome.cancelled,
          (failure) {
            _log.severe(
              'saving the share file failed',
              failure.error,
              failure.stackTrace,
            );
            return ShareExportOutcome.failed;
          },
        );
    }
  }

  void dispose() => state.dispose();
}
