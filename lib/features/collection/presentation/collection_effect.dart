import 'package:knit/features/collection/domain/collection_models.dart';

/// Async-work descriptors for the Collection screen (fcis.md §6.4). Positions
/// are pre-computed by the (pure) updater and ride in the effect, so the shell
/// and write repo carry no ordering logic.
sealed class CollectionEffect {
  const CollectionEffect();
}

/// Read the header + ordered feed + link candidates (§8.7) for [collectionId].
class LoadCollectionEffect extends CollectionEffect {
  const LoadCollectionEffect(this.collectionId);
  final String collectionId;
}

/// Append a card of [kind] at [position] (§8.4). [text] is the body or URL.
class AddCardEffect extends CollectionEffect {
  const AddCardEffect({
    required this.collectionId,
    required this.kind,
    required this.position,
    this.text,
  });
  final String collectionId;
  final CardKind kind;
  final String position;
  final String? text;
}

class EditCardEffect extends CollectionEffect {
  const EditCardEffect(this.cardId, this.text);
  final String cardId;
  final String text;
}

class DeleteCardEffect extends CollectionEffect {
  const DeleteCardEffect(this.cardId);
  final String cardId;
}

class ReorderCardEffect extends CollectionEffect {
  const ReorderCardEffect(this.cardId, this.position);
  final String cardId;
  final String position;
}

class LinkEffect extends CollectionEffect {
  const LinkEffect({required this.cardId, required this.targetCollectionId});
  final String cardId;
  final String targetCollectionId;
}

class EditTitleEffect extends CollectionEffect {
  const EditTitleEffect(this.collectionId, this.title);
  final String collectionId;
  final String title;
}
