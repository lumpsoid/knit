import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:knit/features/audio_playback/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/infra/in_memory_present_progress_repository.dart';
import 'package:knit/features/collection_present/presentation/present_controller.dart';
import 'package:knit/features/collection_present/presentation/present_page.dart';
import 'package:knit/features/collection_present/presentation/present_route_args.dart';
import 'package:knit/features/connections/presentation/connections_route_args.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:result_dart/result_dart.dart';

import 'present_fakes.dart';

/// A smoke test of the presentation page: the title slide, the resume offer,
/// turning slides with the keyboard and the overlay's position.
void main() {
  const source = PresentSource(
    collectionId: 'col',
    title: 'Old town',
    description: 'A walk through it',
    cards: [
      PresentCard(id: 'intro', kind: CardKind.text, text: 'Start at the gate'),
      PresentCard(
        id: 'part',
        kind: CardKind.text,
        text: 'The square',
        emphasized: true,
      ),
      PresentCard(id: 'market', kind: CardKind.text, text: 'Market on Fridays'),
    ],
  );

  late InMemoryPresentProgressRepository progress;

  Future<void> pumpPage(WidgetTester tester) async {
    final attachments = FakeAttachments();
    final controller = PresentController(
      routeArgs: InMemoryPresentRouteArgsStore()..open('col'),
      readRepository: FakePresentRead(const Ok(source)),
      progressReadRepository: progress,
      progressWriteRepository: progress,
      imageCache: AttachmentImageCache(attachmentReadRepository: attachments),
      playback: AudioPlaybackController(
        player: SilentPlayer(),
        attachmentRead: attachments,
      ),
      linkLauncher: FakeLauncher(),
      connectionsRouteArgs: InMemoryConnectionsRouteArgsStore(),
      screenAwake: FakeAwake(),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PresentPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => progress = InMemoryPresentProgressRepository());

  testWidgets('opens on the title slide and turns with the keyboard', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('Old town'), findsOneWidget);
    expect(find.text('A walk through it'), findsOneWidget);
    expect(find.text('Swipe up to start'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('Start at the gate'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('The square'), findsOneWidget);
    expect(find.text('Market on Fridays'), findsOneWidget);
    expect(progress.anchors['col'], 'part');
  });

  testWidgets('continues from the remembered slide', (tester) async {
    progress.anchors['col'] = 'part';
    await pumpPage(tester);

    await tester.tap(find.text('Continue from slide 3'));
    await tester.pumpAndSettle();
    expect(find.text('Market on Fridays'), findsOneWidget);
    // The overlay hides once the viewer moves on; a tap brings it back.
    await tester.tapAt(const Offset(200, 500));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
  });
}
