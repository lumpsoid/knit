import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/share_capture/domain/share_capture_failure.dart';
import 'package:knit/features/share_capture/domain/share_capture_models.dart';
import 'package:knit/features/share_capture/domain/share_capture_read_repository.dart';
import 'package:knit/features/share_capture/domain/share_capture_write_repository.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';
import 'package:knit/features/share_capture/presentation/share_capture_controller.dart';
import 'package:knit/features/share_capture/presentation/share_capture_state.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

class _FakeRead implements ShareCaptureReadRepository {
  Result<List<ShareTarget>, ShareCaptureFailure> targets = const Ok([
    ShareTarget(collectionId: 'c1', title: 'Coffee'),
    ShareTarget(collectionId: 'c2', title: 'Travel plans'),
  ]);
  Result<String?, ShareCaptureFailure> tail = const Ok('a3');

  @override
  Future<Result<List<ShareTarget>, ShareCaptureFailure>> loadTargets() async =>
      targets;

  @override
  Future<Result<String?, ShareCaptureFailure>> lastCardPosition(
    String collectionId,
  ) async => tail;
}

class _FakeWrite implements ShareCaptureWriteRepository {
  final List<String> created = [];
  final Map<String, List<PlannedCard>> saved = {};
  bool failSave = false;
  bool failCreate = false;

  @override
  Future<Result<String, ShareCaptureFailure>> createCollection(
    String title,
  ) async {
    if (failCreate) return Failure(ShareCaptureWriteFailure('boom'));
    created.add(title);
    return Ok('new-${created.length}');
  }

  @override
  Future<Result<int, ShareCaptureFailure>> saveCards(
    String collectionId,
    List<PlannedCard> cards,
  ) async {
    if (failSave) return Failure(ShareCaptureWriteFailure('boom'));
    saved[collectionId] = cards;
    return Ok(cards.length);
  }
}

class _FakeChannel implements TimelineChannelEmitter {
  final List<TimelineChannelEvent> events = [];

  @override
  void emit(TimelineChannelEvent event) => events.add(event);
}

void main() {
  late _FakeRead read;
  late _FakeWrite write;
  late _FakeChannel channel;
  late ShareCaptureController controller;

  const items = <SharedItem>[
    SharedText('https://example.com'),
    SharedFile(path: '/c/p.jpg', mime: 'image/jpeg', name: 'p.jpg'),
  ];

  setUp(() {
    read = _FakeRead();
    write = _FakeWrite();
    channel = _FakeChannel();
    controller = ShareCaptureController(
      items: items,
      readRepository: read,
      writeRepository: write,
      timelineChannel: channel,
      logger: Logger('test.share_capture'),
    );
  });

  test('load lists the targets, filter narrows them', () async {
    await controller.load();
    expect(controller.state.status, ShareCaptureStatus.ready);
    expect(controller.state.visibleTargets, hasLength(2));

    controller.filter('TRAVEL');
    expect(controller.state.visibleTargets.map((t) => t.collectionId), ['c2']);
  });

  test('a failed load shows the failure', () async {
    read.targets = Failure(ShareCaptureLoadFailure('db'));
    await controller.load();
    expect(controller.state.status, ShareCaptureStatus.failed);
  });

  test('saveTo appends the planned cards after the tail', () async {
    await controller.load();
    final saved = await controller.saveTo(controller.state.targets.first);

    expect(saved?.collectionId, 'c1');
    expect(saved?.title, 'Coffee');
    expect(saved?.cardCount, 2);
    final cards = write.saved['c1']!;
    expect(cards.map((c) => c.kind), [CardKind.link, CardKind.image]);
    expect(cards.first.position.compareTo('a3'), greaterThan(0));
    expect(channel.events.single, isA<RefreshChannelEvent>());
    expect(controller.state.saving, isFalse);
    expect(controller.state.saveFailed, isFalse);
  });

  test('saveToNew creates the collection and starts it at first()', () async {
    final saved = await controller.saveToNew('  Inbox  ');
    expect(write.created, ['Inbox']);
    expect(saved?.collectionId, 'new-1');
    expect(saved?.title, 'Inbox');
    expect(write.saved['new-1']!.first.position, 'a0');
  });

  test('saveToNew ignores a blank title', () async {
    expect(await controller.saveToNew('   '), isNull);
    expect(write.created, isEmpty);
    expect(controller.state.saveFailed, isFalse);
  });

  test('a failed write reports saveFailed and still refreshes', () async {
    write.failSave = true;
    final saved = await controller.saveTo(
      const ShareTarget(collectionId: 'c1', title: 'Coffee'),
    );
    expect(saved, isNull);
    expect(controller.state.saveFailed, isTrue);
    expect(controller.state.saving, isFalse);
    expect(channel.events, hasLength(1));
  });

  test('a failed tail read writes nothing', () async {
    read.tail = Failure(ShareCaptureLoadFailure('db'));
    final saved = await controller.saveTo(
      const ShareTarget(collectionId: 'c1', title: 'Coffee'),
    );
    expect(saved, isNull);
    expect(write.saved, isEmpty);
    expect(controller.state.saveFailed, isTrue);
  });

  test('a failed create writes no cards', () async {
    write.failCreate = true;
    expect(await controller.saveToNew('Inbox'), isNull);
    expect(write.saved, isEmpty);
    expect(controller.state.saveFailed, isTrue);
  });

  test('a second save while one runs is ignored', () async {
    final first = controller.saveTo(
      const ShareTarget(collectionId: 'c1', title: 'Coffee'),
    );
    final second = await controller.saveTo(
      const ShareTarget(collectionId: 'c2', title: 'Travel plans'),
    );
    expect(second, isNull);
    await first;
    expect(write.saved.keys, ['c1']);
  });

  tearDown(() => controller.dispose());
}
