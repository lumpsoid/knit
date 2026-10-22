import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/recents/recents.dart';
import 'package:knit/features/card_links/domain/card_links_failure.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/card_links/domain/card_links_write_repository.dart';
import 'package:knit/features/card_links/domain/link_targets_read_repository.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:result_dart/result_dart.dart';

LinkTarget _col(String id) =>
    LinkTarget(kind: ConnectedEntityKind.collection, id: id, label: id);

LinkTarget _card(String id) =>
    LinkTarget(kind: ConnectedEntityKind.card, id: id, label: id);

class _FakeRead implements LinkTargetsReadRepository {
  List<LinkTarget> collections = [_col('col-1'), _col('col-2')];
  Map<String, List<LinkTarget>> cards = {
    'col-1': [_card('c1'), _card('c2')],
  };
  Map<(ConnectedEntityKind, String), String> linked = {};
  bool failLinked = false;
  final linkedReads = <String>[];
  bool fail = false;
  int collectionReads = 0;
  final Map<String, int> cardReads = {};
  Completer<void>? gate;

  @override
  Future<Result<List<LinkTarget>, CardLinksFailure>> loadCollections() async {
    collectionReads++;
    await gate?.future;
    if (fail) return Failure(CardLinksReadFailure(StateError('boom')));
    return Ok(collections);
  }

  @override
  Future<Result<LinkedTargets, CardLinksFailure>> loadLinkedTargets(
    String cardId,
  ) async {
    linkedReads.add(cardId);
    if (failLinked) return Failure(CardLinksReadFailure(StateError('boom')));
    return Ok(LinkedTargets(linked));
  }

  @override
  Future<Result<List<LinkTarget>, CardLinksFailure>> loadCards(
    String collectionId,
  ) async {
    cardReads[collectionId] = (cardReads[collectionId] ?? 0) + 1;
    if (fail) return Failure(CardLinksReadFailure(StateError('boom')));
    return Ok(cards[collectionId] ?? const []);
  }
}

class _FakeWrite implements CardLinksWriteRepository {
  final added = <(String, ConnectedEntityKind, String)>[];
  final removed = <String>[];
  final made = <String>[];
  bool fail = false;

  @override
  Future<Result<LinksAdded, CardLinksFailure>> addLinks({
    required List<String> sourceIds,
    required ConnectedEntityKind targetKind,
    required String targetId,
  }) async {
    if (fail) return Failure(CardLinksWriteFailure(StateError('boom')));
    for (final id in sourceIds) {
      added.add((id, targetKind, targetId));
    }
    return Ok(LinksAdded(targetId: targetId, count: sourceIds.length));
  }

  @override
  Future<Result<LinksAdded, CardLinksFailure>> addLinksToNewCollection({
    required List<String> sourceIds,
    required String title,
  }) async {
    if (fail) return Failure(CardLinksWriteFailure(StateError('boom')));
    made.add(title);
    for (final id in sourceIds) {
      added.add((id, ConnectedEntityKind.collection, 'new-$title'));
    }
    return Ok(LinksAdded(targetId: 'new-$title', count: sourceIds.length));
  }

  @override
  Future<Result<String, CardLinksFailure>> addLink({
    required ConnectedEntityKind sourceKind,
    required String sourceId,
    required ConnectedEntityKind targetKind,
    required String targetId,
  }) async {
    if (fail) return Failure(CardLinksWriteFailure(StateError('boom')));
    added.add((sourceId, targetKind, targetId));
    return const Ok('link-1');
  }

  @override
  Future<Result<String, CardLinksFailure>> removeLink(String linkId) async {
    removed.add(linkId);
    return Ok(linkId);
  }
}

void main() {
  late _FakeRead read;
  late _FakeWrite write;
  late CardLinksController controller;
  late InMemoryRecentTargetsRepository recents;

  const source = LinkSource(cardId: 'c1', collectionId: 'col-1');

  setUp(() {
    read = _FakeRead();
    write = _FakeWrite();
    recents = InMemoryRecentTargetsRepository();
    controller = CardLinksController(
      readRepository: read,
      writeRepository: write,
      recentsReadRepository: recents,
      recentsWriteRepository: recents,
    );
  });

  group('picker', () {
    test('opening loads the collections level', () async {
      final opening = controller.openPicker(source);
      expect(controller.state.collections, isNull, reason: 'loading');
      await opening;
      expect(controller.state.collections!.map((c) => c.id), [
        'col-1',
        'col-2',
      ]);
      expect(controller.state.source, source);
    });

    test('a failed collections read shows an empty list', () async {
      read.fail = true;
      await controller.openPicker(source);
      expect(controller.state.collections, isEmpty);
    });

    test('drilling loads a collection\'s cards once per session', () async {
      await controller.openPicker(source);
      await controller.openCollection('col-1');
      await controller.openCollection('col-1');
      expect(read.cardReads['col-1'], 1);
    });

    test('a new session re-reads (a write may have changed targets)', () async {
      await controller.openPicker(source);
      await controller.openCollection('col-1');
      await controller.openPicker(source);
      expect(controller.state.hasCardsOf('col-1'), isFalse);
      await controller.openCollection('col-1');
      expect(read.collectionReads, 2);
      expect(read.cardReads['col-1'], 2);
    });

    test('a slow read from an earlier session is dropped', () async {
      final slow = Completer<void>();
      read.gate = slow;
      final stale = controller.openPicker(source); // parks on [slow]
      read
        ..gate = null
        ..collections = [_col('fresh')];
      await controller.openPicker(source);
      // Release the first read; it now returns a different list, too late.
      read.collections = [_col('stale')];
      slow.complete();
      await stale;
      expect(controller.state.collections!.single.id, 'fresh');
    });
  });

  group('✓ linked targets', () {
    test('the source card\'s links mark ✓ and toggle to unlink', () async {
      read.linked = {(ConnectedEntityKind.collection, 'col-2'): 'l-2'};
      await controller.openPicker(source);
      expect(read.linkedReads, ['c1']);
      expect(controller.state.isLinked(_col('col-2')), isTrue);
      expect(controller.state.isLinked(_card('c2')), isFalse);

      final unpick = controller.state.choose(_col('col-2'));
      expect(unpick, isA<LinkTargetUnpicked>());
      expect((unpick as LinkTargetUnpicked).linkId, 'l-2');
      expect(controller.state.choose(_card('c2')), isA<LinkTargetPicked>());
    });

    test('no source card (a new Connection), no checks read', () async {
      read.linked = {(ConnectedEntityKind.collection, 'col-2'): 'l-2'};
      await controller.openPicker(const NewConnection(collectionId: 'col-1'));
      expect(read.linkedReads, isEmpty);
      expect(controller.state.isLinked(_col('col-2')), isFalse);
    });

    test('a failed read shows no ✓, the list still loads', () async {
      read.failLinked = true;
      await controller.openPicker(source);
      expect(controller.state.collections, hasLength(2));
      expect(controller.state.isLinked(_col('col-2')), isFalse);
    });

    test('a new session forgets the last one\'s checks', () async {
      read.linked = {(ConnectedEntityKind.collection, 'col-2'): 'l-2'};
      await controller.openPicker(source);
      read.linked = {};
      await controller.openPicker(source);
      expect(controller.state.isLinked(_col('col-2')), isFalse);
    });
  });

  group('recent row', () {
    test('lists recent collections the source may link to', () async {
      read.collections = [_col('col-1'), _col('col-2'), _col('col-3')];
      // col-1 is the card's own collection; gone was deleted.
      for (final id in ['col-3', 'gone', 'col-1', 'col-2']) {
        await recents.record(RecentPurpose.link, id);
      }
      await controller.openPicker(source);
      expect(controller.state.recentCollections.map((c) => c.id), [
        'col-2',
        'col-3',
      ]);
    });

    test('"Link from my card…" shows no recent row', () async {
      await recents.record(RecentPurpose.link, 'col-2');
      await controller.openPicker(const LinkFromMine(targetCardId: 'x'));
      expect(controller.state.recentCollections, isEmpty);
    });

    test('move recents never show in the link picker', () async {
      await recents.record(RecentPurpose.move, 'col-2');
      await controller.openPicker(source);
      expect(controller.state.recentCollections, isEmpty);
    });
  });

  group('link rules (LinkSource)', () {
    test('a card never offers itself as a target', () async {
      await controller.openPicker(source);
      await controller.openCollection('col-1');
      expect(controller.state.cardsIn('col-1')!.map((c) => c.id), ['c2']);
    });

    test('a card never links to its own collection, only to others', () async {
      await controller.openPicker(source);
      expect(controller.state.canLinkToCollection('col-1'), isFalse);
      expect(controller.state.canLinkToCollection('col-2'), isTrue);
    });
  });

  group('writes', () {
    test('link adds a link from the source card to the target', () async {
      final result = await controller.link(
        sourceId: 'c1',
        targetKind: ConnectedEntityKind.card,
        targetId: 'c9',
      );
      expect(result.getOrThrow(), 'link-1');
      expect(write.added.single, ('c1', ConnectedEntityKind.card, 'c9'));
    });

    test('a link to a collection is remembered as recent', () async {
      await controller.link(
        sourceId: 'c1',
        targetKind: ConnectedEntityKind.collection,
        targetId: 'col-2',
      );
      expect((await recents.load(RecentPurpose.link)).getOrThrow().ids, [
        'col-2',
      ]);
    });

    test('a card link or a failed link remembers nothing', () async {
      await controller.link(
        sourceId: 'c1',
        targetKind: ConnectedEntityKind.card,
        targetId: 'c9',
      );
      write.fail = true;
      await controller.link(
        sourceId: 'c1',
        targetKind: ConnectedEntityKind.collection,
        targetId: 'col-2',
      );
      expect(
        (await recents.load(RecentPurpose.link)).getOrThrow().ids,
        isEmpty,
      );
    });

    test('unlink removes the link', () async {
      await controller.unlink('link-7');
      expect(write.removed, ['link-7']);
    });
  });

  group('batched links', () {
    test('linkAll links every source and remembers a collection', () async {
      final result = await controller.linkAll(
        sourceIds: ['c1', 'c2'],
        targetKind: ConnectedEntityKind.collection,
        targetId: 'col-2',
      );
      expect(result.value, const LinksAdded(targetId: 'col-2', count: 2));
      expect(write.added, [
        ('c1', ConnectedEntityKind.collection, 'col-2'),
        ('c2', ConnectedEntityKind.collection, 'col-2'),
      ]);
      expect((await recents.load(RecentPurpose.link)).value!.ids, ['col-2']);
    });

    test('linkAll to a card is not remembered', () async {
      await controller.linkAll(
        sourceIds: ['c1'],
        targetKind: ConnectedEntityKind.card,
        targetId: 'c9',
      );
      expect((await recents.load(RecentPurpose.link)).value!.ids, isEmpty);
    });

    test('linkToNewCollection remembers the new collection', () async {
      final result = await controller.linkToNewCollection(
        sourceIds: ['c1'],
        title: 'Trips',
      );
      expect(result.value?.targetId, 'new-Trips');
      expect(write.made, ['Trips']);
      expect((await recents.load(RecentPurpose.link)).value!.ids, [
        'new-Trips',
      ]);
    });

    test('a failed batch is reported and remembers nothing', () async {
      write.fail = true;
      final result = await controller.linkToNewCollection(
        sourceIds: ['c1'],
        title: 'Trips',
      );
      expect(result.isFailure, isTrue);
      expect((await recents.load(RecentPurpose.link)).value!.ids, isEmpty);
    });
  });
}
