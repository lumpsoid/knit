import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/core/previews/card_preview_label.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/link_tile.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/timeline/domain/timeline_connection_preview.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_repository.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/sync/sync.dart';

/// The Home preview of a Connection card (§4.1): "→ Trips" instead of the
/// generic "Link", falling back when the target is gone.
void main() {
  CollectionSummary summary(String id, {String? title, CardPreview? last}) =>
      CollectionSummary(
        collectionId: id,
        title: title ?? id,
        coverAttachmentId: null,
        cardCount: last == null ? 0 : 1,
        lastCard: last,
        lastUpdated: 1,
      );

  CardLinkOut toCollection(String id) =>
      (targetKind: ConnectedEntityKind.collection, targetId: id);
  CardLinkOut toCard(String id) =>
      (targetKind: ConnectedEntityKind.card, targetId: id);

  group('TimelineConnectionPreview (pure)', () {
    final index = summary(
      'index',
      last: const CardPreview(id: 'c1', kind: 'link'),
    );
    final trips = summary(
      'trips',
      title: 'Trips',
      last: const CardPreview(id: 'p1', kind: 'image'),
    );

    test('only text and link newest cards are candidates', () {
      expect(TimelineConnectionPreview.candidates([index, trips]), ['c1']);
    });

    test('a link to a live collection names it', () {
      final out = TimelineConnectionPreview.attach(
        [index, trips],
        linksOut: {
          'c1': [toCollection('trips')],
        },
        cards: const {},
      );
      expect(out.first.lastCard?.linkTarget?.name, 'Trips');
      expect(out.first.lastCard?.linkTarget?.cardKind, isNull);
      expect(out.first.lastCard?.id, 'c1');
      expect(out.last.lastCard?.linkTarget, isNull);
    });

    test('a link to a live card names its text', () {
      final out = TimelineConnectionPreview.attach(
        [index],
        linksOut: {
          'c1': [toCard('lisbon')],
        },
        cards: const {'lisbon': (kind: 'text', text: 'Lisbon')},
      );
      final target = out.single.lastCard?.linkTarget;
      expect(target?.cardKind, 'text');
      expect(target?.name, 'Lisbon');
    });

    test('a gone target, or more than a link, keeps the plain preview', () {
      expect(
        TimelineConnectionPreview.attach(
          [index],
          linksOut: {
            'c1': [toCollection('deleted')],
          },
          cards: const {},
        ).single.lastCard?.linkTarget,
        isNull,
      );
      expect(
        TimelineConnectionPreview.attach(
          [index],
          linksOut: {
            'c1': [toCollection('trips'), toCard('lisbon')],
          },
          cards: const {'lisbon': (kind: 'text', text: 'Lisbon')},
        ).single.lastCard?.linkTarget,
        isNull,
      );
    });
  });

  group('CardPreviewLabel.linkTo', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('names a collection, or untitled', () {
      expect(CardPreviewLabel.linkTo(l10n, name: 'Trips'), '→ Trips');
      expect(CardPreviewLabel.linkTo(l10n, name: ' '), '→ Untitled');
    });

    test('names a card by its first line, else its kind', () {
      expect(
        CardPreviewLabel.linkTo(l10n, cardKind: 'text', name: 'Lisbon\nin May'),
        '→ Lisbon',
      );
      expect(
        CardPreviewLabel.linkTo(l10n, cardKind: 'image'),
        '→ ${l10n.timelinePreviewPhoto}',
      );
    });
  });

  group('SyncStoreTimelineRepository', () {
    late SyncStore store;
    late SyncStoreTimelineRepository read;
    late SyncStoreTimelineWriteRepository timelineWrite;
    late SyncStoreCollectionWriteRepository write;

    setUp(() async {
      final graph = AppGraph();
      store = SyncStore.inMemory();
      await store.open();
      graph.bindStore(store);
      const ids = UuidIdGenerator();
      read = SyncStoreTimelineRepository(graph: graph);
      timelineWrite = SyncStoreTimelineWriteRepository(graph: graph, ids: ids);
      write = SyncStoreCollectionWriteRepository(graph: graph, ids: ids);
    });

    Future<CardPreview?> lastCardOf(String id) async =>
        (await read.loadTimeline())
            .getOrThrow()
            .firstWhere((s) => s.collectionId == id)
            .lastCard;

    test('a newest Connection card previews its target', () async {
      final index = (await timelineWrite.createCollection(
        'Index',
      )).getOrThrow();
      final trips = (await timelineWrite.createCollection(
        'Trips',
      )).getOrThrow();
      final lisbon = (await write.addCard(
        collectionId: trips,
        kind: CardKind.text,
        position: 'a0',
        text: 'Lisbon',
      )).getOrThrow();
      await write.addConnectionCard(
        collectionId: index,
        position: 'a0',
        targetKind: ConnectedEntityKind.collection,
        targetId: trips,
      );
      expect((await lastCardOf(index))?.linkTarget?.name, 'Trips');

      await write.addConnectionCard(
        collectionId: index,
        position: 'a1',
        targetKind: ConnectedEntityKind.card,
        targetId: lisbon,
      );
      final target = (await lastCardOf(index))?.linkTarget;
      expect(target?.cardKind, 'text');
      expect(target?.name, 'Lisbon');

      // The target card is gone: the generic label again.
      await store.delete(EntityType.card, lisbon);
      final last = await lastCardOf(index);
      expect(last?.kind, 'link');
      expect(last?.linkTarget, isNull);
    });
  });
}
