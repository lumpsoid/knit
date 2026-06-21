import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow port for opening a link card's URL in the system browser (§4.2,
/// business_logic.md §5). The shell hands over the raw link text the user
/// stored on the card; the impl resolves it to a launchable URI and delegates
/// to the platform, so the url-launching dependency never leaks into the page
/// or the shell. The twin of [CardShareRepository] for the open-in-browser
/// side-effect — a read-only action that triggers no resync.
abstract interface class LinkLauncher {
  /// Open [url] in the platform browser. [url] is the raw text the user typed
  /// into the link card (a bare host like `example.com` is acceptable — the
  /// impl defaults a missing scheme). Fails when the text isn't a launchable
  /// URL or the platform has no handler for it.
  Future<Result<void, CollectionFailure>> open(String url);
}
