import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/features/timeline/domain/timeline_order.dart';
import 'package:knit/features/timeline/domain/timeline_order_repository.dart';
import 'package:result_dart/result_dart.dart';

/// In-memory manual-order store for dev mode and tests — no platform channel, so
/// it runs anywhere. Holds the order for the process lifetime; asserts the same
/// contract as the shared_preferences impl.
class InMemoryTimelineOrderRepository
    implements TimelineOrderReadRepository, TimelineOrderWriteRepository {
  InMemoryTimelineOrderRepository([
    TimelineOrder initial = const TimelineOrder(),
  ]) : _order = TimelineOrder([...initial.ids]);

  TimelineOrder _order;

  @override
  Future<Result<TimelineOrder, TimelineFailure>> loadOrder() async =>
      Ok(TimelineOrder([..._order.ids]));

  @override
  Future<Result<TimelineOrder, TimelineFailure>> saveOrder(
    TimelineOrder order,
  ) async {
    _order = TimelineOrder([...order.ids]);
    return Ok(TimelineOrder([..._order.ids]));
  }
}
