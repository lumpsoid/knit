import 'package:knit/features/onboard/domain/identity_card.dart';

/// Intents + async-result deliveries for Onboard (fcis.md §6.4).
sealed class OnboardAction {
  const OnboardAction();
}

class ViewAttached extends OnboardAction {
  const ViewAttached();
}

class GetStartedTapped extends OnboardAction {
  const GetStartedTapped();
}

class NicknameChanged extends OnboardAction {
  const NicknameChanged(this.value);
  final String value;
}

class NicknameSubmitted extends OnboardAction {
  const NicknameSubmitted();
}

class BackTapped extends OnboardAction {
  const BackTapped();
}

class GenerateIdentityTapped extends OnboardAction {
  const GenerateIdentityTapped();
}

class IdentityCreated extends OnboardAction {
  const IdentityCreated(this.card);
  final IdentityCard card;
}

class IdentityCreationFailed extends OnboardAction {
  const IdentityCreationFailed(this.message);
  final String message;
}

class EnterAppTapped extends OnboardAction {
  const EnterAppTapped();
}

class DeactivateFeature extends OnboardAction {
  const DeactivateFeature();
}
