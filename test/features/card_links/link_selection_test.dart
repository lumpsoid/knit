import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// Multi-select "Link to…" (§4.2): each selected card follows the
/// [LinkSource] rule on its own.
void main() {
  const selection = LinkSelection(
    cardIds: ['a', 'b', 'c'],
    collectionId: 'here',
  );

  test('every card links to another collection', () {
    expect(selection.sourcesFor(ConnectedEntityKind.collection, 'there'), [
      'a',
      'b',
      'c',
    ]);
    expect(selection.canLinkToCollection('there'), isTrue);
  });

  test('none links to its own collection', () {
    expect(selection.sourcesFor(ConnectedEntityKind.collection, 'here'), []);
    expect(selection.canLinkToCollection('here'), isFalse);
  });

  test('a selected card picked as the target is skipped, the rest link', () {
    expect(selection.sourcesFor(ConnectedEntityKind.card, 'b'), ['a', 'c']);
    expect(selection.canLinkToCard('b'), isTrue);
  });

  test('any other card is linked from all, in order', () {
    expect(selection.sourcesFor(ConnectedEntityKind.card, 'x'), [
      'a',
      'b',
      'c',
    ]);
  });

  test('a lone selected card is not its own target', () {
    const one = LinkSelection(cardIds: ['a'], collectionId: 'here');
    expect(one.sourcesFor(ConnectedEntityKind.card, 'a'), isEmpty);
    expect(one.canLinkToCard('a'), isFalse);
  });

  test('no ✓ (no single source card), and a new collection is offered', () {
    expect(selection.linkedFrom, isNull);
    expect(selection.offersNewCollection, isTrue);
  });

  test('only "Link from my card…" offers no new collection', () {
    expect(const LinkFromMine(targetCardId: 'x').offersNewCollection, isFalse);
    expect(
      const LinkSource(cardId: 'a', collectionId: 'here').offersNewCollection,
      isTrue,
    );
    expect(
      const NewConnection(collectionId: 'here').offersNewCollection,
      isTrue,
    );
  });
}
