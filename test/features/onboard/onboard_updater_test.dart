import 'package:flutter_test/flutter_test.dart';
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
}
