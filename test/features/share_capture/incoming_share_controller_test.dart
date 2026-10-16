import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/share_capture/domain/incoming_share_source.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';
import 'package:knit/features/share_capture/presentation/incoming_share_controller.dart';
import 'package:logging/logging.dart';

class _FakeSource implements IncomingShareSource {
  _FakeSource({this.launch = const []});

  final List<SharedItem> launch;
  final StreamController<List<SharedItem>> warm = StreamController();
  int resets = 0;

  @override
  Future<List<SharedItem>> initial() async => launch;

  @override
  Stream<List<SharedItem>> get shares => warm.stream;

  @override
  Future<void> reset() async => resets++;
}

void main() {
  test('the launch share becomes pending', () async {
    final source = _FakeSource(launch: const [SharedText('cold')]);
    final controller = IncomingShareController(
      source: source,
      logger: Logger('test.share'),
    );
    await controller.start();
    expect(controller.state.hasPending, isTrue);
    expect((controller.state.pending!.single as SharedText).text, 'cold');
  });

  test('an empty launch share leaves nothing pending', () async {
    final controller = IncomingShareController(source: _FakeSource());
    await controller.start();
    expect(controller.state.hasPending, isFalse);
  });

  test('a warm share replaces an untaken one and notifies', () async {
    final source = _FakeSource(launch: const [SharedText('first')]);
    final controller = IncomingShareController(source: source);
    await controller.start();
    var notified = 0;
    controller.state.addListener(() => notified++);

    source.warm.add(const [SharedText('second')]);
    await pumpEventQueue();

    expect(notified, 1);
    expect((controller.state.pending!.single as SharedText).text, 'second');
  });

  test('take hands the share out once and resets the platform', () async {
    final source = _FakeSource(launch: const [SharedText('x')]);
    final controller = IncomingShareController(source: source);
    await controller.start();

    expect(controller.take(), hasLength(1));
    expect(controller.take(), isNull);
    await pumpEventQueue();
    expect(source.resets, 1);
    expect(controller.state.hasPending, isFalse);
  });
}
