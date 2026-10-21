import 'dart:typed_data';

import 'package:effect_emitter/effect_emitter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/core/recents/recents.dart';
import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/card_edit/domain/card_edit_links_read_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_timeline_preview_read_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_write_repository.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_shell.dart';
import 'package:knit/features/card_edit/presentation/card_edit_ui_effect.dart';
import 'package:knit/features/card_links/domain/card_links_write_repository.dart';
import 'package:knit/features/card_links/domain/link_targets_read_repository.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

/// Stands in for a port the optimize flow never calls.
mixin _Unused {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedLinksRead with _Unused implements CardEditLinksReadRepository {}

class _UnusedPreview
    with _Unused
    implements CardEditTimelinePreviewReadRepository {}

class _UnusedTargets with _Unused implements LinkTargetsReadRepository {}

class _UnusedLinksWrite with _Unused implements CardLinksWriteRepository {}

class _ImagePicker with _Unused implements ImagePickerPort {
  List<PickedImage> next = const [];

  @override
  Future<List<PickedImage>> pickImages() async => next;
}

class _UnusedFilePicker with _Unused implements FilePickerPort {}

class _Channel implements TimelineChannelEmitter {
  @override
  void emit(TimelineChannelEvent event) {}
}

class _Write with _Unused implements CardEditWriteRepository {
  final attached = <(String, String, CardKind)>[];
  final images = <(String, List<String>)>[];
  final removed = <String>[];

  @override
  Future<Result<String, CardEditFailure>> setCardImages({
    required String cardId,
    required List<String> attachmentIds,
  }) async {
    images.add((cardId, attachmentIds));
    return Ok(cardId);
  }

  @override
  Future<Result<String, CardEditFailure>> removeCardAttachment({
    required String cardId,
  }) async {
    removed.add(cardId);
    return Ok(cardId);
  }

  @override
  Future<Result<String, CardEditFailure>> setCardAttachment({
    required String cardId,
    required String attachmentId,
    required CardKind kind,
  }) async {
    attached.add((cardId, attachmentId, kind));
    return Ok(cardId);
  }
}

class _AttachmentRead implements AttachmentReadRepository {
  final bytes = <String, AttachmentBytes>{};

  @override
  Future<Result<AttachmentBytes, AttachmentFailure>> bytesOf(
    String attachmentId,
  ) async {
    final found = bytes[attachmentId];
    return found == null
        ? Failure(AttachmentNotFound(attachmentId))
        : Ok(found);
  }
}

class _AttachmentWrite with _Unused implements AttachmentWriteRepository {
  final created = <PickedImage>[];
  final deleted = <String>[];

  @override
  Future<Result<String, AttachmentFailure>> createFromPicked(
    PickedImage image,
  ) async {
    created.add(image);
    return Ok('a-new-${created.length}');
  }

  @override
  Future<Result<String, AttachmentFailure>> delete(String attachmentId) async {
    deleted.add(attachmentId);
    return Ok(attachmentId);
  }
}

class _Optimizer implements ImageOptimizerPort {
  PickedImage? next;
  PickedImage? seen;

  /// Per-input results by first byte, overriding [next].
  final byFirstByte = <int, PickedImage?>{};

  @override
  Future<PickedImage?> optimize(PickedImage image) async {
    seen = image;
    final key = image.bytes.first;
    return byFirstByte.containsKey(key) ? byFirstByte[key] : next;
  }
}

void main() {
  final original = Uint8List.fromList(List.filled(100, 7));
  final smaller = PickedImage(
    bytes: Uint8List.fromList([1, 2]),
    mime: 'image/jpeg',
  );

  late _Write write;
  late _AttachmentRead read;
  late _AttachmentWrite attachmentWrite;
  late _Optimizer optimizer;
  late _ImagePicker picker;
  late AttachmentImageCache images;
  late List<CardEditUiEffect> uiEffects;
  late List<CardEditAction> dispatched;
  late CardEditShell shell;

  setUp(() {
    write = _Write();
    read = _AttachmentRead()
      ..bytes['a1'] = AttachmentBytes(bytes: original, mime: 'image/png');
    attachmentWrite = _AttachmentWrite();
    optimizer = _Optimizer();
    picker = _ImagePicker();
    images = AttachmentImageCache(attachmentReadRepository: read);
    uiEffects = [];
    dispatched = [];
    final emitter = EffectEmitter<CardEditUiEffect>()..attach(uiEffects.add);
    shell = CardEditShell(
      writeRepository: write,
      linksReadRepository: _UnusedLinksRead(),
      timelinePreviewRepository: _UnusedPreview(),
      timelineChannel: _Channel(),
      cardLinks: CardLinksController(
        readRepository: _UnusedTargets(),
        writeRepository: _UnusedLinksWrite(),
        recentsReadRepository: InMemoryRecentTargetsRepository(),
        recentsWriteRepository: InMemoryRecentTargetsRepository(),
      ),
      imageCache: images,
      attachmentReadRepository: read,
      attachmentWriteRepository: attachmentWrite,
      imagePicker: picker,
      imageOptimizer: optimizer,
      filePicker: _UnusedFilePicker(),
      effectEmitter: emitter,
      logger: Logger('test.card_edit'),
    );
  });

  Future<void> optimize([List<String> ids = const ['a1']]) => shell.run(
    OptimizeImageEffect(cardId: 'c1', attachmentIds: ids),
    dispatch: dispatched.add,
  );

  test('swaps the image for the smaller copy and drops the original', () async {
    optimizer.next = smaller;
    await optimize();

    expect(optimizer.seen!.bytes, original);
    expect(optimizer.seen!.mime, 'image/png');
    expect(attachmentWrite.created.single, same(smaller));
    expect(write.images.single.$1, 'c1');
    expect(write.images.single.$2, ['a-new-1']);
    expect(attachmentWrite.deleted, ['a1']);
    expect(images.state.of('a-new-1'), smaller.bytes);
    final resolved = dispatched.single as AttachmentResolved;
    expect(resolved.attachmentId, 'a-new-1');
    final saved = uiEffects.single as CardEditImageOptimizedUiEffect;
    expect((saved.fromBytes, saved.toBytes), (100, 2));
  });

  test('nothing to gain says so and leaves the card alone', () async {
    optimizer.next = null;
    await optimize();

    expect(attachmentWrite.created, isEmpty);
    expect(write.images, isEmpty);
    expect(attachmentWrite.deleted, isEmpty);
    expect(dispatched.single, isA<AttachmentEditEnded>());
    expect(
      (uiEffects.single as CardEditShowMessageUiEffect).message,
      CardEditMessage.imageNotSmaller,
    );
  });

  test('an unreadable image fails the edit without writing', () async {
    read.bytes.clear();
    await optimize();

    expect(optimizer.seen, isNull);
    expect(write.images, isEmpty);
    expect(dispatched.single, isA<AttachmentEditEnded>());
    expect(
      (uiEffects.single as CardEditShowMessageUiEffect).message,
      CardEditMessage.saveFailed,
    );
  });

  test('several images: each that shrinks is swapped, in place', () async {
    final second = Uint8List.fromList(List.filled(50, 9));
    read.bytes['a2'] = AttachmentBytes(bytes: second, mime: 'image/png');
    optimizer.byFirstByte[7] = null; // a1: nothing to gain
    optimizer.byFirstByte[9] = smaller; // a2 shrinks
    await optimize(['a1', 'a2']);

    expect(write.images.single.$1, 'c1');
    expect(write.images.single.$2, ['a1', 'a-new-1']);
    expect(attachmentWrite.deleted, ['a2']);
    final resolved = dispatched.single as AttachmentResolved;
    expect(resolved.attachmentId, 'a1');
    expect(resolved.moreAttachmentIds, ['a-new-1']);
    final saved = uiEffects.single as CardEditImageOptimizedUiEffect;
    expect((saved.fromBytes, saved.toBytes), (50, 2));
  });

  group('add / remove photos', () {
    final p1 = PickedImage(bytes: Uint8List.fromList([1]), mime: 'image/png');
    final p2 = PickedImage(bytes: Uint8List.fromList([2]), mime: 'image/png');

    test('picked photos join the card\'s images, in order', () async {
      picker.next = [p1, p2];
      await shell.run(
        const PickImageEffect(cardId: 'c1', keptImageIds: ['a1']),
        dispatch: dispatched.add,
      );
      expect(write.images.single.$1, 'c1');
      expect(write.images.single.$2, ['a1', 'a-new-1', 'a-new-2']);
      expect(attachmentWrite.deleted, isEmpty);
      final resolved = dispatched.single as AttachmentResolved;
      expect(resolved.kind, CardKind.image);
      expect(resolved.moreAttachmentIds, ['a-new-1', 'a-new-2']);
    });

    test('photos on a file card take its place and drop the file', () async {
      picker.next = [p1];
      await shell.run(
        const PickImageEffect(cardId: 'c1', replacedAttachmentId: 'f1'),
        dispatch: dispatched.add,
      );
      expect(write.images.single.$1, 'c1');
      expect(write.images.single.$2, ['a-new-1']);
      expect(attachmentWrite.deleted, ['f1']);
    });

    test('a cancelled pick changes nothing', () async {
      await shell.run(
        const PickImageEffect(cardId: 'c1', keptImageIds: ['a1']),
        dispatch: dispatched.add,
      );
      expect(write.images, isEmpty);
      expect(dispatched.single, isA<AttachmentEditEnded>());
    });

    test('removing one image keeps the rest and drops it', () async {
      await shell.run(
        const RemoveImageEffect(
          cardId: 'c1',
          remainingIds: ['a1', 'a3'],
          removedId: 'a2',
        ),
        dispatch: dispatched.add,
      );
      expect(write.images.single.$1, 'c1');
      expect(write.images.single.$2, ['a1', 'a3']);
      expect(attachmentWrite.deleted, ['a2']);
      final resolved = dispatched.single as AttachmentResolved;
      expect(resolved.attachmentId, 'a1');
      expect(resolved.moreAttachmentIds, ['a3']);
    });

    test('removing the last image leaves a text card', () async {
      await shell.run(
        const RemoveImageEffect(
          cardId: 'c1',
          remainingIds: [],
          removedId: 'a1',
        ),
        dispatch: dispatched.add,
      );
      expect(write.removed, ['c1']);
      expect(attachmentWrite.deleted, ['a1']);
      final resolved = dispatched.single as AttachmentResolved;
      expect(resolved.attachmentId, isNull);
      expect(resolved.kind, isNull);
    });
  });
}
