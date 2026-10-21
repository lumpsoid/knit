import 'dart:typed_data';

import 'package:effect_emitter/effect_emitter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/attachments.dart';
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

class _UnusedImagePicker with _Unused implements ImagePickerPort {}

class _UnusedFilePicker with _Unused implements FilePickerPort {}

class _Channel implements TimelineChannelEmitter {
  @override
  void emit(TimelineChannelEvent event) {}
}

class _Write with _Unused implements CardEditWriteRepository {
  final attached = <(String, String, CardKind)>[];

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

  @override
  Future<PickedImage?> optimize(PickedImage image) async {
    seen = image;
    return next;
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
      ),
      imageCache: images,
      attachmentReadRepository: read,
      attachmentWriteRepository: attachmentWrite,
      imagePicker: _UnusedImagePicker(),
      imageOptimizer: optimizer,
      filePicker: _UnusedFilePicker(),
      effectEmitter: emitter,
      logger: Logger('test.card_edit'),
    );
  });

  Future<void> optimize() => shell.run(
    const OptimizeImageEffect(cardId: 'c1', attachmentId: 'a1'),
    dispatch: dispatched.add,
  );

  test('swaps the image for the smaller copy and drops the original', () async {
    optimizer.next = smaller;
    await optimize();

    expect(optimizer.seen!.bytes, original);
    expect(optimizer.seen!.mime, 'image/png');
    expect(attachmentWrite.created.single, same(smaller));
    expect(write.attached.single, ('c1', 'a-new-1', CardKind.image));
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
    expect(write.attached, isEmpty);
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
    expect(write.attached, isEmpty);
    expect(dispatched.single, isA<AttachmentEditEnded>());
    expect(
      (uiEffects.single as CardEditShowMessageUiEffect).message,
      CardEditMessage.saveFailed,
    );
  });
}
