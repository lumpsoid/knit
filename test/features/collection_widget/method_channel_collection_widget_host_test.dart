import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection_widget/domain/domain.dart';
import 'package:knit/features/collection_widget/infra/method_channel_collection_widget_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelCollectionWidgetHost.channelName);
  final calls = <MethodCall>[];
  late MethodChannelCollectionWidgetHost host;

  setUp(() {
    calls.clear();
    host = MethodChannelCollectionWidgetHost();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialRequest' => {'type': 'configure', 'widgetId': 4},
            'bindings' => [
              {'widgetId': 1, 'collectionId': 'a'},
              {'widgetId': 2, 'collectionId': null},
            ],
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('parseRequest decodes open and configure, rejects the rest', () {
    final open = MethodChannelCollectionWidgetHost.parseRequest({
      'type': 'open',
      'collectionId': 'a',
    });
    expect((open! as OpenCollectionRequest).collectionId, 'a');
    final configure = MethodChannelCollectionWidgetHost.parseRequest({
      'type': 'configure',
      'widgetId': 3,
    });
    expect((configure! as ConfigureWidgetRequest).widgetId, 3);
    final quick = MethodChannelCollectionWidgetHost.parseRequest({
      'type': 'quickInput',
      'collectionId': 'a',
    });
    expect((quick! as QuickInputRequest).collectionId, 'a');
    expect(
      MethodChannelCollectionWidgetHost.parseRequest({
        'type': 'quickInput',
        'collectionId': '',
      }),
      isNull,
    );
    expect(MethodChannelCollectionWidgetHost.parseRequest(null), isNull);
    expect(
      MethodChannelCollectionWidgetHost.parseRequest({'type': 'open'}),
      isNull,
    );
  });

  test('initial and bindings decode the platform replies', () async {
    expect(await host.initial(), isA<ConfigureWidgetRequest>());
    final bindings = (await host.bindings()).getOrThrow();
    expect(bindings.map((b) => (b.widgetId, b.collectionId)), [
      (1, 'a'),
      (2, null),
    ]);
  });

  test('bind and publish send the expected arguments', () async {
    await host.bind(
      5,
      const CollectionWidgetTarget(collectionId: 'a', title: 'Coffee'),
    );
    await host.publish(const [
      CollectionWidgetTile.live(widgetId: 1, title: 'Coffee'),
      CollectionWidgetTile.removed(widgetId: 2),
    ]);
    expect(calls[0].arguments, {
      'widgetId': 5,
      'collectionId': 'a',
      'title': 'Coffee',
    });
    expect(calls[1].arguments, [
      {'widgetId': 1, 'title': 'Coffee', 'removed': false, 'quickInput': true},
      {'widgetId': 2, 'title': null, 'removed': true, 'quickInput': false},
    ]);
  });

  test('a platform request arrives on the requests stream', () async {
    final next = host.requests.first;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('request', {'type': 'open', 'collectionId': 'z'}),
          ),
          (_) {},
        );
    expect(((await next) as OpenCollectionRequest).collectionId, 'z');
  });
}
