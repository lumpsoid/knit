import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/timeline/domain/timeline_order.dart';
import 'package:knit/features/timeline/domain/timeline_sections.dart';
import 'package:knit/sync/sync.dart';

void main() {
  CollectionSummary summary(String id, {bool archived = false}) =>
      CollectionSummary(
        collectionId: id,
        title: id,
        coverAttachmentId: null,
        cardCount: 0,
        lastCard: null,
        lastUpdated: 1,
        archived: archived,
      );

  // Already in §8.6.3 recency order (newest first).
  final feed = [summary('a'), summary('b'), summary('c'), summary('d')];
  List<String> ids(List<CollectionSummary> l) =>
      l.map((c) => c.collectionId).toList();

  test('no pins → everything in the rest, no Pinned section', () {
    final s = TimelineSections.split(
      feed,
      const {},
      order: const TimelineOrder(),
    );
    expect(s.hasPinned, isFalse);
    expect(s.pinned, isEmpty);
    expect(ids(s.others), ['a', 'b', 'c', 'd']);
  });

  test('pinned lift to the top section, both keep recency order', () {
    final s = TimelineSections.split(feed, const {
      'd',
      'b',
    }, order: const TimelineOrder());
    expect(s.hasPinned, isTrue);
    expect(ids(s.pinned), ['b', 'd']);
    expect(ids(s.others), ['a', 'c']);
  });

  test('stale pinned ids (deleted collections) are ignored', () {
    final s = TimelineSections.split(feed, const {
      'gone',
      'c',
    }, order: const TimelineOrder());
    expect(ids(s.pinned), ['c']);
    expect(ids(s.others), ['a', 'b', 'd']);
  });

  test('only stale pins → no Pinned section', () {
    final s = TimelineSections.split(feed, const {
      'gone',
    }, order: const TimelineOrder());
    expect(s.hasPinned, isFalse);
    expect(ids(s.others), ['a', 'b', 'c', 'd']);
  });

  test('everything pinned → empty rest', () {
    final s = TimelineSections.split(feed, const {
      'a',
      'b',
      'c',
      'd',
    }, order: const TimelineOrder());
    expect(ids(s.pinned), ['a', 'b', 'c', 'd']);
    expect(s.others, isEmpty);
  });

  test('archived collections leave Home for the archive, in order', () {
    final mixed = [
      summary('a'),
      summary('b', archived: true),
      summary('c'),
      summary('d', archived: true),
    ];
    final s = TimelineSections.split(
      mixed,
      const {},
      order: const TimelineOrder(),
    );
    expect(ids(s.others), ['a', 'c']);
    expect(ids(s.archived), ['b', 'd']);
    expect(s.hasArchived, isTrue);
    expect(s.homeIsEmpty, isFalse);
  });

  test('archived wins over pinned', () {
    final mixed = [summary('a', archived: true), summary('b')];
    final s = TimelineSections.split(mixed, const {
      'a',
    }, order: const TimelineOrder());
    expect(s.pinned, isEmpty);
    expect(ids(s.archived), ['a']);
    expect(ids(s.others), ['b']);
  });

  test('everything archived → Home is empty, the archive is not', () {
    final s = TimelineSections.split(
      [summary('a', archived: true)],
      const {},
      order: const TimelineOrder(),
    );
    expect(s.homeIsEmpty, isTrue);
    expect(s.hasArchived, isTrue);
  });

  test('nothing archived → no archive', () {
    final s = TimelineSections.split(
      feed,
      const {},
      order: const TimelineOrder(),
    );
    expect(s.hasArchived, isFalse);
    expect(s.archived, isEmpty);
  });

  group('TimelineSections order', () {
    test('split with an order arranges pinned and others, not archived', () {
      final collections = [
        summary('a'),
        summary('b', archived: true),
        summary('c'),
        summary('d'),
        summary('e', archived: true),
        summary('f'),
      ];
      final s = TimelineSections.split(collections, const {
        'd',
        'f',
      }, order: const TimelineOrder(['f', 'd', 'c', 'a', 'e', 'b']));
      expect(ids(s.pinned), ['f', 'd']);
      expect(ids(s.others), ['c', 'a']);
      // Archived keeps its incoming order even though the order lists it.
      expect(ids(s.archived), ['b', 'e']);
    });

    test('moved within others uses section-local indices after pinned', () {
      final collections = [
        summary('a'),
        summary('b'),
        summary('c'),
        summary('d'),
        summary('e'),
      ];
      final s = TimelineSections.split(collections, const {
        'a',
      }, order: const TimelineOrder());
      // Flat [a, b, c, d, e]: drag c (flat 2) to its final slot 4.
      final next = s.moved(2, 4);
      expect(next, isNotNull);
      expect(next!.ids, ['b', 'd', 'e', 'c']);

      final again = TimelineSections.split(collections, const {
        'a',
      }, order: next);
      expect(ids(again.others), ['b', 'd', 'e', 'c']);
    });

    test(
      'moved from pinned clamps a drop past the section to its last slot',
      () {
        final s = TimelineSections.split(feed, const {
          'a',
          'b',
        }, order: const TimelineOrder());
        // Flat index 3 is in the rest; the drop clamps to pinned slot 1.
        final next = s.moved(0, 3);
        expect(next, isNotNull);
        expect(next!.ids, ['b', 'a']);
      },
    );

    test('moved returns null when the drop lands on the same slot', () {
      final s = TimelineSections.split(feed, const {
        'a',
        'b',
      }, order: const TimelineOrder());
      // Positive control: a real move in the rest is not null.
      expect(s.moved(3, 0), isNotNull);
      // Last pinned row dropped past its section clamps onto itself.
      expect(s.moved(1, 9), isNull);
      // First rest row dragged up over the boundary clamps to its own slot.
      expect(s.moved(2, 1), isNull);
      expect(s.moved(0, 0), isNull);
    });

    test('moved returns null for an out-of-range old index', () {
      final s = TimelineSections.split(feed, const {
        'b',
      }, order: const TimelineOrder());
      expect(s.moved(4, 0), isNull);
      expect(s.moved(-1, 0), isNull);
    });
  });
}
