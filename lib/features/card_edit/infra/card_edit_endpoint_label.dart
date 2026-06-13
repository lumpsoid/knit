import 'package:knit/sync/sync.dart';

/// Display label for a link endpoint or picker target snapshot: a collection's
/// title, or a card's text preview (falling back to a kind-based summary). Shared
/// by the card-edit links read repo and the target-tree read repo so the
/// labelling rule lives in one place (it mirrors the Connections view's).
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
