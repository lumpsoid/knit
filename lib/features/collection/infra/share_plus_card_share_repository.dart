import 'package:result_dart/result_dart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:knit/features/collection/domain/card_share_repository.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';

/// [CardShareRepository] over `package:share_plus` — the one place the
/// system-share dependency lives. A text-only card shares its text; an image
/// card shares the photo (named after the card's date) plus its caption.
class SharePlusCardShareRepository implements CardShareRepository {
  const SharePlusCardShareRepository();

  @override
  Future<Result<void, CollectionFailure>> share(ShareableCard card) async {
    try {
      final image = card.image;
      final params = image == null
          ? ShareParams(text: card.text)
          : ShareParams(
              text: card.text,
              files: [
                XFile.fromData(
                  image.bytes,
                  mimeType: image.mime,
                  name: image.fileName,
                ),
              ],
              // Some platforms ignore XFile.name for in-memory data; the
              // override guarantees the date-stamped name reaches the sheet.
              fileNameOverrides: [image.fileName],
            );
      await SharePlus.instance.share(params);
      return const Ok<void, CollectionFailure>(null);
    } catch (e, st) {
      return Failure(CollectionShareFailure(e, st));
    }
  }
}
