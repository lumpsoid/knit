import 'dart:io';

import 'package:knit/core/attachments/domain/mime_types.dart';
import 'package:knit/features/share_capture/domain/incoming_share_source.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// [IncomingShareSource] over `package:receive_sharing_intent` (Android
/// `ACTION_SEND` / `ACTION_SEND_MULTIPLE`, and `ACTION_VIEW` for an opened
/// `.knitc` collection file). The plugin copies every shared
/// stream into the app cache and reports its path; shared text arrives in the
/// same `path` field, so an entry is a file only when that path is an existing
/// local file.
class ReceiveSharingIntentShareSource implements IncomingShareSource {
  ReceiveSharingIntentShareSource({ReceiveSharingIntent? plugin})
    : _plugin = plugin ?? ReceiveSharingIntent.instance;

  final ReceiveSharingIntent _plugin;

  @override
  Future<List<SharedItem>> initial() async =>
      _toItems(await _plugin.getInitialMedia());

  @override
  Stream<List<SharedItem>> get shares => _plugin.getMediaStream().map(_toItems);

  @override
  Future<void> reset() async {
    await _plugin.reset();
  }

  static List<SharedItem> _toItems(List<SharedMediaFile> media) => [
    for (final m in media) ?_toItem(m),
  ];

  static SharedItem? _toItem(SharedMediaFile media) {
    final value = media.path;
    if (value.isEmpty) return null;
    if (_isLocalFile(value)) {
      final name = value.split(Platform.pathSeparator).last;
      return SharedFile(
        path: value,
        mime: media.mimeType ?? MimeTypes.forFileName(name),
        name: name,
      );
    }
    return SharedText(value);
  }

  static bool _isLocalFile(String value) =>
      value.startsWith('/') && File(value).existsSync();
}
