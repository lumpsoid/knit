import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

// The §9.1 gate-5 property: replaying change_log in *any* order through the
// merge comparator yields the identical projection. That order-independence
// *is* local-first (spec §8.9).

Snapshot col(int hlcMs, {bool deleted = false, String title = 't'}) => Snapshot(
  type: EntityType.collection,
  id: 'col-1',
  author: 'aa',
  createdBy: 'aa',
  createdAt: 1000,
  hlc: Hlc(hlcMs, 0),
  deleted: deleted,
  sig: 's$hlcMs',
  content: {'title': title, 'cover_attachment_id': null},
);

Snapshot crd(
  String id, {
  required int hlcMs,
  required int posMs,
  String text = '',
  String position = 'a0',
  bool deleted = false,
}) => Snapshot(
  type: EntityType.card,
  id: id,
  author: 'aa',
  createdBy: 'aa',
  createdAt: 1000,
  hlc: Hlc(hlcMs, 0),
  deleted: deleted,
  sig: 's$id$hlcMs$posMs',
  placement: Hlc(posMs, 0),
  position: position,
  content: {'collection_id': 'col-1', 'kind': 'text', 'text': text},
);

void main() {
  test('projection is identical across all arrival orders (spec §8.9)', () {
    // A realistic log: create, edit, reorder, delete, resurrect — with a blend.
    final log = <Snapshot>[
      col(100, title: 'Espresso'),
      crd('c1', hlcMs: 110, posMs: 110, text: 'grind finer', position: 'a0'),
      crd('c2', hlcMs: 120, posMs: 120, text: 'tamp level', position: 'a1'),
      // edit c1 text (content bumps, placement frozen)
      crd(
        'c1',
        hlcMs: 200,
        posMs: 110,
        text: 'grind much finer',
        position: 'a0',
      ),
      // reorder c1 (placement bumps, content frozen at the edit's base)
      crd('c1', hlcMs: 110, posMs: 300, text: 'grind finer', position: 'a5'),
      // delete c2 then resurrect
      crd(
        'c2',
        hlcMs: 220,
        posMs: 120,
        text: 'tamp level',
        position: 'a1',
        deleted: true,
      ),
      crd('c2', hlcMs: 400, posMs: 120, text: 'tamp 30lb', position: 'a1'),
      col(150, title: 'Espresso dialing-in'),
    ];

    final canonical = Projection()..replay(log);

    // Try several permutations; each must reach the same projection.
    final orders = <List<Snapshot>>[
      log.reversed.toList(),
      [log[3], log[4], log[0], log[6], log[1], log[7], log[2], log[5]],
      [for (var i = log.length - 1; i >= 0; i--) log[i]],
      [...log]..shuffle(),
    ];

    String fingerprint(Projection p) {
      final rows = p.rows.toList()..sort((a, b) => a.id.compareTo(b.id));
      return rows
          .map(
            (s) =>
                '${s.id}|hlc=${s.hlc}|pos=${s.position}@${s.placement}|del=${s.deleted}'
                '|sig=${s.sig}|text=${s.content['text'] ?? s.content['title']}',
          )
          .join(';');
    }

    final expected = fingerprint(canonical);
    for (final order in orders) {
      expect(fingerprint(Projection()..replay(order)), expected);
    }

    // Spot-check the merged truth.
    final c1 = canonical['c1']!;
    expect(c1.content['text'], 'grind much finer', reason: 'content winner');
    expect(c1.position, 'a5', reason: 'placement winner (blend, spec §7.6)');
    final c2 = canonical['c2']!;
    expect(c2.deleted, isFalse, reason: 'late edit resurrected');
    expect(c2.content['text'], 'tamp 30lb');
    expect(canonical['col-1']!.content['title'], 'Espresso dialing-in');
  });
}
