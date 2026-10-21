import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

import 'op_builders.dart';

/// An image card's several images (§4.2): `attachment_id` plus the ordered
/// `more_attachment_ids`, encoded as one signed string (§7.1).
void main() {
  group('CardSchema more_attachment_ids', () {
    test('round-trips an ordered list; none encodes to null', () {
      final encoded = CardSchema.encodeMoreAttachmentIds(['b', 'a', 'c']);
      expect(CardSchema.decodeMoreAttachmentIds(encoded), ['b', 'a', 'c']);
      expect(CardSchema.encodeMoreAttachmentIds(const []), isNull);
      expect(CardSchema.decodeMoreAttachmentIds(null), isEmpty);
      expect(CardSchema.decodeMoreAttachmentIds(''), isEmpty);
    });

    test('attachmentIdsOf lists the first image, then the rest', () {
      final c = card(
        hlcMs: 1,
        kind: 'image',
        attachmentId: 'a1',
        moreAttachmentIds: ['a2', 'a3'],
      );
      expect(CardSchema.attachmentIdsOf(c.content), ['a1', 'a2', 'a3']);
      expect(CardSchema.attachmentIdsOf(card(hlcMs: 1).content), isEmpty);
    });

    test('is signed: the canonical card payload carries it', () {
      final c = card(
        hlcMs: 1,
        kind: 'image',
        attachmentId: 'a1',
        moreAttachmentIds: ['a2', 'a3'],
      );
      expect(
        CanonicalSerializer.string(c),
        contains('"more_attachment_ids":"a2,a3"'),
      );
    });
  });

  test('a collection share scopes every image of its cards', () {
    final scope = ShareScope.of('col-1', [
      card(
        hlcMs: 1,
        kind: 'image',
        attachmentId: 'a1',
        moreAttachmentIds: ['a2', 'a3'],
      ),
    ]);
    expect(scope.attachmentIds, {'a1', 'a2', 'a3'});
  });

  test('a SyncStore write keeps the images through the projection', () async {
    final store = SyncStore.inMemory(signer: FakeSigner(identitySeed: 'mira'));
    await store.open();
    await store.create(EntityType.card, 'c1', {
      'collection_id': 'col-1',
      'kind': 'image',
      'attachment_id': 'a1',
      'more_attachment_ids': CardSchema.encodeMoreAttachmentIds(['a2']),
    }, position: 'a0');
    final row = await store.get(EntityType.card, 'c1');
    expect(CardSchema.attachmentIdsOf(row!.content), ['a1', 'a2']);
  });
}
