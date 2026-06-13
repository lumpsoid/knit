/// Display label for a link endpoint or picker target — a read-time derivation
/// over a projection [Snapshot] (mirrors the Connections view's labelling rule),
/// kept in one place so every link/picker surface labels endpoints identically.
/// Pure, never synced, never signed.
library;

import 'package:knit/sync/snapshot.dart';

/// A collection's title, or a card's text preview (falling back to a kind-based
/// summary). Other entity kinds fall back to their id.
String endpointLabel(Snapshot s) {
  switch (s.type) {
    case EntityType.collection:
      final title = (s.content['title'] as String?)?.trim();
      return title == null || title.isEmpty ? 'Untitled' : title;
    case EntityType.card:
      final text = (s.content['text'] as String?)?.trim();
      if (text != null && text.isNotEmpty) return text;
      return switch (s.content['kind'] as String?) {
        'image' => 'Photo',
        'audio' => 'Audio',
        'link' => 'Link',
        _ => 'Empty note',
      };
    case EntityType.link:
    case EntityType.profile:
    case EntityType.attachment:
      return s.id;
  }
}
