import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection_widget/domain/domain.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_controller.dart';

import 'fakes.dart';

void main() {
  late FakeRequestSource source;
  late FakeHost host;
  late FakeRead read;
  late ChangeNotifier headers;
  late CollectionWidgetController controller;

  setUp(() {
    source = FakeRequestSource();
    host = FakeHost();
    read = FakeRead();
    headers = ChangeNotifier();
    controller = CollectionWidgetController(
      source: source,
      host: host,
      readRepository: read,
      headerChanges: headers,
    );
  });

  group('requests', () {
    test('the launch request is pending after start', () async {
      source.launch = const OpenCollectionRequest('a');
      await controller.start();
      final request = controller.take();
      expect(request, isA<OpenCollectionRequest>());
      expect((request! as OpenCollectionRequest).collectionId, 'a');
      expect(controller.take(), isNull);
    });

    test('a warm request replaces one nobody took', () async {
      await controller.start();
      source.warm.add(const OpenCollectionRequest('a'));
      source.warm.add(const ConfigureWidgetRequest(7));
      await pumpEventQueue();
      final request = controller.take();
      expect((request! as ConfigureWidgetRequest).widgetId, 7);
    });
  });

  group('tiles', () {
    setUp(() {
      host.placed = const [
        CollectionWidgetBinding(widgetId: 1, collectionId: 'a'),
        CollectionWidgetBinding(widgetId: 2, collectionId: 'b'),
      ];
      read.live = {'a': 'Coffee', 'b': 'Books'};
    });

    test('nothing is published before attach', () async {
      await controller.refreshTiles();
      expect(host.published, isEmpty);
    });

    test('attach publishes the current tiles', () async {
      controller.attach();
      await pumpEventQueue();
      expect(host.published.single, const [
        CollectionWidgetTile.live(widgetId: 1, title: 'Coffee'),
        CollectionWidgetTile.live(widgetId: 2, title: 'Books'),
      ]);
    });

    test('a rename republishes; an unchanged plan is not re-sent', () async {
      controller.attach();
      await pumpEventQueue();
      read.live['a'] = 'Espresso';
      headers.notifyListeners();
      await pumpEventQueue();
      headers.notifyListeners();
      await pumpEventQueue();
      expect(host.published, hasLength(2));
      expect(
        host.published.last.first,
        const CollectionWidgetTile.live(widgetId: 1, title: 'Espresso'),
      );
    });

    test('a deleted collection shows the removed state', () async {
      controller.attach();
      await pumpEventQueue();
      read.live.remove('b');
      await controller.refreshTiles();
      expect(
        host.published.last.last,
        const CollectionWidgetTile.removed(widgetId: 2),
      );
    });

    test('overlapping refreshes fold into one follow-up', () async {
      controller.attach();
      await pumpEventQueue();
      read.live['a'] = 'One';
      final first = controller.refreshTiles();
      read.live['a'] = 'Two';
      final second = controller.refreshTiles();
      final third = controller.refreshTiles();
      await Future.wait([first, second, third]);
      expect(
        host.published.last.first,
        const CollectionWidgetTile.live(widgetId: 1, title: 'Two'),
      );
    });

    test('detach stops following header changes', () async {
      controller.attach();
      await pumpEventQueue();
      controller.detach();
      read.live['a'] = 'Espresso';
      headers.notifyListeners();
      await pumpEventQueue();
      expect(host.published, hasLength(1));
    });

    test(
      'isLive is false for a gone collection and refreshes the tiles',
      () async {
        controller.attach();
        await pumpEventQueue();
        expect(await controller.isLive('a'), isTrue);
        read.live.remove('a');
        expect(await controller.isLive('a'), isFalse);
        await pumpEventQueue();
        expect(
          host.published.last.first,
          const CollectionWidgetTile.removed(widgetId: 1),
        );
      },
    );
  });

  test('returnToHomeScreen goes through the host', () async {
    await controller.returnToHomeScreen();
    expect(host.returnedHome, 1);
  });
}
