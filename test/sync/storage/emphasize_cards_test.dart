import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

/// `SyncStore.setCardsEmphasized` (§3.3): emphasizing is a content write that
/// stamps `emphasized_at` (placement frozen, §8.4). A card is live, settled or
/// emphasized: setting one mark clears the other.
void main() {
  late SyncStore store;

  setUp(() async {
    store = SyncStore.inMemory();
    await store.open();
    await store.create(EntityType.collection, 'col', {
      'title': 'Steps',
    }, physicalNowMs: 1000);
    for (final (id, pos) in [('c1', 'a0'), ('c2', 'a1')]) {
      await store.create(
        EntityType.card,
        id,
        {'collection_id': 'col', 'kind': 'text', 'text': id},
        position: pos,
        physicalNowMs: 1000,
      );
    }
  });

  test('a new card is not emphasized: emphasized_at is null', () async {
    final c1 = (await store.get(EntityType.card, 'c1'))!;
    expect(c1.content['emphasized_at'], isNull);
    expect(CanonicalSerializer.string(c1), contains('"emphasized_at":null'));
  });

  test('emphasizes cards on the content clock, placement frozen', () async {
    final created = (await store.get(EntityType.card, 'c1'))!;
    final ops = await store.setCardsEmphasized(
      ['c1', 'c2'],
      emphasized: true,
      physicalNowMs: 5000,
    );

    expect(ops, hasLength(2));
    final c1 = (await store.get(EntityType.card, 'c1'))!;
    expect(c1.content['emphasized_at'], 5000);
    expect(c1.hlc, const Hlc(5000, 0));
    expect(c1.placement, created.placement, reason: 'placement frozen');
    expect(ops.first.payload, contains('"emphasized_at":5000'));
  });

  test('unemphasize clears emphasized_at', () async {
    await store.setCardsEmphasized(
      ['c1'],
      emphasized: true,
      physicalNowMs: 5000,
    );
    await store.setCardsEmphasized(
      ['c1'],
      emphasized: false,
      physicalNowMs: 6000,
    );
    expect(
      (await store.get(EntityType.card, 'c1'))!.content['emphasized_at'],
      isNull,
    );
  });

  test('emphasizing a settled card unsettles it', () async {
    await store.setCardsSettled(['c1'], settled: true, physicalNowMs: 5000);
    await store.setCardsEmphasized(
      ['c1'],
      emphasized: true,
      physicalNowMs: 6000,
    );

    final c1 = (await store.get(EntityType.card, 'c1'))!;
    expect(c1.content['emphasized_at'], 6000);
    expect(c1.content['settled_at'], isNull);
  });

  test('settling an emphasized card unemphasizes it', () async {
    await store.setCardsEmphasized(
      ['c1'],
      emphasized: true,
      physicalNowMs: 5000,
    );
    await store.setCardsSettled(['c1'], settled: true, physicalNowMs: 6000);

    final c1 = (await store.get(EntityType.card, 'c1'))!;
    expect(c1.content['settled_at'], 6000);
    expect(c1.content['emphasized_at'], isNull);
  });

  test(
    'rebuild-from-log reproduces the emphasized projection (§8.9)',
    () async {
      await store.setCardsEmphasized(
        ['c2'],
        emphasized: true,
        physicalNowMs: 5000,
      );
      final before = (await store.get(EntityType.card, 'c2'))!;
      await store.rebuild();
      final after = (await store.get(EntityType.card, 'c2'))!;
      expect(after.content['emphasized_at'], 5000);
      expect(after.sig, before.sig);
    },
  );
}
