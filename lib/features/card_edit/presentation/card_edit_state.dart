import 'package:flutter/foundation.dart';

enum CardEditStatus { editing, saving, failed }

/// State for the Card Edit page (§4.3). The text being edited lives in a
/// page-owned [TextEditingController]; [initialText] only seeds it on entry.
/// [status] gates the Save control (disabled while [CardEditStatus.saving]).
@immutable
class CardEditState {
  const CardEditState({
    this.status = CardEditStatus.editing,
    this.cardId = '',
    this.initialText = '',
    this.errorMessage,
  });

  final CardEditStatus status;
  final String cardId;
  final String initialText;
  final String? errorMessage;

  CardEditState copyWith({
    CardEditStatus? status,
    String? cardId,
    String? initialText,
    String? errorMessage,
  }) =>
      CardEditState(
        status: status ?? this.status,
        cardId: cardId ?? this.cardId,
        initialText: initialText ?? this.initialText,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}
