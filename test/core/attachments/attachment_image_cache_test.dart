import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/domain/attachment_failure.dart';
import 'package:knit/core/attachments/domain/attachment_models.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:result_dart/result_dart.dart';

/// Serves [blobs] by id and counts every read; an id not in [blobs] is missing.
class _FakeRead implements AttachmentReadRepository {
  final Map<String, Uint8List> blobs = {};
  final Map<String, int> reads = {};
  Completer<void>? gate;

  @override
  Future<Result<AttachmentBytes, AttachmentFailure>> bytesOf(
    String attachmentId,
  ) async {
    reads[attachmentId] = (reads[attachmentId] ?? 0) + 1;
    await gate?.future;
    final bytes = blobs[attachmentId];
    if (bytes == null) {
      return Failure(AttachmentNotFound(attachmentId));
    }
    return Ok(AttachmentBytes(bytes: bytes, mime: 'image/png'));
  }
}

void main() {
  late _FakeRead read;
  late AttachmentImageCache cache;
  final ownerA = Object();
  final ownerB = Object();

  Uint8List blob(int size) => Uint8List(size);

  setUp(() {
    read = _FakeRead()
      ..blobs.addAll({'a': blob(10), 'b': blob(10), 'c': blob(10)});
    cache = AttachmentImageCache(
      attachmentReadRepository: read,
      idleBudgetBytes: 15,
    );
  });

  test('show loads the images and notifies', () async {
    var notified = 0;
    cache.state.addListener(() => notified++);
    await cache.show(ownerA, ['a', 'b']);
    expect(cache.state.of('a'), isNotNull);
    expect(cache.state.of('b'), isNotNull);
    expect(notified, 2);
  });

  test('an image two owners show is read once', () async {
    await cache.show(ownerA, ['a']);
    await cache.show(ownerB, ['a']);
    expect(read.reads['a'], 1);
  });

  test('concurrent shows of an in-flight image share one read', () async {
    read.gate = Completer<void>();
    final first = cache.show(ownerA, ['a']);
    final second = cache.show(ownerB, ['a']);
    read.gate!.complete();
    await Future.wait([first, second]);
    expect(read.reads['a'], 1);
  });

  test('a missing blob is flagged and retried on the next show', () async {
    await cache.show(ownerA, ['gone']);
    expect(cache.state.of('gone'), isNull);
    expect(cache.state.isMissing('gone'), isTrue);

    read.blobs['gone'] = blob(1);
    await cache.show(ownerA, ['gone']);
    expect(cache.state.of('gone'), isNotNull);
    expect(cache.state.isMissing('gone'), isFalse);
  });

  test('shown images are never evicted, however large', () async {
    await cache.show(ownerA, ['a', 'b', 'c']);
    expect(['a', 'b', 'c'].every((id) => cache.state.of(id) != null), isTrue);
  });

  test('released images stay idle within the budget, oldest evicted', () async {
    await cache.show(ownerA, ['a']);
    await cache.show(ownerB, ['b']);
    cache.release(ownerA); // idle: a (10)
    expect(cache.state.of('a'), isNotNull);
    cache.release(ownerB); // idle: a, b (20 > 15) → a goes
    expect(cache.state.of('a'), isNull);
    expect(cache.state.of('b'), isNotNull);
  });

  test('an image still shown by another owner survives a release', () async {
    await cache.show(ownerA, ['a', 'b']);
    await cache.show(ownerB, ['a']);
    cache.release(ownerA);
    await cache.show(ownerA, ['c']); // b idle; a still shown by B
    cache.release(ownerA); // idle: b, c (20 > 15) → b goes
    expect(cache.state.of('a'), isNotNull);
    expect(cache.state.of('b'), isNull);
  });

  test('re-showing an idle image is a hit, not a re-read', () async {
    await cache.show(ownerA, ['a']);
    cache.release(ownerA);
    await cache.show(ownerA, ['a']);
    expect(read.reads['a'], 1);
  });

  test('put seeds bytes so showing them needs no read', () async {
    cache.put('new', blob(3));
    await cache.show(ownerA, ['new']);
    expect(cache.state.of('new'), isNotNull);
    expect(read.reads.containsKey('new'), isFalse);
  });
}
