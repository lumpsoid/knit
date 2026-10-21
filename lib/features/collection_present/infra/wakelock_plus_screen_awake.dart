import 'package:knit/features/collection_present/domain/screen_awake_port.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// [ScreenAwakePort] over `package:wakelock_plus` — the one place the wakelock
/// dependency lives.
class WakelockPlusScreenAwake implements ScreenAwakePort {
  const WakelockPlusScreenAwake();

  @override
  Future<void> keepOn({required bool enabled}) =>
      WakelockPlus.toggle(enable: enabled);
}
