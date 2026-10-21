import 'package:knit/core/files/domain/domain.dart';
import 'package:result_dart/result_dart.dart';
import 'package:share_plus/share_plus.dart';

/// [FileDeliveryPort] over `package:share_plus` — the one place the
/// system-share dependency lives. Hands the bytes to the OS share sheet as an
/// in-memory file.
class SharePlusFileDeliveryPort implements FileDeliveryPort {
  const SharePlusFileDeliveryPort();

  @override
  Future<Result<void, FileFailure>> share(OutgoingFile file) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              file.bytes,
              mimeType: file.mimeType,
              name: file.fileName,
            ),
          ],
          // Some platforms ignore XFile.name for in-memory data; the override
          // guarantees the name reaches the sheet.
          fileNameOverrides: [file.fileName],
        ),
      );
      return const Ok<void, FileFailure>(null);
    } catch (e, st) {
      return Failure(FileDeliveryFailure(e, st));
    }
  }
}
