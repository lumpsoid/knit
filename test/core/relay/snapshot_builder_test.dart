import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/domain/attachment_failure.dart';
import 'package:knit/core/attachments/domain/attachment_hashing.dart';
import 'package:knit/core/attachments/domain/attachment_models.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/relay/relay.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_read_repository.dart';
import 'package:result_dart/result_dart.dart';

/// The snapshot builder is the client half of the "app describes what the web
/// shows" contract (relay §2.6): it must translate the collection read model
/// into the exact JSON the relay renders, and collect the referenced bytes.
void main() {
  final coverBytes = Uint8List.fromList([1, 2, 3, 4]);
  final photoBytes = Uint8List.fromList([9, 8, 7]);

  late _FakeCollectionRead collectionRead;
  late _FakeAttachmentRead attachmentRead;
  late SnapshotBuilder builder;

  setUp(() {
    collectionRead = _FakeCollectionRead();
    attachmentRead = _FakeAttachmentRead({
      'cover': AttachmentBytes(bytes: coverBytes, mime: 'image/png'),
      'photo': AttachmentBytes(bytes: photoBytes, mime: 'image/jpeg'),
      'doc': AttachmentBytes(
        bytes: Uint8List.fromList([5, 5]),
        mime: 'application/pdf',
        name: 'notes.pdf',
        size: 2,
      ),
    });
    builder = SnapshotBuilder(
      collectionRead: collectionRead,
      attachmentRead: attachmentRead,
    );
  });

  test(
    'builds the header, cover, and every card kind into wire JSON',
    () async {
      collectionRead.data = const CollectionData(
        collectionId: 'c1',
        title: 'Trip',
        description: '  Notes for June ',
        coverAttachmentId: 'cover',
        cards: [
          FeedCard(id: 'k1', kind: CardKind.text, position: 'a', text: 'Hello'),
          FeedCard(
            id: 'k2',
            kind: CardKind.link,
            position: 'b',
            text: 'https://example.com',
          ),
          FeedCard(
            id: 'k3',
            kind: CardKind.image,
            position: 'c',
            text: 'a caption',
            attachmentId: 'photo',
          ),
          FeedCard(
            id: 'k4',
            kind: CardKind.file,
            position: 'd',
            attachmentId: 'doc',
            fileName: 'notes.pdf',
            fileSize: 2,
          ),
        ],
      );

      final built = (await builder.build('c1')).getOrThrow();
      final json = built.snapshot.toJson();

      expect(json['title'], 'Trip');
      expect(json['description'], 'Notes for June'); // trimmed
      expect((json['cover'] as Map)['hash'], await sha256Hex(coverBytes));
      expect((json['cover'] as Map)['mime'], 'image/png');

      final cards = json['cards'] as List;
      expect(cards, hasLength(4));

      expect(cards[0], {'id': 'k1', 'kind': 'text', 'text': 'Hello'});
      expect(cards[1], {
        'id': 'k2',
        'kind': 'link',
        'link': {'url': 'https://example.com'},
      });
      expect((cards[2] as Map)['kind'], 'image');
      expect((cards[2] as Map)['text'], 'a caption');
      expect(
        ((cards[2] as Map)['image'] as Map)['hash'],
        await sha256Hex(photoBytes),
      );
      expect((cards[3] as Map)['kind'], 'file');
      expect(((cards[3] as Map)['file'] as Map)['name'], 'notes.pdf');
      expect(((cards[3] as Map)['file'] as Map)['size'], 2);

      // The whole thing round-trips through JSON (no non-encodable values).
      expect(() => jsonEncode(json), returnsNormally);
    },
  );

  test(
    'collects one blob per referenced attachment, deduped by hash',
    () async {
      collectionRead.data = const CollectionData(
        collectionId: 'c1',
        title: 'T',
        description: null,
        coverAttachmentId: 'photo',
        cards: [
          FeedCard(
            id: 'k1',
            kind: CardKind.image,
            position: 'a',
            attachmentId: 'photo',
          ),
        ],
      );

      final built = (await builder.build('c1')).getOrThrow();

      // cover + card reference the same attachment → a single blob.
      expect(built.blobs, hasLength(1));
      expect(built.blobs.single.hash, await sha256Hex(photoBytes));
      expect(built.blobs.single.mime, 'image/jpeg');
    },
  );

  test('an empty description is omitted from the snapshot', () async {
    collectionRead.data = const CollectionData(
      collectionId: 'c1',
      title: 'T',
      description: '   ',
      coverAttachmentId: null,
      cards: [],
    );

    final json = (await builder.build('c1')).getOrThrow().snapshot.toJson();
    expect(json.containsKey('description'), isFalse);
    expect(json.containsKey('cover'), isFalse);
  });

  test('a failed collection read surfaces as a build failure', () async {
    collectionRead.failure = const CollectionLoadFailure('boom');

    final result = await builder.build('c1');
    expect(result.isFailure, isTrue);
    expect(result.error, isA<RelayBuildFailure>());
  });
}

class _FakeCollectionRead implements CollectionReadRepository {
  CollectionData? data;
  CollectionFailure? failure;

  @override
  Future<Result<CollectionData, CollectionFailure>> loadCollection(
    String id, {
    FeedWindow window = const FeedWindow.all(),
  }) async {
    if (failure != null) return Failure(failure!);
    return Ok(data!);
  }

  @override
  Future<Result<FeedPage, CollectionFailure>> loadOlderCards(
    String collectionId, {
    required FeedCursor before,
    required int limit,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<LinkOption>, CollectionFailure>> loadLinkCollections() =>
      throw UnimplementedError();

  @override
  Future<Result<List<LinkOption>, CollectionFailure>> loadCollectionCards(
    String collectionId,
  ) => throw UnimplementedError();

  @override
  Future<Result<bool, CollectionFailure>> isAttachmentReferenced(
    String attachmentId,
  ) => throw UnimplementedError();
}

class _FakeAttachmentRead implements AttachmentReadRepository {
  _FakeAttachmentRead(this._byId);

  final Map<String, AttachmentBytes> _byId;

  @override
  Future<Result<AttachmentBytes, AttachmentFailure>> bytesOf(
    String attachmentId,
  ) async {
    final a = _byId[attachmentId];
    if (a == null) return Failure(AttachmentNotFound(attachmentId));
    return Ok(a);
  }
}
