import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/timeline/domain/timeline_order.dart';
import 'package:knit/sync/sync.dart';

void main() {
  CollectionSummary summary(String id) => CollectionSummary(
    collectionId: id,
    title: id,
    coverAttachmentId: null,
    cardCount: 0,
    lastCard: null,
    lastUpdated: 1,
  );

  List<String> ids(List<CollectionSummary> l) =>
      l.map((c) => c.collectionId).toList();

  // Incoming order: the §8.6.3 recency order (newest first).
  final feed = [summary('a'), summary('b'), summary('c'), summary('d')];

  group('TimelineOrder', () {
    test('empty order keeps the incoming order and is not manual', () {
      const order = TimelineOrder();
      expect(order.isManual, isFalse);
      expect(ids(order.arrange(feed)), ['a', 'b', 'c', 'd']);
    });

    test('a non-empty order makes it manual', () {
      expect(const TimelineOrder(['d']).isManual, isTrue);
    });

    test('unlisted come first in incoming order, listed follow by index', () {
      final order = const TimelineOrder(['d', 'b']);
      expect(ids(order.arrange(feed)), ['a', 'c', 'd', 'b']);
    });

    test('ids that match no collection are ignored', () {
      final order = const TimelineOrder(['gone', 'd', 'c']);
      expect(ids(order.arrange(feed)), ['a', 'b', 'd', 'c']);
    });

    test('arrange returns a new list, the input is not modified', () {
      final input = [...feed];
      final arranged = const TimelineOrder(['d']).arrange(input);
      expect(identical(arranged, input), isFalse);
      expect(ids(input), ['a', 'b', 'c', 'd']);
    });

    test('movedWithin moving down places the item at its final slot', () {
      // Arranged by [d, b]: [a, c, d, b]. Move a (0) to slot 2.
      final order = const TimelineOrder(['d', 'b']);
      final section = order.arrange(feed);
      expect(ids(section), ['a', 'c', 'd', 'b']);

      final moved = order.movedWithin(section, 0, 2);
      expect(moved.ids, ['c', 'd', 'a', 'b']);
      expect(ids(moved.arrange(feed)), ['c', 'd', 'a', 'b']);
    });

    test('movedWithin moving up places the item at its final slot', () {
      // Arranged by [d, b]: [a, c, d, b]. Move b (3) up to slot 1.
      final order = const TimelineOrder(['d', 'b']);
      final section = order.arrange(feed);

      final moved = order.movedWithin(section, 3, 1);
      expect(moved.ids, ['a', 'b', 'c', 'd']);
      expect(ids(moved.arrange(feed)), ['a', 'b', 'c', 'd']);
    });

    test('movedWithin keeps ids outside the section after it, in order', () {
      // x and y belong to another section (no matching collection here).
      final order = const TimelineOrder(['x', 'a', 'y', 'b']);
      final section = order.arrange([summary('a'), summary('b')]);
      expect(ids(section), ['a', 'b']);

      final moved = order.movedWithin(section, 0, 1);
      expect(moved.ids, ['b', 'a', 'x', 'y']);
    });
  });
}
