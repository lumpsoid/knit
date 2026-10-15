import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_media/domain/collection_media_models.dart';
import 'package:knit/features/collection_media/presentation/collection_media_action.dart';
import 'package:knit/features/collection_media/presentation/collection_media_effect.dart';
import 'package:knit/features/collection_media/presentation/collection_media_state.dart';
import 'package:knit/features/collection_media/presentation/collection_media_updater.dart';

void main() {
  const updater = CollectionMediaUpdater();

  MediaItem item(
    String id,
    CardKind kind, {
    String? text,
    String? attachmentId,
    String? fileName,
  }) => MediaItem.fromCard(
    cardId: id,
    cardKind: kind,
    capturedAt: DateTime(2026, 5, 1),
    text: text,
    attachmentId: attachmentId,
    fileName: fileName,
  )!;

  final media = CollectionMedia([
    item('p1', CardKind.image, attachmentId: 'att-p1'),
    item('p2', CardKind.image, attachmentId: 'att-p2'),
    item(
      'f1',
      CardKind.file,
      attachmentId: 'att-f1',
      fileName: 'doc.pdf',
      text: ' notes ',
    ),
    item('l1', CardKind.link, text: 'example.com'),
  ]);

  CollectionMediaState ready() => CollectionMediaState(
    status: CollectionMediaStatus.ready,
    collectionId: 'col-1',
    media: media,
  );

  test('attach resets to loading but keeps the thumbnail cache', () {
    final bytes = Uint8List(1);
    final (next, effects) = updater.update(
      ready().copyWith(photoBytes: {'att-p1': bytes}),
      const ViewAttached(collectionId: 'col-2'),
    );
    expect(next.status, CollectionMediaStatus.loading);
    expect(next.collectionId, 'col-2');
    expect(next.media.isEmpty, isTrue);
    expect(next.photoBytes['att-p1'], same(bytes));
    expect((effects!.single as LoadMediaEffect).collectionId, 'col-2');
  });

  test('loaded media fetches bytes only for uncached photos', () {
    final (next, effects) = updater.update(
      CollectionMediaState(
        collectionId: 'col-1',
        photoBytes: {'att-p1': Uint8List(1)},
      ),
      MediaLoaded(media),
    );
    expect(next.status, CollectionMediaStatus.ready);
    expect(next.media, same(media));
    expect((effects!.single as LoadPhotoBytesEffect).attachmentIds, ['att-p2']);
  });

  test('loaded media with every photo cached emits nothing', () {
    final (_, effects) = updater.update(
      CollectionMediaState(
        photoBytes: {'att-p1': Uint8List(1), 'att-p2': Uint8List(1)},
      ),
      MediaLoaded(media),
    );
    expect(effects, isNull);
  });

  test('a failed load shows the failure; retry goes back to loading', () {
    final (failed, _) = updater.update(ready(), const MediaLoadFailed());
    expect(failed.status, CollectionMediaStatus.failed);

    final (retry, effects) = updater.update(failed, const ReloadRequested());
    expect(retry.status, CollectionMediaStatus.loading);
    expect((effects!.single as LoadMediaEffect).collectionId, 'col-1');
  });

  test('a reload of a ready page keeps showing the current media', () {
    final (next, effects) = updater.update(ready(), const ReloadRequested());
    expect(next.status, CollectionMediaStatus.ready);
    expect(effects!.single, isA<LoadMediaEffect>());
  });

  test('photo bytes cache on success and mark missing on absence', () {
    final bytes = Uint8List(2);
    final (loaded, _) = updater.update(
      ready(),
      PhotoBytesLoaded(attachmentId: 'att-p1', bytes: bytes),
    );
    expect(loaded.photoBytes['att-p1'], same(bytes));

    final (missing, _) = updater.update(
      loaded,
      const PhotoBytesLoaded(attachmentId: 'att-p2'),
    );
    expect(missing.missingPhotos, {'att-p2'});
    expect(missing.photoBytes.containsKey('att-p2'), isFalse);
  });

  test('a file tap shares its attachment under its name with the caption', () {
    final (_, effects) = updater.update(
      ready(),
      const FileShareRequested('f1'),
    );
    final share = effects!.single as ShareFileEffect;
    expect(share.attachmentId, 'att-f1');
    expect(share.fileName, 'doc.pdf');
    expect(share.caption, 'notes');
  });

  test('a link tap opens its URL', () {
    final (_, effects) = updater.update(ready(), const LinkOpenRequested('l1'));
    expect((effects!.single as OpenLinkEffect).url, 'example.com');
  });

  test('taps on unknown or mismatched items are ignored', () {
    expect(
      updater.update(ready(), const FileShareRequested('nope')).$2,
      isNull,
    );
    expect(updater.update(ready(), const LinkOpenRequested('p1')).$2, isNull);
  });
}
