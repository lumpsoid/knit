import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/domain/slide_planner.dart';

PresentCard _img(String id, {bool emphasized = false}) =>
    PresentCard(id: id, kind: CardKind.image, emphasized: emphasized);

PresentCard _txt(String id, {bool emphasized = false, bool settled = false}) =>
    PresentCard(
      id: id,
      kind: CardKind.text,
      text: id,
      emphasized: emphasized,
      settled: settled,
    );

PresentCard _audio(String id) => PresentCard(id: id, kind: CardKind.audio);

SlideDeck _plan(List<PresentCard> cards) => const SlidePlanner().plan(
  PresentSource(
    collectionId: 'col',
    title: 'Old town',
    description: 'A walk',
    coverAttachmentId: 'cover',
    cards: cards,
  ),
);

/// The card ids of each card slide, title slide left out.
List<List<String>> _ids(SlideDeck deck) => [
  for (final s in deck.slides.skip(1))
    [for (final c in (s as CardSlide).cards) c.id],
];

void main() {
  test('slide 0 is the title slide, even for an empty collection', () {
    final deck = _plan(const []);
    expect(deck.length, 1);
    final title = deck.slides.single as TitleSlide;
    expect(title.title, 'Old town');
    expect(title.description, 'A walk');
    expect(title.coverAttachmentId, 'cover');
  });

  test('an image opens a slide and the notes after it join it', () {
    final deck = _plan([
      _img('gate'),
      _txt('built'),
      _audio('story'),
      _img('square'),
      _txt('market'),
    ]);
    expect(_ids(deck), [
      ['gate', 'built', 'story'],
      ['square', 'market'],
    ]);
    final first = deck.slides[1] as CardSlide;
    expect(first.images.map((c) => c.id), ['gate']);
    expect(first.notes.map((c) => c.id), ['built', 'story']);
  });

  test('consecutive images share one slide (a carousel)', () {
    final deck = _plan([_img('a'), _img('b'), _img('c'), _txt('notes')]);
    expect(_ids(deck), [
      ['a', 'b', 'c', 'notes'],
    ]);
    expect((deck.slides[1] as CardSlide).images.length, 3);
  });

  test('notes before the first image form a text slide', () {
    final deck = _plan([_txt('intro'), _txt('more'), _img('gate')]);
    expect(_ids(deck), [
      ['intro', 'more'],
      ['gate'],
    ]);
  });

  test('settled cards are left out', () {
    final deck = _plan([
      _img('a'),
      _txt('old', settled: true),
      _img('b'),
      _txt('new'),
    ]);
    // With the settled note gone, the two images form one run.
    expect(_ids(deck), [
      ['a', 'b', 'new'],
    ]);
    expect(deck.indexOfCard('old'), isNull);
  });

  test('an emphasized card opens a slide in a text-only collection', () {
    final deck = _plan([
      _txt('intro'),
      _txt('Part 1', emphasized: true),
      _txt('one'),
      _txt('Part 2', emphasized: true),
      _txt('two'),
    ]);
    expect(_ids(deck), [
      ['intro'],
      ['Part 1', 'one'],
      ['Part 2', 'two'],
    ]);
  });

  test('a heading right after images heads them', () {
    final deck = _plan([
      _img('gate'),
      _txt('Old Gate', emphasized: true),
      _txt('built'),
    ]);
    expect(_ids(deck), [
      ['gate', 'Old Gate', 'built'],
    ]);
  });

  test('images right after a lone heading join it', () {
    final deck = _plan([
      _txt('notes'),
      _txt('Old Gate', emphasized: true),
      _img('gate'),
      _img('gate2'),
      _txt('built'),
      _img('square'),
    ]);
    expect(_ids(deck), [
      ['notes'],
      ['Old Gate', 'gate', 'gate2', 'built'],
      ['square'],
    ]);
  });

  test('an emphasized image opens a slide like any image', () {
    final deck = _plan([_txt('intro'), _img('gate', emphasized: true)]);
    expect(_ids(deck), [
      ['intro'],
      ['gate'],
    ]);
  });

  group('SlideDeck', () {
    final deck = _plan([_img('gate'), _txt('built'), _img('square')]);

    test('finds the slide of a card', () {
      expect(deck.indexOfCard('built'), 1);
      expect(deck.indexOfCard('square'), 2);
      expect(deck.indexOfCard('missing'), isNull);
    });

    test('anchors a card slide by its first card, the title by nothing', () {
      expect(deck.anchorOf(0), isNull);
      expect(deck.anchorOf(1), 'gate');
      expect(deck.anchorOf(2), 'square');
    });

    test('resumes only on a card slide that is still presented', () {
      expect(deck.resumeIndex('square'), 2);
      expect(deck.resumeIndex('built'), 1);
      expect(deck.resumeIndex(null), isNull);
      expect(deck.resumeIndex('gone'), isNull);
    });
  });
}
