import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/link_tile.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// Which cards the feed draws as a link tile, what it says, and where a tap
/// goes (§4.2).
void main() {
  const toTrips = (
    targetKind: ConnectedEntityKind.collection,
    targetId: 'trips',
  );
  const toCard = (targetKind: ConnectedEntityKind.card, targetId: 'c9');
  const toUnknown = (targetKind: ConnectedEntityKind.unknown, targetId: 'x');

  CardLinkOut? targetOf({
    CardKind kind = CardKind.text,
    String? text = 'Trips',
    List<String> attachmentIds = const [],
    List<CardLinkOut> linksOut = const [toTrips],
  }) => LinkTile.targetOf(
    kind: kind,
    text: text,
    attachmentIds: attachmentIds,
    linksOut: linksOut,
  );

  group('targetOf', () {
    test('a short label linking to one collection is a tile', () {
      expect(targetOf(), toTrips);
      expect(targetOf(text: '  see also: trips  '), toTrips);
      expect(targetOf(text: ''), toTrips);
    });

    test('a short label linking to one card is a tile too', () {
      expect(targetOf(linksOut: const [toCard]), toCard);
      expect(
        targetOf(kind: CardKind.link, text: null, linksOut: const [toCard]),
        toCard,
      );
    });

    test('a link card qualifies only without a URL', () {
      // The Connection block's shape (§6.4): no text, one edge out.
      expect(targetOf(kind: CardKind.link, text: null), toTrips);
      expect(targetOf(kind: CardKind.link, text: '  '), toTrips);
      expect(targetOf(kind: CardKind.link, text: 'https://x.org'), isNull);
    });

    test('a note is more than a link', () {
      expect(targetOf(text: 'line one\nline two'), isNull);
      expect(targetOf(text: 'x' * (LinkTile.maxLabelLength + 1)), isNull);
      expect(targetOf(text: 'x' * LinkTile.maxLabelLength), toTrips);
    });

    test('media cards, and cards with attachments, are not tiles', () {
      expect(targetOf(kind: CardKind.image, text: null), isNull);
      expect(targetOf(kind: CardKind.file, text: null), isNull);
      expect(targetOf(attachmentIds: const ['att-1']), isNull);
    });

    test('exactly one link out, to a collection or a card', () {
      expect(targetOf(linksOut: const []), isNull);
      expect(targetOf(linksOut: const [toUnknown]), isNull);
      expect(targetOf(linksOut: const [toTrips, toCard]), isNull);
      expect(targetOf(linksOut: const [toCard, toCard]), isNull);
      expect(targetOf(linksOut: const [toTrips, toTrips]), isNull);
    });
  });

  group('CollectionLinkTile.of', () {
    CollectionLinkTile tile(String? cardText) => CollectionLinkTile.of(
      cardText: cardText,
      collectionId: 'trips',
      title: 'Trips',
      cardCount: 4,
      coverAttachmentId: 'cov',
      lastCardKind: 'text',
      lastCardText: 'Lisbon',
      lastCardSettled: true,
    );

    test('carries the target\'s header and newest card', () {
      expect(
        tile(null),
        const CollectionLinkTile(
          collectionId: 'trips',
          title: 'Trips',
          cardCount: 4,
          coverAttachmentId: 'cov',
          lastCardKind: 'text',
          lastCardText: 'Lisbon',
          lastCardSettled: true,
        ),
      );
      expect(tile(null).imageAttachmentId, 'cov');
    });

    test('the card\'s text is a caption only when it adds something', () {
      expect(tile(null).caption, isNull);
      expect(tile('  ').caption, isNull);
      expect(tile(' trips ').caption, isNull);
      expect(tile('Next summer').caption, 'Next summer');
    });

    test('a tap opens the collection, wherever the feed is', () {
      expect(tile(null).openFrom('index'), const OpenLinkedCollection('trips'));
    });
  });

  group('CardLinkTile.of', () {
    CardLinkTile tile({
      String? cardText,
      String kind = 'text',
      String? text = ' Lisbon ',
      String? fileName,
    }) => CardLinkTile.of(
      cardText: cardText,
      cardId: 'c9',
      cardKind: kind,
      collectionId: 'trips',
      collectionTitle: 'Trips',
      text: text,
      fileName: fileName,
    );

    test('previews the target\'s text, else a file\'s name, else nothing', () {
      expect(tile().preview, 'Lisbon');
      expect(
        tile(kind: 'file', text: null, fileName: 'a.pdf').preview,
        'a.pdf',
      );
      expect(tile(kind: 'audio', text: '', fileName: 'm.m4a').preview, 'm.m4a');
      expect(
        tile(kind: 'image', text: null, fileName: 'p.jpg').preview,
        isNull,
      );
      expect(tile(text: '  ').preview, isNull);
    });

    test('the card\'s text is a caption only when it adds something', () {
      expect(tile().caption, isNull);
      expect(tile(cardText: 'lisbon').caption, isNull);
      expect(tile(cardText: 'Where we met').caption, 'Where we met');
    });

    test(
      'a card here is revealed in place; elsewhere, its collection opens',
      () {
        expect(tile().openFrom('trips'), const RevealCardHere('c9'));
        expect(
          tile().openFrom('index'),
          const OpenLinkedCollection('trips', focusCardId: 'c9'),
        );
      },
    );
  });
}
