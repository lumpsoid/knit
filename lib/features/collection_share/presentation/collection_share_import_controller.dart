import 'dart:io';
import 'dart:typed_data';

import 'package:knit/core/files/domain/domain.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection_share/domain/collection_share_failure.dart';
import 'package:knit/features/collection_share/domain/collection_share_import_repository.dart';
import 'package:knit/features/collection_share/presentation/collection_share_import_state.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

/// One import of a `.knitc` share file (docs/collection_share.md "Import"):
/// read it — picked in Settings, or opened from another app — validate it
/// into a preview, then apply it, ping the Timeline and point the Collection
/// carrier at it. One per import; the preview sheet disposes it.
class CollectionShareImportController {
  CollectionShareImportController({
    required CollectionShareImportRepository importRepository,
    required FileSourcePort sourcePort,
    required CollectionRouteArgsWriter collectionRouteArgs,
    required TimelineChannelEmitter timelineChannel,
    Future<Uint8List> Function(String path)? readFile,
    Logger? logger,
  }) : _import = importRepository,
       _source = sourcePort,
       _collectionRouteArgs = collectionRouteArgs,
       _timelineChannel = timelineChannel,
       _readFile = readFile ?? ((path) => File(path).readAsBytes()),
       _log = logger ?? Logger('knit.collection_share');

  final CollectionShareImportRepository _import;
  final FileSourcePort _source;
  final CollectionRouteArgsWriter _collectionRouteArgs;
  final TimelineChannelEmitter _timelineChannel;
  final Future<Uint8List> Function(String path) _readFile;
  final Logger _log;

  final CollectionShareImportState state = CollectionShareImportState();

  /// Let the user pick a file, then read it. False when the pick was
  /// cancelled or failed (nothing to preview).
  Future<bool> pick() async {
    switch (await _source.pick()) {
      case Ok(:final value):
        if (value == null) return false;
        await read(value);
        return true;
      case Failure(:final error):
        _log.severe(
          'picking a share file failed',
          error.error,
          error.stackTrace,
        );
        return false;
    }
  }

  /// Read the file another app handed over at [path].
  Future<void> open(String path) async {
    state.startReading();
    final Uint8List bytes;
    try {
      bytes = await _readFile(path);
    } catch (e, st) {
      _fail(
        CollectionShareCorruptFailure(e, st),
        'reading the share file failed',
      );
      return;
    }
    await read(bytes);
  }

  /// Validate [bytes] into a preview.
  Future<void> read(Uint8List bytes) async {
    state.startReading();
    (await _import.plan(bytes)).fold(
      state.showPlan,
      (failure) => _fail(failure, 'the share file was not accepted'),
    );
  }

  /// Apply the previewed file. Returns its collection id — already written to
  /// the Collection carrier, so the caller only navigates — or null.
  Future<String?> confirm() async {
    final plan = state.plan;
    if (plan == null || state.status != ShareImportStatus.ready) return null;
    state.startImporting();
    final result = await _import.apply(plan);
    // Even a partial import changed the home feed.
    _timelineChannel.emit(const RefreshChannelEvent());
    return result.fold(
      (imported) {
        _collectionRouteArgs.open(imported.collectionId);
        return imported.collectionId;
      },
      (failure) {
        _fail(failure, 'importing the share file failed');
        return null;
      },
    );
  }

  void _fail(CollectionShareFailure failure, String message) {
    _log.severe(message, failure.error, failure.stackTrace);
    state.fail(failure);
  }

  void dispose() => state.dispose();
}
