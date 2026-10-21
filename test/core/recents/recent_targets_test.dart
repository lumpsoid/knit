import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/recents/recents.dart';

void main() {
  group('RecentTargets.touched', () {
    test('puts a new id first', () {
      expect(const RecentTargets(['a', 'b']).touched('c').ids, ['c', 'a', 'b']);
    });

    test('moves a known id to the front without repeating it', () {
      expect(const RecentTargets(['a', 'b', 'c']).touched('b').ids, [
        'b',
        'a',
        'c',
      ]);
    });

    test('keeps at most the stored count, dropping the oldest', () {
      var recents = const RecentTargets();
      for (final id in ['1', '2', '3', '4', '5', '6']) {
        recents = recents.touched(id);
      }
      expect(recents.ids, hasLength(RecentTargets.stored));
      expect(recents.ids, ['6', '5', '4', '3', '2']);
    });
  });

  group('RecentTargets.among', () {
    String idOf(String id) => id;

    test('keeps recency order, not the offered order', () {
      expect(const RecentTargets(['c', 'a']).among(['a', 'b', 'c'], idOf), [
        'c',
        'a',
      ]);
    });

    test('drops ids the picker would not offer', () {
      expect(
        const RecentTargets(['gone', 'a', 'current']).among(['a', 'b'], idOf),
        ['a'],
      );
    });

    test('shows at most the shown count', () {
      expect(
        const RecentTargets([
          'a',
          'b',
          'c',
          'd',
        ]).among(['a', 'b', 'c', 'd'], idOf),
        hasLength(RecentTargets.shown),
      );
    });

    test('is empty with nothing remembered or nothing offered', () {
      expect(const RecentTargets().among(['a'], idOf), isEmpty);
      expect(const RecentTargets(['a']).among(<String>[], idOf), isEmpty);
    });
  });

  group('InMemoryRecentTargetsRepository', () {
    test('keeps one list per purpose', () async {
      final repo = InMemoryRecentTargetsRepository();
      await repo.record(RecentPurpose.move, 'm1');
      await repo.record(RecentPurpose.link, 'l1');
      await repo.record(RecentPurpose.move, 'm2');
      expect((await repo.load(RecentPurpose.move)).getOrThrow().ids, [
        'm2',
        'm1',
      ]);
      expect((await repo.load(RecentPurpose.link)).getOrThrow().ids, ['l1']);
    });

    test('starts empty', () async {
      final repo = InMemoryRecentTargetsRepository();
      expect((await repo.load(RecentPurpose.move)).getOrThrow().ids, isEmpty);
    });
  });
}
