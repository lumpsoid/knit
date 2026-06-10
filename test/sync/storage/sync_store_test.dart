import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

import 'op_builders.dart';

void main() {
  group('SyncStore.rebuild (spec §8.9)', () {
    test('replays the log into a projection equal to a direct merge replay', () async {
      // A log with a content edit + a concurrent reorder (the §7.6 blend) and a
      // delete→resurrect.
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

      final log = InMemoryChangeLogStorage();
      for (final op in ops) {
        await log.append(op);
      }

      final store = SyncStore(changeLog: log);
      await store.rebuild();

      // Equivalent to merging the parsed snapshots directly through the core.
      final direct = Projection();
      for (final op in ops) {
        direct.apply(op.toSnapshot());
      }

      String fp(Snapshot s) =>
          '${s.id}|${s.hlc}|${s.position}@${s.placement}|${s.deleted}'
          '|${s.content['text'] ?? s.content['title']}';
      final rebuilt = store.projection.rows.map(fp).toList()..sort();
      final expected = direct.rows.map(fp).toList()..sort();
      expect(rebuilt, expected);

      // Blend + resurrect landed correctly.
      expect(store.projection['c1']!.content['text'], 'grind finer');
      expect(store.projection['c1']!.position, 'a5');
      expect(store.projection['c2']!.deleted, isFalse);
      expect(store.projection['c2']!.content['text'], 'tamp 30lb');
    });

    test('recovers the device clock past the max stamp in the log (§8.9 step 3)', () async {
      final log = InMemoryChangeLogStorage();
      await log.append(opOf(card(id: 'c1', hlcMs: 100, posMs: 900))); // placement is the max
      await log.append(opOf(collection(hlcMs: 400)));

      final store = SyncStore(changeLog: log);
      await store.rebuild();

      expect(store.engine.clock.now >= const Hlc(900, 0), isTrue);
    });
  });

  group('SyncStore.applyRemote (spec §8.5)', () {
    test('applies, persists as remote+acked, and dedups a replay', () async {
      final log = InMemoryChangeLogStorage();
      final store = SyncStore(changeLog: log);
      final op = opOf(collection(hlcMs: 100, title: 'hi'), origin: SyncOrigin.local);

      final first = await store.applyRemote(op, 100);
      expect(first, ApplyOutcome.applied);
      expect(store.projection['col-1']!.content['title'], 'hi');

      final stored = (await log.readOrdered()).single;
      expect(stored.origin, SyncOrigin.remote, reason: 'recorded as remote');
      expect(stored.acked, isTrue);

      final second = await store.applyRemote(op, 100);
      expect(second, ApplyOutcome.deduped);
      expect((await log.readOrdered()).length, 1);
    });

    test('skew-quarantined op is neither merged nor recorded', () async {
      final log = InMemoryChangeLogStorage();
      final store = SyncStore(changeLog: log);
      final far = opOf(collection(hlcMs: 1000 + kMaxSkewMs + 1, title: 'evil'));

      final outcome = await store.applyRemote(far, 1000);
      expect(outcome, ApplyOutcome.quarantinedSkew);
      expect(store.projection['col-1'], isNull);
      expect(await log.readOrdered(), isEmpty);
    });
  });
}
