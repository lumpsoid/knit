/// Quarantine storage (spec §6.7/§8.8) — ops set aside on failed verification or
/// the skew guard, retained for diagnosis. Abstracted: sqflite + in-memory.
library;

export 'domain/domain.dart';
export 'infra/infra.dart';
