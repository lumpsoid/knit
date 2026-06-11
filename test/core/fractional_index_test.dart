import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/ordering/fractional_index.dart';

void main() {
  group('FractionalIndex known values', () {
    test('first / append / prepend', () {
      expect(FractionalIndex.first(), 'a0');
      expect(FractionalIndex.keyAfter('a0'), 'a1');
      expect(FractionalIndex.keyAfter('a1'), 'a2');
      expect(FractionalIndex.keyBefore('a0'), 'Zz');
    });

    test('between two consecutive integers splits the fraction', () {
      expect(FractionalIndex.between('a0', 'a1'), 'a0V');
    });

    test('between two far digits picks a midpoint digit', () {
      final mid = FractionalIndex.between('a0', 'a2');
      expect(mid, 'a1');
    });
  });

  group('FractionalIndex invariants', () {
    test('between is strictly ordered between its neighbours', () {
      var lo = FractionalIndex.first();
      var hi = FractionalIndex.keyAfter(lo);
      // Repeatedly bisect; each key must stay strictly between.
      for (var i = 0; i < 50; i++) {
        final mid = FractionalIndex.between(lo, hi);
        expect(lo.compareTo(mid) < 0, isTrue, reason: '$lo < $mid');
        expect(mid.compareTo(hi) < 0, isTrue, reason: '$mid < $hi');
        hi = mid; // keep squeezing toward lo
      }
    });

    test('appending repeatedly stays monotonically increasing', () {
      final keys = <String>[FractionalIndex.first()];
      for (var i = 0; i < 100; i++) {
        keys.add(FractionalIndex.keyAfter(keys.last));
      }
      final sorted = [...keys]..sort();
      expect(keys, sorted, reason: 'append order == lexicographic order');
      expect(keys.toSet().length, keys.length, reason: 'all distinct');
    });

    test('inserting between every adjacent pair preserves order', () {
      var keys = <String>[
        FractionalIndex.first(),
        FractionalIndex.keyAfter(FractionalIndex.first()),
      ];
      for (var round = 0; round < 5; round++) {
        final next = <String>[keys.first];
        for (var i = 1; i < keys.length; i++) {
          next
            ..add(FractionalIndex.between(keys[i - 1], keys[i]))
            ..add(keys[i]);
        }
        keys = next;
        final sorted = [...keys]..sort();
        expect(keys, sorted);
        expect(keys.toSet().length, keys.length);
      }
    });

    test('rejects a >= b', () {
      expect(() => FractionalIndex.between('a1', 'a0'), throwsArgumentError);
      expect(() => FractionalIndex.between('a1', 'a1'), throwsArgumentError);
    });
  });
}
