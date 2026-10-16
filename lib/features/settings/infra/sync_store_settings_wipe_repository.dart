import 'package:result_dart/result_dart.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/app/device_eraser.dart';
import 'package:knit/features/settings/domain/settings_failure.dart';
import 'package:knit/features/settings/domain/settings_wipe_repository.dart';

/// [SettingsWipeRepository] over the graph's [DeviceEraser]: clears the store
/// and the attachment blobs. The device identity is intentionally untouched.
class SyncStoreSettingsWipeRepository implements SettingsWipeRepository {
  SyncStoreSettingsWipeRepository({required AppGraph graph})
    : _eraser = DeviceEraser(graph: graph);

  final DeviceEraser _eraser;

  @override
  Future<Result<void, SettingsFailure>> wipe() async {
    try {
      await _eraser.wipeData();
      return const Ok<void, SettingsFailure>(null);
    } catch (e, st) {
      return Failure(WipeDataFailure(e, st));
    }
  }
}
