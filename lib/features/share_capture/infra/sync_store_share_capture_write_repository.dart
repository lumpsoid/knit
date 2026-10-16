import 'dart:io';
import 'dart:typed_data';

import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/domain/domain.dart';
import 'package:knit/core/ids/id_generator.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/share_capture/domain/share_capture_failure.dart';
import 'package:knit/features/share_capture/domain/share_capture_models.dart';
import 'package:knit/features/share_capture/domain/share_capture_write_repository.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// Reads a shared file's bytes from its local path.
typedef SharedFileBytesReader = Future<Uint8List> Function(String path);

/// [ShareCaptureWriteRepository] over the graph's [SyncStore] §6.8 write path.
/// File cards store their bytes through the shared [AttachmentWriteRepository]
/// (content-addressed blob + signed record, §7.4.8) before the card is signed.
class SyncStoreShareCaptureWriteRepository
    implements ShareCaptureWriteRepository {
  SyncStoreShareCaptureWriteRepository({
    required AppGraph graph,
    required IdGenerator ids,
    required AttachmentWriteRepository attachments,
    SharedFileBytesReader? readBytes,
  }) : _graph = graph,
       _ids = ids,
       _attachments = attachments,
       _readBytes = readBytes ?? ((path) => File(path).readAsBytes());

  final AppGraph _graph;
  final IdGenerator _ids;
  final AttachmentWriteRepository _attachments;
  final SharedFileBytesReader _readBytes;

  @override
  Future<Result<String, ShareCaptureFailure>> createCollection(
    String title,
  ) async {
    try {
      final id = _ids.newId();
      await _graph.store.create(EntityType.collection, id, {
        'title': title,
        'cover_attachment_id': null,
      });
      return Ok(id);
    } catch (e, st) {
      return Failure(ShareCaptureWriteFailure(e, st));
    }
  }

  @override
  Future<Result<int, ShareCaptureFailure>> saveCards(
    String collectionId,
    List<PlannedCard> cards,
  ) async {
    var written = 0;
    try {
      for (final card in cards) {
        final file = card.file;
        final attachmentId = file == null
            ? null
            : await _storeAttachment(card.kind, file);
        await _graph.store.create(EntityType.card, _ids.newId(), {
          'collection_id': collectionId,
          'kind': card.kind.tag,
          'text': card.text,
          // Omit the key for text/link cards, as the Collection's write does,
          // so their signed payloads stay byte-identical.
          'attachment_id': ?attachmentId,
        }, position: card.position);
        written++;
      }
      return Ok(written);
    } catch (e, st) {
      return Failure(ShareCaptureWriteFailure(e, st));
    }
  }

  Future<String> _storeAttachment(CardKind kind, SharedFile file) async {
    final bytes = await _readBytes(file.path);
    final result = await switch (kind) {
      CardKind.image => _attachments.createFromPicked(
        PickedImage(bytes: bytes, mime: file.mime),
      ),
      CardKind.audio => _attachments.createFromAudio(
        PickedAudio(bytes: bytes, mime: file.mime, name: file.name),
      ),
      _ => _attachments.createFromFile(
        PickedFile(bytes: bytes, mime: file.mime, name: file.name),
      ),
    };
    return result.fold(
      (id) => id,
      (failure) => throw StateError(
        'storing ${file.name} failed: '
        '${failure is AttachmentWriteFailure ? failure.cause : failure}',
      ),
    );
  }
}
