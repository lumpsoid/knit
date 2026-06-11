/// Narrow port for minting entity ids (business_logic.md §5). Every new synced
/// entity needs a globally-unique, time-ordered TEXT id (spec §6.1); the
/// write path depends on this abstraction, not on a concrete UUID library, so
/// the scheme can change and tests can inject a deterministic generator.
///
/// A profile is the one entity that does **not** use this — its id is the
/// pubkey (§7.4.7).
abstract interface class IdGenerator {
  /// A fresh, globally-unique id. Implementations return time-ordered ids so
  /// they double as the §8.7 creation-order tiebreak.
  String newId();
}
