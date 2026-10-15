import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

Snapshot remoteCol(int hlcMs, {String title = 't'}) => Snapshot(
  type: EntityType.collection,
  id: 'col-1',
  author: 'bb',
  createdBy: 'bb',
  createdAt: 1000,
  hlc: Hlc(hlcMs, 0),
  deleted: false,
  sig: 'sig$hlcMs',
  content: {'title': title, 'cover_attachment_id': null},
);

void main() {
  group('MergeEngine remote apply (spec §8.5)', () {
    test('applies a clean op, advances clock, merges projection', () {
      final e = MergeEngine(clock: DeviceClock(const Hlc(50, 0)));
      final out = e.applyRemote(remoteCol(100, title: 'hi'), 90);
      expect(out, ApplyOutcome.applied);
      expect(e.clock.now >= const Hlc(100, 0), isTrue);
      expect(e.projection['col-1']!.content['title'], 'hi');
    });

    test('skew-quarantines a future op without applying or advancing', () {
      final e = MergeEngine(clock: DeviceClock(const Hlc(50, 0)));
      final far = remoteCol(1000 + kMaxSkewMs + 1, title: 'evil');
      final out = e.applyRemote(far, 1000);
      expect(out, ApplyOutcome.quarantinedSkew);
      expect(e.projection['col-1'], isNull, reason: 'not applied');
      expect(
        e.clock.now,
        const Hlc(50, 0),
        reason: 'clock not advanced (spec §8.3)',
      );
    });

    test(
      'a card observe reduces over both stamps (placement can exceed content)',
      () {
        final e = MergeEngine(clock: DeviceClock(const Hlc(50, 0)));
        final reorder = Snapshot(
          type: EntityType.card,
          id: 'c1',
          author: 'bb',
          createdBy: 'bb',
          createdAt: 1000,
          hlc: const Hlc(100, 0), // content frozen low
          deleted: false,
          sig: 'r',
          placement: const Hlc(900, 0), // placement is the max stamp
          position: 'a5',
          content: {'collection_id': 'col-1', 'kind': 'text', 'text': 'x'},
        );
        e.applyRemote(reorder, 120);
        expect(
          e.clock.now >= const Hlc(900, 0),
          isTrue,
          reason: 'observed clock = max(content, placement), spec §8.2',
        );
      },
    );
  });

  group('MergeEngine local write (spec §8.2 / §8.4)', () {
    test('a local write after observing a remote edit out-ranks it', () {
      final e = MergeEngine(clock: DeviceClock(const Hlc(50, 0)));
      e.applyRemote(remoteCol(500, title: 'remote'), 60); // observe ms=500

      // Local edit; physical clock still behind remote ms.
      final local = e.writeLocal(
        60,
        (stamp) => Snapshot(
          type: EntityType.collection,
          id: 'col-1',
          author: 'aa',
          createdBy: 'bb',
          createdAt: 1000,
          hlc: stamp,
          deleted: false,
          sig: 'local',
          content: {'title': 'local-wins', 'cover_attachment_id': null},
        ),
      );

      expect(
        local.hlc > const Hlc(500, 0),
        isTrue,
        reason: 'invariant, spec §8.1',
      );
      expect(e.projection['col-1']!.content['title'], 'local-wins');
    });

    test('local writes within one ms strictly increase the stamp', () {
      final e = MergeEngine(clock: DeviceClock(const Hlc(1000, 0)));
      Snapshot mk(Hlc s, int i) => Snapshot(
        type: EntityType.collection,
        id: 'c$i',
        author: 'aa',
        createdBy: 'aa',
        createdAt: 1000,
        hlc: s,
        deleted: false,
        sig: 's$i',
        content: const {'title': 'x', 'cover_attachment_id': null},
      );
      final s1 = e.writeLocal(1000, (s) => mk(s, 1)).hlc;
      final s2 = e.writeLocal(1000, (s) => mk(s, 2)).hlc;
      expect(s2 > s1, isTrue);
    });
  });
}
