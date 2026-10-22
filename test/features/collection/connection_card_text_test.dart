import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/connection_card_text.dart';
import 'package:knit/features/collection/domain/link_tile.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// "+" → Connection with text in the composer (§4.2): the text becomes the
/// card's label, unless it is blank or a bare URL.
void main() {
  const link = (targetKind: ConnectedEntityKind.collection, targetId: 'x');

  CardLinkOut? tileOf(ConnectionCardText text) => LinkTile.targetOf(
    kind: text.kind,
    text: text.label,
    attachmentIds: const [],
    linksOut: const [link],
  );

  test('blank text makes the text-less link block, input untouched', () {
    final text = ConnectionCardText.of('   ');
    expect(text, ConnectionCardText.none);
    expect(text.kind, CardKind.link);
    expect(text.label, isNull);
    expect(text.usesInput, isFalse);
    expect(tileOf(text), link);
  });

  test('a short label is a text card, still drawn as the tile', () {
    final text = ConnectionCardText.of('  Trip ideas \n');
    expect(text.label, 'Trip ideas');
    expect(text.kind, CardKind.text);
    expect(text.usesInput, isTrue);
    expect(tileOf(text), link);
  });

  test('a bare URL is left in the input', () {
    final text = ConnectionCardText.of(' https://example.com/a ');
    expect(text, ConnectionCardText.none);
    expect(text.usesInput, isFalse);
  });

  test('text with a URL in it is still a label', () {
    final text = ConnectionCardText.of('see https://example.com');
    expect(text.label, 'see https://example.com');
  });

  test('a long or multi-line text is still used: a plain card then', () {
    final long = ConnectionCardText.of('x' * (LinkTile.maxLabelLength + 1));
    expect(long.usesInput, isTrue);
    expect(tileOf(long), isNull);

    final lines = ConnectionCardText.of('first\nsecond');
    expect(lines.label, 'first\nsecond');
    expect(lines.kind, CardKind.text);
    expect(tileOf(lines), isNull);
  });
}
