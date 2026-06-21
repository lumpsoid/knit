import 'package:result_dart/result_dart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/link_launcher.dart';

/// [LinkLauncher] over `package:url_launcher` — the one place the url-launching
/// dependency lives. A scheme-less value (e.g. `example.com`) is treated as
/// `https://` so it still resolves; a value that can't be parsed as a URI, or a
/// launch the platform declines, is a [CollectionLinkOpenFailure].
class UrlLauncherLinkLauncher implements LinkLauncher {
  const UrlLauncherLinkLauncher();

  @override
  Future<Result<void, CollectionFailure>> open(String url) async {
    final uri = _resolve(url);
    if (uri == null) {
      return Failure(CollectionLinkOpenFailure('unparseable link: $url'));
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        return Failure(CollectionLinkOpenFailure('no handler for $uri'));
      }
      return const Ok<void, CollectionFailure>(null);
    } catch (e, st) {
      return Failure(CollectionLinkOpenFailure(e, st));
    }
  }

  /// Parse [raw] into a launchable URI, defaulting a scheme-less value to
  /// `https://`. Returns null when it can't be parsed as a URI at all.
  static Uri? _resolve(String raw) {
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed;
    return Uri.tryParse('https://$raw');
  }
}
