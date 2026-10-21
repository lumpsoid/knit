import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:knit/features/collection/presentation/widgets/composer_previews.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The staged photo's size line and "Optimize size" chip.
void main() {
  final bytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 8, height: 8)),
  );

  Future<void> pump(WidgetTester tester, PendingImagePreview preview) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: preview),
        ),
      );

  final size = '${bytes.length} B';

  testWidgets('shows the size and a chip that turns it on', (tester) async {
    bool? changed;
    await pump(
      tester,
      PendingImagePreview(
        bytes: bytes,
        onClear: () {},
        onOptimizeChanged: (value) => changed = value,
      ),
    );
    expect(find.text(size), findsOneWidget);
    await tester.tap(find.text('Optimize size'));
    expect(changed, isTrue);
  });

  testWidgets('once optimized, shows what it saves', (tester) async {
    await pump(
      tester,
      PendingImagePreview(
        bytes: bytes,
        onClear: () {},
        optimize: true,
        optimizedSize: 20,
        onOptimizeChanged: (_) {},
      ),
    );
    expect(find.text('$size → 20 B'), findsOneWidget);
  });

  testWidgets('while optimizing, the chip waits', (tester) async {
    await pump(
      tester,
      PendingImagePreview(
        bytes: bytes,
        onClear: () {},
        optimize: true,
        optimizing: true,
        onOptimizeChanged: (_) {},
      ),
    );
    expect(find.text('$size · Optimizing…'), findsOneWidget);
    expect(
      tester.widget<FilterChip>(find.byType(FilterChip)).onSelected,
      isNull,
    );
  });

  testWidgets('a format it cannot optimize has no chip', (tester) async {
    await pump(tester, PendingImagePreview(bytes: bytes, onClear: () {}));
    expect(find.byType(FilterChip), findsNothing);
  });
}
