import 'package:knit/core/attachments/domain/attachment_failure.dart';
import 'package:knit/core/attachments/domain/attachment_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for attachments (business_logic.md §5): resolve an
/// attachment id to its renderable bytes by reading the metadata record and
/// loading the bytes from the content-addressed blob store.
abstract class AttachmentReadRepository {
  Future<Result<AttachmentBytes, AttachmentFailure>> bytesOf(
    String attachmentId,
  );
}
