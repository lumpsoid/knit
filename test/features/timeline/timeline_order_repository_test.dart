import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/timeline/domain/timeline_order.dart';
import 'package:knit/features/timeline/domain/timeline_order_repository.dart';
import 'package:knit/features/timeline/infra/in_memory_timeline_order_repository.dart';
import 'package:knit/features/timeline/infra/shared_preferences_timeline_order_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The same manual-order store contract, asserted against both impls.
void main() {
  final impls =
      <
        String,
        Future<(TimelineOrderReadRepository, TimelineOrderWriteRepository)>
        Function()
      >{
        'in-memory': () async {
          final r = InMemoryTimelineOrderRepository();
          return (r, r);
        },
        'shared_preferences': () async {
          SharedPreferences.setMockInitialValues({});
          const r = SharedPreferencesTimelineOrderRepository();
          return (r, r);
        },
      };

  for (final MapEntry(key: name, value: make) in impls.entries) {
    group(name, () {
      test('starts empty', () async {
        final (read, _) = await make();
        final order = (await read.loadOrder()).getOrThrow();
        expect(order.ids, isEmpty);
        expect(order.isManual, isFalse);
      });

      test('save then load round-trips the ids in order', () async {
        final (read, write) = await make();
        final saved = (await write.saveOrder(
          const TimelineOrder(['c', 'a', 'b']),
        )).getOrThrow();
        expect(saved.ids, ['c', 'a', 'b']);
        expect((await read.loadOrder()).getOrThrow().ids, ['c', 'a', 'b']);
      });

      test('a save replaces the previous order', () async {
        final (read, write) = await make();
        await write.saveOrder(const TimelineOrder(['a', 'b']));
        await write.saveOrder(const TimelineOrder(['b']));
        expect((await read.loadOrder()).getOrThrow().ids, ['b']);
      });

      test('saving an empty order clears it', () async {
        final (read, write) = await make();
        await write.saveOrder(const TimelineOrder(['a']));
        await write.saveOrder(const TimelineOrder());
        expect((await read.loadOrder()).getOrThrow().ids, isEmpty);
      });
    });
  }

  group('shared_preferences storage', () {
    const key = 'timeline.collectionOrder';

    test('an empty save removes the key', () async {
      SharedPreferences.setMockInitialValues({});
      const repo = SharedPreferencesTimelineOrderRepository();
      await repo.saveOrder(const TimelineOrder(['a']));
      await repo.saveOrder(const TimelineOrder());
      expect((await SharedPreferences.getInstance()).containsKey(key), isFalse);
    });

    test('a save stores the ids as a string list', () async {
      SharedPreferences.setMockInitialValues({});
      const repo = SharedPreferencesTimelineOrderRepository();
      await repo.saveOrder(const TimelineOrder(['a']));
      expect((await SharedPreferences.getInstance()).getStringList(key), ['a']);
    });
  });
}
