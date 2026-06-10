import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

void main() {
  group('Hlc comparator (spec §6.1)', () {
    test('orders by ms then counter, never by string', () {
      expect(const Hlc(1, 0) < const Hlc(2, 0), isTrue);
      expect(const Hlc(2, 0) > const Hlc(1, 99), isTrue, reason: 'ms dominates');
      expect(const Hlc(5, 1) > const Hlc(5, 0), isTrue, reason: 'counter breaks tie');
      expect(const Hlc(5, 0) == const Hlc(5, 0), isTrue);
    });

    test('max returns the later stamp', () {
      expect(Hlc.max(const Hlc(5, 0), const Hlc(5, 3)), const Hlc(5, 3));
      expect(Hlc.max(const Hlc(9, 0), const Hlc(5, 99)), const Hlc(9, 0));
    });
  });

  group('DeviceClock local tick (spec §8.2)', () {
    test('advancing physical time resets counter to 0', () {
      final c = DeviceClock(const Hlc(100, 4));
      expect(c.localTick(200), const Hlc(200, 0));
    });

    test('same/earlier physical time bumps counter (monotonic)', () {
      final c = DeviceClock(const Hlc(100, 4));
      expect(c.localTick(100), const Hlc(100, 5), reason: 'equal ms → counter+1');
      expect(c.localTick(50), const Hlc(100, 6), reason: 'past pt → counter+1, ms held');
    });

    test('a burst of ticks within one ms strictly increases', () {
      final c = DeviceClock(const Hlc(0, 0));
      final stamps = [for (var i = 0; i < 5; i++) c.localTick(1000)];
      for (var i = 1; i < stamps.length; i++) {
        expect(stamps[i] > stamps[i - 1], isTrue);
      }
      expect(stamps.last, const Hlc(1000, 4));
    });
  });

  group('DeviceClock observe (spec §8.2)', () {
    test('a later local write out-ranks a freshly observed remote edit', () {
      // The whole point of the invariant: after seeing a remote stamp, a local
      // write must be able to beat it.
      final c = DeviceClock(const Hlc(100, 0));
      c.observe(const Hlc(500, 7), 120); // observe a remote edit at ms=500
      expect(c.now >= const Hlc(500, 7), isTrue);
      final local = c.localTick(120); // physical clock still behind
      expect(local > const Hlc(500, 7), isTrue);
    });

    test('observed == last ms folds counters and bumps', () {
      final c = DeviceClock(const Hlc(500, 3));
      c.observe(const Hlc(500, 5), 400);
      expect(c.now, const Hlc(500, 6)); // max(3,5)+1
    });

    test('physical now strictly greatest resets counter', () {
      final c = DeviceClock(const Hlc(500, 3));
      c.observe(const Hlc(400, 9), 900);
      expect(c.now, const Hlc(900, 0));
    });

    test('observing a losing (older) op still advances counter', () {
      final c = DeviceClock(const Hlc(500, 3));
      c.observe(const Hlc(200, 0), 100); // far in the past, lost LWW
      expect(c.now, const Hlc(500, 4), reason: 'must still move past what it saw');
    });
  });

  group('skew guard (spec §8.3)', () {
    test('future beyond bound is flagged; within bound and past are not', () {
      expect(exceedsSkew(1000 + kMaxSkewMs + 1, 1000), isTrue);
      expect(exceedsSkew(1000 + kMaxSkewMs, 1000), isFalse, reason: 'boundary inclusive');
      expect(exceedsSkew(1, 10_000_000), isFalse, reason: 'past is harmless');
    });
  });
}
