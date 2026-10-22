import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/domain/link_chip.dart';
import 'package:knit/features/collection/domain/link_tile.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// The link chips under a card bubble (§4.2): which links become chips, their
/// order, the "+N" cap and where a tap goes.
void main() {
  CardLinkOut toCollection(String id) =>
      (targetKind: ConnectedEntityKind.collection, targetId: id);
  CardLinkOut toCard(String id) =>
      (targetKind: ConnectedEntityKind.card, targetId: id);

  const collections = <String, LinkedCollection>{
    'trips': (title: 'Trips', archived: false),
    'old': (title: 'Old', archived: true),
  };
  const cards = <String, LinkedCard>{
    'lisbon': (
      kind: 'text',
      preview: 'Lisbon',
      collectionId: 'trips',
      archived: false,
    ),
  };

  List<LinkChip> chipsOf(List<CardLinkOut> linksOut, {bool hasTile = false}) =>
      LinkChip.allOf(
        linksOut: linksOut,
        hasTile: hasTile,
        collections: collections,
        cards: cards,
      );

  group('LinkChip.allOf', () {
    test('a link to a live collection or card becomes its chip', () {
      expect(chipsOf([toCollection('trips'), toCard('lisbon')]), [
        const CollectionLinkChip(collectionId: 'trips', title: 'Trips'),
        const CardLinkChip(
          cardId: 'lisbon',
          cardKind: 'text',
          collectionId: 'trips',
          preview: 'Lisbon',
        ),
      ]);
    });

    test('an archived target makes an archived chip', () {
      expect(chipsOf([toCollection('old')]), [
        const CollectionLinkChip(
          collectionId: 'old',
          title: 'Old',
          archived: true,
        ),
      ]);
    });

    test('a missing target is broken, after the live ones', () {
      expect(
        chipsOf([
          toCard('gone'),
          toCollection('trips'),
          (targetKind: ConnectedEntityKind.unknown, targetId: 'x'),
        ]),
        [
          const CollectionLinkChip(collectionId: 'trips', title: 'Trips'),
          const BrokenLinkChip(),
          const BrokenLinkChip(),
        ],
      );
    });

    test('a Connection card\'s tile stands for its link: no chips', () {
      expect(chipsOf([toCollection('trips')], hasTile: true), isEmpty);
    });

    test('one chip per pair', () {
      expect(chipsOf([toCollection('trips'), toCollection('trips')]), [
        const CollectionLinkChip(collectionId: 'trips', title: 'Trips'),
      ]);
    });
  });

  group('LinkChipRow', () {
    const a = CollectionLinkChip(collectionId: 'a', title: 'A');
    const b = CollectionLinkChip(collectionId: 'b', title: 'B');
    const c = BrokenLinkChip();

    test('shows up to two chips and no "+N"', () {
      final row = LinkChipRow.of(const [a, b]);
      expect(row.shown, [a, b]);
      expect(row.more, 0);
      expect(LinkChipRow.of(const []).isEmpty, isTrue);
    });

    test('beyond two, the rest fold into "+N"', () {
      final row = LinkChipRow.of(const [a, b, c, a]);
      expect(row.shown, [a, b]);
      expect(row.more, 2);
      expect(LinkChipRow.moreOpen, const ShowCardConnections());
    });
  });

  group('openFrom', () {
    test('a collection chip opens it', () {
      expect(
        const CollectionLinkChip(
          collectionId: 'trips',
          title: 'Trips',
        ).openFrom('here'),
        const OpenLinkedCollection('trips'),
      );
    });

    test('a card here is revealed in place, one elsewhere opens focused', () {
      const chip = CardLinkChip(
        cardId: 'lisbon',
        cardKind: 'text',
        collectionId: 'trips',
      );
      expect(chip.openFrom('trips'), const RevealCardHere('lisbon'));
      expect(
        chip.openFrom('here'),
        const OpenLinkedCollection('trips', focusCardId: 'lisbon'),
      );
    });

    test('a broken chip opens the card\'s Connections', () {
      expect(
        const BrokenLinkChip().openFrom('here'),
        const ShowCardConnections(),
      );
    });
  });
}
