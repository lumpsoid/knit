import 'dart:typed_data';

import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_delivery_port.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/backup/domain/backup_save_port.dart';
import 'package:knit/features/backup/domain/backup_source_port.dart';

/// In-memory [BackupDeliveryPort] for tests/dev — captures the last shared
/// archive instead of touching the OS share sheet.
class RecordingBackupDeliveryPort implements BackupDeliveryPort {
  BackupArchive? lastShared;

  @override
  Future<Result<void, BackupFailure>> share(BackupArchive archive) async {
    lastShared = archive;
    return const Ok<void, BackupFailure>(null);
  }
}

/// In-memory [BackupSourcePort] for tests/dev — returns preset [bytes] (or
/// `null` to simulate a cancel) instead of opening the file picker.
class StubBackupSourcePort implements BackupSourcePort {
  StubBackupSourcePort([this.bytes]);

  Uint8List? bytes;

  @override
  Future<Result<Uint8List?, BackupFailure>> pickArchive() async =>
      Ok<Uint8List?, BackupFailure>(bytes);
}

/// In-memory [BackupSavePort] for tests/dev — captures the last saved archive
/// and reports it as saved ([saved] = `false` simulates a cancelled dialog).
class RecordingBackupSavePort implements BackupSavePort {
  RecordingBackupSavePort({this.saved = true});

  BackupArchive? lastSaved;
  bool saved;

  @override
  Future<Result<bool, BackupFailure>> save(BackupArchive archive) async {
    lastSaved = archive;
    return Ok<bool, BackupFailure>(saved);
  }
}
