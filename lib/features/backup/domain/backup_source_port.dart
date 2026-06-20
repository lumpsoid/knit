import 'dart:typed_data';

import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';

/// Lets the user pick a backup archive to restore (the file picker). The one
/// place the file-pick dependency lives. Returns `null` when the user cancels —
/// a cancel is not a failure.
abstract interface class BackupSourcePort {
  Future<Result<Uint8List?, BackupFailure>> pickArchive();
}
