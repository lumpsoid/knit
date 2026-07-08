import 'dart:typed_data';

import 'package:knit/core/attachments/domain/attachment_hashing.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/relay/domain/publication_snapshot.dart';
import 'package:knit/core/relay/domain/relay_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_read_repository.dart';
import 'package:result_dart/result_dart.dart';

/// A blob to upload before publishing — content-addressed bytes (relay §7.7).
class PendingBlob {
  const PendingBlob({required this.hash, required this.mime, required this.bytes});

  final String hash;
  final String mime;
  final Uint8List bytes;
}

/// The output of [SnapshotBuilder]: the self-contained [snapshot] to publish and
/// the deduped [blobs] its images/files reference, to upload first.
class BuiltSnapshot {
  const BuiltSnapshot({required this.snapshot, required this.blobs});

  final PublicationSnapshot snapshot;
  final List<PendingBlob> blobs;
}

/// Turns the collection read model into the relay's web [PublicationSnapshot]
/// (relay §2.6) — the mirror of the collection screen's render, resolved to
/// primitives + content-addressed blobs so the relay can serve it without ever
/// parsing an op. This is the client half of the "the app describes what the web
/// shows" contract.
class SnapshotBuilder {
  const SnapshotBuilder({
    required CollectionReadRepository collectionRead,
    required AttachmentReadRepository attachmentRead,
  }) : _collectionRead = collectionRead,
       _attachmentRead = attachmentRead;

  final CollectionReadRepository _collectionRead;
  final AttachmentReadRepository _attachmentRead;

  Future<Result<BuiltSnapshot, RelayFailure>> build(String collectionId) async {
    try {
      final loaded = await _collectionRead.loadCollection(collectionId);
      if (loaded.isFailure) return Failure(RelayBuildFailure(loaded.error!));
      final data = loaded.getOrThrow();

      // Deduped by content hash: one collection can reuse the same photo across
      // cover + cards, but the relay only needs the bytes once.
      final blobs = <String, PendingBlob>{};

      SnapshotBlob? cover;
      if (data.coverAttachmentId != null) {
        final r = await _resolve(data.coverAttachmentId!, blobs);
        if (r.isFailure) return Failure(r.error!);
        final b = r.getOrThrow();
        cover = SnapshotBlob(hash: b.hash, mime: b.mime);
      }

      final cards = <SnapshotCard>[];
      for (final c in data.cards) {
        final kind = c.kind;

        if (kind == CardKind.image && c.attachmentId != null) {
          final r = await _resolve(c.attachmentId!, blobs);
          if (r.isFailure) return Failure(r.error!);
          final b = r.getOrThrow();
          cards.add(SnapshotCard(
            id: c.id,
            kind: 'image',
            text: _clean(c.text),
            image: SnapshotBlob(hash: b.hash, mime: b.mime),
          ));
        } else if ((kind == CardKind.file || kind == CardKind.audio) &&
            c.attachmentId != null) {
          // Audio has no dedicated web widget (§2.6), so publish it as a
          // downloadable file chip alongside its bytes.
          final r = await _resolve(c.attachmentId!, blobs);
          if (r.isFailure) return Failure(r.error!);
          final b = r.getOrThrow();
          cards.add(SnapshotCard(
            id: c.id,
            kind: kind.tag,
            text: _clean(c.text),
            file: SnapshotFile(
              hash: b.hash,
              name: c.fileName ?? b.name,
              size: c.fileSize ?? b.size,
            ),
          ));
        } else if (kind == CardKind.link) {
          // Knit stores a link card's URL as its body (collection_updater.dart).
          cards.add(SnapshotCard(
            id: c.id,
            kind: 'link',
            link: SnapshotLink(url: _clean(c.text)),
          ));
        } else {
          // text, unknown, or a media card whose attachment went missing.
          cards.add(SnapshotCard(
            id: c.id,
            kind: kind == CardKind.unknown ? 'text' : kind.tag,
            text: _clean(c.text),
          ));
        }
      }

      return Ok(BuiltSnapshot(
        snapshot: PublicationSnapshot(
          title: data.title,
          description: _clean(data.description),
          cover: cover,
          cards: cards,
        ),
        blobs: blobs.values.toList(growable: false),
      ));
    } catch (e, st) {
      return Failure(RelayUnexpected(e, st));
    }
  }

  /// Resolve an attachment id to its bytes + metadata, recording the blob (by
  /// content hash) in [blobs] for upload. The hash is computed from the bytes —
  /// the same sha256 the attachment's `content_hash` carries (§7.4.8) — so the
  /// relay's `sha256(bytes) == hash` check passes.
  Future<Result<_ResolvedBlob, RelayFailure>> _resolve(
    String attachmentId,
    Map<String, PendingBlob> blobs,
  ) async {
    final res = await _attachmentRead.bytesOf(attachmentId);
    if (res.isFailure) return Failure(RelayBuildFailure(res.error!));
    final a = res.getOrThrow();
    final hash = await sha256Hex(a.bytes);
    blobs.putIfAbsent(
      hash,
      () => PendingBlob(hash: hash, mime: a.mime, bytes: a.bytes),
    );
    return Ok(_ResolvedBlob(hash: hash, mime: a.mime, name: a.name, size: a.size));
  }

  static String? _clean(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}

class _ResolvedBlob {
  const _ResolvedBlob({
    required this.hash,
    required this.mime,
    this.name,
    this.size,
  });

  final String hash;
  final String mime;
  final String? name;
  final int? size;
}
