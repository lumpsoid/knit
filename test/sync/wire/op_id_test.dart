import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

void main() {
  group('OpId (§7.3)', () {
    test('format is <id>@<ms>.<counter>.<sig16>', () {
      final id = OpId.build(
        entityId: 'e1',
        hlc: const Hlc(1718020800000, 2),
        sig: 'd4e5f6a7b8c9d0e1ffffffffffffffff',
      );
      expect(id, 'e1@1718020800000.2.d4e5f6a7b8c9d0e1');
    });

    test('sig16 is the first 16 hex chars of the signature', () {
      expect(OpId.sig16('0123456789abcdef0000'), '0123456789abcdef');
      // A short sig is used whole (defensive; real sigs are 128 hex).
      expect(OpId.sig16('abc'), 'abc');
    });

    test('gate 2: a reorder reusing the frozen content HLC mints a DISTINCT '
        'op_id from the edit (§7.3 case 2)', () {
      // Edit and reorder share entity_id + content hlc (reorder freezes hlc_*),
      // but differ in payload → different sig → different sig16 → distinct op_id.
      const hlc = Hlc(1718020800000, 0);
      final editOpId = OpId.build(
        entityId: 'card-1',
        hlc: hlc,
        sig: 'aaaa1111aaaa1111rest',
      );
      final reorderOpId = OpId.build(
        entityId: 'card-1',
        hlc: hlc,
        sig: 'bbbb2222bbbb2222rest',
      );
      expect(editOpId, isNot(reorderOpId));
    });
  });
}
