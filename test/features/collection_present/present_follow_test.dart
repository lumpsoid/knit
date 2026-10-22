import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_present/domain/present_follow.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/domain/slide_planner.dart';

PresentLink _toCollection(String id) => PresentLink(
  kind: PresentLinkKind.collection,
  id: id,
  label: id,
  collectionId: id,
);

PresentLink _toCard(String id, String collectionId) => PresentLink(
  kind: PresentLinkKind.card,
  id: id,
  label: id,
  collectionId: collectionId,
);

void main() {
  // 'here' is presented over 'bottom': title, [a], [b].
  final deck = const SlidePlanner().plan(
    const PresentSource(
      collectionId: 'here',
      title: 'Here',
      cards: [
        PresentCard(id: 'a', kind: CardKind.image),
        PresentCard(id: 'b', kind: CardKind.image, emphasized: true),
        PresentCard(id: 'gone', kind: CardKind.text, settled: true),
      ],
    ),
  );
  const presented = ['bottom', 'here'];

  PresentFollow follow(PresentLink link) =>
      PresentFollow.of(link, presented: presented, deck: deck);

  test('a card here turns this deck to its slide', () {
    expect(follow(_toCard('a', 'here')), const JumpToSlide(1));
    expect(follow(_toCard('gone', 'here')), const JumpToSlide(1));
  });

  test('this very collection turns to the title slide', () {
    expect(follow(_toCollection('here')), const JumpToSlide(0));
  });

  test('a collection further down is gone back to', () {
    expect(
      follow(_toCollection('bottom')),
      const ReturnToPresentation('bottom'),
    );
    expect(
      follow(_toCard('x', 'bottom')),
      const ReturnToPresentation('bottom', focusCardId: 'x'),
    );
  });

  test('anything else is presented on top', () {
    expect(follow(_toCollection('new')), const PresentOnTop('new'));
    expect(
      follow(_toCard('x', 'new')),
      const PresentOnTop('new', focusCardId: 'x'),
    );
  });
}
