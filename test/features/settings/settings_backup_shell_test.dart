import 'package:effect_emitter/effect_emitter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/features/backup/infra/in_memory_backup_ports.dart';
import 'package:knit/features/backup/infra/sync_store_backup_export_repository.dart';
import 'package:knit/features/backup/infra/sync_store_backup_import_repository.dart';
import 'package:knit/features/settings/domain/app_preferences.dart';
import 'package:knit/features/settings/domain/settings_failure.dart';
import 'package:knit/features/settings/domain/settings_read_repository.dart';
import 'package:knit/features/settings/domain/settings_write_repository.dart';
import 'package:knit/features/settings/infra/sync_store_settings_wipe_repository.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';
import 'package:knit/features/settings/presentation/settings_effect.dart';
import 'package:knit/features/settings/presentation/settings_shell.dart';
import 'package:knit/features/settings/presentation/settings_ui_effect.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/features/timeline/infra/timeline_channel_notifier.dart';
import 'package:knit/sync/sync.dart';

class _FakeSettingsRead implements SettingsReadRepository {
  @override
  Future<Result<AppPreferences, SettingsFailure>> load() async =>
      const Ok(AppPreferences());
}

class _FakeSettingsWrite implements SettingsWriteRepository {
  @override
  Future<Result<AppPreferences, SettingsFailure>> save(
    AppPreferences preferences,
  ) async => Ok(preferences);
}

void main() {
  late AppGraph graph;
  late RecordingBackupDeliveryPort delivery;
  late RecordingBackupSavePort save;
  late StubBackupSourcePort source;
  late EffectEmitter<SettingsUiEffect> emitter;
  late List<SettingsUiEffect> uiEffects;
  late List<SettingsAction> dispatched;
  late TimelineChannelNotifier timelineChannel;
  late int refreshCount;
  late SettingsShell shell;

  setUp(() async {
    graph = AppGraph()
      ..bindStore(SyncStore.inMemory())
      ..bindBlobStore(InMemoryAttachmentBlobStore());
    await graph.store.open();

    delivery = RecordingBackupDeliveryPort();
    save = RecordingBackupSavePort();
    source = StubBackupSourcePort();
    emitter = EffectEmitter<SettingsUiEffect>();
    uiEffects = [];
    emitter.attach(uiEffects.add);
    dispatched = [];
    timelineChannel = TimelineChannelNotifier();
    refreshCount = 0;
    timelineChannel.addListener(() {
      if (timelineChannel.latestEvent is RefreshChannelEvent) refreshCount++;
    });

    shell = SettingsShell(
      readRepository: _FakeSettingsRead(),
      writeRepository: _FakeSettingsWrite(),
      wipeRepository: SyncStoreSettingsWipeRepository(graph: graph),
      backupExportRepository: SyncStoreBackupExportRepository(graph: graph),
      backupImportRepository: SyncStoreBackupImportRepository(graph: graph),
      backupDeliveryPort: delivery,
      backupSavePort: save,
      backupSourcePort: source,
      effectEmitter: emitter,
      timelineChannel: timelineChannel,
      logger: Logger('test.settings'),
    );
  });

  test('export to share hands the bundle to the delivery port', () async {
    await shell.run(
      const RunExportEffect(BackupDestination.share),
      dispatch: dispatched.add,
    );

    expect(delivery.lastShared, isNotNull);
    expect(save.lastSaved, isNull);
    expect(
      uiEffects.whereType<SettingsBackupExportedUiEffect>().single.destination,
      BackupDestination.share,
    );
    expect(dispatched, contains(isA<DataActionFinished>()));
  });

  test('export to file hands the bundle to the save port', () async {
    await shell.run(
      const RunExportEffect(BackupDestination.saveFile),
      dispatch: dispatched.add,
    );

    expect(save.lastSaved, isNotNull);
    expect(delivery.lastShared, isNull);
    expect(
      uiEffects.whereType<SettingsBackupExportedUiEffect>().single.destination,
      BackupDestination.saveFile,
    );
    expect(dispatched, contains(isA<DataActionFinished>()));
  });

  test('a cancelled save dialog stays silent but still finishes', () async {
    save.saved = false;

    await shell.run(
      const RunExportEffect(BackupDestination.saveFile),
      dispatch: dispatched.add,
    );

    expect(save.lastSaved, isNotNull);
    expect(uiEffects.whereType<SettingsBackupExportedUiEffect>(), isEmpty);
    expect(dispatched, contains(isA<DataActionFinished>()));
  });

  test('a cancelled import pick stays silent but still finishes', () async {
    source.bytes = null; // user cancelled the picker

    await shell.run(
      const RunDataActionEffect(DataAction.importData),
      dispatch: dispatched.add,
    );

    expect(uiEffects, isEmpty);
    expect(dispatched, contains(isA<DataActionFinished>()));
  });

  test('wipe clears the store, keeps identity, and confirms', () async {
    await graph.store.create(EntityType.collection, 'col-1', const {
      'title': 'Notes',
    });
    final authorBefore = await graph.store.authorPubkey();
    expect(await graph.store.pendingCount(), greaterThan(0));

    await shell.run(
      const RunDataActionEffect(DataAction.wipeData),
      dispatch: dispatched.add,
    );

    expect(await graph.store.readAll(EntityType.collection), isEmpty);
    expect(await graph.store.pendingCount(), 0);
    // The device identity survives the wipe.
    expect(await graph.store.authorPubkey(), authorBefore);
    expect(uiEffects.whereType<SettingsDataWipedUiEffect>(), hasLength(1));
    expect(dispatched, contains(isA<DataActionFinished>()));
    // The home feed changed — the Timeline was nudged to re-read.
    expect(refreshCount, 1);
  });

  test('wipe keeps the identity profile but removes other entities', () async {
    final pubkey = await graph.store.authorPubkey();
    await graph.store.create(EntityType.profile, pubkey, {'nickname': 'Ada'});
    await graph.store.create(EntityType.collection, 'col-1', const {
      'title': 'Notes',
    });

    await shell.run(
      const RunDataActionEffect(DataAction.wipeData),
      dispatch: dispatched.add,
    );

    // The signed profile record (identity) survives the wipe, nickname intact.
    final profile = await graph.store.get(EntityType.profile, pubkey);
    expect(profile, isNotNull);
    expect(profile!.content['nickname'], 'Ada');
    // The pending profile op is preserved (re-appended), not lost.
    expect(await graph.store.pendingCount(), 1);
    // Every other entity is gone.
    expect(await graph.store.readAll(EntityType.collection), isEmpty);
  });

  test('a read-only export does not nudge the timeline', () async {
    await shell.run(
      const RunExportEffect(BackupDestination.share),
      dispatch: dispatched.add,
    );

    expect(refreshCount, 0);
  });
}
