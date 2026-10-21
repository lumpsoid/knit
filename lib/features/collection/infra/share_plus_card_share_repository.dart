import 'package:result_dart/result_dart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:knit/features/collection/domain/card_share_repository.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';

/// [CardShareRepository] over `package:share_plus` — the one place the
/// system-share dependency lives. A text-only card shares its text; an image
/// card shares its photos (named after the card's date) plus its caption.
class SharePlusCardShareRepository implements CardShareRepository {
  const SharePlusCardShareRepository();

  @override
  Future<Result<void, CollectionFailure>> share(ShareableCard card) async {
    try {
      final files = card.files;
      final params = files.isEmpty
          ? ShareParams(text: card.text)
          : ShareParams(
              text: card.text,
              files: [
                for (final file in files)
                  XFile.fromData(
                    file.bytes,
                    mimeType: file.mime,
                    name: file.fileName,
                  ),
              ],
              // Some platforms ignore XFile.name for in-memory data; the
              // override guarantees the date-stamped name reaches the sheet.
              fileNameOverrides: [for (final file in files) file.fileName],
            );
      await SharePlus.instance.share(params);
      return const Ok<void, CollectionFailure>(null);
    } catch (e, st) {
      return Failure(CollectionShareFailure(e, st));
    }
  }
}
