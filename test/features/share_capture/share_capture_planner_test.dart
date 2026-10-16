import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/ordering/fractional_index.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/share_capture/domain/share_capture_planner.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';

void main() {
  const planner = ShareCapturePlanner();

  SharedFile file(String name, String mime) =>
      SharedFile(path: '/cache/$name', mime: mime, name: name);

  test('one card per item, in the order shared', () {
    final cards = planner.plan([
      const SharedText('hello'),
      file('a.jpg', 'image/jpeg'),
      file('b.m4a', 'audio/mp4'),
      file('c.pdf', 'application/pdf'),
      file('d.mp4', 'video/mp4'),
    ]);
    expect(cards.map((c) => c.kind), [
      CardKind.text,
      CardKind.image,
      CardKind.audio,
      CardKind.file,
      CardKind.file,
    ]);
    expect(cards[0].text, 'hello');
    expect(cards[1].file?.name, 'a.jpg');
  });

  test('positions start at first() in an empty collection and ascend', () {
    final cards = planner.plan([
      const SharedText('a'),
      const SharedText('b'),
      const SharedText('c'),
    ]);
    expect(cards.first.position, FractionalIndex.first());
    final positions = cards.map((c) => c.position).toList();
    expect([...positions]..sort(), positions);
    expect(positions.toSet(), hasLength(3));
  });

  test('cards are appended after the last position', () {
    const last = 'a5';
    final cards = planner.plan([
      const SharedText('a'),
      const SharedText('b'),
    ], lastPosition: last);
    expect(cards[0].position.compareTo(last), greaterThan(0));
    expect(cards[1].position.compareTo(cards[0].position), greaterThan(0));
  });

  test('a bare http(s) URL becomes a link card', () {
    final cards = planner.plan([
      const SharedText('  https://example.com/a?b=1 \n'),
      const SharedText('http://example.org'),
    ]);
    expect(cards.map((c) => c.kind), [CardKind.link, CardKind.link]);
    expect(cards[0].text, 'https://example.com/a?b=1');
  });

  test('text around a URL, or a non-web scheme, stays a text card', () {
    final cards = planner.plan([
      const SharedText('Read this https://example.com'),
      const SharedText('mailto:a@b.c'),
      const SharedText('example.com'),
    ]);
    expect(cards.map((c) => c.kind), everyElement(CardKind.text));
  });

  test('blank text is dropped', () {
    final cards = planner.plan([
      const SharedText('   '),
      const SharedText('kept'),
    ]);
    expect(cards.single.text, 'kept');
    expect(cards.single.position, FractionalIndex.first());
  });
}
