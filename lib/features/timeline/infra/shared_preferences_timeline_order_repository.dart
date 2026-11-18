import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/features/timeline/domain/timeline_order.dart';
import 'package:knit/features/timeline/domain/timeline_order_repository.dart';
import 'package:result_dart/result_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The production manual-order store, over `shared_preferences` — device-local UI
/// config, kept out of the synced SQLite/change-log store (like pins). The order
/// is a native string list; an empty order removes the key, so "reset to recent"
/// leaves nothing behind. One class satisfies both narrow ports since it's a
/// single key/value backing.
class SharedPreferencesTimelineOrderRepository
    implements TimelineOrderReadRepository, TimelineOrderWriteRepository {
  const SharedPreferencesTimelineOrderRepository();

  static const _orderKey = 'timeline.collectionOrder';

  @override
  Future<Result<TimelineOrder, TimelineFailure>> loadOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Ok(TimelineOrder([...?prefs.getStringList(_orderKey)]));
    } catch (e, st) {
      return Failure(TimelineOrderFailure(e, st));
    }
  }

  @override
  Future<Result<TimelineOrder, TimelineFailure>> saveOrder(
    TimelineOrder order,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (order.isManual) {
        await prefs.setStringList(_orderKey, order.ids);
      } else {
        await prefs.remove(_orderKey);
      }
      return Ok(order);
    } catch (e, st) {
      return Failure(TimelineOrderFailure(e, st));
    }
  }
}
