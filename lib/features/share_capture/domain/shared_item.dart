/// One item another app shared into Knit (§4.7) — the platform-agnostic shape
/// the [IncomingShareSource] hands over, so nothing past the adapter sees the
/// share plugin's types.
sealed class SharedItem {
  const SharedItem();
}

/// Shared text (a note, a selection, a URL).
final class SharedText extends SharedItem {
  const SharedText(this.text);

  final String text;
}

/// A shared file the platform already copied to a local [path]. [mime] is the
/// declared media type (derived from the name when the sender gave none);
/// [name] is the original file name, kept on the stored attachment (§7.4.8).
final class SharedFile extends SharedItem {
  const SharedFile({
    required this.path,
    required this.mime,
    required this.name,
  });

  final String path;
  final String mime;
  final String name;
}
