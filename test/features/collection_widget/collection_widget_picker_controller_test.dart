import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection_widget/domain/domain.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_picker_controller.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_picker_state.dart';

import 'fakes.dart';

void main() {
  late FakeHost host;
  late FakeRead read;
  late CollectionWidgetPickerController picker;

  setUp(() {
    host = FakeHost();
    read = FakeRead()..live = {'a': 'Coffee', 'b': 'Books'};
    picker = CollectionWidgetPickerController(
      widgetId: 9,
      readRepository: read,
      host: host,
    );
  });

  test('load lists the collections and filter narrows them', () async {
    await picker.load();
    expect(picker.state.status, CollectionWidgetPickerStatus.ready);
    expect(picker.state.targets, hasLength(2));
    picker.filter('boo');
    expect(picker.state.visibleTargets.single.title, 'Books');
  });

  test('a failed load shows the failure', () async {
    read.failTargets = true;
    await picker.load();
    expect(picker.state.status, CollectionWidgetPickerStatus.failed);
  });

  test('choose binds the widget to the target', () async {
    const target = CollectionWidgetTarget(collectionId: 'a', title: 'Coffee');
    expect(await picker.choose(target), isTrue);
    expect(host.bound[9]?.collectionId, 'a');
    expect(picker.state.saving, isFalse);
  });

  test('a failed bind reports it', () async {
    host.failBind = true;
    const target = CollectionWidgetTarget(collectionId: 'a', title: 'Coffee');
    expect(await picker.choose(target), isFalse);
    expect(picker.state.saveFailed, isTrue);
  });
}
