import 'package:flutter/material.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/l10n/app_localizations.dart';

class AddBlockSheet extends StatelessWidget {
  const AddBlockSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.collectionBlockLink),
            subtitle: Text(l10n.collectionBlockLinkSubtitle),
            onTap: () => Navigator.of(context).pop(CardKind.link),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(l10n.collectionBlockPhoto),
            onTap: () => Navigator.of(context).pop(CardKind.image),
          ),
          ListTile(
            leading: const Icon(Icons.mic_none),
            title: Text(l10n.collectionBlockAudio),
            onTap: () => Navigator.of(context).pop(CardKind.audio),
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text(l10n.collectionBlockFile),
            onTap: () => Navigator.of(context).pop(CardKind.file),
          ),
        ],
      ),
    );
  }
}
