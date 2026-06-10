import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/sync/hlc.dart';
import 'package:knit/sync/storage/device_clock/domain/domain.dart';

/// In-memory [DeviceClockStorage] for dev mode and tests.
class InMemoryDeviceClockStorage implements DeviceClockStorage {
  Hlc? _clock;

  @override
  Future<void> ensureSchema({StorageContext? ctx}) async {}

  @override
  Future<Hlc?> load({StorageContext? ctx}) async => _clock;

  @override
  Future<void> save(Hlc clock, {StorageContext? ctx}) async => _clock = clock;

  @override
  Future<void> clear({StorageContext? ctx}) async => _clock = null;
}
