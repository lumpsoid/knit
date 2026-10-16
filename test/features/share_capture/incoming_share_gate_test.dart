import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/share_capture/domain/incoming_share_source.dart';
import 'package:knit/features/share_capture/domain/share_capture_failure.dart';
import 'package:knit/features/share_capture/domain/share_capture_models.dart';
import 'package:knit/features/share_capture/domain/share_capture_read_repository.dart';
import 'package:knit/features/share_capture/domain/share_capture_write_repository.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';
import 'package:knit/features/share_capture/presentation/incoming_share_controller.dart';
import 'package:knit/features/share_capture/presentation/incoming_share_gate.dart';
import 'package:knit/features/share_capture/presentation/share_capture_controller.dart';
import 'package:knit/features/share_capture/presentation/share_capture_scope.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:result_dart/result_dart.dart';

class _Source implements IncomingShareSource {
  final StreamController<List<SharedItem>> warm = StreamController();

  @override
  Future<List<SharedItem>> initial() async => const [];

  @override
  Stream<List<SharedItem>> get shares => warm.stream;

  @override
  Future<void> reset() async {}
}

class _Read implements ShareCaptureReadRepository {
  @override
  Future<Result<List<ShareTarget>, ShareCaptureFailure>> loadTargets() async =>
      const Ok([ShareTarget(collectionId: 'c1', title: 'Coffee')]);

  @override
  Future<Result<String?, ShareCaptureFailure>> lastCardPosition(
    String collectionId,
  ) async => const Ok(null);
}

class _Write implements ShareCaptureWriteRepository {
  final Map<String, List<PlannedCard>> saved = {};

  @override
  Future<Result<String, ShareCaptureFailure>> createCollection(
    String title,
  ) async => const Ok('new');

  @override
  Future<Result<int, ShareCaptureFailure>> saveCards(
    String collectionId,
    List<PlannedCard> cards,
  ) async {
    saved[collectionId] = cards;
    return Ok(cards.length);
  }
}

class _Channel implements TimelineChannelEmitter {
  @override
  void emit(TimelineChannelEvent event) {}
}

void main() {
  late _Source source;
  late _Write write;
  late IncomingShareController incoming;

  // Built inside each testWidgets body: the source's stream must live in the
  // test's fake-async zone, or the gate's continuations never run during pumps.
  Future<void> wire() async {
    source = _Source();
    write = _Write();
    incoming = IncomingShareController(source: source);
    await incoming.start();
    ShareCaptureScope.setIncoming(incoming);
    ShareCaptureScope.setCollectionRouteArgsWriter(
      InMemoryCollectionRouteArgsStore(),
    );
    ShareCaptureScope.setFactory(
      (items) => ShareCaptureController(
        items: items,
        readRepository: _Read(),
        writeRepository: write,
        timelineChannel: _Channel(),
      ),
    );
  }

  Widget app(IncomingShareGateMode mode) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: IncomingShareGate(
      mode: mode,
      child: const Scaffold(body: Text('home')),
    ),
  );

  testWidgets('capture: a share opens the picker; picking saves + confirms', (
    tester,
  ) async {
    await wire();
    await tester.pumpWidget(app(IncomingShareGateMode.capture));
    source.warm.add(const [SharedText('a note')]);
    await tester.pumpAndSettle();

    expect(find.text('Save to Knit'), findsOneWidget);
    expect(find.text('a note'), findsOneWidget);

    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();

    expect(find.text('Save to Knit'), findsNothing);
    expect(write.saved['c1']!.single.text, 'a note');
    expect(find.text('Saved 1 card to “Coffee”'), findsOneWidget);
    expect(incoming.state.hasPending, isFalse);
  });

  testWidgets('reject: the share is dropped with a message', (tester) async {
    await wire();
    await tester.pumpWidget(app(IncomingShareGateMode.reject));
    source.warm.add(const [SharedText('a note')]);
    await tester.pumpAndSettle();

    expect(find.text('Save to Knit'), findsNothing);
    expect(
      find.text("Set up Knit first — the shared item wasn't saved"),
      findsOneWidget,
    );
    expect(incoming.state.hasPending, isFalse);
    expect(write.saved, isEmpty);
  });
}
