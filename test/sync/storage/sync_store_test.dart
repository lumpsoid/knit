import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

import 'op_builders.dart';

void main() {
  group('SyncStore.applyRemote (spec §8.5)', () {
    test('applies, persists projection + change_log (remote/acked), dedups replay',
        () async {
      final store = SyncStore.inMemory();
      final op = opOf(collection(hlcMs: 100, title: 'hi'));

      expect(await store.applyRemote(op, 100), ApplyOutcome.applied);

      final row = await store.get(EntityType.collection, 'col-1');
      expect(row!.content['title'], 'hi');

      final stored = (await store.changeLog.readOrdered()).single;
      expect(stored.origin, SyncOrigin.remote);
      expect(stored.acked, isTrue);

      expect(await store.applyRemote(op, 100), ApplyOutcome.deduped);
      expect((await store.changeLog.readOrdered()).length, 1);
    });

    test('higher-HLC remote edit wins in the persisted projection', () async {
      final store = SyncStore.inMemory();
      await store.applyRemote(opOf(collection(hlcMs: 100, title: 'old')), 100);
      await store.applyRemote(opOf(collection(hlcMs: 200, title: 'new')), 200);
      final row = await store.get(EntityType.collection, 'col-1');
      expect(row!.content['title'], 'new');
    });

    test('skew-quarantined op is neither merged nor recorded (spec §8.3)', () async {
      final store = SyncStore.inMemory();
      final far = opOf(collection(hlcMs: 1000 + kMaxSkewMs + 1, title: 'evil'));

      expect(await store.applyRemote(far, 1000), ApplyOutcome.quarantinedSkew);
      expect(await store.get(EntityType.collection, 'col-1'), isNull);
      expect(await store.changeLog.readOrdered(), isEmpty);
      expect(store.clock.now, Hlc.zero, reason: 'clock not advanced');
    });

    test('persists the advanced device clock', () async {
      final store = SyncStore.inMemory();
      await store.applyRemote(opOf(collection(hlcMs: 500)), 100);
      expect(store.clock.now >= const Hlc(500, 0), isTrue);
      expect(await store.deviceClock.load(), store.clock.now);
    });
  });

  group('SyncStore.applyRemote verify (spec §8.5 step 2 / §8.8)', () {
    test('a locally-written op verifies and applies on another device', () async {
      final a = SyncStore.inMemory();
      await a.open();
      final op = await a.create(
        EntityType.collection,
        'col-1',
        {'title': 'hi'},
        physicalNowMs: 5000,
      );

      final b = SyncStore.inMemory();
      await b.open();
      expect(await b.applyRemote(op, 5000), ApplyOutcome.applied);
      expect((await b.get(EntityType.collection, 'col-1'))!.content['title'], 'hi');
    });

    test('a tampered op is quarantined bad_sig — not merged, not logged', () async {
      final store = SyncStore.inMemory();
      final good = opOf(collection(hlcMs: 100, title: 'x'));
      final tampered = PersistedOp(
        opId: good.opId,
        entityType: good.entityType,
        entityId: good.entityId,
        op: good.op,
        hlcMs: good.hlcMs,
        hlcCounter: good.hlcCounter,
        author: good.author,
        payload: good.payload,
        sig: 'deadbeefdeadbeef', // does not match the canonical bytes
        origin: good.origin,
      );

      expect(await store.applyRemote(tampered, 100),
          ApplyOutcome.quarantinedBadSig);
      expect(await store.get(EntityType.collection, 'col-1'), isNull);
      expect(await store.changeLog.readOrdered(), isEmpty);
      expect(store.clock.now, Hlc.zero, reason: 'clock not advanced');

      final q = (await store.quarantine.readAll()).single;
      expect(q.reason, QuarantineReason.badSig);
      expect(q.opId, good.opId);
    });

    test('a skew-quarantined op is retained in quarantine (§8.8)', () async {
      final store = SyncStore.inMemory();
      final far = opOf(collection(hlcMs: 1000 + kMaxSkewMs + 1, title: 'evil'));

      expect(await store.applyRemote(far, 1000), ApplyOutcome.quarantinedSkew);
      expect(await store.changeLog.readOrdered(), isEmpty);
      final q = (await store.quarantine.readAll()).single;
      expect(q.reason, QuarantineReason.skew);
    });
  });

  group('SyncStore.rebuild (spec §8.9)', () {
    test('replays the log into a projection equal to a direct merge replay',
        () async {
      // Content edit + concurrent reorder (the §7.6 blend) + delete→resurrect.
      final ops = [
        opOf(collection(hlcMs: 100, title: 'Espresso')),
        opOf(card(id: 'c1', hlcMs: 110, posMs: 110, text: 'grind', position: 'a0')),
        opOf(card(id: 'c1', hlcMs: 200, posMs: 110, text: 'grind finer', position: 'a0')),
        opOf(card(id: 'c1', hlcMs: 110, posMs: 300, text: 'grind', position: 'a5')),
        opOf(card(id: 'c2', hlcMs: 120, posMs: 120, text: 'tamp', position: 'a1')),
        opOf(card(id: 'c2', hlcMs: 220, posMs: 120, text: 'tamp', position: 'a1', deleted: true)),
        opOf(card(id: 'c2', hlcMs: 400, posMs: 120, text: 'tamp 30lb', position: 'a1')),
        opOf(collection(hlcMs: 150, title: 'Espresso dialing-in')),
      ];

      final store = SyncStore.inMemory();
      for (final op in ops) {
        await store.changeLog.append(op);
      }
      await store.rebuild();

      final direct = Projection();
      for (final op in ops) {
        direct.apply(op.toSnapshot());
      }

      String fp(Snapshot s) =>
          '${s.id}|${s.hlc}|${s.position}@${s.placement}|${s.deleted}'
          '|${s.content['text'] ?? s.content['title']}';
      final rebuilt = (await store.projection.readAll()).map(fp).toList()..sort();
      final expected = direct.rows.map(fp).toList()..sort();
      expect(rebuilt, expected);

      final c1 = await store.get(EntityType.card, 'c1');
      expect(c1!.content['text'], 'grind finer');
      expect(c1.position, 'a5', reason: 'placement winner blended in (§7.6)');
      final c2 = await store.get(EntityType.card, 'c2');
      expect(c2!.deleted, isFalse, reason: 'late edit resurrected');
    });

    test('recovers the device clock past the max stamp (§8.9 step 3)', () async {
      final store = SyncStore.inMemory();
      await store.changeLog.append(opOf(card(id: 'c1', hlcMs: 100, posMs: 900)));
      await store.changeLog.append(opOf(collection(hlcMs: 400)));
      await store.rebuild();
      expect(store.clock.now >= const Hlc(900, 0), isTrue);
      expect(await store.deviceClock.load(), store.clock.now);
    });
  });

  test('open restores a persisted device clock', () async {
    final store = SyncStore.inMemory();
    await store.deviceClock.save(const Hlc(777, 3));
    await store.open();
    expect(store.clock.now, const Hlc(777, 3));
  });
}
