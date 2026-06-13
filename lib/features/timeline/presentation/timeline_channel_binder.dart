import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';

/// Folds [TimelineChannelEvent]s into feature-owned Actions (cross_feature.md
/// §1.5/§3). On each channel notification it reads the latest event off the
/// [TimelineChannelReader] and dispatches the matching Timeline Action; the
/// reducer — not the binder — decides what to do with it. The binder unwraps
/// the foreign channel into the feature's own Actions and nothing more.
///
/// [bind]/[unbind] are idempotent and driven by the controller's attach/detach
/// hooks, so the subscription lives exactly as long as the Timeline is mounted.
class TimelineChannelBinder {
  TimelineChannelBinder({
    required TimelineChannelReader reader,
    required ActionSink<TimelineAction> sink,
  })  : _reader = reader,
        _sink = sink;

  final TimelineChannelReader _reader;
  final ActionSink<TimelineAction> _sink;
  bool _bound = false;

  void _onEvent() {
    switch (_reader.latestEvent) {
      case RefreshChannelEvent():
        _sink.dispatch(const RefreshRequested());
      case null:
        break;
    }
  }

  void bind() {
    if (_bound) return;
    _reader.addListener(_onEvent);
    _bound = true;
  }

  void unbind() {
    if (!_bound) return;
    _reader.removeListener(_onEvent);
    _bound = false;
  }
}
