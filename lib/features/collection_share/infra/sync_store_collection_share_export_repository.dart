import 'dart:convert';
import 'dart:typed_data';

import 'package:knit/app/app_graph.dart';
import 'package:knit/core/files/domain/outgoing_file.dart';
import 'package:knit/features/collection_share/domain/collection_share_export_repository.dart';
import 'package:knit/features/collection_share/domain/collection_share_failure.dart';
import 'package:knit/features/collection_share/domain/collection_share_models.dart';
import 'package:knit/features/collection_share/infra/collection_share_codec.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CollectionShareExportRepository] over the graph's [SyncStore] share set
/// and blob store. Never re-signs: the ops ship as they sit in the log. A
/// missing blob is skipped, so its card shows "media not included" there.
class SyncStoreCollectionShareExportRepository
    implements CollectionShareExportRepository {
  SyncStoreCollectionShareExportRepository({
    required AppGraph graph,
    CollectionShareCodec codec = const CollectionShareCodec(),
    DateTime Function() now = DateTime.now,
  }) : _graph = graph,
       _codec = codec,
       _now = now;

  final AppGraph _graph;
  final CollectionShareCodec _codec;
  final DateTime Function() _now;

  /// Characters no file system takes in a name.
  static final RegExp _unsafeName = RegExp(r'[\\/:*?"<>|\x00-\x1f]');

  @override
  Future<Result<CollectionShareEstimate, CollectionShareFailure>> estimate(
    String collectionId,
  ) async {
    try {
      final set = await _graph.store.shareSet(collectionId);
      var mediaBytes = 0;
      for (final MapEntry(key: hash, value: size) in set.media.entries) {
        mediaBytes +=
            size ?? (await _graph.blobStore.readBytes(hash))?.length ?? 0;
      }
      return Ok(
        CollectionShareEstimate(
          title: _titleOf(set),
          cardCount: set.liveCardCount,
          baseBytes: set.ops.fold(
            0,
            (sum, op) => sum + utf8.encode(jsonEncode(op.toDb())).length,
          ),
          mediaBytes: mediaBytes,
          mediaCount: set.media.length,
        ),
      );
    } catch (e, st) {
      return Failure(CollectionShareExportFailure(e, st));
    }
  }

  @override
  Future<Result<OutgoingFile, CollectionShareFailure>> export(
    String collectionId, {
    required bool includeMedia,
  }) async {
    try {
      final set = await _graph.store.shareSet(collectionId);
      final blobs = <String, Uint8List>{};
      if (includeMedia) {
        for (final hash in set.media.keys) {
          final bytes = await _graph.blobStore.readBytes(hash);
          if (bytes != null) blobs[hash] = bytes;
        }
      }
      final title = _titleOf(set);
      final bytes = _codec.encode(
        CollectionShareBundle(
          manifest: CollectionShareManifest(
            createdAtMs: _now().millisecondsSinceEpoch,
            collectionId: collectionId,
            owner: set.collection.createdBy,
            title: title,
            cardCount: set.liveCardCount,
            opCount: set.ops.length,
            blobCount: blobs.length,
            mediaIncluded: includeMedia,
          ),
          ops: set.ops,
          blobs: blobs,
        ),
      );
      return Ok(
        OutgoingFile(
          bytes: bytes,
          fileName: '${_fileStem(title)}.$kCollectionShareExtension',
          mimeType: kCollectionShareMime,
          extension: kCollectionShareExtension,
        ),
      );
    } catch (e, st) {
      return Failure(CollectionShareExportFailure(e, st));
    }
  }

  static String _titleOf(ShareSet set) =>
      (set.collection.content[CollectionSchema.colTitle] as String?)?.trim() ??
      '';

  static String _fileStem(String title) {
    final stem = title.replaceAll(_unsafeName, ' ').trim();
    return stem.isEmpty ? 'collection' : stem;
  }
}
