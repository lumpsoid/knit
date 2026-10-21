import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/presentation/widgets/card_image_grid.dart';

/// An image card's several images in its bubble (§4.2).
void main() {
  // A 1×1 transparent PNG, so Image.memory decodes in the test.
  final png = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  Widget grid(List<Uint8List?> images, {ValueChanged<int>? onTap}) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CardImageGrid(
              cardId: 'c1',
              images: images,
              onImageTap: onTap,
            ),
          ),
        ),
      );

  testWidgets('shows up to four tiles; the last says how many more', (
    tester,
  ) async {
    await tester.pumpWidget(grid(List.filled(6, png)));
    expect(find.byType(Image), findsNWidgets(4));
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('four images show them all, with no count', (tester) async {
    await tester.pumpWidget(grid(List.filled(4, png)));
    expect(find.byType(Image), findsNWidgets(4));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('a tap opens the preview on that image', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(grid([png, png, png], onTap: tapped.add));
    await tester.tap(find.byType(Image).at(2));
    expect(tapped, [2]);
  });

  testWidgets('an image still loading does not open the preview', (
    tester,
  ) async {
    final tapped = <int>[];
    await tester.pumpWidget(grid([null, png], onTap: tapped.add));
    await tester.tap(find.byIcon(Icons.image_outlined));
    expect(tapped, isEmpty);
  });

  test('the first image keeps the single-image hero tag', () {
    expect(imageHeroTag('c1'), imageHeroTag('c1', 0));
    expect(imageHeroTag('c1', 1), isNot(imageHeroTag('c1')));
  });
}
