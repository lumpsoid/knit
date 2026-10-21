import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/domain/collection_link_tile.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// Which cards the feed draws as a collection-link tile, and what it says
/// (§4.2).
void main() {
  const toTrips = (
    targetKind: ConnectedEntityKind.collection,
    targetId: 'trips',
  );
  const toCard = (targetKind: ConnectedEntityKind.card, targetId: 'c9');

  String? targetOf({
    CardKind kind = CardKind.text,
    String? text = 'Trips',
    List<String> attachmentIds = const [],
    List<CardLinkOut> linksOut = const [toTrips],
  }) => CollectionLinkTile.targetOf(
    kind: kind,
    text: text,
    attachmentIds: attachmentIds,
    linksOut: linksOut,
  );

  group('targetOf', () {
    test('a short label linking to one collection is a tile', () {
      expect(targetOf(), 'trips');
      expect(targetOf(text: '  see also: trips  '), 'trips');
      expect(targetOf(text: ''), 'trips');
    });

    test('a link card qualifies only without a URL', () {
      // The Connection block's shape (§6.4): no text, one edge out.
      expect(targetOf(kind: CardKind.link, text: null), 'trips');
      expect(targetOf(kind: CardKind.link, text: '  '), 'trips');
      expect(targetOf(kind: CardKind.link, text: 'https://x.org'), isNull);
    });

    test('a note is more than a link', () {
      expect(targetOf(text: 'line one\nline two'), isNull);
      expect(
        targetOf(text: 'x' * (CollectionLinkTile.maxLabelLength + 1)),
        isNull,
      );
      expect(targetOf(text: 'x' * CollectionLinkTile.maxLabelLength), 'trips');
    });

    test('media cards, and cards with attachments, are not tiles', () {
      expect(targetOf(kind: CardKind.image, text: null), isNull);
      expect(targetOf(kind: CardKind.file, text: null), isNull);
      expect(targetOf(attachmentIds: const ['att-1']), isNull);
    });

    test('exactly one link out, and it must point at a collection', () {
      expect(targetOf(linksOut: const []), isNull);
      expect(targetOf(linksOut: const [toCard]), isNull);
      expect(targetOf(linksOut: const [toTrips, toCard]), isNull);
      expect(targetOf(linksOut: const [toTrips, toTrips]), isNull);
    });
  });

  group('of', () {
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
    });

    test('the card\'s text is a caption only when it adds something', () {
      expect(tile(null).caption, isNull);
      expect(tile('  ').caption, isNull);
      expect(tile(' trips ').caption, isNull);
      expect(tile('Next summer').caption, 'Next summer');
    });
  });
}
