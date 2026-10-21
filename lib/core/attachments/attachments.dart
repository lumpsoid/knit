/// Attachments foundation (spec §6.4/§7.4.8): pick → hash → store → read →
/// render. A headless shared library — the card-edit page and the collection
/// cover-image feature build their repos over these ports. Bytes live in a
/// content-addressed blob store out-of-band; only the metadata record is signed.
library;

export 'domain/domain.dart';
export 'infra/infra.dart';
export 'presentation/attachment_image.dart';
export 'presentation/attachment_image_cache.dart';
export 'presentation/attachment_image_cache_state.dart';
export 'presentation/byte_size.dart';
