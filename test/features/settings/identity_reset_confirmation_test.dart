import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/settings/domain/identity_reset_confirmation.dart';

void main() {
  test('the nickname is the confirmation word', () {
    const confirmation = IdentityResetConfirmation('mira');
    expect(confirmation.word, 'mira');
    expect(confirmation.accepts(' mira '), isTrue);
    expect(confirmation.accepts('Mira'), isFalse);
  });

  test('without a nickname the fallback word confirms', () {
    const confirmation = IdentityResetConfirmation('  ');
    expect(confirmation.word, IdentityResetConfirmation.fallbackWord);
    expect(confirmation.accepts('reset'), isTrue);
  });
}
