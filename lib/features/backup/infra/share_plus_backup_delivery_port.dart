import 'package:result_dart/result_dart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:knit/features/backup/domain/backup_delivery_port.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_models.dart';

/// [BackupDeliveryPort] over `package:share_plus` — the one place the
/// system-share dependency lives (mirrors `SharePlusCardShareRepository`). Hands
/// the zip to the OS share sheet as an in-memory file named after the bundle.
class SharePlusBackupDeliveryPort implements BackupDeliveryPort {
  const SharePlusBackupDeliveryPort();

  @override
  Future<Result<void, BackupFailure>> share(BackupArchive archive) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              archive.bytes,
              mimeType: 'application/zip',
              name: archive.fileName,
            ),
          ],
          // Some platforms ignore XFile.name for in-memory data; the override
          // guarantees the bundle name reaches the sheet.
          fileNameOverrides: [archive.fileName],
        ),
      );
      return const Ok<void, BackupFailure>(null);
    } catch (e, st) {
      return Failure(BackupDeliveryFailure(e, st));
    }
  }
}
