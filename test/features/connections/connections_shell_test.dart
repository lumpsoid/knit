import 'package:effect_emitter/effect_emitter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/recents/recents.dart';
import 'package:knit/features/card_links/domain/card_links_failure.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/card_links/domain/card_links_write_repository.dart';
import 'package:knit/features/card_links/domain/link_targets_read_repository.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/connections/domain/connections_failure.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/domain/connections_read_repository.dart';
import 'package:knit/features/connections/domain/mention_read_repository.dart';
import 'package:knit/features/connections/domain/unlinked_mentions.dart';
import 'package:knit/features/connections/presentation/connections_action.dart';
import 'package:knit/features/connections/presentation/connections_effect.dart';
import 'package:knit/features/connections/presentation/connections_shell.dart';
import 'package:knit/features/connections/presentation/connections_ui_effect.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

/// The Connections shell's "Mentioned in" half (§4.4, §8.6.5) over fake ports:
/// the read corpus goes through the pure finder, and Link writes a
/// card→collection link through the shared card links, then re-reads.
class _UnusedRead implements ConnectionsReadRepository {
  @override
  Future<Result<ConnectionsData, ConnectionsFailure>> loadConnections(
    ConnectedEntityKind kind,
    String id,
  ) => throw UnimplementedError();
}

class _FakeMentions implements MentionReadRepository {
  _FakeMentions(this.result);
  final Result<MentionCorpus, ConnectionsFailure> result;

  @override
  Future<Result<MentionCorpus, ConnectionsFailure>> loadMentionCorpus(
    String collectionId,
  ) async => result;
}

class _UnusedTargets implements LinkTargetsReadRepository {
  @override
  Future<Result<List<LinkTarget>, CardLinksFailure>> loadCollections() =>
      throw UnimplementedError();

  @override
  Future<Result<List<LinkTarget>, CardLinksFailure>> loadCards(
    String collectionId,
  ) => throw UnimplementedError();

  @override
  Future<Result<LinkedTargets, CardLinksFailure>> loadLinkedTargets(
    String cardId,
  ) => throw UnimplementedError();
}

class _FakeLinkWrite implements CardLinksWriteRepository {
  _FakeLinkWrite({this.fail = false});
  final bool fail;
  final added = <(String, ConnectedEntityKind, String)>[];
  final sourceKinds = <ConnectedEntityKind>[];
  final removed = <String>[];

  @override
  Future<Result<String, CardLinksFailure>> addLink({
    required ConnectedEntityKind sourceKind,
    required String sourceId,
    required ConnectedEntityKind targetKind,
    required String targetId,
  }) async {
    if (fail) return const Failure(CardLinksWriteFailure('disk full'));
    added.add((sourceId, targetKind, targetId));
    sourceKinds.add(sourceKind);
    return const Ok('link-1');
  }

  @override
  Future<Result<String, CardLinksFailure>> removeLink(String linkId) async {
    if (fail) return const Failure(CardLinksWriteFailure('disk full'));
    removed.add(linkId);
    return Ok(linkId);
  }
}

void main() {
  late List<ConnectionsUiEffect> uiEffects;
  late EffectEmitter<ConnectionsUiEffect> emitter;

  setUp(() {
    uiEffects = [];
    emitter = EffectEmitter<ConnectionsUiEffect>()..attach(uiEffects.add);
  });

  ConnectionsShell shell({
    Result<MentionCorpus, ConnectionsFailure>? corpus,
    _FakeLinkWrite? write,
  }) => ConnectionsShell(
    readRepository: _UnusedRead(),
    mentionRepository: _FakeMentions(
      corpus ?? const Ok(MentionCorpus(cards: [], linkedCardIds: <String>{})),
    ),
    cardLinks: CardLinksController(
      readRepository: _UnusedTargets(),
      writeRepository: write ?? _FakeLinkWrite(),
      recentsReadRepository: InMemoryRecentTargetsRepository(),
      recentsWriteRepository: InMemoryRecentTargetsRepository(),
    ),
    effectEmitter: emitter,
    logger: Logger('test.connections'),
  );

  MentionCandidate card(String id, String text, {bool canLink = true}) =>
      MentionCandidate(
        cardId: id,
        collectionId: 'elsewhere',
        collectionTitle: 'Elsewhere',
        text: text,
        updatedAtMs: 1,
        canLink: canLink,
      );

  test('mentions come from the corpus through the finder', () async {
    final dispatched = <ConnectionsAction>[];
    await shell(
      corpus: Ok(
        MentionCorpus(
          cards: [
            card('hit', 'packing for kyoto'),
            card('miss', 'nothing here'),
            card('linked', 'kyoto again'),
            card('foreign', 'kyoto', canLink: false),
          ],
          linkedCardIds: const {'linked'},
        ),
      ),
    ).run(
      const LoadMentionsEffect(collectionId: 'kyoto', title: 'Kyoto'),
      dispatch: dispatched.add,
    );
    final loaded = dispatched.single as MentionsLoaded;
    expect(loaded.collectionId, 'kyoto');
    expect(loaded.mentions.items.map((m) => m.cardId), ['hit']);
  });

  test('a failed mention read dispatches nothing', () async {
    final dispatched = <ConnectionsAction>[];
    await shell(corpus: const Failure(ConnectionsLoadFailure('boom'))).run(
      const LoadMentionsEffect(collectionId: 'kyoto', title: 'Kyoto'),
      dispatch: dispatched.add,
    );
    expect(dispatched, isEmpty);
    expect(uiEffects, isEmpty);
  });

  test('Link writes a card→collection link, then re-reads', () async {
    final write = _FakeLinkWrite();
    final dispatched = <ConnectionsAction>[];
    await shell(write: write).run(
      const LinkMentionEffect(cardId: 'card', collectionId: 'kyoto'),
      dispatch: dispatched.add,
    );
    expect(write.added.single, (
      'card',
      ConnectedEntityKind.collection,
      'kyoto',
    ));
    expect(dispatched.single, isA<ReloadRequested>());
    expect(uiEffects, isEmpty);
  });

  test('a failed Link says so and re-reads', () async {
    final dispatched = <ConnectionsAction>[];
    await shell(write: _FakeLinkWrite(fail: true)).run(
      const LinkMentionEffect(cardId: 'card', collectionId: 'kyoto'),
      dispatch: dispatched.add,
    );
    expect(
      (uiEffects.single as ConnectionsShowMessageUiEffect).message,
      ConnectionsMessage.linkFailed,
    );
    expect(dispatched.single, isA<ReloadRequested>());
  });

  group('Remove + Undo (§4.4)', () {
    const ends = LinkEnds(
      sourceKind: ConnectedEntityKind.collection,
      sourceId: 'hub',
      targetKind: ConnectedEntityKind.card,
      targetId: 'c9',
    );

    test('Remove deletes the link, offers Undo, then re-reads', () async {
      final write = _FakeLinkWrite();
      final dispatched = <ConnectionsAction>[];
      await shell(write: write).run(
        const RemoveLinkEffect(linkId: 'l1', ends: ends),
        dispatch: dispatched.add,
      );
      expect(write.removed, ['l1']);
      expect((uiEffects.single as ConnectionsLinkRemovedUiEffect).ends, ends);
      expect(dispatched.single, isA<ReloadRequested>());
    });

    test('a failed Remove says so, offers no Undo, and re-reads', () async {
      final dispatched = <ConnectionsAction>[];
      await shell(write: _FakeLinkWrite(fail: true)).run(
        const RemoveLinkEffect(linkId: 'l1', ends: ends),
        dispatch: dispatched.add,
      );
      expect(
        (uiEffects.single as ConnectionsShowMessageUiEffect).message,
        ConnectionsMessage.removeFailed,
      );
      expect(dispatched.single, isA<ReloadRequested>());
    });

    test('Undo links the same two ends again, then re-reads', () async {
      final write = _FakeLinkWrite();
      final dispatched = <ConnectionsAction>[];
      await shell(
        write: write,
      ).run(const RestoreLinkEffect(ends), dispatch: dispatched.add);
      expect(write.added.single, ('hub', ConnectedEntityKind.card, 'c9'));
      expect(write.sourceKinds.single, ConnectedEntityKind.collection);
      expect(uiEffects, isEmpty);
      expect(dispatched.single, isA<ReloadRequested>());
    });

    test('a failed Undo says so', () async {
      final dispatched = <ConnectionsAction>[];
      await shell(
        write: _FakeLinkWrite(fail: true),
      ).run(const RestoreLinkEffect(ends), dispatch: dispatched.add);
      expect(
        (uiEffects.single as ConnectionsShowMessageUiEffect).message,
        ConnectionsMessage.linkFailed,
      );
      expect(dispatched.single, isA<ReloadRequested>());
    });
  });
}
