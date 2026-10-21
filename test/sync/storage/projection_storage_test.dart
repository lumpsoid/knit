import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'op_builders.dart';

/// One contract, verified against both impls — in-memory for dev/tests, sqflite
/// (the §6.4 entity tables) for prod.
void main() {
  sqfliteFfiInit();

  Future<ProjectionStorage> inMemory() async {
    final s = InMemoryProjectionStorage();
    await s.ensureSchema();
    return s;
  }

  Future<ProjectionStorage> sqflite() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final s = SqfliteProjectionStorage(db: db);
    await s.ensureSchema();
    return s;
  }

  for (final (name, open) in <(String, Future<ProjectionStorage> Function())>[
    ('InMemoryProjectionStorage', inMemory),
    ('SqfliteProjectionStorage', sqflite),
  ]) {
    group(name, () {
      late ProjectionStorage store;
      setUp(() async => store = await open());

      test('upsert + get round-trips a collection', () async {
        await store.upsert(collection(hlcMs: 100, title: 'Espresso'));
        final got = await store.get(EntityType.collection, 'col-1');
        expect(got!.type, EntityType.collection);
        expect(got.content['title'], 'Espresso');
        expect(got.hlc, const Hlc(100, 0));
      });

      test(
        'upsert + get round-trips a card with its placement clock',
        () async {
          await store.upsert(
            card(hlcMs: 100, posMs: 300, text: 'grind finer', position: 'a5'),
          );
          final got = await store.get(EntityType.card, 'card-1');
          expect(got!.position, 'a5');
          expect(got.placement, const Hlc(300, 0));
          expect(got.content['text'], 'grind finer');
          expect(got.content['collection_id'], 'col-1');
        },
      );

      test('deleteMany removes only the given ids of one type', () async {
        await store.upsert(collection(hlcMs: 100));
        await store.upsert(card(hlcMs: 100));
        await store.upsert(card(id: 'card-2', hlcMs: 100, deleted: true));
        await store.upsert(card(id: 'card-3', hlcMs: 100));

        await store.deleteMany(EntityType.card, ['card-1', 'card-2', 'nope']);
        expect((await store.readAll()).map((s) => s.id).toSet(), {
          'col-1',
          'card-3',
        });
      });

      test('upsert replaces an existing row by id', () async {
        await store.upsert(collection(hlcMs: 100, title: 'old'));
        await store.upsert(collection(hlcMs: 200, title: 'new'));
        final got = await store.get(EntityType.collection, 'col-1');
        expect(got!.content['title'], 'new');
      });

      test(
        'feed: position ASC, id ASC, excludes tombstones (spec §8.7)',
        () async {
          await store.upsert(card(id: 'c-b', position: 'a2', hlcMs: 1));
          await store.upsert(card(id: 'c-a', position: 'a1', hlcMs: 1));
          await store.upsert(
            card(id: 'c-z', position: 'a1', hlcMs: 1),
          ); // tie → id
          await store.upsert(
            card(id: 'c-d', position: 'a9', hlcMs: 1, deleted: true),
          );
          await store.upsert(
            card(id: 'other', collectionId: 'col-2', position: 'a0', hlcMs: 1),
          );

          final ids = (await store.feed('col-1')).map((s) => s.id).toList();
          expect(ids, ['c-a', 'c-z', 'c-b']);
        },
      );

      group('feedPage (newest first, keyset)', () {
        setUp(() async {
          // Feed order: c1 a1 · c2 a2 · c3a/c3b tie on a3 · c4 a4.
          for (final (id, pos) in [
            ('c1', 'a1'),
            ('c2', 'a2'),
            ('c3b', 'a3'),
            ('c3a', 'a3'),
            ('c4', 'a4'),
          ]) {
            await store.upsert(card(id: id, position: pos, hlcMs: 1));
          }
          await store.upsert(
            card(id: 'gone', position: 'a5', hlcMs: 1, deleted: true),
          );
          await store.upsert(
            card(id: 'other', collectionId: 'col-2', position: 'a9', hlcMs: 1),
          );
        });

        Future<List<String>> ids({
          FeedKey? before,
          FeedKey? atOrAfter,
          int? limit,
        }) async => (await store.feedPage(
          'col-1',
          before: before,
          atOrAfter: atOrAfter,
          limit: limit,
        )).map((s) => s.id).toList();

        test('unbounded is the reversed feed, tombstones excluded', () async {
          expect(await ids(), ['c4', 'c3b', 'c3a', 'c2', 'c1']);
        });

        test('limit takes the newest cards', () async {
          expect(await ids(limit: 2), ['c4', 'c3b']);
        });

        test('before is strictly older, honouring the id tie-break', () async {
          expect(await ids(before: (position: 'a3', id: 'c3b'), limit: 2), [
            'c3a',
            'c2',
          ]);
        });

        test('atOrAfter is inclusive of the anchor', () async {
          expect(await ids(atOrAfter: (position: 'a3', id: 'c3a')), [
            'c4',
            'c3b',
            'c3a',
          ]);
        });
      });

      test('getMany returns only the requested rows', () async {
        await store.upsert(card(id: 'x', hlcMs: 1));
        await store.upsert(card(id: 'y', hlcMs: 1, deleted: true));
        await store.upsert(card(id: 'z', hlcMs: 1));
        final got = await store.getMany(EntityType.card, ['x', 'y', 'nope']);
        expect(got.map((s) => s.id).toSet(), {'x', 'y'});
      });

      test('linkCounts = linksOut + backlinks per id, live only', () async {
        await store.upsert(
          link(id: 'l1', sourceId: 'card-1', targetId: 'col-1', hlcMs: 1),
        );
        await store.upsert(
          link(id: 'l2', sourceId: 'card-2', targetId: 'card-1', hlcMs: 1),
        );
        await store.upsert(
          link(
            id: 'l3',
            sourceId: 'card-1',
            targetId: 'col-2',
            hlcMs: 1,
            deleted: true,
          ),
        );
        final counts = await store.linkCounts(['card-1', 'card-2', 'card-9']);
        expect(counts, {'card-1': 2, 'card-2': 1});
      });

      test('backlinks: live links to a target only (spec §8.6.2)', () async {
        await store.upsert(link(id: 'l1', targetId: 'col-1', hlcMs: 1));
        await store.upsert(
          link(id: 'l2', targetId: 'col-1', hlcMs: 1, deleted: true),
        );
        await store.upsert(link(id: 'l3', targetId: 'col-2', hlcMs: 1));

        final ids = (await store.backlinks('col-1')).map((s) => s.id).toList();
        expect(ids, ['l1']);
      });

      test('linksOut: live links from a source only (spec §4.4)', () async {
        await store.upsert(link(id: 'l1', sourceId: 'card-1', hlcMs: 1));
        await store.upsert(
          link(id: 'l2', sourceId: 'card-1', hlcMs: 1, deleted: true),
        );
        await store.upsert(link(id: 'l3', sourceId: 'card-9', hlcMs: 1));

        final ids = (await store.linksOut('card-1')).map((s) => s.id).toList();
        expect(ids, ['l1']);
      });

      test(
        'linksOutOf / backlinksTo: live links of many ids at once',
        () async {
          await store.upsert(
            link(id: 'l1', sourceId: 'card-1', targetId: 'col-1', hlcMs: 1),
          );
          await store.upsert(
            link(id: 'l2', sourceId: 'card-2', targetId: 'col-2', hlcMs: 1),
          );
          await store.upsert(
            link(
              id: 'l3',
              sourceId: 'card-1',
              targetId: 'col-2',
              hlcMs: 1,
              deleted: true,
            ),
          );
          await store.upsert(
            link(id: 'l4', sourceId: 'card-9', targetId: 'col-9', hlcMs: 1),
          );

          final out = await store.linksOutOf(['card-1', 'card-2', 'nope']);
          expect(out.map((s) => s.id).toSet(), {'l1', 'l2'});
          final back = await store.backlinksTo(['col-1', 'col-2']);
          expect(back.map((s) => s.id).toSet(), {'l1', 'l2'});
          expect(await store.linksOutOf(const []), isEmpty);
        },
      );

      test('liveCardsIn: the live cards of the given collections', () async {
        await store.upsert(card(id: 'x', collectionId: 'col-1', hlcMs: 1));
        await store.upsert(
          card(id: 'y', collectionId: 'col-1', hlcMs: 1, deleted: true),
        );
        await store.upsert(card(id: 'z', collectionId: 'col-2', hlcMs: 1));
        await store.upsert(card(id: 'w', collectionId: 'col-3', hlcMs: 1));
        final got = await store.liveCardsIn(['col-1', 'col-2']);
        expect(got.map((s) => s.id).toSet(), {'x', 'z'});
      });

      test('readAll spans every entity table', () async {
        await store.upsert(collection(hlcMs: 1));
        await store.upsert(card(hlcMs: 1));
        await store.upsert(link(hlcMs: 1));
        await store.upsert(profile(hlcMs: 1));
        final types = (await store.readAll()).map((s) => s.type).toSet();
        expect(types, {
          EntityType.collection,
          EntityType.card,
          EntityType.link,
          EntityType.profile,
        });
      });

      test('clear empties all tables', () async {
        await store.upsert(collection(hlcMs: 1));
        await store.upsert(card(hlcMs: 1));
        await store.clear();
        expect(await store.readAll(), isEmpty);
      });
    });
  }
}
