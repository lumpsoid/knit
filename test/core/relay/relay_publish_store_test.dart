import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/relay/relay.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// One store contract, verified against both impls (the device-local relay
/// publication table — never synced).
void main() {
  sqfliteFfiInit();

  Future<RelayPublishStore> inMemory() async {
    final s = InMemoryRelayPublishStore();
    await s.ensureSchema();
    return s;
  }

  Future<RelayPublishStore> sqflite() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final s = SqfliteRelayPublishStore(db: db);
    await s.ensureSchema();
    return s;
  }

  for (final (name, open) in <(String, Future<RelayPublishStore> Function())>[
    ('InMemoryRelayPublishStore', inMemory),
    ('SqfliteRelayPublishStore', sqflite),
  ]) {
    group(name, () {
      late RelayPublishStore store;
      setUp(() async => store = await open());

      test('relay url round-trips; null before any save', () async {
        expect(await store.loadRelayUrl(), isNull);
        await store.saveRelayUrl(Uri.parse('https://relay.example:4000'));
        expect(await store.loadRelayUrl(), Uri.parse('https://relay.example:4000'));
      });

      test('publication round-trips with a null slug', () async {
        expect(await store.loadPublication('c1'), isNull);

        await store.savePublication(const CollectionPublication(
          collectionId: 'c1',
          topicId: 'topic-1',
          writeToken: 'wtok-1',
          visibility: PublishVisibility.private,
        ));

        final got = (await store.loadPublication('c1'))!;
        expect(got.topicId, 'topic-1');
        expect(got.writeToken, 'wtok-1');
        expect(got.slug, isNull);
        expect(got.visibility, PublishVisibility.private);
        expect(got.publishedAt, isNull);
      });

      test('upsert by collection id replaces the row', () async {
        await store.savePublication(const CollectionPublication(
          collectionId: 'c1',
          topicId: 'topic-1',
          writeToken: 'wtok-1',
          visibility: PublishVisibility.private,
        ));
        await store.savePublication(const CollectionPublication(
          collectionId: 'c1',
          topicId: 'topic-1',
          writeToken: 'wtok-1',
          slug: 'slug-1',
          visibility: PublishVisibility.public,
          publishedAt: 1718020800000,
        ));

        final got = (await store.loadPublication('c1'))!;
        expect(got.slug, 'slug-1');
        expect(got.visibility, PublishVisibility.public);
        expect(got.publishedAt, 1718020800000);
      });

      test('delete removes the record', () async {
        await store.savePublication(const CollectionPublication(
          collectionId: 'c1',
          topicId: 'topic-1',
          writeToken: 'wtok-1',
          visibility: PublishVisibility.public,
        ));
        await store.deletePublication('c1');
        expect(await store.loadPublication('c1'), isNull);
      });
    });
  }
}
