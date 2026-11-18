import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:knit/features/timeline/presentation/widgets/timeline_collection_avatar.dart';
import 'package:knit/l10n/app_localizations.dart';

/// A collection's row in Home reorder mode (§4.1): its avatar, its title and the
/// drag grip.
class TimelineReorderRow extends StatelessWidget {
  const TimelineReorderRow({
    super.key,
    required this.collectionId,
    required this.title,
    required this.coverBytes,
    required this.index,
  });

  /// The collection id, which seeds the avatar's placeholder tint.
  final String collectionId;

  /// The collection's current title (blank ⇒ shown as untitled).
  final String title;

  /// Decoded cover bytes, or null when the collection has no cover or its bytes
  /// haven't loaded.
  final Uint8List? coverBytes;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = this.title.trim().isEmpty ? l10n.labelUntitled : this.title;
    return ListTile(
      leading: TimelineCollectionAvatar(
        collectionId: collectionId,
        title: title,
        coverBytes: coverBytes,
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_indicator),
      ),
    );
  }
}
