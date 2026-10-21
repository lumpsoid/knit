import 'package:fcis_core/fcis_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/features/timeline/infra/timeline_channel_notifier.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_channel_binder.dart';

class _Sink implements ActionSink<TimelineAction> {
  final actions = <TimelineAction>[];
  @override
  void dispatch(TimelineAction action) => actions.add(action);
}

void main() {
  test('a deleted collection folds into CollectionDeleted', () {
    final channel = TimelineChannelNotifier();
    final sink = _Sink();
    TimelineChannelBinder(reader: channel, sink: sink).bind();

    channel.emit(const CollectionDeletedChannelEvent('c1'));

    expect((sink.actions.single as CollectionDeleted).collectionId, 'c1');
  });
}
