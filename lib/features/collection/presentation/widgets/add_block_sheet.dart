import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';

/// What the "+" sheet adds (§4.2): a Connection card to another collection, or
/// a staged photo, audio clip or file for the composer.
enum AddBlock { connection, photo, audio, file }

class AddBlockSheet extends StatelessWidget {
  const AddBlockSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: Text(l10n.collectionBlockConnection),
            subtitle: Text(l10n.collectionBlockConnectionSubtitle),
            onTap: () => Navigator.of(context).pop(AddBlock.connection),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(l10n.collectionBlockPhoto),
            onTap: () => Navigator.of(context).pop(AddBlock.photo),
          ),
          ListTile(
            leading: const Icon(Icons.mic_none),
            title: Text(l10n.collectionBlockAudio),
            onTap: () => Navigator.of(context).pop(AddBlock.audio),
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text(l10n.collectionBlockFile),
            onTap: () => Navigator.of(context).pop(AddBlock.file),
          ),
        ],
      ),
    );
  }
}
