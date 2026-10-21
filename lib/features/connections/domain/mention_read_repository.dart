import 'package:knit/features/connections/domain/connections_failure.dart';
import 'package:knit/features/connections/domain/unlinked_mentions.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the "Mentioned in" section (§4.4, business_logic.md
/// §5): every live card of every live collection, flattened to its text, and
/// the cards already linking to [collectionId]. Which of them mention the
/// collection is the pure [UnlinkedMentionFinder]'s call (§8.6.5).
abstract interface class MentionReadRepository {
  Future<Result<MentionCorpus, ConnectionsFailure>> loadMentionCorpus(
    String collectionId,
  );
}
