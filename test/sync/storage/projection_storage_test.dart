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
