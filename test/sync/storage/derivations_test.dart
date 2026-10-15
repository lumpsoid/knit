import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'op_builders.dart';

/// Read-time derivations (spec §8.6) — verified against both projection impls,
/// like the rest of the storage contract. The broken-link resolver reads
/// endpoints from the store; the home timeline is a pure build over `readAll`,
/// exercised here through each backing store.
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

      // --- Broken-link chip (spec §8.6.1 / §8.6.2) --------------------------

      group('BrokenLinkResolver', () {
        // Links from op_builders go card-1 -> col-1 (source card, target
        // collection).
        Future<LinkEndpointStatus> statusOf(Snapshot l) =>
            BrokenLinkResolver(store).resolve(l);

        test('both endpoints live → not broken', () async {
          await store.upsert(card(id: 'card-1', hlcMs: 1));
          await store.upsert(collection(id: 'col-1', hlcMs: 1));
          final s = await statusOf(
            link(sourceId: 'card-1', targetId: 'col-1', hlcMs: 1),
          );
          expect(s.isBroken, isFalse);
          expect(s.sourceBroken, isFalse);
          expect(s.targetBroken, isFalse);
        });

        test('missing endpoint row → broken (spec §8.6.1)', () async {
          await store.upsert(card(id: 'card-1', hlcMs: 1));
          // col-1 never inserted.
          final s = await statusOf(
            link(sourceId: 'card-1', targetId: 'col-1', hlcMs: 1),
          );
          expect(s.targetBroken, isTrue);
          expect(s.isBroken, isTrue);
        });

        test('tombstoned endpoint → broken (spec §8.6.1)', () async {
          await store.upsert(card(id: 'card-1', hlcMs: 1));
          await store.upsert(collection(id: 'col-1', hlcMs: 2, deleted: true));
          final s = await statusOf(
            link(sourceId: 'card-1', targetId: 'col-1', hlcMs: 1),
          );
          expect(s.targetBroken, isTrue);
          expect(s.isBroken, isTrue);
        });

        test('tombstoned source → broken backlink (spec §8.6.2)', () async {
          await store.upsert(card(id: 'card-1', hlcMs: 2, deleted: true));
          await store.upsert(collection(id: 'col-1', hlcMs: 1));
          final s = await statusOf(
            link(sourceId: 'card-1', targetId: 'col-1', hlcMs: 1),
          );
          expect(s.sourceBroken, isTrue);
          expect(s.targetBroken, isFalse);
          expect(s.isBroken, isTrue);
        });
      });

      // --- Home timeline (spec §8.6.3) --------------------------------------

      group('homeTimeline', () {
        Future<List<CollectionSummary>> build() async =>
            buildHomeTimeline(await store.readAll());

        test('per-collection card_count / last_card / last_updated', () async {
          await store.upsert(
            collection(id: 'col-1', hlcMs: 1, title: 'Espresso'),
          );
          await store.upsert(
            card(
              id: 'a',
              collectionId: 'col-1',
              hlcMs: 1,
              createdAt: 100,
              text: 'old',
            ),
          );
          await store.upsert(
            card(
              id: 'b',
              collectionId: 'col-1',
              hlcMs: 1,
              createdAt: 300,
              text: 'newest',
              // earlier in the feed (position) but most-recently *added*.
              position: 'a0',
            ),
          );
          await store.upsert(
            card(
              id: 'c',
              collectionId: 'col-1',
              hlcMs: 1,
              createdAt: 200,
              deleted: true,
            ),
          );

          final row = (await build()).single;
          expect(row.collectionId, 'col-1');
          expect(row.title, 'Espresso');
          expect(row.cardCount, 2); // tombstone excluded
          expect(
            row.lastCard!.text,
            'newest',
          ); // greatest created_at, not feed order
          expect(row.lastUpdated, 300);
        });

        test(
          'empty collection → last_updated is its own created_at, no last_card',
          () async {
            await store.upsert(
              collection(id: 'col-1', hlcMs: 1, createdAt: 500),
            );
            final row = (await build()).single;
            expect(row.cardCount, 0);
            expect(row.lastCard, isNull);
            expect(row.lastUpdated, 500);
          },
        );

        test(
          'sorted last_updated DESC, tombstoned collections excluded',
          () async {
            await store.upsert(collection(id: 'old', hlcMs: 1, createdAt: 100));
            await store.upsert(collection(id: 'mid', hlcMs: 1, createdAt: 100));
            await store.upsert(
              card(id: 'k', collectionId: 'mid', hlcMs: 1, createdAt: 400),
            );
            await store.upsert(collection(id: 'new', hlcMs: 1, createdAt: 900));
            await store.upsert(collection(id: 'gone', hlcMs: 2, deleted: true));

            final ids = (await build()).map((s) => s.collectionId).toList();
            // new(900) > mid(400) > old(100); 'gone' excluded.
            expect(ids, ['new', 'mid', 'old']);
          },
        );

        test(
          'non-text last_card preview carries its kind (spec §8.6.3)',
          () async {
            await store.upsert(collection(id: 'col-1', hlcMs: 1));
            await store.upsert(
              card(
                id: 'img',
                collectionId: 'col-1',
                hlcMs: 1,
                createdAt: 100,
                kind: 'image',
                text: '',
                attachmentId: 'att-1',
              ),
            );
            final row = (await build()).single;
            expect(row.lastCard!.kind, 'image');
          },
        );
      });
    });
  }
}
