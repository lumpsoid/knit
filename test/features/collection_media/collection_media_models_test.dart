import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_media/domain/collection_media_models.dart';

void main() {
  MediaItem item(
    String id,
    CardKind kind,
    DateTime at, {
    String? text,
    String? attachmentId = 'att',
  }) => MediaItem.fromCard(
    cardId: id,
    cardKind: kind,
    capturedAt: at,
    text: text,
    attachmentId: attachmentId,
  )!;

  group('MediaItem.fromCard', () {
    test('text and unknown cards are not media', () {
      for (final kind in [CardKind.text, CardKind.unknown]) {
        expect(
          MediaItem.fromCard(
            cardId: 'c',
            cardKind: kind,
            capturedAt: DateTime(2026),
            text: 'hello',
          ),
          isNull,
        );
      }
    });

    test('an attachment kind without its attachment is dropped', () {
      for (final kind in [CardKind.image, CardKind.audio, CardKind.file]) {
        expect(
          MediaItem.fromCard(
            cardId: 'c',
            cardKind: kind,
            capturedAt: DateTime(2026),
          ),
          isNull,
        );
      }
    });

    test('a link needs a non-blank URL; its url is the trimmed body', () {
      expect(
        MediaItem.fromCard(
          cardId: 'c',
          cardKind: CardKind.link,
          capturedAt: DateTime(2026),
          text: '   ',
        ),
        isNull,
      );
      final link = item(
        'c',
        CardKind.link,
        DateTime(2026),
        text: ' example.com ',
        attachmentId: null,
      );
      expect(link.kind, MediaKind.link);
      expect(link.url, 'example.com');
      expect(link.attachmentId, isNull);
    });

    test('maps card kinds to tabs and back', () {
      expect(item('c', CardKind.image, DateTime(2026)).kind, MediaKind.photo);
      for (final kind in MediaKind.values) {
        expect(MediaKind.fromCardKind(kind.cardKind), kind);
      }
    });

    test('a blank caption reads as null', () {
      expect(
        item('c', CardKind.image, DateTime(2026), text: '  ').caption,
        isNull,
      );
      expect(item('c', CardKind.image, DateTime(2026)).url, isNull);
    });
  });

  group('CollectionMedia', () {
    final media = CollectionMedia([
      item('a', CardKind.image, DateTime(2026, 3, 2)),
      item('b', CardKind.file, DateTime(2026, 5, 1)),
      item('c', CardKind.image, DateTime(2026, 5, 9)),
      item('d', CardKind.link, DateTime(2026, 4, 1), text: 'x.io'),
      item('e', CardKind.image, DateTime(2026, 5, 9)),
    ]);

    test('orders newest first, breaking time ties by card id', () {
      expect(media.items.map((i) => i.cardId), ['e', 'c', 'b', 'd', 'a']);
    });

    test('counts per kind', () {
      final counts = media.counts;
      expect(counts.photos, 3);
      expect(counts.files, 1);
      expect(counts.links, 1);
      expect(counts.audio, 0);
      expect(counts.total, 5);
      expect(counts.of(MediaKind.photo), 3);
      expect(CollectionMedia.empty.counts.isEmpty, isTrue);
    });

    test('recentPhotos takes the newest photos only', () {
      expect(media.recentPhotos(2).map((p) => p.item.cardId), ['e', 'c']);
    });

    test('a card with several images counts and lists each, in order', () {
      final many = CollectionMedia([
        MediaItem.fromCard(
          cardId: 'm',
          cardKind: CardKind.image,
          capturedAt: DateTime(2026, 6),
          attachmentId: 'p1',
          moreAttachmentIds: const ['p2', 'p3'],
        )!,
        item('a', CardKind.image, DateTime(2026, 3, 2)),
      ]);
      expect(many.counts.photos, 4);
      expect(many.photos.map((p) => (p.attachmentId, p.index)), [
        ('p1', 0),
        ('p2', 1),
        ('p3', 2),
        ('att', 0),
      ]);
      expect(many.recentPhotos(2).map((p) => p.attachmentId), ['p1', 'p2']);
    });

    test('byCardId finds an item or returns null', () {
      expect(media.byCardId('d')!.kind, MediaKind.link);
      expect(media.byCardId('zz'), isNull);
    });

    test('byMonth groups under month headers, newest month first', () {
      final months = CollectionMedia.byMonth(media.ofKind(MediaKind.photo));
      expect(months.map((m) => m.month), [
        DateTime(2026, 5),
        DateTime(2026, 3),
      ]);
      expect(months.first.items.map((i) => i.cardId), ['e', 'c']);
      expect(months.last.items.map((i) => i.cardId), ['a']);
      expect(CollectionMedia.byMonth(const []), isEmpty);
    });
  });
}
