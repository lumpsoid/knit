import 'package:knit/sync/storage/quarantine/domain/quarantine_schema.dart';

/// Why an op was quarantined (spec §8.8). `skew` may auto-retry once the device
/// clock is back within bound; `bad_sig` and `hint_mismatch` are terminal.
enum QuarantineReason {
  badSig,
  skew,
  hintMismatch;

  static QuarantineReason fromDb(String str) => switch (str) {
    'bad_sig' => QuarantineReason.badSig,
    'skew' => QuarantineReason.skew,
    'hint_mismatch' => QuarantineReason.hintMismatch,
    _ => throw ArgumentError('unknown quarantine reason: $str'),
  };

  String toDb() => switch (this) {
    QuarantineReason.badSig => 'bad_sig',
    QuarantineReason.skew => 'skew',
    QuarantineReason.hintMismatch => 'hint_mismatch',
  };
}

/// A quarantined op row (spec §6.7) — keeps the full received op verbatim for
/// diagnosis.
class QuarantinedOp {
  const QuarantinedOp({
    required this.opId,
    required this.reason,
    required this.rawOp,
    required this.seenAt,
    this.relaySeq,
  });

  factory QuarantinedOp.fromDb(Map<String, Object?> row) => QuarantinedOp(
    opId: row[QuarantineSchema.colOpId]! as String,
    relaySeq: row[QuarantineSchema.colRelaySeq] as int?,
    reason: QuarantineReason.fromDb(row[QuarantineSchema.colReason]! as String),
    rawOp: row[QuarantineSchema.colRawOp]! as String,
    seenAt: row[QuarantineSchema.colSeenAt]! as int,
  );

  final String opId;
  final int? relaySeq;
  final QuarantineReason reason;

  /// The full received op envelope, verbatim (the canonical payload for now;
  /// the relay wire bytes arrive with the relay task).
  final String rawOp;
  final int seenAt;

  Map<String, Object?> toDb() => {
    QuarantineSchema.colOpId: opId,
    QuarantineSchema.colRelaySeq: relaySeq,
    QuarantineSchema.colReason: reason.toDb(),
    QuarantineSchema.colRawOp: rawOp,
    QuarantineSchema.colSeenAt: seenAt,
  };

  @override
  String toString() => 'QuarantinedOp(${reason.toDb()} $opId)';
}
