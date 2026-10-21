import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/connections/domain/unlinked_mentions.dart';

/// The §8.6.5 unlinked-mention rule: the folded title as a whole phrase on word
/// boundaries, only cards a link may come from, newest first, capped.
void main() {
  MentionCandidate card(
    String id,
    String text, {
    String collectionId = 'other',
    int at = 1000,
    bool canLink = true,
  }) => MentionCandidate(
    cardId: id,
    collectionId: collectionId,
    collectionTitle: 'Other',
    text: text,
    updatedAtMs: at,
    canLink: canLink,
  );

  List<String> find(
    String title,
    List<MentionCandidate> cards, {
    Set<String> linked = const {},
  }) => [
    for (final m in UnlinkedMentionFinder.find(
      collectionId: 'focus',
      title: title,
      corpus: MentionCorpus(cards: cards, linkedCardIds: linked),
    ).items)
      m.cardId,
  ];

  test('matches the title as a whole phrase, folding case and accents', () {
    expect(
      find('Café Plans', [
        card('a', 'Booked the CAFE plans today'),
        card('b', 'cafe\n  plans across lines'),
        card('c', 'café without the other word'),
      ]),
      ['a', 'b'],
    );
  });

  test('needs word boundaries on both edges', () {
    expect(
      find('Trip', [
        card('a', 'the trip was long'),
        card('b', 'tripod and stripes'),
        card('c', 'trip.'),
        card('d', 'Trip'),
      ]),
      unorderedEquals(['a', 'c', 'd']),
    );
  });

  test('folds ё to е, as search does', () {
    expect(find('Ёлка', [card('a', 'купить елку? нет, елка')]), ['a']);
  });

  test('skips titles too short or a single common word', () {
    final cards = [card('a', 'go to the new notes on it')];
    expect(find('it', cards), isEmpty);
    expect(find('  Go ', cards), isEmpty);
    expect(find('Notes', cards), isEmpty);
    expect(find('New', cards), isEmpty);
    // Common words are fine inside a longer title.
    expect(find('new notes', cards), ['a']);
  });

  test('leaves out linked cards, own-collection cards and imported ones', () {
    expect(
      find(
        'Kyoto',
        [
          card('linked', 'Kyoto'),
          card('inside', 'Kyoto', collectionId: 'focus'),
          card('foreign', 'Kyoto', canLink: false),
          card('ok', 'Kyoto'),
        ],
        linked: {'linked'},
      ),
      ['ok'],
    );
  });

  test('lists newest first and counts the rest past the cap', () {
    final cards = [
      for (var i = 0; i < UnlinkedMentionFinder.limit + 3; i++)
        card('c$i', 'kyoto $i', at: i),
    ];
    final result = UnlinkedMentionFinder.find(
      collectionId: 'focus',
      title: 'Kyoto',
      corpus: MentionCorpus(cards: cards, linkedCardIds: const {}),
    );
    expect(result.items, hasLength(UnlinkedMentionFinder.limit));
    expect(result.items.first.cardId, 'c${UnlinkedMentionFinder.limit + 2}');
    expect(result.more, 3);
    expect(result.without(result.items.first.cardId).items, hasLength(19));
  });

  test('the preview starts near a late mention', () {
    final text = '${'word ' * 20}then Kyoto at last';
    final preview = UnlinkedMentionFinder.find(
      collectionId: 'focus',
      title: 'Kyoto',
      corpus: MentionCorpus(cards: [card('a', text)], linkedCardIds: const {}),
    ).items.single.preview;
    expect(preview, startsWith('…'));
    expect(preview, endsWith('then Kyoto at last'));
    expect(preview.length, lessThan(text.length));
  });
}
