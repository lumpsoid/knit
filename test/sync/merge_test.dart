import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

// --- Snapshot builders for tests -------------------------------------------

const _authorA = 'aa11'; // lower byte sequence
const _authorB = 'bb22'; // higher byte sequence

Snapshot collection({
  String id = 'col-1',
  String author = _authorA,
  String? createdBy,
  required int hlcMs,
  int hlcCounter = 0,
  bool deleted = false,
  String sig = 'sig0',
  String title = 'untitled',
}) =>
    Snapshot(
      type: EntityType.collection,
      id: id,
      author: author,
      createdBy: createdBy ?? author,
      createdAt: 1000,
      hlc: Hlc(hlcMs, hlcCounter),
      deleted: deleted,
      sig: sig,
      content: {'title': title, 'cover_attachment_id': null},
    );

Snapshot card({
  String id = 'card-1',
  String collectionId = 'col-1',
  String author = _authorA,
  String? createdBy,
  required int hlcMs,
  int hlcCounter = 0,
  bool deleted = false,
  String sig = 'sig0',
  String text = '',
  String position = 'a0',
  int posMs = 1000,
  int posCounter = 0,
}) =>
    Snapshot(
      type: EntityType.card,
      id: id,
      author: author,
      createdBy: createdBy ?? author,
      createdAt: 1000,
      hlc: Hlc(hlcMs, hlcCounter),
      deleted: deleted,
      sig: sig,
      placement: Hlc(posMs, posCounter),
      position: position,
      content: {'collection_id': collectionId, 'kind': 'text', 'text': text},
    );

void main() {
  group('content comparator (spec §6.9 / §8.5)', () {
    test('higher HLC wins', () {
      final a = collection(hlcMs: 200, title: 'new');
      final b = collection(hlcMs: 100, title: 'old');
      expect(compareContent(a, b) > 0, isTrue);
      expect(merge(b, a).content['title'], 'new');
      expect(merge(a, b).content['title'], 'new', reason: 'order-independent');
    });

    test('equal HLC → author is the meaningful tiebreak', () {
      final a = collection(hlcMs: 100, author: _authorB, title: 'B');
      final b = collection(hlcMs: 100, author: _authorA, title: 'A');
      expect(compareContent(a, b) > 0, isTrue);
      expect(merge(b, a).content['title'], 'B');
    });

    test('equal HLC and author → sig is the total-order backstop', () {
      // Same keypair on two devices, same ms: equal author, distinct sig.
      final a = collection(hlcMs: 100, sig: 'ffff', title: 'hi-sig');
      final b = collection(hlcMs: 100, sig: '0000', title: 'lo-sig');
      expect(compareContent(a, b) > 0, isTrue);
      expect(merge(b, a).content['title'], 'hi-sig');
    });

    test('byte-identical resend is idempotent (keeps current)', () {
      final a = collection(hlcMs: 100, sig: 'same');
      final again = collection(hlcMs: 100, sig: 'same');
      final merged = merge(a, again);
      expect(identical(merged, a), isTrue);
    });

    test('created_by is not a comparator input and rides the winner unchanged', () {
      // Original creator A; editor B authors a higher-HLC version but must
      // preserve created_by = A (spec §6.2 honesty rule, modelled by the build).
      final original = collection(hlcMs: 100, author: _authorA);
      final edit = collection(
          hlcMs: 200, author: _authorB, createdBy: _authorA, title: 'edited');
      final won = merge(original, edit);
      expect(won.content['title'], 'edited');
      expect(won.author, _authorB);
      expect(won.createdBy, _authorA, reason: 'original creator preserved');
    });
  });

  group('delete vs edit (spec §6.9 — later HLC wins)', () {
    test('later delete tombstones an earlier edit', () {
      final edit = collection(hlcMs: 100, title: 'live');
      final del = collection(hlcMs: 200, deleted: true, title: 'live');
      expect(merge(edit, del).deleted, isTrue);
    });

    test('a late edit resurrects a deleted row', () {
      final del = collection(hlcMs: 100, deleted: true);
      final lateEdit = collection(hlcMs: 200, deleted: false, title: 'back');
      final merged = merge(del, lateEdit);
      expect(merged.deleted, isFalse);
      expect(merged.content['title'], 'back');
    });
  });

  group('reorder vs content blend (spec §7.6 / §8.4)', () {
    test('concurrent reorder and text edit each keep their dimension', () {
      // Base card on both devices.
      final base = card(hlcMs: 100, posMs: 100, text: 'orig', position: 'a0');

      // Device A: edit text → fresh content HLC, placement frozen.
      final textEdit = card(
          hlcMs: 200, posMs: 100, text: 'edited', position: 'a0', sig: 'edit');

      // Device B: reorder → fresh placement HLC, content HLC frozen at base.
      final reorder = card(
          hlcMs: 100, posMs: 300, text: 'orig', position: 'a5', sig: 'move');

      var p = Projection()..apply(base);
      p.apply(textEdit);
      p.apply(reorder);
      final row = p['card-1']!;

      // Content winner = textEdit; placement winner = reorder. Blended row.
      expect(row.content['text'], 'edited', reason: 'text edit preserved');
      expect(row.position, 'a5', reason: 'reorder preserved');
      expect(row.sig, 'edit', reason: 'sig reflects content winner (spec §7.6)');
    });

    test('a stale drag (frozen content HLC) cannot clobber a newer text edit', () {
      final textEdit = card(hlcMs: 500, posMs: 100, text: 'keep-me', position: 'a0');
      // Reorder carries the OLD content snapshot; its hlc_* stayed frozen low.
      final staleReorder =
          card(hlcMs: 100, posMs: 600, text: 'stale', position: 'b0', sig: 'r');
      final merged = merge(textEdit, staleReorder);
      expect(merged.content['text'], 'keep-me', reason: 'content edit survives');
      expect(merged.position, 'b0', reason: 'but the placement still applies');
    });
  });

  group('feed order (spec §8.7)', () {
    test('orders by position then id, excludes tombstones', () {
      final p = Projection()
        ..apply(card(id: 'c-b', position: 'a2', hlcMs: 1))
        ..apply(card(id: 'c-a', position: 'a1', hlcMs: 1))
        // Identical position on different cards → id breaks the tie.
        ..apply(card(id: 'c-z', position: 'a1', hlcMs: 1))
        ..apply(card(id: 'c-d', position: 'a9', hlcMs: 1, deleted: true));

      final ids = p.feed('col-1').map((s) => s.id).toList();
      expect(ids, ['c-a', 'c-z', 'c-b'], reason: 'position asc, id asc, no tombstone');
    });
  });
}
