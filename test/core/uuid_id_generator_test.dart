import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/ids/id_generator.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';

void main() {
  final IdGenerator ids = const UuidIdGenerator();

  final v7 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('mints RFC-9562 UUIDv7 strings', () {
    for (var i = 0; i < 100; i++) {
      expect(ids.newId(), matches(v7));
    }
  });

  test('ids are distinct', () {
    final set = {for (var i = 0; i < 1000; i++) ids.newId()};
    expect(set.length, 1000);
  });

  test('ids are time-ordered (v7 timestamp prefix sorts ascending)', () async {
    final first = ids.newId();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final later = ids.newId();
    expect(first.compareTo(later) < 0, isTrue);
  });
}
