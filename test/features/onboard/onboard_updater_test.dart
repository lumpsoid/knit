import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/onboard/domain/identity_card.dart';
import 'package:knit/features/onboard/presentation/onboard_action.dart';
import 'package:knit/features/onboard/presentation/onboard_effect.dart';
import 'package:knit/features/onboard/presentation/onboard_state.dart';
import 'package:knit/features/onboard/presentation/onboard_updater.dart';

void main() {
  const updater = OnboardUpdater();

  test('Get started advances welcome → nickname', () {
    final (next, effects) = updater.update(
      const OnboardState(),
      const GetStartedTapped(),
    );
    expect(next.step, OnboardStep.nickname);
    expect(effects, isNull);
  });

  test('nickname submit is gated on non-empty', () {
    const blank = OnboardState(step: OnboardStep.nickname, nickname: '  ');
    final (stay, _) = updater.update(blank, const NicknameSubmitted());
    expect(stay.step, OnboardStep.nickname);

    const named = OnboardState(step: OnboardStep.nickname, nickname: 'mira');
    final (go, _) = updater.update(named, const NicknameSubmitted());
    expect(go.step, OnboardStep.explainIdentity);
  });

  test(
    'Generate goes to generating and emits CreateIdentityEffect (trimmed)',
    () {
      const state = OnboardState(
        step: OnboardStep.explainIdentity,
        nickname: '  mira ',
      );
      final (next, effects) = updater.update(
        state,
        const GenerateIdentityTapped(),
      );
      expect(next.step, OnboardStep.generating);
      expect(next.hasError, isFalse);
      expect(effects, hasLength(1));
      expect((effects!.single as CreateIdentityEffect).nickname, 'mira');
    },
  );

  test('IdentityCreated reveals the identity', () {
    const card = IdentityCard(
      nickname: 'mira',
      publicKeyHex: 'ab12',
      fingerprint: 'a4f9',
    );
    final (next, _) = updater.update(
      const OnboardState(step: OnboardStep.generating, nickname: 'mira'),
      const IdentityCreated(card),
    );
    expect(next.step, OnboardStep.reveal);
    expect(next.identity, same(card));
  });

  test('failure returns to explain with the error flag set', () {
    final (next, _) = updater.update(
      const OnboardState(step: OnboardStep.generating, nickname: 'mira'),
      const IdentityCreationFailed(),
    );
    expect(next.step, OnboardStep.explainIdentity);
    expect(next.hasError, isTrue);
  });

  test('Enter app emits EnterAppEffect', () {
    final (_, effects) = updater.update(
      const OnboardState(step: OnboardStep.reveal),
      const EnterAppTapped(),
    );
    expect(effects, const [EnterAppEffect()]);
  });

  test('back steps explain → nickname → welcome', () {
    final (toNickname, _) = updater.update(
      const OnboardState(step: OnboardStep.explainIdentity),
      const BackTapped(),
    );
    expect(toNickname.step, OnboardStep.nickname);
    final (toWelcome, _) = updater.update(toNickname, const BackTapped());
    expect(toWelcome.step, OnboardStep.welcome);
  });

  group('restore from backup', () {
    const bundle = BackupBundle(
      author: 'aaaa',
      createdAtMs: 0,
      identity: null,
      opLines: [],
      blobs: {},
    );
    const card = IdentityCard(
      nickname: 'mira',
      publicKeyHex: 'aaaa',
      fingerprint: 'a4f9',
    );

    test('Restore opens the picker and clears a prior error', () {
      const failed = OnboardState(restoreError: OnboardRestoreError.failed);
      final (next, effects) = updater.update(failed, const RestoreTapped());
      expect(next.restoreError, isNull);
      expect(effects!.single, isA<PickBackupEffect>());
    });

    test('a picked bundle asks for its passphrase', () {
      final (next, _) = updater.update(
        const OnboardState(),
        const RestorePicked(bundle),
      );
      expect(next.step, OnboardStep.restorePassphrase);
      expect(next.restoreBundle, same(bundle));
    });

    test('submitting the passphrase restores the held bundle', () {
      const asking = OnboardState(
        step: OnboardStep.restorePassphrase,
        restoreBundle: bundle,
      );
      final (next, effects) = updater.update(
        asking,
        const RestorePassphraseSubmitted('pass'),
      );
      expect(next.step, OnboardStep.restoring);
      final effect = effects!.single as RestoreBackupEffect;
      expect(effect.bundle, same(bundle));
      expect(effect.passphrase, 'pass');
    });

    test('an empty passphrase is ignored', () {
      const asking = OnboardState(
        step: OnboardStep.restorePassphrase,
        restoreBundle: bundle,
      );
      final (next, effects) = updater.update(
        asking,
        const RestorePassphraseSubmitted(''),
      );
      expect(next.step, OnboardStep.restorePassphrase);
      expect(effects, isNull);
    });

    test('a wrong passphrase asks again with the bundle still held', () {
      const restoring = OnboardState(
        step: OnboardStep.restoring,
        restoreBundle: bundle,
      );
      final (next, _) = updater.update(
        restoring,
        const RestorePassphraseRejected(),
      );
      expect(next.step, OnboardStep.restorePassphrase);
      expect(next.restoreBundle, same(bundle));
      expect(next.restoreError, OnboardRestoreError.wrongPassphrase);
    });

    test('a rejected restore returns to the welcome with the reason', () {
      final (next, _) = updater.update(
        const OnboardState(step: OnboardStep.restoring),
        const RestoreRejected(OnboardRestoreError.noIdentity),
      );
      expect(next.step, OnboardStep.welcome);
      expect(next.restoreError, OnboardRestoreError.noIdentity);
    });

    test('a restored identity is revealed as a welcome back', () {
      final (next, _) = updater.update(
        const OnboardState(step: OnboardStep.restoring),
        const IdentityRestored(card),
      );
      expect(next.step, OnboardStep.reveal);
      expect(next.identity, same(card));
      expect(next.restored, isTrue);
      expect(next.restoreBundle, isNull);
    });

    test('back from the passphrase step drops the bundle', () {
      const asking = OnboardState(
        step: OnboardStep.restorePassphrase,
        restoreBundle: bundle,
      );
      final (next, _) = updater.update(asking, const BackTapped());
      expect(next.step, OnboardStep.welcome);
      expect(next.restoreBundle, isNull);
    });
  });

  test('mounting the page starts a fresh ceremony', () {
    const revealed = OnboardState(step: OnboardStep.reveal, nickname: 'mira');
    final (next, _) = updater.update(revealed, const ViewAttached());
    expect(next.step, OnboardStep.welcome);
    expect(next.nickname, isEmpty);
  });
}
