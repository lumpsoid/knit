import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:knit/features/audio_playback/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/domain/present_read_repository.dart';
import 'package:knit/features/collection_present/infra/in_memory_present_progress_repository.dart';
import 'package:knit/features/collection_present/presentation/present_controller.dart';
import 'package:knit/features/collection_present/presentation/present_page.dart';
import 'package:knit/features/collection_present/presentation/present_route_args.dart';
import 'package:knit/l10n/app_localizations.dart';

import 'present_fakes.dart';

/// A smoke test of the presentation page: the title slide, the resume offer,
/// turning slides with the keyboard, the overlay's position, and following a
/// "See also" chip into another presentation on top.
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
      PresentCard(
        id: 'market',
        kind: CardKind.text,
        text: 'Market on Fridays',
        links: [
          PresentLink(
            kind: PresentLinkKind.collection,
            id: 'museums',
            label: 'Museums',
            collectionId: 'museums',
            outgoing: false,
          ),
        ],
      ),
    ],
  );
  const museums = PresentSource(
    collectionId: 'museums',
    title: 'Museums',
    cards: [
      PresentCard(id: 'm1', kind: CardKind.text, text: 'The city museum'),
    ],
  );

  late InMemoryPresentProgressRepository progress;

  Future<void> pumpPage(WidgetTester tester) async {
    final attachments = FakeAttachments();
    final carrier = InMemoryPresentRouteArgsStore()..open('col');
    final PresentReadRepository read = FakePresentSources({
      'col': source,
      'museums': museums,
    });
    PresentController create() => PresentController(
      routeArgs: carrier,
      routeArgsWriter: carrier,
      createOnTop: create,
      readRepository: read,
      progressReadRepository: progress,
      progressWriteRepository: progress,
      imageCache: AttachmentImageCache(attachmentReadRepository: attachments),
      playback: AudioPlaybackController(
        player: SilentPlayer(),
        attachmentRead: attachments,
      ),
      linkLauncher: FakeLauncher(),
      screenAwake: FakeAwake(),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PresentPage(controller: create()),
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

  testWidgets('a See also chip presents its collection on top; closing it '
      'returns to the slide', (tester) async {
    await pumpPage(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('Market on Fridays'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Museums'));
    await tester.pumpAndSettle();
    expect(find.text('Swipe up to start'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Market on Fridays'), findsOneWidget);
    expect(find.text('Swipe up to start'), findsNothing);
  });
}
