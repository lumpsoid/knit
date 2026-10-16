import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/timeline/domain/timeline_pin_repository.dart';
import 'package:knit/features/timeline/infra/in_memory_timeline_pin_repository.dart';
import 'package:knit/features/timeline/infra/shared_preferences_timeline_pin_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The same pin-store contract, asserted against both impls.
void main() {
  final impls =
      <
        String,
        Future<(TimelinePinReadRepository, TimelinePinWriteRepository)>
        Function()
      >{
        'in-memory': () async {
          final r = InMemoryTimelinePinRepository();
          return (r, r);
        },
        'shared_preferences': () async {
          SharedPreferences.setMockInitialValues({});
          const r = SharedPreferencesTimelinePinRepository();
          return (r, r);
        },
      };

  for (final MapEntry(key: name, value: make) in impls.entries) {
    group(name, () {
      test('starts empty', () async {
        final (read, _) = await make();
        expect((await read.loadPinned()).getOrThrow(), isEmpty);
      });

      test('pin then unpin round-trips and returns the full set', () async {
        final (read, write) = await make();
        expect((await write.setPinned('a', pinned: true)).getOrThrow(), {'a'});
        expect((await write.setPinned('b', pinned: true)).getOrThrow(), {
          'a',
          'b',
        });
        expect((await read.loadPinned()).getOrThrow(), {'a', 'b'});
        expect((await write.setPinned('a', pinned: false)).getOrThrow(), {'b'});
        expect((await read.loadPinned()).getOrThrow(), {'b'});
      });

      test('pinning twice / unpinning an unpinned id is a no-op', () async {
        final (read, write) = await make();
        await write.setPinned('a', pinned: true);
        await write.setPinned('a', pinned: true);
        await write.setPinned('zzz', pinned: false);
        expect((await read.loadPinned()).getOrThrow(), {'a'});
      });
    });
  }
}
