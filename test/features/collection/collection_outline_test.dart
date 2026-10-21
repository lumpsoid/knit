import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_outline.dart';

void main() {
  FeedCard card(
    String id, {
    CardKind kind = CardKind.text,
    String? text,
    String? fileName,
    bool emphasized = false,
    bool settled = false,
  }) => FeedCard(
    id: id,
    kind: kind,
    position: 'a0',
    text: text,
    fileName: fileName,
    emphasizedAt: emphasized ? 1 : null,
    settledAt: settled ? 2 : null,
  );

  group('CollectionOutline.of (§4.2)', () {
    test('lists the emphasized cards only, in feed order', () {
      final outline = CollectionOutline.of([
        card('a', text: 'Intro', emphasized: true),
        card('b', text: 'body'),
        card('c', text: 'Part two', emphasized: true),
      ]);
      expect(outline, const [
        OutlineEntry(cardId: 'a', kind: CardKind.text, label: 'Intro'),
        OutlineEntry(cardId: 'c', kind: CardKind.text, label: 'Part two'),
      ]);
    });

    test('a settled card never heads a section', () {
      final outline = CollectionOutline.of([
        card('a', text: 'Done', emphasized: true, settled: true),
      ]);
      expect(outline, isEmpty);
    });

    test('is empty when nothing is emphasized', () {
      expect(CollectionOutline.of([card('a', text: 'x')]), isEmpty);
      expect(CollectionOutline.of(const []), isEmpty);
    });
  });

  group('CollectionOutline.labelOf', () {
    test('takes the first non-blank line of the text, trimmed', () {
      expect(
        CollectionOutline.labelOf(card('a', text: '\n  Heading  \nmore')),
        'Heading',
      );
    });

    test('falls back to a file or audio card\'s file name', () {
      expect(
        CollectionOutline.labelOf(
          card('a', kind: CardKind.file, fileName: 'report.pdf'),
        ),
        'report.pdf',
      );
      expect(
        CollectionOutline.labelOf(
          card('b', kind: CardKind.audio, text: '  ', fileName: 'memo.m4a'),
        ),
        'memo.m4a',
      );
    });

    test('a caption wins over the file name', () {
      expect(
        CollectionOutline.labelOf(
          card('a', kind: CardKind.file, text: 'Slides', fileName: 'x.pdf'),
        ),
        'Slides',
      );
    });

    test('is null with no text and no name, so the row names the kind', () {
      expect(CollectionOutline.labelOf(card('a', kind: CardKind.image)), null);
      expect(CollectionOutline.labelOf(card('b', text: ' \n ')), null);
      expect(
        CollectionOutline.labelOf(card('c', kind: CardKind.audio)),
        isNull,
      );
    });
  });
}
