import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/card_edit/domain/card_text_edit.dart';
import 'package:knit/features/collection/domain/collection_link_tile.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// What saving a card's text writes (§4.3), and the Connection card's blank
/// label.
void main() {
  const toTrips = (
    targetKind: ConnectedEntityKind.collection,
    targetId: 'trips',
  );
  const toCard = (targetKind: ConnectedEntityKind.card, targetId: 'c9');

  CardTextEdit? save(
    String text, {
    CardKind kind = CardKind.text,
    List<String> attachmentIds = const [],
    List<CardLinkOut> linksOut = const [],
  }) => CardTextEdit.of(
    kind: kind,
    text: text,
    attachmentIds: attachmentIds,
    linksOut: linksOut,
  );

  test('a plain card saves trimmed text and refuses a blank one', () {
    expect(save('  note  '), const CardTextEdit(text: 'note'));
    expect(save('   '), isNull);
    expect(save('', kind: CardKind.link), isNull);
    expect(save('', linksOut: const [toCard]), isNull);
    expect(save('', linksOut: const [toTrips, toCard]), isNull);
    expect(
      save('', attachmentIds: const ['a'], linksOut: const [toTrips]),
      isNull,
    );
  });

  test('a Connection card may clear its label: back to the link block', () {
    const block = CardTextEdit(text: null, kind: CardKind.link);
    expect(save('  ', linksOut: const [toTrips]), block);
    expect(save('', kind: CardKind.link, linksOut: const [toTrips]), block);
  });

  test('a Connection card\'s label makes it a text card, a URL a link', () {
    expect(
      save(' Trips ', kind: CardKind.link, linksOut: const [toTrips]),
      const CardTextEdit(text: 'Trips', kind: CardKind.text),
    );
    expect(
      save('https://x.org', linksOut: const [toTrips]),
      const CardTextEdit(text: 'https://x.org', kind: CardKind.link),
    );
  });

  test('a media card is never a Connection card', () {
    expect(save('', kind: CardKind.image, linksOut: const [toTrips]), isNull);
  });
}
