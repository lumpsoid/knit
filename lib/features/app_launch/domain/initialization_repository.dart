/// The init seam (composition.md §1) — the single, infallible-by-contract entry
/// App Launch awaits to bring the dependency graph up. It composes the concrete
/// startup steps (open the DB, run migrations, restore the clock) internally;
/// callers never see them. Concrete impls live in `infra/` and differ per graph
/// (prod sqflite, dev in-memory).
abstract interface class InitializationRepository {
  Future<void> initialize();
}
