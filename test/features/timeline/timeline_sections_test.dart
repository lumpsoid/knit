import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/timeline/domain/timeline_sections.dart';
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

  // Already in §8.6.3 recency order (newest first).
  final feed = [summary('a'), summary('b'), summary('c'), summary('d')];
  List<String> ids(List<CollectionSummary> l) =>
      l.map((c) => c.collectionId).toList();

  test('no pins → everything in the rest, no Pinned section', () {
    final s = TimelineSections.split(feed, const {});
    expect(s.hasPinned, isFalse);
    expect(s.pinned, isEmpty);
    expect(ids(s.others), ['a', 'b', 'c', 'd']);
  });

  test('pinned lift to the top section, both keep recency order', () {
    final s = TimelineSections.split(feed, const {'d', 'b'});
    expect(s.hasPinned, isTrue);
    expect(ids(s.pinned), ['b', 'd']);
    expect(ids(s.others), ['a', 'c']);
  });

  test('stale pinned ids (deleted collections) are ignored', () {
    final s = TimelineSections.split(feed, const {'gone', 'c'});
    expect(ids(s.pinned), ['c']);
    expect(ids(s.others), ['a', 'b', 'd']);
  });

  test('only stale pins → no Pinned section', () {
    final s = TimelineSections.split(feed, const {'gone'});
    expect(s.hasPinned, isFalse);
    expect(ids(s.others), ['a', 'b', 'c', 'd']);
  });

  test('everything pinned → empty rest', () {
    final s = TimelineSections.split(feed, const {'a', 'b', 'c', 'd'});
    expect(ids(s.pinned), ['a', 'b', 'c', 'd']);
    expect(s.others, isEmpty);
  });
}
