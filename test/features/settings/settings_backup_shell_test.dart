import 'dart:typed_data';

import 'package:effect_emitter/effect_emitter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/backup/infra/argon2_identity_key_cipher.dart';
import 'package:knit/features/backup/infra/in_memory_backup_ports.dart';
import 'package:knit/features/backup/infra/sync_store_backup_export_repository.dart';
import 'package:knit/features/backup/infra/sync_store_backup_import_repository.dart';
import 'package:knit/features/settings/domain/app_preferences.dart';
import 'package:knit/features/settings/domain/settings_failure.dart';
import 'package:knit/features/settings/domain/settings_read_repository.dart';
import 'package:knit/features/settings/domain/settings_write_repository.dart';
import 'package:knit/features/settings/infra/sync_store_settings_identity_repository.dart';
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

final _cipher = Argon2IdentityKeyCipher(
  params: const KdfParams(memoryKib: 8, iterations: 1, parallelism: 1),
);

const _passphrase = 'correct horse';

/// A seeded graph under another identity, exported as a backup bundle.
Future<List<int>> _otherIdentityBackup() async {
  final other = AppGraph()
    ..bindStore(SyncStore.inMemory(signer: FakeSigner(identitySeed: 'other')))
    ..bindBlobStore(InMemoryAttachmentBlobStore());
  await other.store.open();
  await other.store.create(EntityType.collection, 'theirs', const {
    'title': 'Theirs',
  });
  final archive = await SyncStoreBackupExportRepository(
    graph: other,
    cipher: _cipher,
  ).exportAll(_passphrase);
  return archive.getOrThrow().bytes;
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
      identityReadRepository: SyncStoreSettingsIdentityReadRepository(
        graph: graph,
      ),
      identityResetRepository: SyncStoreSettingsIdentityResetRepository(
        graph: graph,
      ),
      backupExportRepository: SyncStoreBackupExportRepository(
        graph: graph,
        cipher: _cipher,
      ),
      backupImportRepository: SyncStoreBackupImportRepository(
        graph: graph,
        cipher: _cipher,
      ),
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
      const RunExportEffect(BackupDestination.share, _passphrase),
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
      const RunExportEffect(BackupDestination.saveFile, _passphrase),
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
      const RunExportEffect(BackupDestination.saveFile, _passphrase),
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
      const RunExportEffect(BackupDestination.share, _passphrase),
      dispatch: dispatched.add,
    );

    expect(refreshCount, 0);
  });

  group('import of another identity\'s backup', () {
    test('holds the bundle and asks to replace the device', () async {
      source.bytes = Uint8List.fromList(await _otherIdentityBackup());

      await shell.run(
        const RunDataActionEffect(DataAction.importData),
        dispatch: dispatched.add,
      );

      expect(dispatched.whereType<RestoreAwaitingPassphrase>(), hasLength(1));
      final ask = uiEffects.whereType<SettingsConfirmReplaceUiEffect>().single;
      expect(ask.wrongPassphrase, isFalse);
      expect(dispatched.last, isA<DataActionFinished>());
      // Nothing was restored yet.
      expect(await graph.store.readAll(EntityType.collection), isEmpty);
    });

    test('a wrong passphrase asks again and keeps the device', () async {
      source.bytes = Uint8List.fromList(await _otherIdentityBackup());
      await shell.run(
        const RunDataActionEffect(DataAction.importData),
        dispatch: dispatched.add,
      );
      final bundle = dispatched.whereType<RestoreAwaitingPassphrase>().single;
      final authorBefore = await graph.store.authorPubkey();
      uiEffects.clear();
      dispatched.clear();

      await shell.run(
        RunReplaceDeviceEffect(bundle.bundle, 'wrong horse'),
        dispatch: dispatched.add,
      );

      expect(
        uiEffects
            .whereType<SettingsConfirmReplaceUiEffect>()
            .single
            .wrongPassphrase,
        isTrue,
      );
      expect(dispatched.whereType<RestoreSettled>(), isEmpty);
      expect(await graph.store.authorPubkey(), authorBefore);
    });

    test('the right passphrase replaces the device', () async {
      source.bytes = Uint8List.fromList(await _otherIdentityBackup());
      await shell.run(
        const RunDataActionEffect(DataAction.importData),
        dispatch: dispatched.add,
      );
      final bundle = dispatched.whereType<RestoreAwaitingPassphrase>().single;

      await shell.run(
        RunReplaceDeviceEffect(bundle.bundle, _passphrase),
        dispatch: dispatched.add,
      );

      expect(await graph.store.authorPubkey(), bundle.bundle.author);
      final titles = (await graph.store.readAll(
        EntityType.collection,
      )).map((c) => c.content['title']);
      expect(titles, ['Theirs']);
      expect(
        uiEffects.whereType<SettingsDeviceReplacedUiEffect>(),
        hasLength(1),
      );
      expect(dispatched, contains(isA<RestoreSettled>()));
      expect(refreshCount, 1);
    });
  });

  group('reset identity', () {
    test('asks for the nickname as the confirmation word', () async {
      final pubkey = await graph.store.authorPubkey();
      await graph.store.create(EntityType.profile, pubkey, {'nickname': 'Ada'});

      await shell.run(
        const RunDataActionEffect(DataAction.resetIdentity),
        dispatch: dispatched.add,
      );

      final ask = uiEffects.whereType<SettingsConfirmResetUiEffect>().single;
      expect(ask.confirmation.word, 'Ada');
      expect(dispatched.last, isA<DataActionFinished>());
    });

    test('erases the data and the keypair, then leaves', () async {
      await graph.store.create(EntityType.collection, 'col-1', const {
        'title': 'Notes',
      });

      await shell.run(const RunResetIdentityEffect(), dispatch: dispatched.add);

      expect(await graph.store.hasIdentity(), isFalse);
      expect(await graph.store.readAll(EntityType.collection), isEmpty);
      expect(
        uiEffects.whereType<SettingsIdentityResetUiEffect>(),
        hasLength(1),
      );
      expect(dispatched.last, isA<DataActionFinished>());
    });
  });
}
