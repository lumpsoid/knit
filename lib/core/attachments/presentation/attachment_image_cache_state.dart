import 'package:flutter/foundation.dart';

/// The app-wide decoded-image state — a [ChangeNotifier] the
/// [AttachmentImageCache] owns and mutates, and every page that renders an
/// attachment image listens to. Keyed by `attachment_id`, which is immutable
/// (content-addressed, §7.4.8), so a cached entry never goes stale.
class AttachmentImageCacheState extends ChangeNotifier {
  final Map<String, Uint8List> _bytes = {};
  final Set<String> _missing = {};

  /// The decoded bytes for [attachmentId], or null while not loaded (or when
  /// the blob is missing on this device) — callers render a placeholder.
  Uint8List? of(String attachmentId) => _bytes[attachmentId];

  /// Whether the last read of [attachmentId] found no blob on this device
  /// (e.g. not yet synced), so a page can show a broken-image glyph instead of
  /// a loading placeholder.
  bool isMissing(String attachmentId) => _missing.contains(attachmentId);

  bool contains(String attachmentId) => _bytes.containsKey(attachmentId);

  void put(String attachmentId, Uint8List bytes) {
    _bytes[attachmentId] = bytes;
    _missing.remove(attachmentId);
    notifyListeners();
  }

  void markMissing(String attachmentId) {
    if (!_missing.add(attachmentId)) return;
    notifyListeners();
  }

  /// Drop [attachmentIds]' bytes. No notification: an evicted image is by
  /// definition one no page is showing.
  void evict(Iterable<String> attachmentIds) {
    for (final id in attachmentIds) {
      _bytes.remove(id);
    }
  }
}
