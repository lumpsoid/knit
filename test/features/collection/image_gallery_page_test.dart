import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/presentation/image_gallery_page.dart';
import 'package:knit/l10n/app_localizations.dart';

/// A 1×1 transparent PNG — enough for `Image.memory` to decode.
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

List<GalleryImage> _images(int n) => [
  for (var i = 0; i < n; i++)
    GalleryImage(bytes: _png, heroTag: 'img-$i', caption: 'caption $i'),
];

Future<void> _pumpGallery(WidgetTester tester, {int initialIndex = 0}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ImageGalleryPage(images: _images(3), initialIndex: initialIndex),
    ),
  );
  await tester.pumpAndSettle();
}

/// The scale of the (single, settled) page's viewer.
double _scale(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value
    .getMaxScaleOnAxis();

Future<void> _doubleTapAt(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(kDoubleTapMinTime);
  await tester.tapAt(at);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the initial image with its caption', (tester) async {
    await _pumpGallery(tester, initialIndex: 1);
    expect(find.text('caption 1'), findsOneWidget);
  });

  testWidgets('swiping at 1x pages between images', (tester) async {
    await _pumpGallery(tester);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('caption 1'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('caption 0'), findsOneWidget);
  });

  testWidgets('double-tap toggles zoom', (tester) async {
    await _pumpGallery(tester);
    final center = tester.getCenter(find.byType(PageView));

    await _doubleTapAt(tester, center);
    expect(_scale(tester), closeTo(2.5, 0.001));

    await _doubleTapAt(tester, center);
    expect(_scale(tester), closeTo(1, 0.001));
  });

  testWidgets('while zoomed away from an edge, a drag pans instead of paging', (
    tester,
  ) async {
    await _pumpGallery(tester, initialIndex: 1);
    final center = tester.getCenter(find.byType(PageView));
    await _doubleTapAt(tester, center);

    await tester.dragFrom(center, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(find.text('caption 1'), findsOneWidget);
    expect(_scale(tester), closeTo(2.5, 0.001));
  });

  testWidgets(
    'an outward swipe at a zoomed edge turns the page, which reopens at 1x',
    (tester) async {
      await _pumpGallery(tester, initialIndex: 1);
      final box = tester.getRect(find.byType(PageView));
      // Zoom around the left edge so the image's left edge is flush.
      await _doubleTapAt(tester, Offset(box.left, box.center.dy));
      expect(_scale(tester), closeTo(2.5, 0.001));

      await tester.dragFrom(
        Offset(box.left + 20, box.center.dy),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('caption 0'), findsOneWidget);
      expect(_scale(tester), closeTo(1, 0.001));

      // Back to the image that was zoomed: it starts over at 1x.
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('caption 1'), findsOneWidget);
      expect(_scale(tester), closeTo(1, 0.001));
    },
  );

  testWidgets('a single tap keeps the viewer; close dismisses it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(ImageGalleryPage.route(images: _images(2))),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageGalleryPage), findsOneWidget);

    // A single tap resolves only once the double-tap window has passed.
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(find.byType(ImageGalleryPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(ImageGalleryPage), findsNothing);
  });
}
