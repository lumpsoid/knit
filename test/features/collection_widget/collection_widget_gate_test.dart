import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection_widget/domain/domain.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_controller.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_gate.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_picker_controller.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_scope.dart';
import 'package:knit/l10n/app_localizations.dart';

import 'fakes.dart';

void main() {
  late FakeRequestSource source;
  late FakeHost host;
  late FakeRead read;
  late CollectionWidgetController controller;
  late InMemoryCollectionRouteArgsStore routeArgs;

  // Built inside each testWidgets body: the source's stream must live in the
  // test's fake-async zone, or the gate's continuations never run during pumps.
  Future<void> wire() async {
    source = FakeRequestSource();
    host = FakeHost()..placed = const [CollectionWidgetBinding(widgetId: 3)];
    read = FakeRead()..live = {'a': 'Coffee'};
    routeArgs = InMemoryCollectionRouteArgsStore();
    controller = CollectionWidgetController(
      source: source,
      host: host,
      readRepository: read,
      headerChanges: ChangeNotifier(),
    );
    await controller.start();
    CollectionWidgetScope.setController(controller);
    CollectionWidgetScope.setCollectionRouteArgsWriter(routeArgs);
    CollectionWidgetScope.setPickerFactory(
      (widgetId) => CollectionWidgetPickerController(
        widgetId: widgetId,
        readRepository: read,
        host: host,
      ),
    );
  }

  Widget app(CollectionWidgetGateMode mode) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CollectionWidgetGate(
      mode: mode,
      child: const Scaffold(body: Text('home')),
    ),
  );

  testWidgets('handle: configure opens the picker; picking binds the widget '
      'and returns to the home screen', (tester) async {
    await wire();
    await tester.pumpWidget(app(CollectionWidgetGateMode.handle));
    source.warm.add(const ConfigureWidgetRequest(3));
    await tester.pumpAndSettle();

    expect(find.text('Choose a collection for the widget'), findsOneWidget);
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a collection for the widget'), findsNothing);
    expect(host.bound[3]?.collectionId, 'a');
    expect(host.returnedHome, 1);
  });

  testWidgets('handle: a removed collection falls back with a message', (
    tester,
  ) async {
    await wire();
    await tester.pumpWidget(app(CollectionWidgetGateMode.handle));
    source.warm.add(const OpenCollectionRequest('gone'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(
      find.text('That collection was removed — tap the widget to pick another'),
      findsOneWidget,
    );
    expect(routeArgs.collectionId, isEmpty);
  });

  testWidgets('handle: attaching publishes the tiles', (tester) async {
    await wire();
    host.placed = const [
      CollectionWidgetBinding(widgetId: 1, collectionId: 'a'),
    ];
    await tester.pumpWidget(app(CollectionWidgetGateMode.handle));
    await tester.pumpAndSettle();

    expect(host.published.single, const [
      CollectionWidgetTile.live(widgetId: 1, title: 'Coffee'),
    ]);
  });

  testWidgets('reject: configuring asks to set up Knit first', (tester) async {
    await wire();
    await tester.pumpWidget(app(CollectionWidgetGateMode.reject));
    source.warm.add(const ConfigureWidgetRequest(3));
    await tester.pumpAndSettle();

    expect(find.text('Choose a collection for the widget'), findsNothing);
    expect(
      find.text('Set up Knit first, then tap the widget again'),
      findsOneWidget,
    );
    expect(controller.state.hasPending, isFalse);
    expect(host.published, isEmpty);
  });
}
